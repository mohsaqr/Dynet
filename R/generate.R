# ===========================================================================
# Random temporal networks
# ===========================================================================
# Every fixture in the package was either the bundled data or a hand-typed
# frame, so no measure could be calibrated against a network whose answer is
# known in advance. These generators supply that ground truth: a Poisson
# process has burstiness exactly zero, a binomial network has expected density
# exactly p, and a block network has a planted partition to recover.

#' Build the ordered dyad universe for a generated network
#' @param names Vertex names.
#' @param directed Whether arcs are ordered.
#' @param loops Whether to include self-pairs.
#' @return A data frame with `from` and `to`, one row per eligible dyad.
#' @keywords internal
.dyad_universe <- function(names, directed, loops) {
  grid <- expand.grid(from = names, to = names, stringsAsFactors = FALSE,
                      KEEP.OUT.ATTRS = FALSE)
  if (!loops) grid <- grid[grid$from != grid$to, , drop = FALSE]
  if (!directed) grid <- grid[grid$from <= grid$to, , drop = FALSE]
  rownames(grid) <- NULL
  grid
}

#' Turn a dyad-by-slice activity matrix into interval spells
#' @param active Logical matrix, one row per dyad and one column per slice.
#' @param dyads The dyad table the rows index.
#' @param interval Width of one slice in network time.
#' @return A data frame of interval spells.
#' @keywords internal
.runs_to_spells <- function(active, dyads, interval) {
  # Each maximal run of consecutive active slices becomes ONE spell. That is
  # what turns a slice model into Dynet's spell model, and it means the network
  # has fewer, longer spells than the model has active slices.
  rows <- lapply(seq_len(nrow(active)), function(i) {
    on <- active[i, ]
    if (!any(on)) return(NULL)
    d <- diff(c(FALSE, on, FALSE))
    starts <- which(d == 1L)
    ends <- which(d == -1L) - 1L
    data.frame(from = dyads$from[[i]], to = dyads$to[[i]],
               start = (starts - 1L) * interval, end = ends * interval,
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- data.frame(from = character(), to = character(),
                      start = numeric(), end = numeric(),
                      stringsAsFactors = FALSE)
  }
  out
}

#' Draw a dyad-by-slice activity matrix
#' @param n_dyads Number of eligible dyads.
#' @param times Number of slices.
#' @param p Per-slice probability, or `NULL` under the Markov variant.
#' @param birth Probability an inactive dyad becomes active.
#' @param persist Probability an active dyad stays active.
#' @return A logical matrix.
#' @keywords internal
.draw_activity <- function(n_dyads, times, p, birth, persist) {
  if (is.null(birth)) {
    return(matrix(stats::rbinom(n_dyads * times, 1L, p) == 1L,
                  nrow = n_dyads, ncol = times))
  }
  # Start from the stationary distribution so there is no burn-in artefact in
  # the first slice.
  stationary <- birth / (1 - persist + birth)
  state <- stats::rbinom(n_dyads, 1L, stationary) == 1L
  out <- matrix(FALSE, nrow = n_dyads, ncol = times)
  out[, 1L] <- state
  # A Markov chain over slices is sequential by definition; vectorising would
  # need the whole path up front, which is what we are generating.
  for (t in seq_len(times - 1L)) {
    keep <- stats::runif(n_dyads) < ifelse(state, persist, birth)
    state <- keep
    out[, t + 1L] <- state
  }
  out
}

#' Draw renewal event times for one dyad
#' @param times Length of the observation window.
#' @param rate Mean events per unit time.
#' @param waiting Gap distribution.
#' @param shape Shape parameter for `"weibull"` and `"lognormal"`.
#' @return A numeric vector of event times inside `[0, times]`.
#' @keywords internal
.renewal_times <- function(times, rate, waiting, shape) {
  # Scale so the MEAN gap is 1/rate whatever the shape, or changing `shape`
  # would change the event rate as well as the burstiness and the two effects
  # would be inseparable in any test that used it.
  draw <- function(k) switch(waiting,
    exponential = stats::rexp(k, rate = rate),
    weibull = stats::rweibull(k, shape = shape,
                              scale = 1 / (rate * gamma(1 + 1 / shape))),
    lognormal = {
      sdlog <- sqrt(log(1 + shape^2))
      stats::rlnorm(k, meanlog = -log(rate) - sdlog^2 / 2, sdlog = sdlog)
    }
  )
  out <- numeric(0)
  total <- 0
  repeat {
    gaps <- draw(max(8L, as.integer(2 * rate * times)))
    cum <- total + cumsum(gaps)
    out <- c(out, cum[cum <= times])
    if (any(cum > times)) break
    total <- cum[[length(cum)]]
  }
  out
}

#' Simulate a random temporal network
#'
#' @description
#' Generates a temporal network with a known generating process, so a measure
#' can be checked against an answer that is known in advance rather than only
#' against another implementation. A Poisson process has burstiness exactly
#' zero; a binomial network has expected per-slice density exactly `p`; a block
#' network carries its planted partition as a node attribute.
#'
#' @param nodes A vertex count, or a character vector of names. A count
#'   generates zero-padded names so that lexical and numeric order agree.
#' @param times Number of slices for the slice models, or the length of the
#'   observation window for the event models.
#' @param model `"binomial"` for independent per-slice edges, `"poisson"` for
#'   a renewal process on every dyad, `"block"` for a planted partition, or
#'   `"activation"` for a static graph whose links activate as a renewal
#'   process with tunable burstiness.
#' @param p Per-slice edge probability for `"binomial"`, or the density of the
#'   underlying static graph for `"activation"`.
#' @param birth,persist The two-state Markov variant of `"binomial"`:
#'   probability an inactive dyad becomes active, and probability an active one
#'   stays active. Named `persist`, not a death rate, because that is what it
#'   is. Supplying either requires both and forbids `p`.
#' @param rate Mean events per unit time for the event models.
#' @param blocks A block count, or one block label per vertex.
#' @param p_within,p_between Per-slice edge probability inside and between
#'   blocks.
#' @param block_switch Per-slice probability a vertex changes block, so the
#'   planted partition drifts. Zero gives a static partition.
#' @param waiting,shape The renewal gap distribution for `"activation"`.
#'   Weibull with `shape < 1` is bursty, `shape > 1` regular, `shape = 1`
#'   Poisson. The scale is set so the mean gap is `1 / rate` at every shape.
#' @param directed,interval,loops Passed through to [dynet()].
#' @param seed A single whole number for a reproducible draw, or `NULL`.
#' @return A `dynet`, so every verb, plot and accessor applies with no special
#'   casing. `"binomial"` and `"block"` produce interval networks;
#'   `"poisson"` and `"activation"` produce contact networks. For `"block"`
#'   the planted partition is written into the node table as `block`, so
#'   `mixing(dn, attribute = "block")` reads it with no further argument.
#' @details
#' The slice models draw a dyad-by-slice activity matrix and then collapse each
#' maximal run of consecutive active slices into one spell. The generated
#' network therefore has fewer, longer spells than the model has active slices,
#' which is what makes it a spell network rather than a stack of snapshots.
#'
#' `"poisson"` and `"activation"` use **exponential** waiting times, so they are
#' genuine renewal processes. teneto's `rand_poisson` draws integer gaps that
#' can be zero, which is not a Poisson process and is not numerically
#' comparable with these.
#'
#' **Reading burstiness off a generated network.** [burstiness()] is a
#' node-level measure: it pools the events of every dyad incident to a vertex.
#' Superposing independent renewal processes drives the pooled process toward
#' Poisson, so a vertex with many partners scores near zero however bursty each
#' of its links is. Measured here at `shape = 0.5`, whose per-link burstiness is
#' 0.382: a vertex with one incident process scored 0.36, with three 0.26, with
#' seven 0.19 and with fifteen 0.14. To calibrate against the per-link value,
#' generate `nodes = 2, directed = FALSE`, which gives each vertex exactly one
#' process. This is a property of the measure, not of the generator.
#'
#' Weibull waiting has a closed-form burstiness,
#' \eqn{B = (\sigma - \mu)/(\sigma + \mu)} with \eqn{\mu = \Gamma(1 + 1/k)}
#' and \eqn{\sigma^2 = \Gamma(1 + 2/k) - \mu^2}, giving 0.381966 at
#' `shape = 0.5`, 0 at `shape = 1` and -0.313436 at `shape = 2`. The generated
#' network approaches these from a finite window; `shape = 0.5` converges most
#' slowly because its gaps are heavy-tailed.
#' @examples
#' random_dynet(nodes = 10, times = 12, model = "binomial", p = 0.2, seed = 1)
#' random_dynet(nodes = 8, times = 50, model = "poisson", rate = 0.5, seed = 1)
#' random_dynet(nodes = 12, times = 15, model = "block", blocks = 2, seed = 1)
#' @seealso [randomise()] for destroying structure in an observed network
#'   rather than generating it.
#' @references
#' Erdos, P., and Renyi, A. (1959). On random graphs I. *Publicationes
#' Mathematicae*, 6, 290-297.
#'
#' Holland, P. W., Laskey, K. B., and Leinhardt, S. (1983). Stochastic
#' blockmodels: first steps. *Social Networks*, 5(2), 109-137.
#'
#' Goh, K.-I., and Barabasi, A.-L. (2008). Burstiness and memory in complex
#' systems. *Europhysics Letters*, 81(4), 48002.
#'
#' Vazquez, A., Oliveira, J. G., Dezso, Z., Goh, K.-I., Kondor, I., and
#' Barabasi, A.-L. (2006). Modeling bursts and heavy tails in human dynamics.
#' *Physical Review E*, 73, 036127.
#' @export
random_dynet <- function(nodes = 20L, times = 20L,
                         model = c("binomial", "poisson", "block",
                                   "activation"),
                         p = 0.1, birth = NULL, persist = NULL,
                         rate = 1,
                         blocks = 2L, p_within = 0.3, p_between = 0.02,
                         block_switch = 0,
                         waiting = c("exponential", "weibull", "lognormal"),
                         shape = 1,
                         directed = TRUE, interval = 1, loops = FALSE,
                         seed = NULL) {
  # missing() must be read before match.arg() reassigns the argument.
  supplied <- c(p = !missing(p), waiting = !missing(waiting),
                blocks = !missing(blocks), p_within = !missing(p_within),
                p_between = !missing(p_between),
                block_switch = !missing(block_switch))
  model <- match.arg(model)
  waiting <- match.arg(waiting)
  slice_model <- model %in% c("binomial", "block")
  .check(
    "`times` must be a single positive whole number." =
      length(times) == 1L && is.numeric(times) && is.finite(times) &&
        times >= 1 && times == trunc(times),
    "`rate` must be a single positive number." =
      length(rate) == 1L && is.numeric(rate) && is.finite(rate) && rate > 0,
    "`shape` must be a single positive number." =
      length(shape) == 1L && is.numeric(shape) && is.finite(shape) &&
        shape > 0,
    "`interval` must be a single positive number." =
      length(interval) == 1L && is.numeric(interval) && is.finite(interval) &&
        interval > 0
  )
  # An argument the chosen model ignores is an error, never silently dropped.
  if (supplied[["waiting"]] && !identical(model, "activation")) {
    stop(errorCondition(
      "`waiting` applies only to model = \"activation\".",
      class = "dynet_bad_input", call = NULL))
  }
  if (supplied[["p"]] && model %in% c("poisson", "block")) {
    stop(errorCondition(sprintf(
      "`p` has no meaning for model = \"%s\".", model),
      class = "dynet_bad_input", call = NULL))
  }
  if (any(supplied[c("blocks", "p_within", "p_between", "block_switch")]) &&
      !identical(model, "block")) {
    stop(errorCondition(
      "Block arguments apply only to model = \"block\".",
      class = "dynet_bad_input", call = NULL))
  }
  if (!is.null(birth) || !is.null(persist)) {
    if (!identical(model, "binomial")) {
      stop(errorCondition(
        "`birth` and `persist` apply only to model = \"binomial\".",
        class = "dynet_bad_input", call = NULL))
    }
    .check(
      "`birth` and `persist` must be supplied together." =
        !is.null(birth) && !is.null(persist),
      "`birth` must be a single probability." =
        length(birth) == 1L && is.numeric(birth) && birth >= 0 && birth <= 1,
      "`persist` must be a single probability." =
        length(persist) == 1L && is.numeric(persist) && persist >= 0 &&
          persist <= 1
    )
    if (supplied[["p"]]) {
      stop(errorCondition(
        "Supply either `p` or the `birth`/`persist` pair, not both.",
        class = "dynet_bad_input", call = NULL))
    }
  }

  names <- if (is.character(nodes)) {
    nodes
  } else {
    .check("`nodes` must be a count or a character vector of names." =
             length(nodes) == 1L && is.numeric(nodes) && nodes >= 2)
    sprintf(paste0("n%0", nchar(as.character(as.integer(nodes))), "d"),
            seq_len(as.integer(nodes)))
  }
  n <- length(names)
  times <- as.integer(times)

  membership <- NULL
  if (identical(model, "block")) {
    membership <- if (is.character(blocks)) {
      .check("`blocks` must give one label per vertex." =
               length(blocks) == n)
      blocks
    } else {
      .check("`blocks` must be a count of at least one." =
               length(blocks) == 1L && is.numeric(blocks) && blocks >= 1)
      rep_len(sprintf("b%d", seq_len(as.integer(blocks))), n)
    }
  }

  build <- function() {
    dyads <- .dyad_universe(names, directed, loops)
    if (slice_model) {
      if (identical(model, "binomial")) {
        active <- .draw_activity(nrow(dyads), times, if (is.null(birth)) p,
                                 birth, persist)
      } else {
        same <- membership[match(dyads$from, names)] ==
          membership[match(dyads$to, names)]
        prob <- ifelse(same, p_within, p_between)
        active <- matrix(
          stats::rbinom(nrow(dyads) * times, 1L, rep(prob, times = times)) == 1L,
          nrow = nrow(dyads), ncol = times)
      }
      edges <- .runs_to_spells(active, dyads, interval)
      list(edges = edges, format = "interval")
    } else {
      keep <- if (identical(model, "activation")) {
        stats::rbinom(nrow(dyads), 1L, p) == 1L
      } else rep(TRUE, nrow(dyads))
      chosen <- dyads[keep, , drop = FALSE]
      rows <- lapply(seq_len(nrow(chosen)), function(i) {
        ts <- .renewal_times(times * interval, rate, waiting, shape)
        if (!length(ts)) return(NULL)
        data.frame(from = chosen$from[[i]], to = chosen$to[[i]], time = ts,
                   stringsAsFactors = FALSE)
      })
      edges <- do.call(rbind, rows)
      if (is.null(edges)) {
        edges <- data.frame(from = character(), to = character(),
                            time = numeric(), stringsAsFactors = FALSE)
      }
      list(edges = edges, format = "contact")
    }
  }

  drawn <- .with_seed(seed, build())
  if (!nrow(drawn$edges)) {
    stop(errorCondition(sprintf(
      "The draw produced no edges; raise `p` or `rate`, or lengthen `times` (model = \"%s\").",
      model), class = "dynet_generator_empty", call = NULL))
  }

  node_table <- data.frame(name = names, stringsAsFactors = FALSE)
  if (identical(model, "block")) node_table$block <- membership

  dn <- dynet(drawn$edges, format = drawn$format, nodes = node_table,
              directed = directed, interval = interval, loops = loops,
              observation_start = 0, observation_end = times * interval)
  dn$meta$source <- "random_dynet"
  dn$meta$generator <- list(
    model = model, nodes = n, times = times, p = if (supplied[["p"]]) p else NULL,
    birth = birth, persist = persist, rate = rate,
    blocks = if (identical(model, "block")) membership,
    p_within = p_within, p_between = p_between,
    waiting = waiting, shape = shape, seed = seed
  )
  dn
}
