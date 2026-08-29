# ===========================================================================
# dyn_centrality() — time-varying vertex centrality
# ===========================================================================

.node_measures <- c("degree", "indegree", "outdegree", "strength", "prestige",
                    "closeness", "betweenness",
                    "eigenvector", "pagerank", "hub", "authority",
                    "coreness", "constraint", "power", "harary",
                    "information", "load", "flow_betweenness", "diffusion",
                    "participation")

# The measures for which "out" and "in" mean something. Every other measure
# has a single directional definition and ignores `mode`, as in igraph.
.mode_aware_measures <- c("degree", "indegree", "outdegree", "strength",
                          "closeness", "coreness", "harary", "eigenvector",
                          "diffusion", "participation")

.temporal_measures <- c("closeness", "betweenness", "reach", "reach_count",
                        "katz")

# Temporal measures computed by streaming the contact sequence rather than by
# searching for paths. They need no per-source tree, so the trees are built
# only when a path-based measure is actually requested.
.stream_measures <- c("katz")

#' Resolve the `mode` argument, which may name several directions at once
#'
#' The signature carries every direction as its default, so an untouched `mode`
#' has to be read as `"all"` rather than as a request for all three.
#'
#' @param mode The `mode` argument as supplied.
#' @return A character vector of unique modes.
#' @examples
#' Dynet:::.resolve_modes(c("all", "out", "in"))
#' Dynet:::.resolve_modes("in")
#' @keywords internal
.resolve_modes <- function(mode) {
  choices <- c("all", "out", "in")
  if (identical(mode, choices)) return("all")
  .check("`mode` must be a character vector naming one or more directions." =
           is.character(mode) && length(mode) > 0L && !anyNA(mode))
  # `match.arg(several.ok = TRUE)` drops names it cannot match and only errors
  # when none match at all, so an unknown direction would pass unnoticed.
  unknown <- setdiff(mode, choices)
  if (length(unknown) > 0L) {
    stop(errorCondition(
      sprintf("Unknown `mode` %s; use %s.",
              paste(sQuote(unknown), collapse = ", "),
              paste(sQuote(choices), collapse = ", ")),
      class = "dynet_bad_input", call = NULL))
  }
  unique(mode)
}

#' Expand measures across directions into one job per output column
#'
#' Asking for in- and out-degree in one call must not silently return two
#' identically named stacks, and asking a direction-blind measure for three
#' directions must not compute it three times. Directions are therefore
#' dropped where they mean nothing, and the surviving ones are suffixed only
#' when more than one direction was requested -- so a single-`mode` call keeps
#' the plain measure name it has always had.
#'
#' @param measure Character vector of measures.
#' @param mode Character vector of resolved directions.
#' @param directed Whether the network is directed.
#' @return A data frame with `measure`, `mode` and `label`, one row per column
#'   the result will carry.
#' @examples
#' Dynet:::.measure_modes("degree", c("in", "out"), TRUE)
#' Dynet:::.measure_modes(c("degree", "betweenness"), c("all", "in"), TRUE)
#' @keywords internal
.measure_modes <- function(measure, mode, directed) {
  many <- length(mode) > 1L
  rows <- lapply(measure, function(m) {
    aware <- directed && m %in% .mode_aware_measures
    modes <- if (aware) mode else mode[[1L]]
    data.frame(
      measure = m, mode = modes,
      label = if (many && aware) {
        ifelse(modes == "all", m, paste0(m, "_", modes))
      } else m,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Time-varying vertex centrality
#'
#' @description
#' Centrality for every vertex at every time point. Ask for several measures
#' in one call and they arrive stacked in a single tidy frame, one row per
#' vertex, time point and measure.
#'
#' Two scopes answer two different questions. `"snapshot"` measures the
#' network as it stands in each time bin, so the result is a trajectory of
#' ordinary centrality. `"temporal"` measures the vertex against time-respecting
#' paths across the whole observation window, or the supplied `start`-to-`end`
#' traversal window for temporal reach, closeness, and betweenness. This quantity has no counterpart in a
#' static network: it cannot run backwards in time, so it is never inflated the
#' way a flattened network is.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure One or more of `"degree"`, `"strength"`, `"prestige"`, `"closeness"`,
#'   `"betweenness"`, `"eigenvector"`, `"pagerank"`, `"hub"`, `"authority"`,
#'   `"coreness"`, `"constraint"`, `"power"`, `"harary"`, `"information"`,
#'   `"load"`, `"flow_betweenness"`, or `"diffusion"` for snapshot scope;
#'   `"closeness"`,
#'   `"betweenness"`, `"reach"` or `"reach_count"` for temporal scope.
#' @param scope `"snapshot"` for a value per time bin, `"temporal"` for one
#'   value per vertex computed on time-respecting paths.
#' @param mode Which edges count on a directed network: `"all"` both
#'   directions, `"out"` outgoing only, `"in"` incoming only. Name several at
#'   once -- `mode = c("all", "in", "out")` -- to get degree, in-degree and
#'   out-degree from a single call; the extra directions are then labelled
#'   `degree_in` and `degree_out` in the `measure` column, while a call naming
#'   one direction keeps the plain measure name. Applies to
#'   `"degree"`, `"strength"`, `"closeness"`, `"coreness"`, `"harary"` and
#'   `"eigenvector"`; the remaining measures have a single directional
#'   definition and ignore it. Ignored
#'   entirely on an undirected network. In-degree is therefore
#'   `mode = "in"`. The old `"indegree"` and `"outdegree"` measure names
#'   remain as deprecated aliases.
#' @param sessions How to treat sessions: `"bounded"` keeps paths inside a
#'   session, `"collapse"` ignores sessions, `"separate"` reports each session
#'   on its own rows.
#' @param sample Deprecated. `"instant"` is equivalent to `window = 0`;
#'   `"window"` uses the current positive/default window.
#' @param start,end First and last time at which to measure. Default to the
#'   observed range. For temporal measures these are inclusive path-traversal
#'   bounds. A network built from dates may be addressed with dates.
#' @param step How often to measure. Defaults to the interval the network was
#'   built with.
#' @param window How much time each measurement covers. Defaults to `step`,
#'   which tiles the period into disjoint bins. A larger value slides an
#'   overlapping window; `0` samples the network at each point in time.
#'   `"all"` measures the whole observed period as one window, closed on the
#'   right so an event at the final instant is inside it; it cannot be combined
#'   with `step`, and under `sessions = "separate"` or discontinuous
#'   observation it gives one window per session or observed component.
#' @param damping Damping factor for PageRank.
#' @param exponent Attenuation factor for Bonacich `"power"`. Positive rewards
#'   being connected to well-connected others; negative rewards the opposite,
#'   which is the bargaining reading.
#' @param lambda Nonnegative multiplier for `"diffusion"`. Diffusion degree is
#'   the sum of the selected degree of a vertex and all of its one-step
#'   neighbours, multiplied by `lambda`.
#' @param prestige Prestige definition. `"indegree"` counts distinct active
#'   incoming dyads. `"indegree.rownorm"` first gives every active sender one
#'   unit split equally across its distinct outgoing dyads, then sums the
#'   received mass. `"indegree.rowcolnorm"` balances a total-support binary
#'   adjacency to doubly stochastic form; feasible scores are necessarily
#'   uniform. `"domain"` counts the distinct other vertices with a directed
#'   path into each vertex in the active snapshot. `"domain.proximity"`
#'   discounts that incoming domain fraction by its mean directed hop distance.
#'   `"eigenvector"` uses the unique nonnegative Perron ray of the transposed
#'   binary adjacency. `"eigenvector.rownorm"` first divides every nonzero
#'   binary sender row by its outgoing-dyad count and then solves the same
#'   certified incoming Perron equation. `"eigenvector.colnorm"` instead
#'   divides every nonzero binary receiver column by its incoming-dyad count
#'   before solving. `"eigenvector.rowcolnorm"` first certifies total support
#'   and balances binary adjacency to doubly stochastic form. Prestige is
#'   directed and snapshot-only.
#' @param rescale Whether to divide prestige by its total independently
#'   inside every reported time/session block. Zero-total count/proximity
#'   definitions return `NaN`; structurally undefined spectral definitions
#'   return `NA`. This argument requires `measure = "prestige"`.
#' @param criterion For `scope = "temporal"` only: which optimisation problem
#'   the journeys solve. `"foremost_then_shortest"` is the default and what
#'   every earlier release computed; `"min_hops"` counts fewest contacts, which
#'   makes closeness dimensionless and comparable with its static counterpart.
#'   `"foremost"` (pure earliest arrival) is accepted for closeness, where it
#'   equals the default because closeness reads only the arrival, and refused
#'   for betweenness with `dynet_intractable_criterion`, because that needs
#'   the count of every vertex-simple foremost journey, which is #P-hard
#'   (Buss et al., 2024). `"fastest"` measures closeness by journey duration
#'   rather than arrival, so a vertex that is reached late but quickly is
#'   close; betweenness under it is not implemented. Reach and reach count
#'   are identical under all.
#' @param traversal_time Nonnegative duration charged for every temporal-path
#'   hop, in the network's time unit. A calendar network also accepts a scalar
#'   `difftime`. Nonzero values require `scope = "temporal"`.
#'
#' @param beta For `measure = "katz"` only: walk attenuation in `(0, 1]`.
#'   Each additional hop multiplies a walk's contribution by `beta`.
#' @param decay For `measure = "katz"` only: exponential time-decay rate. Zero
#'   weights every past walk equally.
#' @param groups For `measure = "participation"` only: the name of a node
#'   attribute, or one group label per vertex. Required for that measure and
#'   rejected for every other.
#' @return A `dynet_metric`: a tidy data frame with one row per vertex, time
#'   point and measure. Columns are `session` (only when the network has
#'   sessions), `time` (snapshot scope only), `node`, `measure` and `value`.
#'   Print it, [summary()] it, [plot()] it, or take the plain frame with
#'   [as.data.frame()]. A closeness- or betweenness-only temporal result stores
#'   its mathematical choices as direct attributes; a mixed temporal result
#'   stores named records under `measure_metadata`. Snapshot prestige follows
#'   the same direct-versus-scoped metadata convention.
#'
#' @details
#' `step` and `window` are separate on purpose. `step` is how often you look;
#' `window` is how much of the timeline each look takes in. Setting them equal
#' partitions the period; setting `window` larger than `step` is a rolling
#' window, which keeps the resolution of the smaller step while smoothing over
#' the noise of a sparse bin. The arguments match `tsna::tSnaStats()`, where
#' they are called `time.interval` and `aggregate.dur`.
#'
#' `"eigenvector"` is uniquely determined when the Perron eigenvalue has a
#' one-dimensional eigenspace; strong connectivity is a sufficient condition.
#' Disconnected snapshots with equally dominant components can have more than
#' one correct eigenvector, so read the result as a within-snapshot ranking
#' rather than an automatically comparable number across the whole series.
#'
#' Indegree prestige is the column sum of the directed binary active-dyad
#' adjacency matrix. It is exactly snapshot degree with `mode = "in"`:
#' duplicate, split, and overlapping spells and edge weights do not multiply
#' the result, while an explicitly retained directed loop contributes once.
#' With `rescale = TRUE`, the column sums are divided by their block total. A
#' zero total is mathematically undefined and is returned as literal `NaN`.
#'
#' Row-normalized indegree prestige first converts every nonzero binary
#' adjacency row to sum one; zero rows remain all zero. Its column sums are the
#' received sender-nomination mass, so their total is the number of active
#' senders. `rescale = TRUE` divides again by that block total. This closed-form
#' transform is the `sna::prestige(cmode = "indegree.rownorm")` definition on
#' binary matrices. Dynet deliberately ignores edge weights, whereas `sna`
#' uses their magnitudes on valued matrices.
#'
#' Row-column-normalized prestige uses deterministic Sinkhorn--Knopp scaling
#' only when the full binary vertex matrix has total support: every active dyad
#' must belong to a perfect matching. It preserves all binary dyads and does
#' not remove isolates or unsupported edges. Infeasible blocks return `NA` for
#' every vertex with a classed warning. A feasible transform has every incoming
#' column sum equal to one, so raw prestige is uniformly one and rescaled
#' prestige uniformly `1 / n`; this definition is a transform diagnostic, not
#' a vertex ranking. Dynet uses fixed-order sweeps, maximum absolute row/column
#' residual `1e-12`, and at most 10,000 sweeps. It never returns a partial
#' iterate. This deliberately differs from the randomized loose-tolerance
#' annealer in `sna` 2.8.
#'
#' Domain prestige is incoming indegree in the directed reachability graph
#' after excluding its reflexive diagonal. If `H[i,j]` records whether `i = j`
#' or a directed path from `i` to `j` exists, then
#' `p[j] = sum(H[,j]) - 1`. Every distinct reaching vertex counts once,
#' regardless of path length or multiplicity. Loops cannot add self credit,
#' isolates score zero, and a zero-total rescaling returns literal `NaN`.
#' Closure is computed on the binary active snapshot for each reporting block,
#' not on chronologically ordered temporal journeys through the raw spells.
#'
#' Domain-proximity prestige additionally uses the shortest incoming hop
#' distances. For the nonself domain `D[j]`, let `r[j]` be its size and `s[j]`
#' the sum of its finite distances into `j`. The score is zero when `r[j] = 0`
#' and otherwise `r[j]^2 / ((n - 1) * s[j])`: the incoming domain fraction
#' divided by mean hop distance. Unreachable vertices are omitted before the
#' distance sum. This deliberately fixes an arithmetic artifact in `sna` 2.8,
#' whose `FALSE * Inf` operation incorrectly zeros partial nonempty domains.
#'
#' Eigenvector prestige solves `t(B) %*% p = rho * p` for the nonnegative
#' Perron ray of binary adjacency `B`. It requires positive spectral radius and
#' a one-dimensional Perron eigenspace. Raw scores have Euclidean norm one;
#' `rescale = TRUE` makes their sum one. Zero-radius or nonunique blocks return
#' all `NA` with a classed warning and diagnostics. Periodic cycles remain
#' valid even when negative or complex roots share the spectral radius. Dynet
#' uses direct eigenvalues plus an SVD nullity/residual check at tolerance
#' `1e-10`, orients the ray as nonnegative, and never applies elementwise
#' absolute value.
#'
#' Row-normalized eigenvector prestige first forms binary adjacency `B` and
#' divides each nonzero sender row by its number of distinct outgoing dyads;
#' zero rows remain exactly zero. It then solves the certified incoming Perron
#' equation for the transpose of that row-stochastic matrix. Thus each active
#' sender distributes one unit of recursive nomination mass, with no
#' teleportation or dangling-row imputation. Binary session union and retained
#' loop policy occur before row normalization. The positive-radius, geometric-
#' uniqueness, nonnegative-sign, L2/sum-scale, warning, and diagnostic rules
#' are otherwise exactly those of ordinary eigenvector prestige.
#'
#' Column-normalized eigenvector prestige divides each nonzero binary receiver
#' column by its number of distinct incoming dyads; zero columns remain zero.
#' It solves the incoming Perron equation only after that transform. If every
#' vertex has positive indegree, the transformed transpose is row-stochastic
#' and every certified score is necessarily uniform. Nonuniform defined scores
#' therefore require a zero-indegree vertex. Binary union and retained-loop
#' policy precede normalization; certification and scaling remain those above.
#'
#' Row-column-normalized eigenvector prestige composes the total-support and
#' deterministic Sinkhorn--Knopp contract with the certified Perron contract.
#' Infeasible support and nonconvergent balancing terminate before the spectral
#' solve. A completed doubly stochastic transform always has the all-ones
#' Perron ray, but reducible transforms have several such rays and remain
#' undefined. Every fully certified score is therefore exactly uniform:
#' `1 / sqrt(n)` raw or `1 / n` rescaled. This selector diagnoses support,
#' balance, and irreducibility; it is not a vertex ranking.
#'
#' Temporal betweenness is the raw dependency sum over reachable forward
#' ordered pairs. For each source-target pair, its unit dependency is divided
#' equally over every canonical shortest-foremost journey, and an internal
#' vertex receives the fraction of those journeys that contain it. Sources and
#' targets receive no endpoint credit. This ordered-pair convention also
#' applies to undirected contacts because temporal reach is generally
#' asymmetric. The result is not normalized; its fixed range is
#' `[0, (n - 1) * (n - 2)]`.
#'
#' Temporal closeness is inverse mean forward latency over reachable vertices:
#' if \eqn{R_s} is the set of reachable vertices other than source \eqn{s},
#' \deqn{C(s) = |R_s| / \sum_{z \in R_s} (a_z - L),}
#' where \eqn{a_z} is the foremost arrival time and \eqn{L} is the traversal
#' window's lower bound. Every reachable endpoint is included once, regardless
#' of how many optimal paths reach it. A source with no reachable nonself
#' endpoints has value zero. If all reachable endpoints have zero latency, the
#' value is `Inf`; zero-latency endpoints remain in the numerator when mixed
#' with positive latencies. The measure therefore has inverse-time units, is
#' invariant to translating the time axis, and scales inversely when time is
#' rescaled.
#'
#' Temporal measures use [paths()] traversal semantics: nondecreasing
#' times, unlimited waiting, half-open interval spells, and a separate exact
#' timestamp rule for point events. Positive `traversal_time` requires an
#' interval traversal to finish within continuous pair activity; a point event
#' triggers at its timestamp and reaches its endpoint after that duration.
#' `start` and `end` bound every temporal measure. Temporal `"reach"` is the
#' proportion of other vertices reachable in the forward direction, while
#' `"reach_count"` is their number. The source is excluded from both and a
#' singleton proportion is defined as zero. In separate-session output, a
#' session outside a one-sided bound contributes zero-reach rows.
#'
#' @references
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' Tang, J., Musolesi, M., Mascolo, C., Latora, V., & Nicosia, V. (2010).
#' Analysing information flows and key mediators through temporal centrality
#' metrics. *Proceedings of SNS '10*.
#'
#' Buss, S., Molter, H., Niedermeier, R., & Rymar, M. (2024). Algorithmic
#' aspects of temporal betweenness. *Network Science*, 12(2), 160-188.
#'
#' Nicosia, V., Tang, J., Mascolo, C., Musolesi, M., Russo, G., & Latora, V.
#' (2013). Graph metrics for temporal networks. In *Temporal Networks*
#' (pp. 15-40). Springer.
#'
#' Wasserman, S., & Faust, K. (1994). *Social Network Analysis: Methods and
#' Applications*. Cambridge University Press, Chapter 5.
#'
#' Butts, C. T. (2024). *sna: Tools for Social Network Analysis*, version 2.8.
#' doi:10.32614/CRAN.package.sna.
#'
#' Lin, N. (1976). *Foundations of Social Research*. McGraw-Hill.
#'
#' @examples
#' dn <- dynet(school_contacts)
#'
#' dyn_centrality(dn, measure = "degree")
#' dyn_centrality(dn, measure = c("degree", "betweenness"))
#' dyn_centrality(dn, measure = "prestige", rescale = TRUE)
#' dyn_centrality(dn, measure = "prestige",
#'                prestige = "indegree.rownorm")
#' dyn_centrality(dn, measure = "prestige", prestige = "domain")
#' dyn_centrality(dn, measure = "prestige",
#'                prestige = "domain.proximity")
#' dyn_centrality(dn, measure = "prestige", prestige = "eigenvector")
#' dyn_centrality(dn, measure = "prestige",
#'                prestige = "eigenvector.rownorm")
#' dyn_centrality(dn, measure = "prestige",
#'                prestige = "eigenvector.colnorm")
#' dyn_centrality(dn, measure = "prestige",
#'                prestige = "eigenvector.rowcolnorm")
#' # Temporal scope walks journeys between every ordered pair, so it costs far
#' # more than a snapshot and grows steeply with the vertex count. Shown on a
#' # subgraph so the example stays quick.
#' few <- induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara", "Dan", "Eve",
#'                                      "Finn", "Gita", "Hugo"))
#' dyn_centrality(few, measure = "closeness", scope = "temporal")
#' dyn_centrality(few, measure = "reach", scope = "temporal",
#'                start = 0, end = 10)
#'
#' # A seven-day window, stepped one day at a time.
#' dyn_centrality(dn, measure = "degree", step = 1, window = 7)
#'
#' summary(dyn_centrality(dn, measure = "degree"))
#'
#' @details
#' At snapshot scope, declared vertex activity induces the eligible vertex
#' population before any kernel is evaluated. Positive windows independently
#' use any-time vertex and edge unions before induction, while `window = 0`
#' evaluates the exact state. Results remain rectangular over the fixed vertex
#' universe: inactive vertices receive typed `NA`, while eligible isolates keep
#' the centrality kernel's ordinary static result. At temporal scope, declared
#' vertex activity gates the exact source anchor and every hop. Waiting after a
#' valid anchor may cross inactivity; interval traversal requires both endpoints
#' through completion, while a point trigger requires the receiver again after
#' any traversal delay. Fixed node rows and pre-V04 denominators are retained.
#'
#' @export
dyn_centrality <- function(dn,
                           measure = "degree",
                           scope = c("snapshot", "temporal"),
                           sessions = c("bounded", "collapse", "separate"),
                           sample = NULL,
                           damping = 0.85,
                           mode = c("all", "out", "in"),
                           start = NULL, end = NULL,
                           step = NULL, window = NULL,
                           exponent = 1, traversal_time = 0,
                           prestige = "indegree", rescale = FALSE,
                           lambda = 1, groups = NULL,
                           beta = 0.1, decay = 0,
                           criterion = c("foremost_then_shortest",
                                         "min_hops", "foremost", "fastest")) {
  sessions <- match.arg(sessions)
  criterion <- match.arg(criterion)
  .check_dynet(dn, sessions)
  scope <- match.arg(scope)
  if (identical(criterion, "foremost") && "betweenness" %in% measure) {
    .stop_intractable_criterion("betweenness")
  }
  if (identical(criterion, "fastest") && "betweenness" %in% measure) {
    stop(errorCondition(
      "Temporal betweenness under criterion = \"fastest\" is not implemented; use \"foremost_then_shortest\" or \"min_hops\".",
      class = "dynet_bad_input", call = NULL))
  }
  mode  <- .resolve_modes(mode)
  traversal_time <- .as_traversal_time(traversal_time, dn)
  window <- .legacy_sample(window, sample)
  .check(
    "`measure` must be a character vector." = is.character(measure),
    "`measure` must name at least one measure." = length(measure) > 0L,
    "`measure` cannot contain missing values." = !anyNA(measure),
    "`damping` must be a single number strictly between zero and one." =
      is.numeric(damping) && length(damping) == 1L && damping > 0 && damping < 1,
    "`exponent` must be a single finite number." =
      is.numeric(exponent) && length(exponent) == 1L && is.finite(exponent),
    "`lambda` must be a single non-negative finite number." =
      is.numeric(lambda) && length(lambda) == 1L && is.finite(lambda) &&
        lambda >= 0,
    "`prestige` must be one of \"indegree\", \"indegree.rownorm\", \"indegree.rowcolnorm\", \"domain\", \"domain.proximity\", \"eigenvector\", \"eigenvector.rownorm\", \"eigenvector.colnorm\", or \"eigenvector.rowcolnorm\"." =
      is.character(prestige) && length(prestige) == 1L &&
        !is.na(prestige) &&
        prestige %in% c("indegree", "indegree.rownorm",
                        "indegree.rowcolnorm", "domain", "domain.proximity",
                        "eigenvector", "eigenvector.rownorm",
                        "eigenvector.colnorm", "eigenvector.rowcolnorm"),
    "`rescale` must be a single non-missing logical value." =
      is.logical(rescale) && length(rescale) == 1L && !is.na(rescale)
  )

  if (rescale && !"prestige" %in% measure) {
    stop(errorCondition(
      "`rescale = TRUE` requires `measure = \"prestige\"`.",
      class = "dynet_bad_input", call = NULL
    ))
  }

  allowed <- if (identical(scope, "temporal")) .temporal_measures else .node_measures
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown measure %s for scope \"%s\". Available: %s",
              paste(sQuote(bad), collapse = ", "), scope,
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  # `groups` belongs to participation and to nothing else; supplying it
  # elsewhere is an error rather than a silently ignored argument.
  wants_groups <- "participation" %in% measure
  if (!is.null(groups) && !wants_groups) {
    stop(errorCondition(
      "`groups` applies only to measure = \"participation\".",
      class = "dynet_bad_input", call = NULL))
  }
  if ("katz" %in% measure) {
    # A stream measure walks no journeys, so a per-hop traversal cost has no
    # meaning for it. Reject only when every requested measure is a stream
    # measure; a mixed call still needs it for the path-based ones.
    if (traversal_time > 0 && !length(setdiff(measure, .stream_measures))) {
      stop(errorCondition(
        "`traversal_time` has no meaning for a stream measure such as \"katz\", which walks no journeys.",
        class = "dynet_bad_input", call = NULL))
    }
    .check(
      "`beta` must be a single number in (0, 1]." =
        length(beta) == 1L && is.numeric(beta) && is.finite(beta) &&
          beta > 0 && beta <= 1,
      "`decay` must be a single non-negative number." =
        length(decay) == 1L && is.numeric(decay) && is.finite(decay) &&
          decay >= 0
    )
  }
  group_labels <- NULL
  if (wants_groups) {
    if (is.null(groups)) {
      stop(errorCondition(
        "measure = \"participation\" needs `groups`: a node attribute name, or one label per vertex.",
        class = "dynet_bad_input", call = NULL))
    }
    if (length(groups) == 1L && is.character(groups) &&
        groups %in% names(dn$nodes)) {
      group_labels <- as.character(dn$nodes[[groups]])
    } else if (length(groups) == nrow(dn$nodes)) {
      group_labels <- as.character(groups)
      if (!is.null(names(groups))) {
        idx <- match(dn$nodes$name, names(groups))
        if (anyNA(idx)) {
          stop(errorCondition(
            "`groups` is named but does not cover every vertex.",
            class = "dynet_bad_input", call = NULL))
        }
        group_labels <- as.character(groups)[idx]
      }
    } else {
      have <- setdiff(names(dn$nodes), c("id", "label", "name", "x", "y"))
      stop(errorCondition(sprintf(
        "No vertex attribute %s, and `groups` is not one label per vertex. This network has %s.",
        sQuote(as.character(groups)[[1L]]),
        if (length(have)) paste(have, collapse = ", ") else "no attributes"),
        class = "dynet_unknown_attribute", call = NULL))
    }
    if (anyNA(group_labels)) {
      stop(errorCondition(
        "`groups` leaves some vertices unassigned; every vertex needs a label.",
        class = "dynet_bad_input", call = NULL))
    }
  }
  retired <- intersect(measure, c("indegree", "outdegree"))
  if (length(retired) > 0L) {
    warning(sprintf(
      "%s deprecated; use `measure = \"degree\"` with %s.",
      paste(sQuote(retired), collapse = " and "),
      paste(sprintf("`mode = \"%s\"`", sub("degree$", "", retired)),
            collapse = " and ")),
      call. = FALSE)
  }
  if (!dn$directed) {
    undirected_only <- intersect(measure,
                                 c("indegree", "outdegree", "hub", "authority",
                                   "prestige"))
    if (length(undirected_only) > 0L) {
      stop(errorCondition(
        sprintf("%s needs a directed network; this one is undirected.",
                paste(sQuote(undirected_only), collapse = ", ")),
        class = "dynet_needs_directed", call = NULL))
    }
  }

  if (identical(scope, "temporal")) {
    if (!identical(mode, "all")) {
      stop(errorCondition(
        "`mode` has no meaning for `scope = \"temporal\"`; temporal paths use the network's recorded direction.",
        class = "dynet_bad_input", call = NULL))
    }
    grid_args <- c("step", "window")
    given <- grid_args[!vapply(list(step, window), is.null,
                               logical(1L))]
    if (length(given) > 0L) {
      stop(errorCondition(sprintf(
        "%s %s no meaning for scope = \"temporal\", which measures time-respecting paths across the whole window rather than a grid of snapshots.",
        paste(sQuote(given), collapse = ", "),
        if (length(given) == 1L) "has" else "have"),
        class = "dynet_bad_input", call = NULL))
    }
    return(.temporal_centrality(
      dn, measure, sessions, start, end, traversal_time, beta, decay,
      criterion
    ))
  }

  if (traversal_time > 0) {
    stop(errorCondition(
      "A nonzero `traversal_time` applies only to `scope = \"temporal\"`.",
      class = "dynet_bad_input", call = NULL
    ))
  }

  jobs <- .measure_modes(measure, mode, dn$directed)
  spec <- .window_spec(dn, start, end, step, window)
  prestige_diagnostics <- list()
  df <- .over_bins(dn, sessions, node_level = TRUE, spec = spec,
    snapshot = TRUE, fun = function(enc, act, bin, state) {
      binary_full <- .adjacency(enc, act, dn$directed, weighted = FALSE)
      binary_a <- binary_full[state$index, state$index, drop = FALSE]
      valued_a <- if ("strength" %in% measure) {
        valued_full <- .adjacency(enc, act, dn$directed, weighted = TRUE)
        valued_full[state$index, state$index, drop = FALSE]
      } else {
        binary_a
      }
      values <- lapply(seq_len(nrow(jobs)), function(job) {
        m <- jobs$measure[[job]]
        value <- if (length(state$index)) {
          .snapshot_measure(
            m, if (identical(m, "strength")) valued_a else binary_a,
            dn$directed, damping, jobs$mode[[job]], exponent, prestige,
            rescale, lambda, group_labels[state$index]
          )
        } else numeric()
        diagnostic <- attr(value, "prestige_diagnostic")
        if (!is.null(diagnostic)) {
          session_label <- if (identical(sessions, "separate")) {
            labels <- unique(enc$session[!is.na(enc$session)])
            if (length(labels) == 1L) labels else NA_character_
          } else {
            NA_character_
          }
          prestige_diagnostics[[length(prestige_diagnostics) + 1L]] <<-
            data.frame(
              session = session_label, time = bin$time,
              stage = diagnostic$stage %||% if (
                identical(diagnostic$status, "infeasible")
              ) {
                "support"
              } else if (identical(diagnostic$status, "nonconverged")) {
                "balance"
              } else {
                "spectrum"
              },
              status = diagnostic$status, reason = diagnostic$reason,
              iterations = diagnostic$iterations %||% NA_integer_,
              residual = diagnostic$residual %||% NA_real_,
              balance_status = diagnostic$balance_status %||% if (
                diagnostic$status %in% c("infeasible", "nonconverged")
              ) diagnostic$status else NA_character_,
              balance_reason = diagnostic$balance_reason %||% if (
                diagnostic$status %in% c("infeasible", "nonconverged")
              ) diagnostic$reason else NA_character_,
              balance_iterations =
                diagnostic$balance_iterations %||% if (
                  diagnostic$status %in% c("infeasible", "nonconverged")
                ) diagnostic$iterations %||% NA_integer_ else NA_integer_,
              balance_residual = diagnostic$balance_residual %||% if (
                diagnostic$status %in% c("infeasible", "nonconverged")
              ) diagnostic$residual %||% NA_real_ else NA_real_,
              spectral_radius = diagnostic$spectral_radius %||% NA_real_,
              eigenspace_dimension =
                diagnostic$eigenspace_dimension %||% NA_integer_,
              eigen_residual = diagnostic$eigen_residual %||% if (
                identical(diagnostic$status, "undefined")
              ) diagnostic$residual %||% NA_real_ else NA_real_,
              stringsAsFactors = FALSE
            )
        }
        expanded <- rep(NA_real_, enc$n)
        expanded[state$index] <- as.numeric(value)
        expanded
      })
      stats::setNames(values, jobs$label)
    })

  out <- .metric(
    df, level = "node",
    what = if (nrow(jobs) == 1L) {
      .measure_label(measure, prestige)
    } else {
      "Centrality"
    },
    dn = dn, spec = spec,
    mode = if (length(mode) == 1L && !identical(mode, "all") && dn$directed &&
              any(measure %in% .mode_aware_measures)) mode else NULL
  )
  attr(out, "vertex_population") <- "eligible_window_any_induced"
  attr(out, "vertex_window_rule") <- if (spec$window == 0) {
    "instant_exact"
  } else "any"
  attr(out, "edge_endpoint_rule") <- "induced_after_elementwise_union"
  attr(out, "inactive_vertex_value") <- "NA"
  attr(out, "eligible_kernel_order") <- "induce_then_compute_then_expand"
  attr(out, "vertex_observation") <- "component_intersection_non_destructive"
  attr(out, "session_vertex_aggregation") <- switch(
    sessions, collapse = "calendar_union", bounded = "session_induced_union",
    separate = "session_local"
  )
  if ("prestige" %in% measure) {
    metadata <- list(
      definition = prestige,
      direction = "incoming",
      matrix_transform = if (prestige %in% c(
        "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
        "eigenvector.rowcolnorm"
      )) {
        if (identical(prestige, "eigenvector.rownorm")) {
          "transpose_row_stochastic_binary_adjacency"
        } else if (identical(prestige, "eigenvector.colnorm")) {
          "transpose_column_stochastic_binary_adjacency"
        } else if (identical(prestige, "eigenvector.rowcolnorm")) {
          "transpose_sinkhorn_knopp_balanced_binary_adjacency"
        } else {
          "transpose_binary_adjacency"
        }
      } else if (identical(prestige, "domain.proximity")) {
        "directed_unweighted_geodesics"
      } else if (identical(prestige, "domain")) {
        "directed_transitive_closure"
      } else if (identical(prestige, "indegree.rowcolnorm")) {
        "sinkhorn_knopp_row_column"
      } else if (identical(prestige, "indegree.rownorm")) {
        "row_stochastic"
      } else {
        "none"
      },
      normalization = if (rescale) {
        "sum_to_one"
      } else if (prestige %in% c(
        "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
        "eigenvector.rowcolnorm"
      )) {
        "l2_unit"
      } else {
        "none"
      },
      unit = if (prestige %in% c(
        "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
        "eigenvector.rowcolnorm"
      )) {
        if (identical(prestige, "eigenvector.rownorm")) {
          if (rescale) {
            "share_of_incoming_row_stochastic_perron_weight"
          } else {
            "l2_incoming_row_stochastic_perron_weight"
          }
        } else if (identical(prestige, "eigenvector.colnorm")) {
          if (rescale) {
            "share_of_incoming_column_stochastic_perron_weight"
          } else {
            "l2_incoming_column_stochastic_perron_weight"
          }
        } else if (identical(prestige, "eigenvector.rowcolnorm")) {
          if (rescale) {
            "share_of_incoming_doubly_stochastic_perron_weight"
          } else {
            "l2_incoming_doubly_stochastic_perron_weight"
          }
        } else if (rescale) {
          "share_of_incoming_perron_weight"
        } else {
          "l2_incoming_perron_weight"
        }
      } else if (identical(prestige, "domain.proximity")) {
        if (rescale) {
          "share_of_lin_domain_proximity"
        } else {
          "lin_domain_proximity"
        }
      } else if (identical(prestige, "domain")) {
        if (rescale) {
          "share_of_ordered_reachable_pairs"
        } else {
          "distinct_reaching_vertices"
        }
      } else if (identical(prestige, "indegree.rowcolnorm")) {
        if (rescale) {
          "share_of_balanced_incoming_nomination_mass"
        } else {
          "balanced_incoming_nomination_mass"
        }
      } else if (identical(prestige, "indegree.rownorm")) {
        if (rescale) {
          "share_of_active_sender_nomination_mass"
        } else {
          "active_sender_nomination_mass"
        }
      } else if (rescale) {
        "share_of_active_binary_dyads"
      } else {
        "active_binary_dyads"
      },
      weights = "ignored",
      loops = if (prestige %in% c(
        "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
        "eigenvector.rowcolnorm"
      )) {
        if (identical(prestige, "eigenvector.rownorm")) {
          "retained_once_before_row_normalization"
        } else if (identical(prestige, "eigenvector.colnorm")) {
          "retained_once_before_column_normalization"
        } else if (identical(prestige, "eigenvector.rowcolnorm")) {
          "retained_once_before_support_and_balancing"
        } else {
          "retained_once_before_eigensolve"
        }
      } else if (prestige %in% c("domain", "domain.proximity")) {
        "no_effect_self_excluded"
      } else if (identical(prestige, "indegree.rowcolnorm")) {
        "retained_once_before_balancing"
      } else {
        "retained_once"
      },
      zero_total = if (prestige %in%
                       c("indegree.rowcolnorm", "eigenvector",
                         "eigenvector.rownorm", "eigenvector.colnorm",
                         "eigenvector.rowcolnorm")) {
        "not_applicable_feasible"
      } else {
        "NaN"
      },
      session_aggregation = if (identical(sessions, "separate")) {
        "session_local"
      } else {
        "binary_calendar_union"
      }
    )
    if (identical(prestige, "indegree.rownorm")) {
      metadata$zero_rows <- "all_zero"
    }
    if (identical(prestige, "indegree.rowcolnorm")) {
      metadata$support_requirement <- "total_support_full_vertex_matrix"
      metadata$support_policy <- "preserve_all_binary_dyads"
      metadata$undefined <- "NA"
      metadata$solver_tolerance <- 1e-12
      metadata$error_norm <- "max_absolute_margin"
      metadata$maximum_iterations <- 10000L
    }
    if (identical(prestige, "domain")) {
      metadata$path_scope <- "static_active_snapshot"
      metadata$path_weighting <- "unweighted_distinct_reachers"
      metadata$self_reach <- "excluded"
      metadata$unreachable <- "zero"
    }
    if (identical(prestige, "domain.proximity")) {
      metadata$path_scope <- "static_active_snapshot"
      metadata$domain <- "distinct_reaching_nonself_vertices"
      metadata$distance <- "minimum_hop_count"
      metadata$path_weighting <- "domain_fraction_over_mean_distance"
      metadata$unreachable <- "excluded_from_domain_and_distance_sum"
      metadata$formula <- "r^2/((n-1)*sum_distance)"
      metadata$network_size_normalization <- "n_minus_one"
      metadata$zero_domain <- "zero"
    }
    if (prestige %in% c(
      "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
      "eigenvector.rowcolnorm"
    )) {
      metadata$eigenvalue <- "positive_perron_root"
      metadata$spectral_requirement <-
        "positive_radius_unique_perron_eigenspace"
      metadata$uniqueness <- "geometric_multiplicity_one"
      metadata$sign <- "nonnegative"
      metadata$undefined <- "NA"
      metadata$solver <- "base_eigen_svd_nullity"
      metadata$solver_tolerance <- 1e-10
      metadata$error_norm <- "max_absolute_eigen_residual"
    }
    if (identical(prestige, "eigenvector.rownorm")) {
      metadata$row_denominator <- "distinct_outgoing_binary_dyads"
      metadata$zero_rows <- "all_zero"
    }
    if (identical(prestige, "eigenvector.colnorm")) {
      metadata$column_denominator <- "distinct_incoming_binary_dyads"
      metadata$zero_columns <- "all_zero"
    }
    if (identical(prestige, "eigenvector.rowcolnorm")) {
      metadata$pipeline_order <-
        "binary_union_total_support_balance_transpose_perron"
      metadata$support_requirement <- "total_support_full_vertex_matrix"
      metadata$support_policy <- "preserve_all_binary_dyads"
      metadata$balance_solver <- "fixed_order_sinkhorn_knopp"
      metadata$balance_solver_tolerance <- 1e-12
      metadata$balance_error_norm <- "max_absolute_margin"
      metadata$balance_maximum_iterations <- 10000L
      metadata$defined_values <- "uniform"
      metadata$terminal_stages <- "support_balance_spectrum"
    }
    if (identical(measure, "prestige")) {
      for (field in names(metadata)) { # Direct attributes mirror one record.
        attr(out, field) <- metadata[[field]]
      }
    } else {
      attr(out, "measure_metadata") <- list(prestige = metadata)
    }
  }
  if (length(prestige_diagnostics)) {
    diagnostics <- do.call(rbind, prestige_diagnostics)
    rownames(diagnostics) <- NULL
    attr(out, "prestige_diagnostics") <- diagnostics
    if (any(diagnostics$status == "infeasible")) {
      warning(warningCondition(sprintf(
        "Row-column prestige is structurally undefined in %d reporting block(s); values are NA. See `prestige_diagnostics`.",
        sum(diagnostics$status == "infeasible")
      ), class = "dynet_prestige_infeasible", call = NULL))
    }
    if (any(diagnostics$status == "nonconverged")) {
      warning(warningCondition(sprintf(
        "Row-column prestige did not converge in %d reporting block(s); values are NA. See `prestige_diagnostics`.",
        sum(diagnostics$status == "nonconverged")
      ), class = "dynet_prestige_nonconvergence", call = NULL))
    }
    if (any(diagnostics$status == "undefined")) {
      warning(warningCondition(sprintf(
        "Eigenvector prestige is undefined in %d reporting block(s); values are NA. See `prestige_diagnostics`.",
        sum(diagnostics$status == "undefined")
      ), class = "dynet_prestige_eigen_undefined", call = NULL))
    }
  }
  out
}

#' Participation coefficient of every vertex in one snapshot
#'
#' Guimera and Amaral's coefficient: one minus the sum of squared shares of a
#' vertex's contacts falling in each group. Zero when every contact is inside a
#' single group, approaching `1 - 1/g` when they are spread evenly over `g`.
#'
#' @param b Binary adjacency for the bin.
#' @param directed Whether the network is directed.
#' @param mode Which margin counts as a contact.
#' @param groups Character vector of group labels, one per vertex, in the
#'   adjacency's own order.
#' @return A numeric vector, one value per vertex. `NaN` for an eligible
#'   vertex of degree zero, whose shares are 0/0.
#' @keywords internal
.participation <- function(b, directed, mode, groups) {
  n <- nrow(b)
  if (is.null(groups) || !n) return(rep(NaN, n))
  k <- .margin(b, directed, mode)
  indicator <- outer(groups, sort(unique(groups)), "==") * 1
  # The per-group counts must use the SAME margin as k, or the shares do not
  # sum to one and the coefficient breaks its own 1 - 1/g bound.
  contacts <- if (!directed) {
    b
  } else {
    switch(mode, out = b, `in` = t(b), all = b + t(b), b)
  }
  # Contacts of i falling in each group: one matrix product, no loop.
  per_group <- contacts %*% indicator
  share <- per_group / k
  out <- 1 - rowSums(share^2)
  # A degree-zero vertex has no shares, so the coefficient is undefined. teneto
  # returns 0 there; Dynet returns NaN, matching its own convention that an
  # undefined ratio is NaN and never a fabricated zero. Note NA (not eligible)
  # and NaN (eligible, degree zero) are different statements.
  out[!is.finite(k) | k == 0] <- NaN
  unname(out)
}

#' Compute one snapshot centrality measure
#' @param m Measure name.
#' @param a Adjacency matrix for the bin.
#' @param directed Whether the network is directed.
#' @param damping PageRank damping factor.
#' @param mode Which edges count: `"all"`, `"out"` or `"in"`.
#' @param exponent Attenuation factor for Bonacich power.
#' @param prestige Prestige definition.
#' @param rescale Whether to normalize prestige by its block total.
#' @param lambda Diffusion-degree multiplier.
#' @param groups Group labels for `"participation"`, one per vertex.
#' @return A numeric vector, one value per vertex.
#' @keywords internal
.snapshot_measure <- function(m, a, directed, damping, mode = "all",
                              exponent = 1, prestige = "indegree",
                              rescale = FALSE, lambda = 1, groups = NULL) {
  b <- .binary(a, directed)
  degree_b <- (a > 0) * 1
  if (!directed) {
    degree_b <- pmax(degree_b, t(degree_b))
    # An undirected loop contributes two stubs, as in igraph and cograph.
    diag(degree_b) <- 2 * (diag(a) > 0)
  }
  switch(m,
    participation = .participation(degree_b, directed, mode, groups),
    degree      = .margin(degree_b, directed, mode),
    indegree    = .margin(degree_b, directed, "in"),
    outdegree   = .margin(degree_b, directed, "out"),
    strength    = .margin(a, directed, mode),
    prestige    = if (prestige %in% c(
      "eigenvector", "eigenvector.rownorm", "eigenvector.colnorm",
      "eigenvector.rowcolnorm"
    )) {
      .eigen_prestige(a, rescale, definition = prestige, warn = FALSE)
    } else if (identical(prestige, "domain.proximity")) {
      .domain_proximity_prestige(a, rescale)
    } else if (identical(prestige, "domain")) {
      .domain_prestige(a, rescale)
    } else {
      .indegree_prestige(a, rescale, prestige, warn = FALSE)
    },
    closeness   = .closeness(a, directed, mode),
    betweenness = .betweenness(a, directed),
    # `b`, not `a`: an edge counts once however many spells produced it, as
    # for every other centrality here. Volume is what `strength` is for.
    eigenvector = .eigen_centrality(b, directed, mode),
    pagerank    = .pagerank(b, damping),
    hub         = .hits(b, "hub"),
    authority   = .hits(b, "authority"),
    coreness    = .coreness(a, directed, mode),
    constraint  = .constraint(b),
    power       = .bonacich_power(a, directed, exponent),
    harary      = .harary(a, directed, mode),
    information = .information(a),
    load        = .load(a, directed),
    flow_betweenness = .flow_betweenness(a, directed),
    diffusion   = .diffusion_degree(a, directed, mode, lambda)
  )
}

#' Deterministic bipartite perfect matching
#'
#' Rows and columns are the two vertex copies of a square binary support
#' matrix. Ordered augmenting paths make the returned matching reproducible.
#'
#' @param a Square numeric or logical support matrix.
#' @return An integer vector mapping every row to its matched column, or `NULL`
#'   when no perfect matching exists.
#' @examples
#' cycle <- matrix(c(0, 1, 1, 0), 2, 2, byrow = TRUE)
#' Dynet:::.perfect_matching(cycle)
#' @references
#' Sinkhorn, R., & Knopp, P. (1967). Concerning nonnegative matrices and
#' doubly stochastic matrices. *Pacific Journal of Mathematics*, 21, 343-348.
#' doi:10.2140/pjm.1967.21.343.
#' @keywords internal
.perfect_matching <- function(a) {
  b <- a > 0
  n <- nrow(b)
  if (n != ncol(b) || n == 0L) return(NULL)
  match_col <- integer(n)
  augment <- function(i) {
    neighbours <- which(b[i, ])
    # Reassignment along an augmenting path is sequential by definition.
    for (j in neighbours) {
      if (seen[j]) next
      seen[j] <<- TRUE
      owner <- match_col[j]
      if (owner == 0L || augment(owner)) {
        match_col[j] <<- i
        return(TRUE)
      }
    }
    FALSE
  }
  # Each successful row extends the preceding partial matching.
  for (i in seq_len(n)) {
    seen <- rep(FALSE, n)
    if (!augment(i)) return(NULL)
  }
  row_match <- integer(n)
  row_match[match_col] <- seq_len(n)
  row_match
}

#' Certify total support of a binary matrix
#'
#' A support has total support exactly when every positive entry belongs to a
#' perfect matching. Relative to one matching, nonmatching edges belong to an
#' alternating cycle precisely when their row endpoints lie in the same
#' strongly connected component.
#'
#' @param a Square numeric or logical support matrix.
#' @return A list with logical `ok`, character `reason`, the selected
#'   `matching`, and logical `unsupported` matrix.
#' @examples
#' Dynet:::.total_support(matrix(c(0, 1, 1, 0), 2, 2, byrow = TRUE))
#' Dynet:::.total_support(matrix(c(1, 1, 0, 1), 2, 2, byrow = TRUE))
#' @references
#' Sinkhorn, R., & Knopp, P. (1967). Concerning nonnegative matrices and
#' doubly stochastic matrices. *Pacific Journal of Mathematics*, 21, 343-348.
#' doi:10.2140/pjm.1967.21.343.
#' @keywords internal
.total_support <- function(a) {
  b <- a > 0
  n <- nrow(b)
  blank <- matrix(FALSE, n, n)
  if (n != ncol(b) || n == 0L ||
      any(rowSums(b) == 0L) || any(colSums(b) == 0L)) {
    return(list(ok = FALSE, reason = "zero_margin", matching = NULL,
                unsupported = b))
  }
  matching <- .perfect_matching(b)
  if (is.null(matching)) {
    return(list(ok = FALSE, reason = "no_perfect_matching", matching = NULL,
                unsupported = b))
  }

  match_col <- integer(n)
  match_col[matching] <- seq_len(n)
  edges <- which(b, arr.ind = TRUE)
  next_row <- match_col[edges[, 2L]]
  alternating <- blank
  alternating[cbind(edges[, 1L], next_row)] <- TRUE
  reach <- alternating
  diag(reach) <- TRUE
  # Transitive closure is sequential because paths through k depend on the
  # closure already established through vertices 1, ..., k - 1.
  for (k in seq_len(n)) {
    reach <- reach | outer(reach[, k], reach[k, ], FUN = "&")
  }
  allowed <- edges[, 1L] == next_row |
    reach[cbind(next_row, edges[, 1L])]
  unsupported <- blank
  if (any(!allowed)) unsupported[edges[!allowed, , drop = FALSE]] <- TRUE
  list(
    ok = !any(unsupported),
    reason = if (any(unsupported)) "not_total_support" else NA_character_,
    matching = matching,
    unsupported = unsupported
  )
}

#' One fixed-order Sinkhorn--Knopp sweep
#'
#' @param x Positive-support matrix with no zero row or column.
#' @return `x` after dividing rows by their sums and then columns by theirs.
#' @examples
#' Dynet:::.rowcol_sweep(matrix(c(1, 1, 1, 0), 2, 2))
#' @references
#' Sinkhorn, R., & Knopp, P. (1967). Concerning nonnegative matrices and
#' doubly stochastic matrices. *Pacific Journal of Mathematics*, 21, 343-348.
#' doi:10.2140/pjm.1967.21.343.
#' @keywords internal
.rowcol_sweep <- function(x) {
  x <- x / rowSums(x)
  t(t(x) / colSums(x))
}

#' Deterministic row-column balancing of binary support
#'
#' For total-support binary `B`, fixed-order Sinkhorn--Knopp sweeps seek the
#' unique doubly stochastic matrix `X = D_r B D_c`. The maximum absolute row
#' or column margin error controls termination. No partial result is approved
#' after the iteration cap.
#'
#' @param a Square adjacency or support matrix; positive values are binarized.
#' @param tol Positive maximum permitted absolute margin error.
#' @param max_iter Positive integer cap on complete row-plus-column sweeps.
#' @return A list containing `matrix`, `status`, `reason`, `iterations`, and
#'   `residual`. Status is `"ok"`, `"infeasible"`, or `"nonconverged"`.
#' @examples
#' b <- matrix(c(1, 1, 0, 1, 1, 1, 0, 1, 1), 3, 3, byrow = TRUE)
#' Dynet:::.rowcol_balance(b)
#' @references
#' Sinkhorn, R. (1964). A relationship between arbitrary positive matrices
#' and doubly stochastic matrices. *Annals of Mathematical Statistics*, 35,
#' 876-879. doi:10.1214/aoms/1177703591.
#'
#' Knight, P. A. (2008). The Sinkhorn-Knopp algorithm: convergence and
#' applications. *SIAM Journal on Matrix Analysis and Applications*, 30,
#' 261-275. doi:10.1137/060659624.
#' @keywords internal
.rowcol_balance <- function(a, tol = 1e-12, max_iter = 10000L) {
  b <- (a > 0) * 1
  support <- .total_support(b)
  if (!support$ok) {
    return(list(
      matrix = matrix(NA_real_, nrow(b), ncol(b)),
      status = "infeasible", reason = support$reason,
      iterations = 0L, residual = NA_real_
    ))
  }
  residual <- function(x) max(
    abs(rowSums(x) - 1), abs(colSums(x) - 1)
  )
  x <- b
  error <- residual(x)
  if (is.finite(error) && error <= tol) {
    return(list(matrix = x, status = "ok", reason = NA_character_,
                iterations = 0L, residual = error))
  }
  # Every sweep depends on the complete scaling produced by its predecessor.
  for (iteration in seq_len(max_iter)) {
    x <- .rowcol_sweep(x)
    supported <- b > 0
    numerically_valid <- all(x[!supported] == 0) &&
      all(is.finite(x[supported])) && all(x[supported] > 0)
    if (!numerically_valid) {
      return(list(
        matrix = matrix(NA_real_, nrow(b), ncol(b)),
        status = "nonconverged", reason = "nonfinite_arithmetic",
        iterations = as.integer(iteration), residual = Inf
      ))
    }
    error <- residual(x)
    if (is.finite(error) && error <= tol) {
      return(list(matrix = x, status = "ok", reason = NA_character_,
                  iterations = as.integer(iteration), residual = error))
    }
  }
  list(matrix = matrix(NA_real_, nrow(b), ncol(b)), status = "nonconverged",
       reason = "iteration_cap", iterations = as.integer(max_iter),
       residual = error)
}

#' Directed indegree prestige
#'
#' @details
#' For binary adjacency `B`, ordinary indegree prestige is the column sum
#' `p[j] = sum(B[, j])`. For `definition = "indegree.rownorm"`, each positive
#' row is first divided by its row sum and each zero row remains zero, so
#' `p[j] = sum(B[i, j] / sum(B[i, ]))` over active senders. The optional final
#' rescaling divides `p` by `sum(p)`; an all-zero total yields literal `NaN`.
#' For `"indegree.rowcolnorm"`, total support is certified first and
#' deterministic Sinkhorn--Knopp scaling makes every row and column sum one.
#' Feasible scores are therefore exactly one, or `1 / n` when rescaled;
#' structurally undefined or nonconvergent blocks return `NA`.
#'
#' @param a Binary directed adjacency matrix for one snapshot block.
#' @param rescale Whether to divide the column sums by their total.
#' @param definition One of ordinary `"indegree"`,
#'   `"indegree.rownorm"`, which divides every nonzero binary row by its sum
#'   before taking column sums, or `"indegree.rowcolnorm"`, which requires
#'   total support and doubly stochastic scaling.
#' @param tol Internal S03 maximum absolute margin error.
#' @param max_iter Internal S03 cap on complete balancing sweeps.
#' @param warn Whether direct nonconvergence emits its classed warning. Public
#'   calls aggregate warnings after all reporting blocks.
#' @return A numeric vector, one value per matrix column. Ordinary zero-total
#'   rescaling yields `NaN`; undefined S03 blocks yield `NA` and carry an
#'   internal diagnostic attribute.
#' @examples
#' a <- matrix(c(0, 0, 1, 0), 2, 2)
#' Dynet:::.indegree_prestige(a)
#' Dynet:::.indegree_prestige(a, rescale = TRUE)
#' Dynet:::.indegree_prestige(a, definition = "indegree.rownorm")
#' Dynet:::.indegree_prestige(diag(2), definition = "indegree.rowcolnorm")
#' @references
#' Wasserman, S., & Faust, K. (1994). *Social Network Analysis: Methods and
#' Applications*. Cambridge University Press, Chapter 5.
#'
#' Butts, C. T. (2024). *sna: Tools for Social Network Analysis*, version 2.8.
#' doi:10.32614/CRAN.package.sna.
#' @keywords internal
.indegree_prestige <- function(a, rescale = FALSE, definition = "indegree",
                               tol = 1e-12, max_iter = 10000L,
                               warn = TRUE) {
  b <- (a > 0) * 1
  if (identical(definition, "indegree.rowcolnorm")) {
    balanced <- .rowcol_balance(b, tol, max_iter)
    if (!identical(balanced$status, "ok")) {
      value <- rep(NA_real_, ncol(b))
      attr(value, "prestige_diagnostic") <- balanced[
        c("status", "reason", "iterations", "residual")
      ]
      if (warn && identical(balanced$status, "nonconverged")) {
        warning(warningCondition(sprintf(
          "Row-column prestige did not converge after %d sweeps (residual %.6g).",
          balanced$iterations, balanced$residual
        ), class = "dynet_prestige_nonconvergence", call = NULL))
      }
      return(value)
    }
    return(if (rescale) rep(1 / ncol(b), ncol(b)) else rep(1, ncol(b)))
  }
  if (identical(definition, "indegree.rownorm")) {
    denominator <- rowSums(b)
    positive <- denominator > 0
    b[positive, ] <- b[positive, , drop = FALSE] / denominator[positive]
  }
  value <- unname(colSums(b))
  if (rescale) value <- value / sum(value)
  value
}

#' Directed reachability-domain prestige
#'
#' For binary directed adjacency `B`, let `H[i,j]` be true when `i = j` or a
#' directed path from `i` to `j` exists. Domain prestige excludes self and is
#' the incoming reachability count `p[j] = sum(H[,j]) - 1`. Every distinct
#' predecessor vertex counts once; path length and multiplicity do not enter.
#'
#' @param a Directed adjacency matrix for one snapshot block. Positive values
#'   are treated as binary dyads and loops have no effect.
#' @param rescale Whether to divide the counts by their total. A zero total
#'   yields literal `NaN` for every vertex.
#' @return A numeric vector of incoming nonself reachability counts, or their
#'   block-total shares.
#' @examples
#' chain <- matrix(c(0, 1, 0, 0, 0, 1, 0, 0, 0), 3, 3, byrow = TRUE)
#' Dynet:::.domain_prestige(chain)
#' Dynet:::.domain_prestige(chain, rescale = TRUE)
#' @references
#' Lin, N. (1976). *Foundations of Social Research*. McGraw-Hill.
#'
#' Wasserman, S., & Faust, K. (1994). *Social Network Analysis: Methods and
#' Applications*. Cambridge University Press, Chapter 5.
#' @keywords internal
.domain_prestige <- function(a, rescale = FALSE) {
  distance <- .geodesic(a, directed = TRUE)
  reachable <- is.finite(distance)
  diag(reachable) <- FALSE
  value <- unname(colSums(reachable))
  if (rescale) value <- value / sum(value)
  value
}

#' Directed domain-proximity prestige
#'
#' Let `D[j]` be the distinct nonself vertices with a finite directed
#' unweighted distance into `j`, `r[j]` its size, and `s[j]` the sum of those
#' distances. Lin's proximity prestige is zero for an empty domain and
#' otherwise `r[j]^2 / ((n - 1) * s[j])`: domain fraction divided by mean hop
#' distance. Unreachable vertices are excluded before summing distances.
#'
#' @param a Directed adjacency matrix for one snapshot block. Positive values
#'   are treated as binary dyads and loops have no effect.
#' @param rescale Whether to divide scores by their block total. A zero total
#'   yields literal `NaN` for every vertex.
#' @return A numeric vector in `[0,1]`, or its block-total shares.
#' @examples
#' chain <- matrix(c(0, 1, 0, 0, 0, 1, 0, 0, 0), 3, 3, byrow = TRUE)
#' Dynet:::.domain_proximity_prestige(chain)
#' Dynet:::.domain_proximity_prestige(chain, rescale = TRUE)
#' @references
#' Lin, N. (1976). *Foundations of Social Research*. McGraw-Hill.
#'
#' Wasserman, S., & Faust, K. (1994). *Social Network Analysis: Methods and
#' Applications*. Cambridge University Press, Chapter 5.
#' @keywords internal
.domain_proximity_prestige <- function(a, rescale = FALSE) {
  distance <- .geodesic(a, directed = TRUE)
  finite <- is.finite(distance)
  diag(finite) <- FALSE
  domain <- colSums(finite)
  distance_sum <- colSums(ifelse(finite, distance, 0))
  value <- if (nrow(a) <= 1L) {
    rep(0, nrow(a))
  } else {
    ifelse(domain == 0, 0,
           domain^2 / ((nrow(a) - 1) * distance_sum))
  }
  value <- unname(value)
  if (rescale) value <- value / sum(value)
  value
}

#' Incoming binary Perron prestige with uniqueness certification
#'
#' For binary directed adjacency `B`, ordinary eigenvector prestige solves
#' `t(B) %*% p = rho(B) * p`. The row-normalized definition first forms
#' `P[i,j] = B[i,j] / sum(B[i,])` for positive row totals, leaving zero rows
#' exactly zero. The column-normalized definition analogously forms
#' `Q[i,j] = B[i,j] / sum(B[,j])` and leaves zero columns zero. The row-column
#' definition first certifies total support and balances binary `B` to doubly
#' stochastic form. Each then solves the transposed Perron equation on its
#' transformed matrix. A score is
#' published only when the spectral radius is positive and the Perron
#' eigenspace is one-dimensional. Raw values have Euclidean norm one;
#' optional rescaling makes their sum one. Zero-radius and nonunique blocks
#' return `NA` with a diagnostic rather than an arbitrary eigenvector.
#'
#' @param a Directed adjacency matrix for one snapshot block. Positive values
#'   are treated as binary dyads; retained loops remain on the diagonal.
#' @param rescale Whether to normalize the feasible Perron vector to sum one.
#' @param definition Ordinary `"eigenvector"`, `"eigenvector.rownorm"`,
#'   which row-normalizes binary adjacency, `"eigenvector.colnorm"`, which
#'   column-normalizes it, or `"eigenvector.rowcolnorm"`, which requires total
#'   support and deterministic doubly stochastic balancing before transpose
#'   and eigensolving.
#' @param tol Fixed relative tolerance for root, nullity, sign, and residual
#'   checks.
#' @param balance_tol Internal S09 maximum absolute margin error.
#' @param balance_max_iter Internal S09 cap on complete balancing sweeps.
#' @param warn Whether an undefined direct call emits its classed warning.
#'   Public calls aggregate warnings after all reporting blocks.
#' @return A numeric vector with L2 norm or sum one. Undefined blocks are all
#'   `NA` and carry a `prestige_diagnostic` attribute.
#' @examples
#' cycle <- matrix(c(0, 1, 0, 0, 0, 1, 1, 0, 0), 3, 3, byrow = TRUE)
#' Dynet:::.eigen_prestige(cycle)
#' Dynet:::.eigen_prestige(cycle, rescale = TRUE)
#' Dynet:::.eigen_prestige(cycle, definition = "eigenvector.rownorm")
#' Dynet:::.eigen_prestige(cycle, definition = "eigenvector.colnorm")
#' Dynet:::.eigen_prestige(cycle, definition = "eigenvector.rowcolnorm")
#' @references
#' Bonacich, P. (1972). Factoring and weighting approaches to status scores
#' and clique identification. *Journal of Mathematical Sociology*, 2, 113-120.
#' doi:10.1080/0022250X.1972.9989806.
#'
#' Berman, A., & Plemmons, R. J. (1994). *Nonnegative Matrices in the
#' Mathematical Sciences*. SIAM. doi:10.1137/1.9781611971262.
#' @keywords internal
.eigen_prestige <- function(a, rescale = FALSE,
                            definition = c("eigenvector",
                                           "eigenvector.rownorm",
                                           "eigenvector.colnorm",
                                           "eigenvector.rowcolnorm"),
                            tol = 1e-10, balance_tol = 1e-12,
                            balance_max_iter = 10000L, warn = TRUE) {
  definition <- match.arg(definition)
  b <- (a > 0) * 1
  balance <- NULL
  if (identical(definition, "eigenvector.rownorm")) {
    denominator <- rowSums(b)
    positive <- denominator > 0
    b[positive, ] <- b[positive, , drop = FALSE] / denominator[positive]
  }
  if (identical(definition, "eigenvector.colnorm")) {
    denominator <- colSums(b)
    positive <- denominator > 0
    b[, positive] <- sweep(
      b[, positive, drop = FALSE], 2L, denominator[positive], "/"
    )
  }
  if (identical(definition, "eigenvector.rowcolnorm")) {
    balance <- .rowcol_balance(b, balance_tol, balance_max_iter)
    if (!identical(balance$status, "ok")) {
      value <- rep(NA_real_, nrow(b))
      stage <- if (identical(balance$status, "infeasible")) {
        "support"
      } else {
        "balance"
      }
      attr(value, "prestige_diagnostic") <- list(
        stage = stage, status = balance$status, reason = balance$reason,
        iterations = balance$iterations, residual = balance$residual,
        balance_status = balance$status, balance_reason = balance$reason,
        balance_iterations = balance$iterations,
        balance_residual = balance$residual,
        spectral_radius = NA_real_, eigenspace_dimension = NA_integer_,
        eigen_residual = NA_real_
      )
      if (warn) {
        if (identical(balance$status, "infeasible")) {
          warning(warningCondition(sprintf(
            "Row-column eigenvector prestige is infeasible (%s); values are NA.",
            balance$reason
          ), class = "dynet_prestige_infeasible", call = NULL))
        } else {
          warning(warningCondition(sprintf(
            paste0(
              "Row-column eigenvector prestige did not converge after %d ",
              "sweeps (residual %.6g); values are NA."
            ), balance$iterations, balance$residual
          ), class = "dynet_prestige_nonconvergence", call = NULL))
        }
      }
      return(value)
    }
    b <- balance$matrix
  }
  n <- nrow(b)
  undefined <- function(reason, spectral_radius = NA_real_,
                        eigenspace_dimension = NA_integer_,
                        residual = NA_real_) {
    value <- rep(NA_real_, n)
    attr(value, "prestige_diagnostic") <- list(
      stage = "spectrum", status = "undefined", reason = reason,
      iterations = balance$iterations %||% NA_integer_,
      spectral_radius = spectral_radius,
      eigenspace_dimension = as.integer(eigenspace_dimension),
      residual = residual,
      balance_status = balance$status %||% NA_character_,
      balance_reason = balance$reason %||% NA_character_,
      balance_iterations = balance$iterations %||% NA_integer_,
      balance_residual = balance$residual %||% NA_real_,
      eigen_residual = residual
    )
    if (warn) {
      warning(warningCondition(sprintf(
        "Eigenvector prestige is undefined (%s); values are NA.", reason
      ), class = "dynet_prestige_eigen_undefined", call = NULL))
    }
    value
  }
  if (n == 0L) return(undefined("zero_spectral_radius", 0))
  spectrum <- tryCatch(eigen(t(b), only.values = TRUE)$values,
                       error = function(e) NULL)
  if (is.null(spectrum) || any(!is.finite(spectrum))) {
    return(undefined("numerical_failure"))
  }
  radius <- max(Mod(spectrum))
  scale <- max(1, radius)
  if (radius <= tol * scale) {
    return(undefined("zero_spectral_radius", radius))
  }
  candidates <- which(
    abs(Im(spectrum)) <= tol * scale &
      abs(Re(spectrum) - radius) <= tol * scale
  )
  if (!length(candidates)) {
    return(undefined("numerical_failure", radius))
  }
  perron <- max(Re(spectrum[candidates]))
  shifted <- t(b) - diag(perron, n)
  decomposition <- tryCatch(svd(shifted, nu = n, nv = n),
                            error = function(e) NULL)
  if (is.null(decomposition) || any(!is.finite(decomposition$d))) {
    return(undefined("numerical_failure", perron))
  }
  singular_scale <- max(1, perron, decomposition$d)
  null <- which(decomposition$d <= tol * singular_scale)
  dimension <- length(null)
  if (dimension != 1L) {
    return(undefined("nonunique_perron_eigenspace", perron, dimension))
  }
  vector <- decomposition$v[, null]
  if (sum(vector) < 0) vector <- -vector
  vector_scale <- max(1, abs(vector))
  if (!all(is.finite(vector)) || any(vector < -tol * vector_scale)) {
    return(undefined("numerical_failure", perron, dimension))
  }
  vector[vector < 0] <- 0
  norm <- sqrt(sum(vector^2))
  if (!is.finite(norm) || norm <= tol) {
    return(undefined("numerical_failure", perron, dimension))
  }
  vector <- vector / norm
  residual <- max(abs(t(b) %*% vector - perron * vector))
  if (!is.finite(residual) || residual > tol * max(1, perron)) {
    return(undefined("numerical_failure", perron, dimension, residual))
  }
  if (identical(definition, "eigenvector.rowcolnorm")) {
    return(rep(if (rescale) 1 / n else 1 / sqrt(n), n))
  }
  if (rescale) vector <- vector / sum(vector)
  unname(vector)
}

#' Human-readable label for a measure name
#' @param m Measure name.
#' @param prestige Prestige definition used when `m = "prestige"`.
#' @return A single character string.
#' @keywords internal
.measure_label <- function(m, prestige = "indegree") {
  if (identical(m, "prestige")) {
    return(switch(prestige,
      indegree = "Indegree prestige",
      indegree.rownorm = "Row-normalized indegree prestige",
      indegree.rowcolnorm = "Row-column-normalized indegree prestige",
      domain = "Domain prestige",
      domain.proximity = "Domain proximity prestige",
      eigenvector = "Eigenvector prestige",
      eigenvector.rownorm = "Row-normalized eigenvector prestige",
      eigenvector.colnorm = "Column-normalized eigenvector prestige",
      eigenvector.rowcolnorm = "Row-column-normalized eigenvector prestige"
    ))
  }
  lookup <- c(degree = "Degree", indegree = "In-degree",
              outdegree = "Out-degree", strength = "Strength",
              closeness = "Closeness", betweenness = "Betweenness",
              eigenvector = "Eigenvector centrality", pagerank = "PageRank",
              hub = "Hub score", authority = "Authority score",
              coreness = "Coreness", constraint = "Burt's constraint",
              power = "Bonacich power", harary = "Harary graph centrality",
              information = "Information centrality", load = "Load centrality",
              flow_betweenness = "Flow betweenness",
              diffusion = "Diffusion degree",
              reach = "Reachability", reach_count = "Reach count")
  unname(lookup[m] %||% m)
}

#' Vertex centrality over time-respecting paths
#' @param dn A `dynet` object.
#' @param measure One or more of "closeness", "betweenness", "reach",
#'   "reach_count".
#' @param sessions Session mode.
#' @param start,end Optional traversal bounds for every temporal measure.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A `dynet_metric` at node level with no time column.
#' @keywords internal
.temporal_centrality <- function(dn, measure, sessions,
                                 start = NULL, end = NULL,
                                 traversal_time = 0,
                                 beta = 0.1, decay = 0,
                                 criterion = "foremost_then_shortest") {
  parts <- .split_sessions(dn, sessions)
  bounded <- identical(sessions, "bounded")
  frames <- Map(function(enc, label) {
    walk <- .undirect_or_reverse(enc, dn$directed, "forward")
    encoding_range <- .encoding_time_range(dn, enc)
    horizon <- .path_window(
      dn, "forward", start = start, end = end,
      default_start = encoding_range[["start"]],
      default_end = encoding_range[["end"]],
      clamp_missing = identical(sessions, "separate")
    )
    t0 <- horizon$start
    # Stream measures need no per-source search, so the trees are built only
    # when a path-based measure was actually asked for.
    needs_trees <- length(setdiff(measure, .stream_measures)) > 0L
    # Closeness reads only the earliest arrival, which is identical under
    # "foremost" and "foremost_then_shortest"; only the family differs, and
    # enumerating it is exhaustive. Betweenness under "foremost" is refused
    # before this point.
    search_criterion <- if (identical(criterion, "foremost")) {
      "foremost_then_shortest"
    } else criterion
    trees <- if (!needs_trees) NULL else lapply(seq_len(enc$n), function(s) {
      if (identical(criterion, "fastest")) {
        .fastest_search(
          dn, walk, s, horizon$start, horizon$end, bounded,
          traversal_time = traversal_time,
          activity_mode = if (identical(sessions, "separate")) {
            "separate"
          } else {
            "collapse"
          },
          activity_session = if (identical(sessions, "separate")) label else NULL
        )
      } else {
        .optimal_bounded_search(
          dn, walk, s, t0, "forward", bounded,
          lower = horizon$start, upper = horizon$end,
          traversal_time = traversal_time,
          activity_mode = if (identical(sessions, "separate")) {
            "separate"
          } else {
            "collapse"
          },
          activity_session = if (identical(sessions, "separate")) label else NULL,
          criterion = search_criterion
        )
      }
    })
    vals <- stats::setNames(lapply(measure, function(m)
      .temporal_measure(m, trees, enc, dn, beta, decay,
                        horizon$start, horizon$end, criterion)), measure)
    data.frame(session = label, node = enc$names,
               measure = rep(measure, each = enc$n),
               value = unlist(vals, use.names = FALSE),
               stringsAsFactors = FALSE)
  }, parts, names(parts))
  df <- do.call(rbind, frames)

  out <- .metric(
    df, level = "node",
    what = if (length(measure) == 1L) .measure_label(measure) else "Temporal centrality",
    dn = dn,
    note = if (is.null(start) && is.null(end))
      "computed on time-respecting paths across the whole window" else
      "computed on time-respecting paths within the requested traversal window",
    traversal_time = traversal_time
  )
  closeness_metadata <- list(
    criterion = "foremost_then_shortest",
    distance = "forward_latency",
    normalization = "reachable_inverse_mean"
  )
  betweenness_metadata <- list(
    criterion = "foremost_then_shortest",
    pair_domain = "forward_reachable_ordered",
    normalization = "none",
    path_identity = "canonical_atom_sequence"
  )
  if (identical(measure, "closeness")) {
    attr(out, "criterion") <- closeness_metadata$criterion
    attr(out, "distance") <- closeness_metadata$distance
    attr(out, "normalization") <- closeness_metadata$normalization
  } else if (identical(measure, "betweenness")) {
    attr(out, "criterion") <- betweenness_metadata$criterion
    attr(out, "pair_domain") <- betweenness_metadata$pair_domain
    attr(out, "normalization") <- betweenness_metadata$normalization
    attr(out, "path_identity") <- betweenness_metadata$path_identity
  } else {
    metadata <- list()
    if ("closeness" %in% measure) metadata$closeness <- closeness_metadata
    if ("betweenness" %in% measure) {
      metadata$betweenness <- betweenness_metadata
    }
    if (length(metadata)) attr(out, "measure_metadata") <- metadata
  }
  effective_mode <- if (identical(sessions, "bounded") &&
                        is.null(dn$meta$sessions)) "collapse" else sessions
  .vertex_path_metadata(out, effective_mode)
}

#' Reduce a set of optimal forward searches to one temporal measure
#' @param m Measure name.
#' @param trees List of optimal search results, one per source.
#' @param enc Encoded edge list.
#' @return A numeric vector, one value per vertex.
#' @keywords internal
.temporal_measure <- function(m, trees, enc, dn = NULL, beta = 0.1,
                              decay = 0, lower = NULL, upper = NULL,
                              criterion = "foremost_then_shortest") {
  n <- enc$n
  switch(m,
    katz = .temporal_katz_values(enc, dn, beta, decay, lower, upper),
    reach = .temporal_reach_values(trees, n, m)[[1L]],
    reach_count = .temporal_reach_values(trees, n, m)[[1L]],
    closeness = .temporal_closeness_values(trees, n, criterion),
    betweenness = .temporal_betweenness_values(trees, n)
  )
}

#' Count optimal endpoint routes through each named vertex
#'
#' The result is a numerator, not a fraction. It is computed from exact prefix
#' and suffix counts on one direct appearance DAG and never expands route rows.
#'
#' @param search A direct result from [.optimal_path_search()].
#' @param endpoint Integer target vertex.
#' @return A numeric vector of exact path counts, one per named vertex.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' search <- Dynet:::.optimal_path_search(enc, 1L, 0, upper = 10)
#' Dynet:::.optimal_endpoint_dependency(search, 2L)
#' @keywords internal
.optimal_endpoint_dependency <- function(search, endpoint) {
  n <- search$n
  out <- numeric(n)
  if (endpoint == search$source || search$n_paths[[endpoint]] == 0) return(out)
  terminal <- search$selected_states[[endpoint]]
  if (!length(terminal)) return(out)

  state <- search$state
  suffix <- numeric(length(state$vertex))
  suffix[terminal] <- 1
  # A suffix count depends on every child one hop deeper, so descending hop
  # order is a genuine sequential dependency.
  for (child in order(state$hops, decreasing = TRUE)) {
    if (suffix[[child]] == 0 || !length(state$pred_state[[child]])) next
    parents <- state$pred_state[[child]]
    for (parent in parents) {
      suffix[[parent]] <- .path_count_add(suffix[[parent]], suffix[[child]])
    }
  }
  through <- state$count * suffix
  out <- vapply(seq_len(n), function(vertex) {
    sum(through[state$vertex == vertex])
  }, numeric(1L))
  out[c(search$source, endpoint)] <- 0
  out
}

#' Credit optimal journeys to the contacts that carried them
#'
#' The same prefix and suffix counts the vertex dependency uses, accumulated on
#' the predecessor arc rather than on the vertex it entered. Every optimal
#' journey is vertex-simple, so it traverses each contact at most once.
#'
#' @param search A direct result from [.optimal_path_search()].
#' @param endpoint Integer target vertex.
#' @param n_atoms Number of canonical contact atoms.
#' @return A numeric vector of dependency, one per atom.
#' @keywords internal
.optimal_edge_dependency <- function(search, endpoint, n_atoms) {
  out <- numeric(n_atoms)
  if (endpoint == search$source || search$n_paths[[endpoint]] == 0) return(out)
  terminal <- search$selected_states[[endpoint]]
  if (!length(terminal)) return(out)

  state <- search$state
  suffix <- numeric(length(state$vertex))
  suffix[terminal] <- 1
  # Suffix counts depend on every child one hop deeper, so descending hop order
  # is a genuine sequential dependency, exactly as for the vertex form.
  for (child in order(state$hops, decreasing = TRUE)) {
    if (suffix[[child]] == 0 || !length(state$pred_state[[child]])) next
    for (parent in state$pred_state[[child]]) {
      suffix[[parent]] <- .path_count_add(suffix[[parent]], suffix[[child]])
    }
  }
  for (child in seq_along(state$vertex)) {
    if (suffix[[child]] == 0) next
    parents <- state$pred_state[[child]]
    atoms <- state$pred_atom[[child]]
    if (!length(parents)) next
    for (i in seq_along(parents)) {
      atom <- atoms[[i]]
      out[[atom]] <- out[[atom]] +
        state$count[[parents[[i]]]] * suffix[[child]]
    }
  }
  out / search$n_paths[[endpoint]]
}

#' Reduce optimal appearance DAGs to raw temporal betweenness
#'
#' For every reachable ordered source-target pair, the exact number of
#' shortest-foremost canonical atom journeys through a named internal vertex
#' is divided by the complete pair-family count. Bounded searches combine
#' numerators only from full-cost winning sessions before division.
#'
#' @param trees List of direct or bounded optimal searches, one per source.
#' @param n Size of the fixed vertex universe.
#' @return A nonnegative numeric vector, one raw dependency sum per vertex.
#' @examples
#' dn <- dynet(school_contacts)
#' enc <- Dynet:::.encode(dn)
#' searches <- lapply(seq_len(enc$n), function(source) {
#'   Dynet:::.optimal_path_search(enc, source, 0, upper = 10)
#' })
#' Dynet:::.temporal_betweenness_values(searches, enc$n)
#' @keywords internal
.temporal_betweenness_values <- function(trees, n) {
  per_source <- lapply(trees, function(search) {
    fractions <- lapply(seq_len(n), function(endpoint) {
      sigma <- search$n_paths[[endpoint]]
      if (endpoint == search$source || sigma == 0) return(numeric(n))
      numerator <- if (is.null(search$per_session)) {
        .optimal_endpoint_dependency(search, endpoint)
      } else {
        winners <- search$best_sessions[[endpoint]]
        if (!length(winners)) return(numeric(n))
        Reduce(`+`, lapply(winners, function(index) {
          .optimal_endpoint_dependency(search$per_session[[index]], endpoint)
        }))
      }
      numerator / sigma
    })
    Reduce(`+`, fractions)
  })
  Reduce(`+`, per_source)
}

#' Refuse a betweenness under a criterion whose family cannot be counted
#'
#' Temporal betweenness divides by the number of optimal journeys. Under pure
#' foremost that number is #P-hard to compute (Buss et al., 2024), so the
#' measure is refused rather than approximated.
#'
#' @param what Name of the measure for the message.
#' @return Never returns; raises `dynet_intractable_criterion`.
#' @keywords internal
.stop_intractable_criterion <- function(what) {
  stop(errorCondition(
    sprintf(paste0(
      "Temporal %s under criterion = \"foremost\" needs the count of every ",
      "vertex-simple earliest-arrival journey, which is #P-hard. Use ",
      "\"foremost_then_shortest\" or \"min_hops\"."), what),
    class = c("dynet_intractable_criterion", "dynet_bad_input"), call = NULL
  ))
}

#' Temporal Katz centrality by one pass over the contact stream
#'
#' The attenuated, time-decayed count of temporal walks ending at each vertex,
#' following Beres et al. (2018). Each contact `(u, v, t)` passes `beta` times
#' whatever had reached `u`, plus one for the length-one walk consisting of that
#' contact alone.
#'
#' Simultaneous contacts are handled strictly: every contact sharing a timestamp
#' forms one batch and reads the pre-batch scores. This is a deliberate
#' divergence from [paths()], which composes equal-time contacts at
#' `traversal_time = 0`. Applying that rule here would make the result depend on
#' the arbitrary order of contacts inside one instant.
#'
#' @param enc An encoding from [.encode()].
#' @param dn The temporal network, for the observation test.
#' @param beta Walk attenuation, in `(0, 1]`.
#' @param decay Exponential time-decay rate; zero means no decay.
#' @param lower,upper The measurement window.
#' @return A numeric vector, one score per vertex.
#' @keywords internal
.temporal_katz_values <- function(enc, dn, beta, decay, lower, upper) {
  n <- enc$n
  x <- numeric(n)
  last <- rep(lower, n)
  eligible <- !enc$raw_event_onset_censored &
    .time_in_observation(dn, enc$raw_event_start) &
    enc$raw_event_start >= lower & enc$raw_event_start <= upper
  if (!any(eligible)) return(x)
  from <- enc$raw_from[eligible]
  to <- enc$raw_to[eligible]
  when <- enc$raw_event_start[eligible]
  # Deterministic order, so a row permutation of the input cannot change the
  # answer; the batch rule then makes the within-instant order irrelevant too.
  ord <- order(when, from, to)
  from <- from[ord]; to <- to[ord]; when <- when[ord]
  phi <- function(gap) if (decay == 0) 1 else exp(-decay * gap)
  starts <- c(TRUE, when[-1L] != when[-length(when)])
  batch <- cumsum(starts)
  cap <- .Machine$double.xmax / 2
  # A stream is sequential by definition: each batch reads scores that the
  # previous batch wrote, so there is nothing to vectorise across batches.
  for (b in unique(batch)) {
    idx <- which(batch == b)
    t <- when[[idx[[1L]]]]
    touched <- unique(c(from[idx], to[idx]))
    gap <- t - last[touched]
    .check("Internal contact stream is out of order." = all(gap >= 0))
    x[touched] <- x[touched] * phi(gap)
    last[touched] <- t
    pre <- x
    add <- beta * (pre[from[idx]] + 1)
    # Several contacts in one batch can share a receiver, so their arrivals are
    # summed rather than assigned; a bare x[recv] <- would keep only the last.
    recv <- to[idx]
    agg <- tapply(add, recv, sum)
    target <- as.integer(names(agg))
    x[target] <- x[target] + as.numeric(agg)
    if (any(x > cap)) {
      stop(errorCondition(sprintf(
        "Temporal Katz overflowed at beta = %g; lower `beta` or raise `decay`.",
        beta), class = "dynet_katz_overflow", call = NULL))
    }
  }
  x * phi(upper - last)
}

#' Reduce temporal search trees to inverse mean forward latency
#'
#' Each reachable nonself endpoint contributes once. Zero-latency endpoints
#' are retained, so an all-zero reachable set has infinite closeness, while a
#' source with no reachable nonself endpoint has closeness zero.
#'
#' @param trees List of temporal search results, one per source.
#' @param n Size of the fixed vertex universe.
#' @return A numeric vector, one value per source vertex.
#' @examples
#' trees <- list(list(
#'   arrival = c(0, 0, 2), source = 1L, origin = 0
#' ))
#' Dynet:::.temporal_closeness_values(trees, 3L)
#' @keywords internal
.temporal_closeness_values <- function(trees, n,
                                       criterion = "foremost_then_shortest") {
  vapply(trees, function(tree) {
    target <- seq_len(n) != tree$source & is.finite(tree$arrival)
    if (!any(target)) return(0)
    # The distance is whatever the criterion optimised, so closeness under
    # min_hops is dimensionless and directly comparable with static closeness,
    # while under foremost it carries inverse-time units.
    distance <- if (identical(criterion, "min_hops")) {
      as.numeric(tree$n_hops[target])
    } else if (identical(criterion, "fastest")) {
      # An unattained infimum is still the distance: no journey is that
      # fast, but journeys arbitrarily close to it exist.
      tree$duration[target]
    } else {
      tree$arrival[target] - tree$origin
    }
    .check(
      "Internal temporal search returned a negative distance." =
        all(distance >= 0)
    )
    1 / mean(distance)
  }, numeric(1L))
}

#' Reduce temporal search trees to source-excluding reach measures
#'
#' @param trees List of temporal search results, one per source.
#' @param n Size of the fixed vertex universe.
#' @param measure One or more of `"reach"` and `"reach_count"`.
#' @return A named list of numeric vectors in requested-measure order.
#' @keywords internal
.temporal_reach_values <- function(trees, n, measure) {
  count <- vapply(
    trees,
    function(tree) as.numeric(sum(
      is.finite(tree$arrival) & seq_len(n) != tree$source
    )),
    numeric(1L)
  )
  stats::setNames(lapply(measure, function(m) {
    if (identical(m, "reach_count")) count else count / max(1, n - 1L)
  }), measure)
}

#' Temporal centrality of the contacts themselves
#'
#' @description
#' Credits every optimal time-respecting journey to the contacts that carried
#' it, giving a betweenness score per contact rather than per vertex. This is
#' the measure intervention questions actually ask: not which people matter,
#' but which meetings did.
#'
#' The row unit is one canonical contact, not one pair. The same `A -> B` pair
#' active in two disjoint spells is two rows, because a journey uses one of
#' them and not the other.
#'
#' @param dn A temporal network from [dynet()].
#' @param measure Currently `"betweenness"`.
#' @param criterion Which optimisation problem the credited journeys solve, as
#'   in [paths()]. `"foremost"` is refused with `dynet_intractable_criterion`:
#'   crediting contacts needs the count of every vertex-simple foremost
#'   journey, which is #P-hard.
#' @param sessions Session aggregation policy.
#' @param start,end First and last time to search.
#' @param traversal_time Nonnegative duration charged for every hop.
#' @return A `dynet_metric` at edge level, one row per contact, with columns
#'   `from`, `to`, `start`, `end`, `measure` and `value`. A contact used by no
#'   optimal journey is present with value zero rather than dropped, so the
#'   result is a complete census.
#' @details
#' The score is not normalised, and its range is the same `[0, (n-1)(n-2)]` as
#' the vertex measure.
#'
#' An exact identity ties this to [dyn_centrality()]: because every optimal
#' journey is vertex-simple, it enters each vertex through exactly one contact,
#' so the scores of the contacts arriving at a vertex sum to that vertex's
#' temporal betweenness plus the number of sources that reach it. The tests
#' assert it, which makes this verb checkable without any external reference.
#' @examples
#' dn <- dynet(school_contacts)
#' edge_centrality(dn)
#' @seealso [dyn_centrality()] for the vertex form.
#' @references
#' Oettershagen, L., and Mutzel, P. (2022). TGLib: an open-source library for
#' temporal graph analysis. *ICDM Workshops*. arXiv:2209.12587.
#'
#' Brandes, U. (2001). A faster algorithm for betweenness centrality. *Journal
#' of Mathematical Sociology*, 25(2), 163-177.
#' @export
edge_centrality <- function(dn, measure = "betweenness",
                            criterion = c("foremost_then_shortest",
                                          "min_hops", "foremost", "fastest"),
                            sessions = c("bounded", "collapse", "separate"),
                            start = NULL, end = NULL, traversal_time = 0) {
  sessions <- match.arg(sessions)
  criterion <- match.arg(criterion)
  if (identical(criterion, "foremost")) {
    .stop_intractable_criterion("contact betweenness")
  }
  if (identical(criterion, "fastest")) {
    stop(errorCondition(
      "Contact betweenness under criterion = \"fastest\" is not implemented.",
      class = "dynet_bad_input", call = NULL))
  }
  .check_dynet(dn, sessions)
  traversal_time <- .as_traversal_time(traversal_time, dn)
  allowed <- "betweenness"
  bad <- setdiff(measure, allowed)
  if (length(bad) > 0L) {
    stop(errorCondition(
      sprintf("Unknown edge measure %s. Available: %s",
              paste(sQuote(bad), collapse = ", "),
              paste(allowed, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    walk <- .undirect_or_reverse(enc, dn$directed, "forward")
    encoding_range <- .encoding_time_range(dn, enc)
    horizon <- .path_window(
      dn, "forward", NULL, start, end,
      default_start = encoding_range[["start"]],
      default_end = encoding_range[["end"]],
      clamp_missing = identical(sessions, "separate")
    )
    searches <- lapply(seq_len(enc$n), function(s)
      .optimal_bounded_search(
        dn, walk, s, horizon$start, "forward",
        identical(sessions, "bounded"),
        lower = horizon$start, upper = horizon$end,
        traversal_time = traversal_time,
        activity_mode = if (identical(sessions, "separate")) {
          "separate"
        } else {
          "collapse"
        },
        activity_session = if (identical(sessions, "separate")) label else NULL,
        criterion = criterion
      ))
    atoms <- searches[[1L]]$atoms
    n_atoms <- length(atoms$from)
    credit <- Reduce(`+`, lapply(searches, function(search) {
      Reduce(`+`, lapply(seq_len(enc$n), function(z) {
        .optimal_edge_dependency(search, z, n_atoms)
      }), init = numeric(n_atoms))
    }), init = numeric(n_atoms))
    data.frame(
      session = label,
      from = enc$names[atoms$from], to = enc$names[atoms$to],
      start = atoms$start, end = atoms$end,
      measure = "betweenness", value = credit,
      stringsAsFactors = FALSE
    )
  }, parts, names(parts))

  out <- .metric(do.call(rbind, frames), level = "edge",
                 what = "Contact betweenness", dn = dn,
                 note = "optimal journeys credited to the contacts that carried them",
                 traversal_time = traversal_time)
  attr(out, "criterion") <- criterion
  out
}
