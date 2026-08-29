# ===========================================================================
# Temporal community structure
#
# The substrate is projection(): a time-expanded network whose identity arcs
# carry a vertex from one slice to the next at weight omega. Everything in
# this file reads that object, never a flattened graph, and never the
# nT x nT supra-adjacency as one matrix -- see .supra() for why.
# ===========================================================================

#' Reassemble a projection into per-slice adjacency matrices
#'
#' The multislice quality function needs slice-local strengths and slice-local
#' totals, so it needs the slices apart, not the block matrix. Materialising
#' the `nT x nT` supra-adjacency would also be ruinous: 500 vertices over 100
#' bins is 50,000 states and 2.5e9 doubles, about 20 GB. Per-slice matrices
#' are `T` times `n^2` instead.
#'
#' A projection of a sessioned network carries several disjoint blocks whose
#' identity arcs never cross a session wall, so each block gets its own slice
#' list and the quality function sums over blocks against one global
#' normaliser.
#'
#' @param p A `dynet_projection` from [projection()].
#' @param symmetrise Whether to average a directed projection with its
#'   transpose. Multislice modularity as published is defined for symmetric
#'   slices; the result records that this happened rather than doing it
#'   silently.
#' @return A list with `nodes` (character), `omega`, `coupling`,
#'   `symmetrised` (logical), and `blocks`: one element per session block,
#'   each a list of `session`, `times` (numeric `T`), `layers` (a list of `T`
#'   `n x n` matrices) and `active` (an `n x T` logical matrix).
#' @examples
#' dn <- dynet(school_contacts)
#' s <- Dynet:::.supra(projection(dn, step = 5, window = 5))
#' length(s$blocks[[1]]$layers)
#' @keywords internal
.supra <- function(p, symmetrise = TRUE) {
  .check("`p` must be a projection from projection()." =
           inherits(p, "dynet_projection"))
  vertices <- p$vertices
  edges <- p$edges
  blocked <- "session" %in% names(vertices)
  keys <- if (blocked) vertices$session else rep("", nrow(vertices))
  # Slice one of each block lists every vertex in the network's own node
  # order, which is the order every matrix in this file is indexed by.
  nodes <- unique(vertices$node)
  n <- length(nodes)
  directed <- isTRUE(p$meta$source_directed)
  labels <- unique(keys)
  blocks <- lapply(labels, function(label) {
    rows <- keys == label
    slices <- sort(unique(vertices$slice[rows]))
    times <- vapply(slices, function(s)
      vertices$time[rows & vertices$slice == s][[1L]], numeric(1L))
    active <- vapply(slices, function(s) {
      state <- rows & vertices$slice == s
      stats::setNames(vertices$active[state], vertices$node[state])[nodes]
    }, logical(n))
    dim(active) <- c(n, length(slices))
    dimnames(active) <- list(nodes, NULL)
    within <- edges$edge_type == "within_slice" &
      (if (blocked) edges$session == label else TRUE)
    layers <- lapply(slices, function(s) {
      a <- matrix(0, n, n, dimnames = list(nodes, nodes))
      pick <- within & edges$from_slice == s
      if (any(pick)) {
        i <- match(edges$from_node[pick], nodes)
        j <- match(edges$to_node[pick], nodes)
        # Accumulate by cell: a projection should emit one arc per ordered
        # pair per slice, but summing is correct either way and assignment
        # would silently keep only the last.
        agg <- tapply(edges$weight[pick], (j - 1L) * n + i, sum)
        a[as.integer(names(agg))] <- as.numeric(agg)
      }
      if (directed && symmetrise) (a + t(a)) / 2 else a
    })
    list(session = if (blocked) label else NA_character_,
         times = times, layers = layers, active = active)
  })
  names(blocks) <- labels
  list(nodes = nodes, omega = p$meta$omega, coupling = p$meta$coupling,
       symmetrised = directed && symmetrise, blocks = blocks)
}

#' Interlayer strength of every state under a coupling rule
#'
#' Ordinal coupling gives a state one partner at each end of the series and
#' two in the interior; categorical coupling gives every state `T - 1`.
#'
#' @param n_slices Number of slices in the block.
#' @param coupling `"ordinal"` or `"categorical"`.
#' @return A numeric vector of partner counts, one per slice.
#' @examples
#' Dynet:::.coupling_degree(4L, "ordinal")
#' @keywords internal
.coupling_degree <- function(n_slices, coupling) {
  if (n_slices < 2L) return(rep(0, max(n_slices, 0L)))
  if (identical(coupling, "categorical")) return(rep(n_slices - 1, n_slices))
  c(1, rep(2, n_slices - 2L), 1)[seq_len(n_slices)]
}

#' Turn a membership frame into one label matrix per projection block
#'
#' @param supra A structure from [.supra()].
#' @param membership A data frame with `time`, `node`, `community`, plus
#'   `session` when the projection has blocks, or `NULL` for the partition
#'   that puts every state in one community.
#' @return A list of integer `n x T` matrices, one per block, in block order.
#' @keywords internal
.membership_matrix <- function(supra, membership) {
  nodes <- supra$nodes
  n <- length(nodes)
  if (is.null(membership)) {
    return(lapply(supra$blocks, function(b)
      matrix(1L, n, length(b$times), dimnames = list(nodes, NULL))))
  }
  .check(
    "`membership` must be a data frame with `time`, `node` and `community`." =
      is.data.frame(membership) &&
        all(c("time", "node", "community") %in% names(membership))
  )
  unknown <- setdiff(unique(as.character(membership$node)), nodes)
  if (length(unknown) > 0L) {
    stop(errorCondition(sprintf(
      "`membership` names %s that %s not in this network: %s.",
      if (length(unknown) == 1L) "a vertex" else "vertices",
      if (length(unknown) == 1L) "is" else "are",
      paste(sQuote(utils::head(unknown, 5L)), collapse = ", ")),
      class = "dynet_unknown_node", call = NULL))
  }
  blocked <- !is.na(supra$blocks[[1L]]$session)
  if (blocked && !"session" %in% names(membership)) {
    stop(errorCondition(
      "This network has sessions, so `membership` needs a `session` column.",
      class = "dynet_bad_input", call = NULL))
  }
  # Labels are nominal: whatever they are called, they are renumbered to a
  # dense integer range so the quality function never depends on their type.
  code <- as.integer(factor(as.character(membership$community)))
  Map(function(b, label) {
    rows <- if (blocked) as.character(membership$session) == label else TRUE
    slot <- match(membership$time[rows], b$times)
    who <- match(as.character(membership$node)[rows], nodes)
    g <- matrix(NA_integer_, n, length(b$times), dimnames = list(nodes, NULL))
    keep <- !is.na(slot) & !is.na(who)
    g[cbind(who[keep], slot[keep])] <- code[rows][keep]
    if (anyNA(g)) {
      stop(errorCondition(sprintf(
        "`membership` leaves %d of %d states unlabelled. It must cover every vertex in every bin, and its `time` values must be the bin start times this grid produces.",
        sum(is.na(g)), length(g)),
        class = "dynet_bad_input", call = NULL))
    }
    g
  }, supra$blocks, names(supra$blocks))
}

#' Multislice modularity of a partition of a temporal network
#'
#' @description
#' The Mucha et al. (2010) quality function: how much better a partition
#' explains the network than a degree-preserving null does, computed slice by
#' slice with the slices tied together by the interlayer coupling `omega`.
#'
#' Score a partition you already have -- a class roster, a set of research
#' groups, an externally computed clustering -- or score the one
#' [temporal_communities()] found. It is the objective that verb maximises, so
#' the two round-trip with no reshaping by the caller.
#'
#' @param dn A temporal network from [dynet()].
#' @param membership A data frame with columns `time`, `node` and `community`,
#'   plus `session` when the network has sessions. This is exactly the shape
#'   [temporal_communities()] returns. `NULL` scores the partition that puts
#'   every state in one community.
#' @param gamma Resolution. Values above one favour more, smaller
#'   communities; values below one favour fewer, larger ones.
#' @param omega Interlayer coupling: how much a vertex is rewarded for keeping
#'   its community from one slice to the next. Zero scores the slices
#'   independently.
#' @param coupling Which slices are coupled, `"ordinal"` (consecutive, the
#'   temporal convention) or `"categorical"` (all pairs). See [projection()].
#' @param sessions How to treat sessions: `"bounded"` and `"separate"` keep
#'   session-local blocks whose coupling never crosses a session wall,
#'   `"collapse"` erases the labels.
#' @param start,end First and last slice times. Default to observed support.
#' @param step Spacing between slice starts.
#' @param window Width represented by each slice.
#'
#' @return A `dynet_metric` at graph level, one row per component of the
#'   decomposition: `q` (the multislice modularity), `q_intra` and `q_inter`
#'   (its within-slice and interlayer parts, which sum to `q`), `two_mu` (the
#'   normaliser), `n_communities` and `n_empty_slices`. Columns are `measure`
#'   and `value`; there is no `time` column because \eqn{Q} is a property of
#'   the whole series, not of a bin. Attributes carry `gamma`, `omega`,
#'   `coupling` and `symmetrised`.
#'
#' @details
#' With \eqn{A_{ijs}} the weight of edge \eqn{i}--\eqn{j} in slice \eqn{s},
#' \eqn{k_{is}} its slice-local strength, \eqn{2m_s} the slice total,
#' \eqn{\omega_{jsr}} the coupling of vertex \eqn{j} between slices \eqn{s}
#' and \eqn{r}, and \eqn{2\mu = \sum_{js}(k_{js} + \sum_r \omega_{jsr})},
#' \deqn{Q = \frac{1}{2\mu}\sum_{ijsr}\left[\left(A_{ijs} -
#'   \gamma\frac{k_{is}k_{js}}{2m_s}\right)\delta_{sr} +
#'   \delta_{ij}\omega_{jsr}\right]\delta(g_{is}, g_{jr}).}
#'
#' Three things in that formula are not the static null, and getting any of
#' them wrong gives a different objective that still looks plausible:
#'
#' 1. The null uses \eqn{k_{is}}, \eqn{k_{js}} and \eqn{2m_s} **from slice
#'    \eqn{s} alone**, never the supra-degree. That is what lets a sparse bin
#'    and a dense bin be compared at all.
#' 2. The null is multiplied by \eqn{\delta_{sr}}, so **no null is subtracted
#'    from the interlayer arcs**. Identity arcs are not edges to be explained
#'    away; they assert that a vertex is the same vertex.
#' 3. The normaliser \eqn{2\mu} **includes** the coupling strength, which is
#'    why \eqn{Q} does not diverge as `omega` grows.
#'
#' Running `igraph::cluster_louvain()` on the supra-adjacency matrix gets all
#' three wrong: it applies the static Newman--Girvan null to the whole
#' supra-graph. That is a different objective function, not a different
#' implementation of this one.
#'
#' Two exact reductions follow from the formula and are pinned by tests. With
#' one slice and `omega = 0`, \eqn{Q} is ordinary Newman--Girvan modularity.
#' With `omega = 0` and any number of slices, \eqn{Q} is the \eqn{2m_s}-
#' weighted mean of the per-slice Newman--Girvan modularities.
#'
#' An edgeless slice has \eqn{2m_s = 0} and would divide by zero; its null
#' contribution is defined as exactly zero, and `n_empty_slices` reports how
#' many such slices there were. A network with no edges and no coupling has
#' \eqn{2\mu = 0} and no defined \eqn{Q} at all, which raises
#' `dynet_empty_result` rather than returning `NaN`.
#'
#' A directed network is averaged with its transpose before scoring, because
#' the published quality function is defined for symmetric slices. The result
#' records this in its `symmetrised` attribute.
#'
#' @references
#' Mucha, P. J., Richardson, T., Macon, K., Porter, M. A., & Onnela, J.-P.
#' (2010). Community structure in time-dependent, multiscale, and multiplex
#' networks. *Science*, 328(5980), 876-878.
#'
#' Newman, M. E. J., & Girvan, M. (2004). Finding and evaluating community
#' structure in networks. *Physical Review E*, 69(2), 026113.
#'
#' Reichardt, J., & Bornholdt, S. (2006). Statistical mechanics of community
#' detection. *Physical Review E*, 74(1), 016110.
#'
#' Bazzi, M., Porter, M. A., Williams, S., McDonald, M., Fenn, D. J., &
#' Howison, S. D. (2016). Community detection in temporal multilayer networks,
#' with an application to correlation networks. *Multiscale Modeling &
#' Simulation*, 14(1), 1-41.
#'
#' @seealso [temporal_communities()], which maximises this quantity, and
#'   [projection()], which builds the time-expanded network it is defined on.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' multislice_modularity(dn, step = 5, window = 5)
#' multislice_modularity(dn, membership = temporal_communities(
#'   dn, step = 5, window = 5, seeds = 1:3
#' ), step = 5, window = 5)
#'
#' @export
multislice_modularity <- function(dn, membership = NULL, gamma = 1, omega = 1,
                                  coupling = c("ordinal", "categorical"),
                                  sessions = c("bounded", "collapse",
                                               "separate"),
                                  start = NULL, end = NULL, step = NULL,
                                  window = NULL) {
  coupling <- match.arg(coupling)
  sessions <- match.arg(sessions)
  .check(
    "`gamma` must be a single non-negative finite number." =
      is.numeric(gamma) && length(gamma) == 1L && is.finite(gamma) &&
        gamma >= 0,
    "`omega` must be a single non-negative finite number." =
      is.numeric(omega) && length(omega) == 1L && is.finite(omega) &&
        omega >= 0
  )
  p <- projection(dn, sessions = sessions, start = start, end = end,
                  step = step, window = window, omega = omega,
                  coupling = coupling)
  supra <- .supra(p)
  parts <- .multislice_quality(supra, .membership_matrix(supra, membership),
                               gamma, omega, coupling)
  df <- data.frame(
    measure = c("q", "q_intra", "q_inter", "two_mu", "n_communities",
                "n_empty_slices"),
    value = c(parts$q, parts$q_intra, parts$q_inter, parts$two_mu,
              parts$n_communities, parts$n_empty_slices),
    stringsAsFactors = FALSE
  )
  out <- .metric(df, level = "graph", what = "Multislice modularity",
                 dn = dn, spec = list(step = p$meta$step,
                                      window = p$meta$window),
                 note = if (supra$symmetrised) {
                   "directed slices averaged with their transpose"
                 })
  attr(out, "gamma") <- gamma
  attr(out, "omega") <- omega
  attr(out, "coupling") <- coupling
  attr(out, "symmetrised") <- supra$symmetrised
  out
}

#' The multislice quality function, given assembled slices and labels
#'
#' Split out from [multislice_modularity()] so the optimiser in
#' [temporal_communities()] can recompute \eqn{Q} from scratch at the end of
#' every pass without rebuilding the projection.
#'
#' @param supra A structure from [.supra()].
#' @param labels A list of integer `n x T` label matrices, one per block.
#' @param gamma Resolution.
#' @param omega Interlayer coupling.
#' @param coupling `"ordinal"` or `"categorical"`.
#' @return A list with `q`, `q_intra`, `q_inter`, `two_mu`, `n_communities`
#'   and `n_empty_slices`.
#' @keywords internal
.multislice_quality <- function(supra, labels, gamma, omega, coupling) {
  empty <- 0L
  # Slice by slice, block by block, in a fixed order: the sum is accumulated
  # the same way on every run so Q is reproducible bit for bit.
  per_block <- Map(function(b, g) {
    n_slices <- length(b$layers)
    degree <- .coupling_degree(n_slices, coupling)
    slice <- lapply(seq_len(n_slices), function(s) {
      a <- b$layers[[s]]
      k <- rowSums(a)
      two_m <- sum(k)
      groups <- split(seq_along(k), g[, s])
      edges <- sum(vapply(groups, function(idx) sum(a[idx, idx, drop = FALSE]),
                          numeric(1L)))
      # An edgeless slice has no edges and therefore no expectation; the
      # null term is zero by definition rather than by dividing zero by zero.
      null <- if (two_m > 0) {
        sum(vapply(groups, function(idx) sum(k[idx])^2, numeric(1L))) / two_m
      } else {
        empty <<- empty + 1L
        0
      }
      c(intra = edges - gamma * null, k = two_m)
    })
    intra <- sum(vapply(slice, function(x) x[["intra"]], numeric(1L)))
    # Each coupled pair is counted in both directions, matching the ordered
    # double sum over (s, r) in the published formula.
    agree <- if (n_slices < 2L) {
      0
    } else if (identical(coupling, "categorical")) {
      sum(vapply(seq_len(n_slices - 1L), function(s)
        sum(g[, s] == g[, seq.int(s + 1L, n_slices), drop = FALSE]),
        numeric(1L)))
    } else {
      sum(g[, -n_slices, drop = FALSE] == g[, -1L, drop = FALSE])
    }
    list(intra = intra, inter = 2 * omega * agree,
         two_mu = sum(vapply(slice, function(x) x[["k"]], numeric(1L))) +
           omega * sum(degree) * nrow(g))
  }, supra$blocks, labels)
  two_mu <- sum(vapply(per_block, function(x) x$two_mu, numeric(1L)))
  if (!(two_mu > 0)) {
    stop(errorCondition(
      "Multislice modularity is undefined: this grid has no edges and no interlayer coupling, so its normaliser is zero.",
      class = "dynet_empty_result", call = NULL))
  }
  intra <- sum(vapply(per_block, function(x) x$intra, numeric(1L))) / two_mu
  inter <- sum(vapply(per_block, function(x) x$inter, numeric(1L))) / two_mu
  list(q = intra + inter, q_intra = intra, q_inter = inter, two_mu = two_mu,
       n_communities = length(unique(unlist(labels, use.names = FALSE))),
       n_empty_slices = empty)
}

#' Which slices each slice is coupled to
#'
#' @param n_slices Number of slices.
#' @param coupling `"ordinal"` or `"categorical"`.
#' @return A list of integer vectors, one per slice.
#' @examples
#' Dynet:::.coupling_partners(4L, "ordinal")
#' @keywords internal
.coupling_partners <- function(n_slices, coupling) {
  all <- seq_len(n_slices)
  lapply(all, function(s) {
    if (identical(coupling, "categorical")) return(all[all != s])
    all[abs(all - s) == 1L]
  })
}

#' One generalized-Louvain optimisation of a single projection block
#'
#' Phase one moves individual states; phase two and later move whole
#' communities on the aggregated modularity matrix. The `nT x nT` modularity
#' matrix is never formed: phase one reads slice-local adjacency, strength and
#' community-strength, and the aggregate is built only over the communities
#' phase one produced, which number in the tens.
#'
#' Aggregating the **modularity** matrix rather than the adjacency matrix is
#' the step a naive implementation gets wrong. The multislice null is
#' slice-local, so it is not preserved by summing adjacency; once the null is
#' inside the aggregate, later passes optimise the bare sum with no further
#' null subtraction.
#'
#' @param layers A list of `T` symmetric `n x n` matrices.
#' @param gamma Resolution.
#' @param omega Interlayer coupling.
#' @param coupling `"ordinal"` or `"categorical"`.
#' @param visit Integer permutation of the states, giving the order phase one
#'   considers them in. This is the only place randomness enters.
#' @param tol Minimum improvement that counts as a move.
#' @param max_passes Cap on aggregation passes.
#' @return A list with `membership` (integer, one label per state, in
#'   slice-major order) and `passes` (the number of passes used).
#' @keywords internal
.genlouvain_block <- function(layers, gamma, omega, coupling, visit,
                              tol = 1e-10, max_passes = 20L) {
  n <- nrow(layers[[1L]])
  n_slices <- length(layers)
  n_states <- n * n_slices
  k <- vapply(layers, rowSums, numeric(n))
  dim(k) <- c(n, n_slices)
  two_m <- colSums(k)
  partners <- .coupling_partners(n_slices, coupling)
  memb <- seq_len(n_states)
  strength <- matrix(0, n_states, n_slices)
  strength[cbind(memb, rep(seq_len(n_slices), each = n))] <- as.vector(k)

  # Phase one. Each state reads the labels its neighbours carry right now, so
  # the sweep is sequential by construction; that order dependence is exactly
  # what `visit` randomises and what the multi-seed loop above averages over.
  repeat {
    moved <- FALSE
    for (u in visit) {
      slice <- (u - 1L) %/% n + 1L
      i <- (u - 1L) %% n + 1L
      here <- (slice - 1L) * n + seq_len(n)
      label <- memb[here]
      mine <- memb[[u]]
      a <- layers[[slice]]
      neighbour <- which(a[i, ] != 0 & seq_len(n) != i)
      partner_labels <- memb[(partners[[slice]] - 1L) * n + i]
      candidates <- unique(c(mine, label[neighbour], partner_labels))
      if (length(candidates) < 2L) next
      pull <- vapply(candidates, function(cand) {
        sum(a[i, neighbour][label[neighbour] == cand])
      }, numeric(1L))
      tie <- vapply(candidates, function(cand) sum(partner_labels == cand),
                    numeric(1L))
      own <- strength[mine, slice] - k[i, slice]
      # An edgeless slice has no expectation to subtract; only the coupling
      # can move a state there.
      null <- if (two_m[[slice]] > 0) {
        rival <- strength[candidates, slice] -
          ifelse(candidates == mine, k[i, slice], 0)
        gamma * k[i, slice] * (rival - own) / two_m[[slice]]
      } else {
        numeric(length(candidates))
      }
      gain <- 2 * (pull - pull[candidates == mine] - null) +
        2 * omega * (tie - tie[candidates == mine])
      best <- which.max(gain)
      if (gain[[best]] > tol && candidates[[best]] != mine) {
        target <- candidates[[best]]
        strength[mine, slice] <- strength[mine, slice] - k[i, slice]
        strength[target, slice] <- strength[target, slice] + k[i, slice]
        memb[[u]] <- target
        moved <- TRUE
      }
    }
    if (!moved) break
  }

  # Phase two onwards, on the aggregated modularity matrix.
  pass <- 1L
  while (pass < max_passes) {
    codes <- match(memb, sort(unique(memb)))
    n_comm <- max(codes)
    if (n_comm < 2L) break
    b <- .aggregate_modularity(layers, codes, k, two_m, gamma, omega,
                               partners, n_comm)
    super <- .louvain_dense(b, tol)
    if (max(super) == n_comm) break
    memb <- super[codes]
    pass <- pass + 1L
  }
  list(membership = match(memb, sort(unique(memb))), passes = pass)
}

#' Aggregate the multislice modularity matrix over a partition
#'
#' @param layers Slice adjacency matrices.
#' @param codes Integer community code per state, dense from one.
#' @param k Slice-local strengths, `n x T`.
#' @param two_m Slice totals.
#' @param gamma,omega Resolution and coupling.
#' @param partners Coupled slices, from [.coupling_partners()].
#' @param n_comm Number of communities.
#' @return A symmetric `n_comm x n_comm` numeric matrix.
#' @keywords internal
.aggregate_modularity <- function(layers, codes, k, two_m, gamma, omega,
                                  partners, n_comm) {
  n <- nrow(layers[[1L]])
  n_slices <- length(layers)
  b <- matrix(0, n_comm, n_comm)
  for (slice in seq_len(n_slices)) {          # slice-local null, so per slice
    label <- codes[(slice - 1L) * n + seq_len(n)]
    indicator <- matrix(0, n, n_comm)
    indicator[cbind(seq_len(n), label)] <- 1
    edges <- crossprod(indicator, layers[[slice]] %*% indicator)
    strength <- as.vector(crossprod(indicator, k[, slice]))
    null <- if (two_m[[slice]] > 0) {
      gamma * outer(strength, strength) / two_m[[slice]]
    } else {
      0
    }
    b <- b + edges - null
  }
  # The interlayer arcs carry no null at all, so they are added raw.
  from <- unlist(lapply(seq_len(n_slices), function(s)
    rep((s - 1L) * n + seq_len(n), length(partners[[s]]))))
  to <- unlist(lapply(seq_len(n_slices), function(s)
    as.vector(vapply(partners[[s]], function(r) (r - 1L) * n + seq_len(n),
                     integer(n)))))
  if (length(from)) {
    cell <- (codes[to] - 1L) * n_comm + codes[from]
    agg <- tapply(rep(omega, length(cell)), cell, sum)
    target <- as.integer(names(agg))
    b[target] <- b[target] + as.numeric(agg)
  }
  b
}

#' Plain Louvain local moving on a dense modularity matrix
#'
#' The null is already inside `b`, so the objective is the bare sum
#' \eqn{\sum_{cd} B_{cd}\delta(h_c, h_d)} and nothing further is subtracted.
#'
#' @param b A symmetric numeric matrix.
#' @param tol Minimum improvement that counts as a move.
#' @return An integer membership vector, dense from one.
#' @keywords internal
.louvain_dense <- function(b, tol = 1e-10) {
  n <- nrow(b)
  memb <- seq_len(n)
  repeat {
    moved <- FALSE
    for (i in seq_len(n)) {                  # sequential: reads live labels
      mine <- memb[[i]]
      row <- b[i, ]
      row[[i]] <- 0
      pull <- vapply(split(row, memb), sum, numeric(1L))
      candidates <- as.integer(names(pull))
      gain <- 2 * (pull - pull[candidates == mine])
      best <- which.max(gain)
      if (gain[[best]] > tol && candidates[[best]] != mine) {
        memb[[i]] <- candidates[[best]]
        moved <- TRUE
      }
    }
    if (!moved) break
  }
  match(memb, sort(unique(memb)))
}

# ---------------------------------------------------------------------------
# Comparing two partitions of the same set
#
# All six statistics come from one contingency table, so they are computed
# from a shared primitive rather than six times over.
# ---------------------------------------------------------------------------

#' Contingency table and its derived counts for two labellings
#'
#' @param a,b Integer or character vectors of the same length, one label per
#'   element.
#' @return A list with the table `n`, its margins, the element count, and the
#'   pair counts every statistic below is built from.
#' @examples
#' Dynet:::.contingency(c(1, 1, 1, 2, 2, 2), c(1, 1, 2, 2, 2, 2))$n
#' @keywords internal
.contingency <- function(a, b) {
  n <- unclass(table(a, b))
  total <- sum(n)
  # choose(x, 2) written out: exact in integer arithmetic and free of the
  # branch choose() takes for x < 2.
  pairs <- function(x) x * (x - 1) / 2
  list(n = n, row = rowSums(n), col = colSums(n), total = total,
       pairs_together = sum(pairs(n)),
       pairs_row = sum(pairs(rowSums(n))),
       pairs_col = sum(pairs(colSums(n))),
       pairs_all = pairs(total))
}

#' Mutual information and the two entropies of a contingency table
#'
#' @param ct A structure from [.contingency()].
#' @return A list with `mi`, `h1` and `h2`, in nats.
#' @keywords internal
.mutual_information <- function(ct) {
  total <- ct$total
  # 0 log 0 is 0 by convention; the zero cells are excluded by their value,
  # not swept up by na.rm.
  cells <- ct$n[ct$n > 0]
  rows <- ct$row[ct$row > 0]
  cols <- ct$col[ct$col > 0]
  joint <- cells / total
  expected <- outer(ct$row, ct$col)[ct$n > 0] / total^2
  list(mi = sum(joint * log(joint / expected)),
       h1 = -sum(rows / total * log(rows / total)),
       h2 = -sum(cols / total * log(cols / total)))
}

#' One partition-comparison statistic
#'
#' @param a,b Label vectors of equal length.
#' @param measure One of `"nmi"`, `"ari"`, `"vi"`, `"split_join"`,
#'   `"jaccard"`, `"omega_index"`.
#' @return A single number, or `NA_real_` when fewer than two elements are
#'   shared.
#' @examples
#' Dynet:::.compare_partitions(c(1, 1, 1, 2, 2, 2), c(1, 1, 2, 2, 2, 2), "ari")
#' @keywords internal
.compare_partitions <- function(a, b, measure) {
  if (length(a) < 2L) return(NA_real_)
  ct <- .contingency(a, b)
  switch(measure,
    nmi = {
      info <- .mutual_information(ct)
      denominator <- info$h1 + info$h2
      # Both partitions trivial: they agree perfectly and carry no
      # information, so the ratio is 0/0. Defined as 1, the agreement.
      if (denominator <= 0) 1 else 2 * info$mi / denominator
    },
    vi = {
      info <- .mutual_information(ct)
      info$h1 + info$h2 - 2 * info$mi
    },
    ari = {
      expected <- ct$pairs_row * ct$pairs_col / ct$pairs_all
      denominator <- (ct$pairs_row + ct$pairs_col) / 2 - expected
      if (abs(denominator) < .Machine$double.eps) 1 else
        (ct$pairs_together - expected) / denominator
    },
    split_join = 2 * ct$total - sum(apply(ct$n, 1L, max)) -
      sum(apply(ct$n, 2L, max)),
    jaccard = {
      both <- ct$pairs_together
      either <- ct$pairs_row + ct$pairs_col - both
      if (either <= 0) 1 else both / either
    },
    omega_index = {
      # Agreement on how many communities each pair shares. For disjoint
      # partitions that number is 0 or 1, so the observed agreement is the
      # Rand index and the expectation is its chance level.
      observed <- (ct$pairs_together +
                     (ct$pairs_all - ct$pairs_row - ct$pairs_col +
                        ct$pairs_together)) / ct$pairs_all
      expected <- (ct$pairs_row * ct$pairs_col +
                     (ct$pairs_all - ct$pairs_row) *
                     (ct$pairs_all - ct$pairs_col)) / ct$pairs_all^2
      if (abs(1 - expected) < .Machine$double.eps) 1 else
        (observed - expected) / (1 - expected)
    }
  )
}

# ---------------------------------------------------------------------------
# Matching community labels across time
# ---------------------------------------------------------------------------

#' Maximum-weight assignment on a rectangular matrix
#'
#' The Jonker--Volgenant shortest-augmenting-path solution of the linear
#' assignment problem, in base R. No assignment solver exists in base R and
#' none of the packages that provide one is a dependency here.
#'
#' Greedy "take the best overlap first" matching is order-dependent: two
#' inputs differing only in row order can produce different labels, which is a
#' determinism defect rather than a matter of taste. This is optimal and, with
#' ties broken by the smallest index, fully determined.
#'
#' @param weight A numeric matrix of gains, rows against columns. Rectangular
#'   input is padded to square with zeros.
#' @return An integer vector, one entry per row of `weight`, giving the column
#'   assigned to that row, or `NA` when the row was matched only to padding.
#' @examples
#' Dynet:::.assign_max(matrix(c(4, 1, 1, 3), 2L, 2L))
#' @keywords internal
.assign_max <- function(weight) {
  .check("`weight` must be a numeric matrix." =
           is.matrix(weight) && is.numeric(weight) && !anyNA(weight))
  n_rows <- nrow(weight)
  n_cols <- ncol(weight)
  if (n_rows == 0L || n_cols == 0L) return(rep(NA_integer_, n_rows))
  size <- max(n_rows, n_cols)
  # Maximisation of a gain is minimisation of its negation; padding with zero
  # gain leaves a padded row free to take any spare column at no cost.
  cost <- matrix(0, size, size)
  cost[seq_len(n_rows), seq_len(n_cols)] <- -weight
  potential_row <- numeric(size + 1L)
  potential_col <- numeric(size + 1L)
  match_col <- integer(size + 1L)
  trail <- integer(size + 1L)
  # One augmenting path per row: the search is a shortest-path relaxation and
  # each row must be placed before the next begins, so this is sequential.
  for (row in seq_len(size)) {
    match_col[[1L]] <- row
    free <- 1L
    best <- rep(Inf, size + 1L)
    used <- rep(FALSE, size + 1L)
    repeat {
      used[[free]] <- TRUE
      here <- match_col[[free]]
      open <- which(!used[-1L]) + 1L
      slack <- cost[here, open - 1L] - potential_row[[here]] -
        potential_col[open]
      improved <- slack < best[open]
      best[open[improved]] <- slack[improved]
      trail[open[improved]] <- free
      step <- open[[which.min(best[open])]]
      delta <- best[[step]]
      touched <- which(used)
      potential_row[match_col[touched]] <- potential_row[match_col[touched]] +
        delta
      potential_col[touched] <- potential_col[touched] - delta
      best[-touched] <- best[-touched] - delta
      free <- step
      if (match_col[[free]] == 0L) break
    }
    # Walk the augmenting path back, shifting each match one place along it.
    repeat {
      previous <- trail[[free]]
      match_col[[free]] <- match_col[[previous]]
      free <- previous
      if (free == 1L) break
    }
  }
  assigned <- integer(size)
  columns <- seq.int(2L, size + 1L)
  assigned[match_col[columns]] <- columns - 1L
  out <- assigned[seq_len(n_rows)]
  out[out > n_cols] <- NA_integer_
  out
}

#' Overlap between the communities of two consecutive bins
#'
#' @param a,b Integer label vectors over the same node universe.
#' @param shared Logical vector marking the nodes active in both bins.
#' @param overlap `"intersection"` or `"jaccard"`.
#' @return A matrix of overlaps, rows the labels of `a` and columns those of
#'   `b`, with those labels as dimnames.
#' @keywords internal
.community_overlap <- function(a, b, shared, overlap) {
  left <- factor(a[shared])
  right <- factor(b[shared])
  counts <- unclass(table(left, right))
  if (identical(overlap, "intersection")) return(counts)
  # A quiet node is in neither margin, so a community that merely goes silent
  # is not read as shrinking.
  union <- outer(rowSums(counts), colSums(counts), "+") - counts
  ifelse(union > 0, counts / union, 0)
}

#' Give community labels a meaning that carries across time
#'
#' @description
#' A community label is arbitrary within a bin. If bin 3's "community 2" is
#' bin 4's "community 1", then flexibility, persistence and allegiance measure
#' relabelling noise and nothing else. This verb walks the bins in order and
#' gives a community the label of whichever earlier community it most overlaps
#' with, so a label means the same group throughout.
#'
#' **You usually do not need this.** When [temporal_communities()] runs with
#' `omega > 0`, the interlayer coupling *is* the matching, performed inside
#' the objective rather than as a post-hoc heuristic, and the labels are
#' already consistent. Matching is for `omega = 0`, for per-bin detection, for
#' comparing runs at different `gamma`, and for a partition computed
#' elsewhere.
#'
#' @param x A `dynet_communities` frame from [temporal_communities()], or any
#'   data frame with `time`, `node` and `community` columns.
#' @param method `"hungarian"` solves the assignment optimally, so the answer
#'   does not depend on the order of the rows. `"greedy"` takes the best
#'   overlap first and is offered only for comparability with the published
#'   event-detection literature; it is order-dependent and therefore not
#'   reproducible across row permutations.
#' @param overlap How to score a candidate pairing: `"jaccard"`, the shared
#'   members over the members of either, which is comparable across
#'   communities of different sizes; or `"intersection"`, the raw count of
#'   shared members.
#' @param threshold Minimum overlap for a community to inherit an earlier
#'   label rather than start a new one. In \eqn{[0, 1]} for `"jaccard"`, a
#'   non-negative count for `"intersection"`.
#'
#' @return A `dynet_communities` frame with the same rows as `x` and three
#'   guarantees: `community` now carries the matched, time-consistent label;
#'   `community_raw` keeps the original per-bin label so the matching is
#'   auditable; and `event` records what happened to this state's community at
#'   this bin, one of `"born"`, `"persist"`, `"split"` or `"merge"`. The
#'   community-level lifecycle table, which also carries `"dissolve"`, is
#'   `as.data.frame(x, what = "events")`.
#'
#' @details
#' Overlaps are computed only over the vertices active in **both** bins, so a
#' community whose members merely go quiet is not read as dissolving.
#'
#' The event taxonomy is Greene, Doyle and Cunningham's (2010), with an
#' optimal assignment step in place of their greedy one. A bin-\eqn{s}
#' community that overlaps two or more bin-\eqn{s{+}1} communities above
#' `threshold` has **split**: the assigned one inherits the label and the
#' others are born, and every state involved is marked `"split"`. The mirror
#' case, two earlier communities feeding one later one, is a **merge**. When
#' both descriptions fit, `"split"` is reported.
#'
#' Labels are never recycled. A community that dissolves at bin 10 and an
#' unrelated one born at bin 40 cannot share a label, so a long series does
#' not silently reconnect two different groups.
#'
#' @references
#' Kuhn, H. W. (1955). The Hungarian method for the assignment problem.
#' *Naval Research Logistics Quarterly*, 2(1-2), 83-97.
#'
#' Jonker, R., & Volgenant, A. (1987). A shortest augmenting path algorithm
#' for dense and sparse linear assignment problems. *Computing*, 38, 325-340.
#'
#' Greene, D., Doyle, D., & Cunningham, P. (2010). Tracking the evolution of
#' communities in dynamic social networks. *ASONAM 2010*, 176-183.
#'
#' Palla, G., Barabasi, A.-L., & Vicsek, T. (2007). Quantifying social group
#' evolution. *Nature*, 446, 664-667.
#'
#' Cazabet, R., & Rossetti, G. (2019). Challenges in community discovery on
#' temporal networks. In *Temporal Network Theory*, Springer, 181-197.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' loose <- temporal_communities(dn, omega = 0, step = 5, window = 5,
#'                               seeds = 1:3)
#' match_communities(loose)
#'
#' @export
match_communities <- function(x, method = c("hungarian", "greedy"),
                              overlap = c("jaccard", "intersection"),
                              threshold = 0.1) {
  method <- match.arg(method)
  overlap <- match.arg(overlap)
  .check(
    "`x` must be a data frame with `time`, `node` and `community` columns." =
      is.data.frame(x) && all(c("time", "node", "community") %in% names(x)),
    "`threshold` must be a single non-negative number." =
      is.numeric(threshold) && length(threshold) == 1L &&
        is.finite(threshold) && threshold >= 0
  )
  if (identical(overlap, "jaccard") && threshold > 1) {
    stop(errorCondition(
      "A Jaccard `threshold` is a proportion, so it must be at most one. For a raw count of shared members, use `overlap = \"intersection\"`.",
      class = "dynet_bad_input", call = NULL))
  }
  nodes <- sort(unique(as.character(x$node)))
  raw <- if ("community_raw" %in% names(x)) x$community_raw else x$community
  active <- if ("active" %in% names(x)) x$active else rep(TRUE, nrow(x))
  blocked <- "session" %in% names(x)
  keys <- if (blocked) as.character(x$session) else rep("", nrow(x))
  matched <- rep(NA_integer_, nrow(x))
  event <- rep(NA_character_, nrow(x))
  events <- list()
  next_label <- 0L
  for (block in unique(keys)) {            # blocks are independent registries
    rows <- which(keys == block)
    times <- sort(unique(x$time[rows]))
    previous <- NULL
    # Bins are walked in order because each inherits from the last; that is
    # the whole point of the registry.
    for (index in seq_along(times)) {
      here <- rows[x$time[rows] == times[[index]]]
      slot <- match(as.character(x$node)[here], nodes)
      label <- rep(NA_integer_, length(nodes))
      label[slot] <- as.integer(factor(as.character(raw[here])))
      alive <- rep(FALSE, length(nodes))
      alive[slot] <- active[here]
      # Every community in the bin gets a label, including one whose members
      # are all inactive: a quiet group has not left, and dropping it here
      # would break the chain the next bin inherits from.
      present <- sort(unique(label[!is.na(label)]))
      key <- as.character(present)
      inherit <- stats::setNames(rep(NA_integer_, length(present)), key)
      kind <- stats::setNames(rep("born", length(present)), key)
      score <- stats::setNames(rep(0, length(present)), key)
      source <- stats::setNames(rep(NA_integer_, length(present)), key)
      if (!is.null(previous) && length(present) > 0L) {
        shared <- alive & previous$alive & !is.na(label) &
          !is.na(previous$label)
        if (any(shared)) {
          weight <- .community_overlap(previous$label, label, shared, overlap)
          old <- as.integer(rownames(weight))
          new <- as.integer(colnames(weight))
          pick <- if (identical(method, "hungarian")) {
            .assign_max(weight)
          } else {
            .assign_greedy(weight)
          }
          # Fan-out and fan-in above the threshold are what distinguish a
          # split or a merge from a plain continuation.
          out_degree <- rowSums(weight > threshold)
          in_degree <- colSums(weight > threshold)
          for (r in seq_along(old)) {
            column <- pick[[r]]
            if (is.na(column) || weight[r, column] <= threshold) next
            target <- as.character(new[[column]])
            inherit[[target]] <- previous$inherit[[as.character(old[[r]])]]
            score[[target]] <- weight[r, column]
            source[[target]] <- old[[r]]
            kind[[target]] <- if (out_degree[[r]] > 1) {
              "split"
            } else if (in_degree[[column]] > 1) {
              "merge"
            } else {
              "persist"
            }
          }
          # A later community that overlaps a splitting one but did not win
          # the assignment is still part of that split.
          for (r in which(out_degree > 1)) {
            for (column in which(weight[r, ] > threshold)) {
              target <- as.character(new[[column]])
              if (identical(kind[[target]], "born")) kind[[target]] <- "split"
            }
          }
        }
        # Anything the overlap could not speak for -- a community whose
        # members were all inactive in one of the two bins -- keeps the label
        # most of its members were carrying, provided nothing else claimed it.
        for (target in key[is.na(inherit)]) {
          members <- which(!is.na(label) & label == as.integer(target))
          carried <- previous$assigned[members]
          carried <- carried[!is.na(carried)]
          if (!length(carried)) next
          plurality <- as.integer(names(sort(table(carried),
                                             decreasing = TRUE))[[1L]])
          if (plurality %in% inherit) next
          inherit[[target]] <- plurality
          kind[[target]] <- "persist"
        }
      }
      fresh <- is.na(inherit)
      if (any(fresh)) {
        inherit[fresh] <- next_label + seq_len(sum(fresh))
        next_label <- next_label + sum(fresh)
      }
      if (!is.null(previous)) {
        # A community dissolves when no successor took its label on. A
        # community that merely went quiet has a successor, so it does not
        # appear here.
        lost <- setdiff(previous$inherit, inherit)
        if (length(lost)) {
          events[[length(events) + 1L]] <- data.frame(
            session = block, time = times[[index]], community = lost,
            event = "dissolve", size = 0L, overlap = 0,
            matched_from = NA_integer_, stringsAsFactors = FALSE)
        }
      }
      assigned <- rep(NA_integer_, length(nodes))
      assigned[!is.na(label)] <- inherit[as.character(label[!is.na(label)])]
      matched[here] <- assigned[slot]
      event[here] <- kind[as.character(label[slot])]
      if (length(present)) {
        events[[length(events) + 1L]] <- data.frame(
          session = block, time = times[[index]],
          community = unname(inherit), event = unname(kind),
          size = as.integer(table(factor(label[!is.na(label)],
                                         levels = present))),
          overlap = unname(score), matched_from = unname(source),
          stringsAsFactors = FALSE)
      }
      previous <- list(label = label, alive = alive,
                       inherit = inherit, assigned = assigned)
    }
  }
  out <- x
  out$community <- unname(matched)
  out$community_raw <- raw
  out$event <- event
  lifecycle <- if (length(events)) do.call(rbind, events) else
    data.frame(session = character(), time = numeric(), community = integer(),
               event = character(), size = integer(), overlap = numeric(),
               matched_from = integer(), stringsAsFactors = FALSE)
  if (!blocked) lifecycle$session <- NULL
  rownames(lifecycle) <- NULL
  attr(out, "events") <- lifecycle
  attr(out, "matched") <- TRUE
  attr(out, "match_method") <- method
  attr(out, "match_overlap") <- overlap
  attr(out, "match_threshold") <- threshold
  attr(out, "n_communities") <- length(unique(matched))
  class(out) <- unique(c("dynet_communities", "data.frame"))
  out
}

#' Greedy best-overlap assignment
#'
#' Offered only so the published greedy event-detection pipelines can be
#' reproduced. It is order-dependent by construction.
#'
#' @param weight A numeric matrix of overlaps.
#' @return An integer vector of assigned columns, `NA` where none was left.
#' @keywords internal
.assign_greedy <- function(weight) {
  out <- rep(NA_integer_, nrow(weight))
  taken <- logical(ncol(weight))
  # Genuinely greedy: each choice removes a column from the next one's reach.
  for (step in seq_len(min(dim(weight)))) {
    open <- which(!taken)
    free <- which(is.na(out))
    if (!length(open) || !length(free)) break
    block <- weight[free, open, drop = FALSE]
    if (max(block) <= 0) break
    cell <- which.max(block)
    row <- free[[(cell - 1L) %% nrow(block) + 1L]]
    column <- open[[(cell - 1L) %/% nrow(block) + 1L]]
    out[[row]] <- column
    taken[[column]] <- TRUE
  }
  out
}

#' One optimisation run over every block of a projection
#'
#' @param supra A structure from [.supra()].
#' @param gamma,omega,coupling,tol,max_passes Optimiser settings.
#' @return A list of integer `n x T` label matrices, one per block, whose
#'   labels are distinct across blocks.
#' @keywords internal
.genlouvain_run <- function(supra, gamma, omega, coupling, tol, max_passes) {
  offset <- 0L
  # Blocks share no coupling, so maximising each separately maximises the
  # total; the offset only keeps their labels from colliding.
  lapply(supra$blocks, function(b) {
    n <- length(supra$nodes)
    n_slices <- length(b$layers)
    fit <- .genlouvain_block(b$layers, gamma, omega, coupling,
                             visit = sample.int(n * n_slices),
                             tol = tol, max_passes = max_passes)
    labels <- matrix(fit$membership + offset, n, n_slices,
                     dimnames = list(supra$nodes, NULL))
    offset <<- offset + max(fit$membership)
    labels
  })
}

#' Per-state agreement between a run and the reported partition
#'
#' For each state, the Jaccard overlap between the community the run put it in
#' and the community the reported partition puts it in. One means the run
#' agreed about every one of that state's companions.
#'
#' @param run,best Integer label vectors over the same states.
#' @return A numeric vector in `[0, 1]`, one entry per state.
#' @keywords internal
.state_agreement <- function(run, best) {
  ct <- .contingency(run, best)
  row <- match(as.character(run), rownames(ct$n))
  col <- match(as.character(best), colnames(ct$n))
  shared <- ct$n[cbind(row, col)]
  shared / (ct$row[row] + ct$col[col] - shared)
}

#' Temporal community detection by generalized Louvain
#'
#' @description
#' Which vertices form a group, and how that group survives, splits or
#' dissolves as time passes. The partition is found by maximising the
#' multislice modularity of Mucha et al. (2010) over the time-expanded
#' network, so the slices are solved together rather than one at a time and a
#' community keeps its identity across bins by construction.
#'
#' Two knobs decide what you get. `gamma` sets the resolution: how dense a
#' group has to be to count as one. `omega` sets how much a vertex is
#' rewarded for staying put, so it trades a partition that tracks each bin's
#' structure exactly against one that persists and is readable as a story.
#'
#' @param dn A temporal network from [dynet()].
#' @param gamma Resolution. Above one favours more, smaller communities;
#'   below one favours fewer, larger ones.
#' @param omega Interlayer coupling. Zero detects each bin independently and
#'   the labels are then matched by [match_communities()]; large values force
#'   one community per vertex for the whole series.
#' @param method `"louvain"` reports the best of the `seeds` runs.
#'   `"consensus"` reports the partition the runs agree on, built from their
#'   co-classification matrix (Lancichinetti & Fortunato 2012).
#' @param seeds The seeds to run from, one optimisation each. Modularity
#'   landscapes are near-degenerate, so a single run is not a result; the
#'   default runs ten and reports how much they agreed.
#' @param coupling `"ordinal"` couples consecutive slices, the temporal
#'   convention. `"categorical"` couples every pair, which asserts that the
#'   bins have no order.
#' @param sessions How to treat sessions. `"bounded"` and `"separate"` keep
#'   session-local blocks whose coupling never crosses a session wall.
#' @param start,end First and last slice times. Default to observed support.
#' @param step Spacing between slice starts.
#' @param window Width represented by each slice.
#' @param max_passes Cap on aggregation passes per run.
#' @param tol Smallest improvement that counts as a move.
#'
#' @return A `dynet_communities` frame, one row per vertex per time bin:
#'   `session` (only when the network has sessions), `time`, `node`,
#'   `community` (an integer label, meaning the same group in every bin),
#'   `active` (was the vertex eligible in this bin) and `stability` (in
#'   \eqn{[0, 1]}, how much of the run-to-run variation this state survived).
#'   Print it, [summary()] it, [plot()] it, or take the plain frame with
#'   [as.data.frame()], which also serves `what = "runs"`, `"sizes"` and,
#'   after [match_communities()], `"events"`.
#'
#' @details
#' The objective is [multislice_modularity()], and the two round-trip:
#' `multislice_modularity(dn, membership = temporal_communities(dn))` returns
#' the `q` this verb reports.
#'
#' *Why several seeds.* Louvain visits vertices in some order and takes the
#' first improving move it finds, so its answer depends on that order, and
#' modularity landscapes are near-degenerate: very many partitions sit within
#' a hair of the maximum (Good, de Montjoye & Clauset 2010). One run is a
#' sample from that plateau, not the answer. This verb therefore runs once per
#' seed, reports the best, and reports how much the runs agreed --
#' `stability_ari`, the mean pairwise adjusted Rand index across runs, and a
#' per-state `stability` column. A `stability_ari` near one means the labels
#' can be read; near zero means they cannot, whatever the modularity says.
#' Asking for a single seed raises a `dynet_single_seed` warning for that
#' reason.
#'
#' *What is not implemented.* The Leiden refinement (Traag, Waltman & van Eck
#' 2019) is not, so a community this verb reports can in principle be
#' internally disconnected -- the known defect of Louvain. Running several
#' seeds and reading `stability_ari` is the mitigation on offer here.
#'
#' *Inactive vertices.* A vertex with no activity in a bin still has its
#' identity arcs, because [projection()] lets a vertex wait through
#' inactivity. It is therefore carried along by the coupling and receives a
#' label rather than being dropped, which would break the chain. The `active`
#' column marks those states.
#'
#' *Reproducibility.* The result is a deterministic function of `seeds`: two
#' calls with the same seeds return identical frames. The caller's random
#' stream is saved and restored, so running this verb never changes what the
#' next `sample()` produces.
#'
#' @references
#' Mucha, P. J., Richardson, T., Macon, K., Porter, M. A., & Onnela, J.-P.
#' (2010). Community structure in time-dependent, multiscale, and multiplex
#' networks. *Science*, 328(5980), 876-878.
#'
#' Jeub, L. G. S., Bazzi, M., Jutla, I. S., & Mucha, P. J. (2011-2019). *A
#' generalized Louvain method for community detection implemented in MATLAB.*
#'
#' Blondel, V. D., Guillaume, J.-L., Lambiotte, R., & Lefebvre, E. (2008).
#' Fast unfolding of communities in large networks. *Journal of Statistical
#' Mechanics*, P10008.
#'
#' Good, B. H., de Montjoye, Y.-A., & Clauset, A. (2010). Performance of
#' modularity maximization in practical contexts. *Physical Review E*, 81(4),
#' 046106.
#'
#' Lancichinetti, A., & Fortunato, S. (2012). Consensus clustering in complex
#' networks. *Scientific Reports*, 2, 336.
#'
#' Bassett, D. S., Porter, M. A., Wymbs, N. F., Grafton, S. T., Carlson, J.
#' M., & Mucha, P. J. (2013). Robust detection of dynamic community structure
#' in networks. *Chaos*, 23(1), 013142.
#'
#' Traag, V. A., Waltman, L., & van Eck, N. J. (2019). From Louvain to Leiden:
#' guaranteeing well-connected communities. *Scientific Reports*, 9, 5233.
#'
#' @seealso [multislice_modularity()] for the objective, [match_communities()]
#'   for labels from an uncoupled run, [community_change()] for how much the
#'   partition moved, [community_trajectory()] for what each vertex did, and
#'   [phases()] for regimes found without communities at all.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
#' found
#' summary(found)
#' as.data.frame(found, what = "sizes")
#'
#' @export
temporal_communities <- function(dn, gamma = 1, omega = 1,
                                 method = c("louvain", "consensus"),
                                 seeds = 1:10,
                                 coupling = c("ordinal", "categorical"),
                                 sessions = c("bounded", "collapse",
                                              "separate"),
                                 start = NULL, end = NULL, step = NULL,
                                 window = NULL,
                                 max_passes = 20L, tol = 1e-10) {
  method <- match.arg(method)
  coupling <- match.arg(coupling)
  sessions <- match.arg(sessions)
  .check(
    "`gamma` must be a single non-negative finite number." =
      is.numeric(gamma) && length(gamma) == 1L && is.finite(gamma) &&
        gamma >= 0,
    "`omega` must be a single non-negative finite number." =
      is.numeric(omega) && length(omega) == 1L && is.finite(omega) &&
        omega >= 0,
    "`seeds` must be one or more whole numbers." =
      is.numeric(seeds) && length(seeds) > 0L && all(is.finite(seeds)) &&
        all(seeds == trunc(seeds)),
    "`max_passes` must be a single positive whole number." =
      is.numeric(max_passes) && length(max_passes) == 1L &&
        is.finite(max_passes) && max_passes >= 1,
    "`tol` must be a single positive number." =
      is.numeric(tol) && length(tol) == 1L && is.finite(tol) && tol > 0
  )
  if (length(seeds) == 1L) {
    warning(warningCondition(
      "One seed is one sample from a near-degenerate landscape, not a result. Louvain's answer depends on the order it visits vertices in; run several seeds so `stability_ari` can say whether the labels mean anything.",
      class = "dynet_single_seed", call = NULL))
  }
  p <- projection(dn, sessions = sessions, start = start, end = end,
                  step = step, window = window, omega = omega,
                  coupling = coupling)
  supra <- .supra(p)
  runs <- lapply(seeds, function(seed) .with_seed(seed, {
    labels <- .genlouvain_run(supra, gamma, omega, coupling, tol, max_passes)
    list(labels = labels,
         q = .multislice_quality(supra, labels, gamma, omega, coupling)$q)
  }))
  flat <- lapply(runs, function(r) {
    unname(match(unlist(lapply(r$labels, as.vector)),
                 unique(unlist(lapply(r$labels, as.vector)))))
  })
  q_runs <- vapply(runs, function(r) r$q, numeric(1L))
  if (identical(method, "consensus")) {
    labels <- .consensus_partition(supra, flat, gamma, omega, coupling, tol,
                                   max_passes, seeds)
    quality <- .multislice_quality(supra, labels, gamma, omega, coupling)
  } else {
    # The best run, with ties broken by the lexicographically smallest
    # canonical membership so the answer is fully determined by `seeds`.
    top <- which(q_runs >= max(q_runs) - tol)
    order_key <- do.call(order, as.data.frame(do.call(rbind, flat[top])))
    labels <- runs[[top[[order_key[[1L]]]]]]$labels
    quality <- .multislice_quality(supra, labels, gamma, omega, coupling)
  }
  best <- unname(match(unlist(lapply(labels, as.vector)),
                       unique(unlist(lapply(labels, as.vector)))))
  agreement <- rowMeans(vapply(flat, .state_agreement, numeric(length(best)),
                               best = best))
  # One run has no pair to compare itself with, so agreement is not low, it
  # is unmeasured; the warning above has already said so.
  stability_ari <- if (length(flat) < 2L) NA_real_ else {
    pairs <- utils::combn(seq_along(flat), 2L)
    mean(vapply(seq_len(ncol(pairs)), function(i)
      .compare_partitions(flat[[pairs[1L, i]]], flat[[pairs[2L, i]]], "ari"),
      numeric(1L)))
  }
  out <- .communities_frame(supra, labels, agreement, dn)
  attr(out, "gamma") <- gamma
  attr(out, "omega") <- omega
  attr(out, "coupling") <- coupling
  attr(out, "method") <- method
  attr(out, "seeds") <- seeds
  attr(out, "q") <- quality$q
  attr(out, "q_runs") <- q_runs
  attr(out, "n_communities") <- quality$n_communities
  attr(out, "stability_ari") <- stability_ari
  attr(out, "matched") <- FALSE
  attr(out, "time_unit") <- dn$meta$time_unit
  attr(out, "spec") <- list(step = p$meta$step, window = p$meta$window)
  if (omega == 0) {
    # Uncoupled slices label each bin on its own, so the integers mean nothing
    # across bins until they are matched. Returning them raw would invite
    # every downstream measure to read relabelling noise as change.
    keep <- attributes(out)
    out <- match_communities(out)
    for (field in setdiff(names(keep), names(attributes(out)))) {
      attr(out, field) <- keep[[field]]
    }
  }
  out
}

#' Assemble the tidy membership frame from label matrices
#'
#' @param supra A structure from [.supra()].
#' @param labels A list of `n x T` label matrices, one per block.
#' @param agreement Per-state stability, in state order.
#' @param dn The source network, whose identity travels with the result so a
#'   downstream verb can describe the network it came from.
#' @return A `dynet_communities` data frame.
#' @keywords internal
.communities_frame <- function(supra, labels, agreement, dn) {
  nodes <- supra$nodes
  blocked <- !is.na(supra$blocks[[1L]]$session)
  frames <- Map(function(b, g) {
    data.frame(
      session = b$session,
      time = rep(b$times, each = length(nodes)),
      node = rep(nodes, length(b$times)),
      community = as.vector(g),
      active = as.vector(b$active),
      stringsAsFactors = FALSE
    )
  }, supra$blocks, labels)
  df <- do.call(rbind, frames)
  df$community <- match(df$community, sort(unique(df$community)))
  df$stability <- agreement
  if (!blocked) df$session <- NULL
  rownames(df) <- NULL
  structure(df, class = c("dynet_communities", "data.frame"),
            source = list(meta = dn$meta, nodes = dn$nodes,
                          directed = dn$directed))
}

#' The partition the runs agree on
#'
#' Lancichinetti and Fortunato's consensus clustering: co-classify every pair
#' of states over the runs, discard agreement no better than chance, and
#' re-cluster what is left, repeating until the runs agree.
#'
#' @param supra A structure from [.supra()].
#' @param flat A list of per-run membership vectors over the states.
#' @param gamma,omega,coupling,tol,max_passes Optimiser settings.
#' @param seeds The seeds to re-run from.
#' @return A list of `n x T` label matrices, one per block.
#' @keywords internal
.consensus_partition <- function(supra, flat, gamma, omega, coupling, tol,
                                 max_passes, seeds) {
  shape <- lapply(supra$blocks, function(b) dim(b$active))
  n_states <- length(flat[[1L]])
  if (n_states > 5000L) {
    stop(errorCondition(sprintf(
      "Consensus clustering needs the %d x %d co-classification matrix of all states, which is too large here. Use method = \"louvain\", or a coarser grid.",
      n_states, n_states),
      class = "dynet_too_large", call = NULL))
  }
  runs <- flat
  # Each round re-clusters the agreement of the last; it stops as soon as the
  # runs are unanimous, which is the published termination rule.
  for (round in seq_len(max_passes)) {
    co <- Reduce(`+`, lapply(runs, function(g) outer(g, g, "==") * 1)) /
      length(runs)
    # Chance level: what the same community sizes would co-classify by
    # accident if the labels were permuted at random.
    chance <- mean(vapply(runs, function(g) {
      size <- tabulate(g)
      sum(size * (size - 1)) / (n_states * (n_states - 1))
    }, numeric(1L)))
    thresholded <- co
    thresholded[co <= chance] <- 0
    diag(thresholded) <- 0
    if (all(co[lower.tri(co)] %in% c(0, 1))) break
    runs <- lapply(seeds, function(seed) .with_seed(seed, {
      .genlouvain_block(list(thresholded), gamma = 1, omega = 0,
                        coupling = "ordinal",
                        visit = sample.int(n_states), tol = tol,
                        max_passes = max_passes)$membership
    }))
    if (length(unique(lapply(runs, function(g) match(g, unique(g))))) == 1L) {
      break
    }
  }
  consensus <- runs[[1L]]
  used <- 0L
  lapply(shape, function(dims) {
    take <- consensus[used + seq_len(prod(dims))]
    used <<- used + prod(dims)
    matrix(take, dims[[1L]], dims[[2L]], dimnames = list(supra$nodes, NULL))
  })
}

#' Print a temporal community partition
#'
#' @param x A `dynet_communities` frame.
#' @param n Number of rows to show.
#' @param ... Ignored.
#' @return `x`, invisibly. Called for the printed output.
#' @export
print.dynet_communities <- function(x, n = 12L, ...) {
  cat(sprintf("# Temporal communities: %d over %d bins | gamma = %s, omega = %s\n",
              attr(x, "n_communities") %||% length(unique(x$community)),
              length(unique(x$time)),
              format(attr(x, "gamma")), format(attr(x, "omega"))))
  quality <- attr(x, "q")
  if (!is.null(quality)) {
    cat(sprintf("# multislice Q = %.4f from %d seeds", quality,
                length(attr(x, "seeds"))))
    ari <- attr(x, "stability_ari")
    if (!is.null(ari) && !is.na(ari)) {
      cat(sprintf(" | run agreement ARI = %.3f%s", ari,
                  if (ari < 0.5) "  <- labels are not stable; read with care"
                  else ""))
    }
    cat("\n")
  }
  if (isTRUE(attr(x, "matched"))) {
    cat(sprintf("# labels matched across bins by %s assignment on %s overlap\n",
                attr(x, "match_method"), attr(x, "match_overlap")))
  }
  print(utils::head(as.data.frame(x), n), row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("# %d more rows. summary() gives one row per community.\n",
                nrow(x) - n))
  }
  invisible(x)
}

#' Summarize a temporal community partition
#'
#' @param object A `dynet_communities` frame.
#' @param ... Ignored.
#' @return A data frame with one row per community: `community`, `n_states`,
#'   `n_nodes`, `first_time`, `last_time`, `n_bins` and `persistence`, the
#'   share of the bins it spans in which it is actually present.
#' @export
summary.dynet_communities <- function(object, ...) {
  df <- as.data.frame(object)
  bins <- sort(unique(df$time))
  rows <- lapply(split(df, df$community), function(part) {
    span <- range(part$time)
    reach <- sum(bins >= span[[1L]] & bins <= span[[2L]])
    data.frame(
      community = part$community[[1L]],
      n_states = nrow(part),
      n_nodes = length(unique(part$node)),
      first_time = span[[1L]], last_time = span[[2L]],
      n_bins = length(unique(part$time)),
      persistence = length(unique(part$time)) / reach,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$community), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Tidy data frame of a temporal community partition
#'
#' @param x A `dynet_communities` frame.
#' @param row.names,optional Ignored, for method consistency.
#' @param what `"membership"` for the frame itself, `"sizes"` for one row per
#'   community per bin, `"runs"` for the modularity each seed reached, or
#'   `"events"` for the lifecycle table after [match_communities()].
#' @param ... Ignored.
#' @return A plain data frame.
#' @export
as.data.frame.dynet_communities <- function(x, row.names = NULL,
                                            optional = FALSE,
                                            what = c("membership", "sizes",
                                                     "runs", "events"),
                                            ...) {
  what <- match.arg(what)
  plain <- x
  attributes(plain) <- NULL
  plain <- as.data.frame(unclass(x)[names(x)], stringsAsFactors = FALSE)
  rownames(plain) <- NULL
  switch(what,
    membership = plain,
    sizes = {
      keys <- if ("session" %in% names(plain)) {
        list(session = plain$session, time = plain$time,
             community = plain$community)
      } else {
        list(time = plain$time, community = plain$community)
      }
      counts <- stats::aggregate(list(n_nodes = plain$node), keys, length)
      active <- stats::aggregate(list(n_active = plain$active), keys, sum)
      out <- merge(counts, active, by = names(keys))
      out[order(out$time, out$community), , drop = FALSE]
    },
    runs = {
      q_runs <- attr(x, "q_runs")
      if (is.null(q_runs)) {
        stop(errorCondition(
          "This partition carries no per-seed record; it did not come from temporal_communities().",
          class = "dynet_bad_input", call = NULL))
      }
      data.frame(seed = attr(x, "seeds"), q = q_runs,
                 best = abs(q_runs - max(q_runs)) < 1e-10,
                 stringsAsFactors = FALSE)
    },
    events = {
      events <- attr(x, "events")
      if (is.null(events)) {
        stop(errorCondition(
          "Lifecycle events exist only after match_communities(), which is what decides whether a community persisted, split, merged or dissolved.",
          class = "dynet_bad_input", call = NULL))
      }
      events
    }
  )
}

#' How much the community structure moved between bins
#'
#' @description
#' "Who is with whom" and "did the structure reorganise, and when" are
#' different questions. This one compares each bin's partition with another
#' bin's by a label-invariant statistic, so it says how much changed without
#' needing to know which community became which.
#'
#' Because every statistic here is invariant to relabelling,
#' [match_communities()] is **not** a prerequisite. That is a common
#' misunderstanding and it is worth stating plainly: matching is needed to
#' follow a community, not to measure change.
#'
#' @param x A `dynet_communities` frame from [temporal_communities()].
#' @param measure One or more of `"nmi"`, `"ari"`, `"vi"`, `"split_join"`,
#'   `"jaccard"` and `"omega_index"`.
#' @param against `"previous"` compares each bin with the one before it,
#'   `"first"` with the opening bin, `"all"` with every other bin.
#'
#' @return A `dynet_metric` at graph level. For `"previous"` and `"first"`,
#'   one row per bin per measure with columns `session`, `time`, `measure`,
#'   `value`; for `"all"`, one row per ordered pair with an `other` column
#'   giving the bin compared against, in the same long shape [similarity()]
#'   uses so both plot with the same code. The `n_compared` attribute records
#'   how many vertices each comparison could actually use.
#'
#' @details
#' Every statistic is built from the contingency table of the two labellings,
#' restricted to the vertices **active in both** bins. A vertex that merely
#' goes quiet must not read as a reorganisation, so it is dropped from both
#' sides rather than counted as having left its community. When fewer than two
#' vertices are shared, nothing is defined and the value is `NA` -- a real
#' absence, not a zero.
#'
#' The first bin has no predecessor, so under `against = "previous"` its value
#' is `NA` by construction.
#'
#' What the six measure, briefly. `"nmi"` is shared information normalised by
#' the mean entropy, in \eqn{[0, 1]}, high for agreement; it is **not**
#' chance-corrected, so two unrelated partitions score above zero. `"ari"` is
#' chance-corrected and centred on zero for unrelated partitions, which is why
#' both are offered. `"vi"` is a true metric in nats, zero for agreement and
#' unbounded above. `"split_join"` counts the vertices that would have to move,
#' so it is an integer in \eqn{[0, 2N]}. `"jaccard"` scores agreement over
#' co-classified pairs. `"omega_index"` is chance-corrected pair agreement; for
#' the disjoint partitions this package produces it coincides exactly with
#' `"ari"`, and it is offered because it is what `multinet` reports and because
#' it generalises to overlapping communities.
#'
#' @references
#' Danon, L., Diaz-Guilera, A., Duch, J., & Arenas, A. (2005). Comparing
#' community structure identification. *Journal of Statistical Mechanics*,
#' P09008.
#'
#' Hubert, L., & Arabie, P. (1985). Comparing partitions. *Journal of
#' Classification*, 2, 193-218.
#'
#' Meila, M. (2007). Comparing clusterings -- an information based distance.
#' *Journal of Multivariate Analysis*, 98(5), 873-895.
#'
#' van Dongen, S. (2000). *Performance criteria for graph clustering and
#' Markov cluster experiments.* CWI Technical Report INS-R0012.
#'
#' Collins, L. M., & Dent, C. W. (1988). Omega: a general formulation of the
#' Rand index of cluster recovery suitable for non-disjoint solutions.
#' *Multivariate Behavioral Research*, 23(2), 231-242.
#'
#' Gates, A. J., & Ahn, Y.-Y. (2019). Element-centric clustering comparison
#' unifies overlaps and hierarchy. *Scientific Reports*, 9, 8574.
#'
#' Vinh, N. X., Epps, J., & Bailey, J. (2010). Information theoretic measures
#' for clusterings comparison. *JMLR*, 11, 2837-2854.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
#' community_change(found)
#' community_change(found, measure = c("nmi", "ari"))
#'
#' @export
community_change <- function(x, measure = c("nmi", "ari", "vi", "split_join",
                                            "jaccard", "omega_index"),
                             against = c("previous", "first", "all")) {
  against <- match.arg(against)
  .check(
    "`x` must be a data frame with `time`, `node` and `community` columns." =
      is.data.frame(x) && all(c("time", "node", "community") %in% names(x)),
    "`measure` must be a character vector naming at least one statistic." =
      is.character(measure) && length(measure) > 0L && !anyNA(measure)
  )
  known <- c("nmi", "ari", "vi", "split_join", "jaccard", "omega_index")
  unknown <- setdiff(measure, known)
  if (length(unknown) > 0L) {
    stop(errorCondition(sprintf(
      "Unknown measure %s. Available: %s.",
      paste(sQuote(unknown), collapse = ", "), paste(known, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  active <- if ("active" %in% names(x)) x$active else rep(TRUE, nrow(x))
  blocked <- "session" %in% names(x)
  keys <- if (blocked) as.character(x$session) else rep("", nrow(x))
  compared <- integer(0)
  frames <- lapply(unique(keys), function(block) {
    rows <- keys == block
    times <- sort(unique(x$time[rows]))
    labels <- lapply(times, function(t) {
      pick <- rows & x$time == t & active
      stats::setNames(x$community[pick], as.character(x$node)[pick])
    })
    compare <- function(i, j) {
      shared <- intersect(names(labels[[i]]), names(labels[[j]]))
      compared <<- c(compared, length(shared))
      if (length(shared) < 2L) {
        return(stats::setNames(rep(NA_real_, length(measure)), measure)) 
      }
      vapply(measure, function(m) .compare_partitions(
        labels[[i]][shared], labels[[j]][shared], m), numeric(1L))
    }
    if (identical(against, "all")) {
      grid <- expand.grid(i = seq_along(times), j = seq_along(times))
      values <- lapply(seq_len(nrow(grid)), function(r)
        compare(grid$i[[r]], grid$j[[r]]))
      # One block of `measure` rows per pair, so every column must repeat each
      # pair that many times; recycling instead would silently shear `value`
      # away from the pair it belongs to.
      data.frame(
        session = block,
        time = rep(times[grid$i], each = length(measure)),
        other = rep(times[grid$j], each = length(measure)),
        measure = rep(measure, times = nrow(grid)),
        value = unlist(values, use.names = FALSE),
        stringsAsFactors = FALSE
      )
    } else {
      # The opening bin has nothing before it, and "first" compares the
      # opening bin with itself, which is exact agreement by definition.
      partner <- if (identical(against, "previous")) {
        c(NA_integer_, seq_len(length(times) - 1L))
      } else {
        rep(1L, length(times))
      }
      values <- lapply(seq_along(times), function(i) {
        if (is.na(partner[[i]])) {
          compared <<- c(compared, NA_integer_)
          stats::setNames(rep(NA_real_, length(measure)), measure)
        } else {
          compare(partner[[i]], i)
        }
      })
      data.frame(
        session = block,
        time = rep(times, each = length(measure)),
        measure = rep(measure, times = length(times)),
        value = unlist(values, use.names = FALSE),
        stringsAsFactors = FALSE
      )
    }
  })
  df <- do.call(rbind, frames)
  if (!blocked) df$session <- NULL
  rownames(df) <- NULL
  out <- .metric(df, level = "graph",
                 what = if (length(measure) == 1L) {
                   sprintf("Community change (%s)", measure)
                 } else "Community change",
                 dn = .communities_source(x), spec = attr(x, "spec"),
                 note = sprintf("compared against the %s bin, over vertices active in both",
                                against))
  attr(out, "against") <- against
  attr(out, "n_compared") <- compared
  attr(out, "n_nodes") <- length(unique(x$node))
  out
}

#' The source network a community partition came from
#'
#' A partition travels with enough of its network for a downstream verb to
#' describe what was measured. An externally supplied frame carries none, so a
#' minimal stand-in is built instead rather than the verb refusing to run.
#'
#' @param x A `dynet_communities` frame or a plain data frame.
#' @return A list with `meta`, `nodes` and `directed`.
#' @keywords internal
.communities_source <- function(x) {
  attr(x, "source") %||% list(
    meta = list(time_unit = attr(x, "time_unit") %||% "step",
                interval = NULL, format = NULL),
    nodes = data.frame(name = unique(as.character(x$node))),
    directed = NA
  )
}

#' The community measures of one label matrix
#'
#' Transcribed from `teneto.communitymeasures` 0.5.3 so the conventions match
#' a reference implementation exactly, including the ones that are debatable:
#' promiscuity divides by the **global** distinct-label count, and allegiance
#' divides by the number of bins rather than by the bins where both vertices
#' were active.
#'
#' @param labels An `n x T` matrix of matched community labels.
#' @return A list with `flexibility`, `promiscuity`, `persistence_node`,
#'   `persistence_time`, `persistence_global` and `allegiance`.
#' @keywords internal
.trajectory_measures <- function(labels) {
  n <- nrow(labels)
  n_bins <- ncol(labels)
  if (n_bins < 2L) {
    stop(errorCondition(
      "Flexibility and persistence compare each bin with the one before it, so they need at least two bins. This partition has one.",
      class = "dynet_empty_result", call = NULL))
  }
  stayed <- labels[, -n_bins, drop = FALSE] == labels[, -1L, drop = FALSE]
  distinct <- vapply(seq_len(n), function(i) length(unique(labels[i, ])),
                     integer(1L))
  overall <- length(unique(as.vector(labels)))
  allegiance <- matrix(0, n, n, dimnames = list(rownames(labels),
                                                rownames(labels)))
  # One bin at a time: an n x n indicator per bin, averaged. The alternative
  # is an n x n x T array, which is the same arithmetic and T times the memory.
  for (bin in seq_len(n_bins)) {
    allegiance <- allegiance + outer(labels[, bin], labels[, bin], "==")
  }
  allegiance <- allegiance / n_bins
  diag(allegiance) <- NA_real_
  list(
    flexibility = rowMeans(!stayed),
    # A single community everywhere makes the denominator zero. teneto
    # divides anyway; here every vertex scores zero, which is the value the
    # ratio approaches and the honest reading of "belonged to no others".
    promiscuity = if (overall <= 1L) rep(0, n) else (distinct - 1) /
      (overall - 1),
    persistence_node = rowMeans(stayed),
    persistence_time = c(NA_real_, colMeans(stayed)),
    persistence_global = mean(stayed),
    allegiance = allegiance
  )
}

#' What each vertex did across the community structure
#'
#' @description
#' Once labels mean the same thing in every bin, the interesting quantities
#' are about vertices rather than communities: how often one changes group,
#' how many groups it has belonged to, how reliably it stays put, how often
#' two vertices are found together, and how tightly a vertex sticks to its own
#' reference group rather than visiting others.
#'
#' @param x A `dynet_communities` frame whose labels are consistent across
#'   bins -- either from [temporal_communities()] with `omega > 0`, or from
#'   [match_communities()].
#' @param measure One or more of `"flexibility"`, `"promiscuity"`,
#'   `"persistence"`, `"recruitment"` and `"integration"`.
#' @param reference For `"recruitment"` and `"integration"`: the name of a
#'   vertex attribute on the network the partition came from, or one group
#'   label per vertex. Those two measures compare a vertex's allegiance to its
#'   own reference group against its allegiance to the others, so they have no
#'   meaning without one.
#'
#' @return A `dynet_metric` at node level, one row per vertex per measure,
#'   with columns `session` (only when the network has sessions), `node`,
#'   `measure` and `value`. Every measure here summarises the whole series, so
#'   there is no `time` column; the per-bin and whole-series forms of
#'   persistence, and the pairwise allegiance table, are reached by
#'   `as.data.frame(x, what = )`.
#'
#' @details
#' Let \eqn{C_{it}} be the community of vertex \eqn{i} in bin \eqn{t}, over
#' \eqn{T} bins.
#'
#' **Flexibility** is the share of consecutive bins in which a vertex changed
#' community, \eqn{\frac{1}{T-1}\sum_{t=2}^{T}[C_{it} \ne C_{i,t-1}]}.
#'
#' **Promiscuity** is how much of the whole community structure a vertex
#' visited: its distinct-label count minus one, over the **global**
#' distinct-label count minus one. A vertex that never moves scores zero; one
#' that visits every community scores one. The denominator is global, not per
#' vertex; that is teneto's convention and it is what makes the measure
#' comparable across vertices.
#'
#' **Persistence** is the complement of flexibility, and comes at three
#' granularities: per vertex, per bin, and one number for the whole series.
#' The per-bin form is `NA` in the first bin, which has no predecessor.
#'
#' **Allegiance** \eqn{P_{ij} = \frac{1}{T}\sum_t [C_{it} = C_{jt}]} is how
#' often two vertices were in the same community. It divides by the number of
#' bins, not by the bins in which both were active -- teneto's convention,
#' replicated here so the numbers agree.
#'
#' **Recruitment** is a vertex's mean allegiance to the other members of its
#' own `reference` group; **integration** is its mean allegiance to vertices
#' outside it.
#'
#' *Why the labels must be matched first.* All of these read a change of label
#' as a change of group. If the labels are per-bin arbitrary -- which they are
#' whenever the slices were solved independently -- then flexibility measures
#' relabelling noise and nothing else. This verb therefore refuses to run on
#' an unmatched partition rather than returning a number that looks fine.
#'
#' *Inactive vertices.* A vertex inactive in a bin still carries the label its
#' identity arc brought it, matching [projection()]'s waiting convention, so
#' it is neither dropped nor treated as having left. `n_inactive_states`
#' records how many states that covers, so the reader can judge.
#'
#' @references
#' Bassett, D. S., Wymbs, N. F., Porter, M. A., Mucha, P. J., Carlson, J. M.,
#' & Grafton, S. T. (2011). Dynamic reconfiguration of human brain networks
#' during learning. *PNAS*, 108(18), 7641-7646.
#'
#' Papadopoulos, L., Puckett, J. G., Daniels, K. E., & Bassett, D. S. (2016).
#' Evolution of network architecture in a granular material under compression.
#' *Physical Review E*, 94(3), 032908.
#'
#' Bassett, D. S., Porter, M. A., Wymbs, N. F., Grafton, S. T., Carlson, J.
#' M., & Mucha, P. J. (2013). Robust detection of dynamic community structure
#' in networks. *Chaos*, 23(1), 013142.
#'
#' Bassett, D. S., Yang, M., Wymbs, N. F., & Grafton, S. T. (2015).
#' Learning-induced autonomy of sensorimotor systems. *Nature Neuroscience*,
#' 18(5), 744-751.
#'
#' Thompson, W. H., Brantefors, P., & Fransson, P. (2017). From static to
#' temporal network theory. *Network Neuroscience*, 1(2), 69-99.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' found <- temporal_communities(dn, step = 5, window = 5, seeds = 1:5)
#' community_trajectory(found)
#' as.data.frame(community_trajectory(found), what = "time")
#'
#' @export
community_trajectory <- function(x,
                                 measure = c("flexibility", "promiscuity",
                                             "persistence"),
                                 reference = NULL) {
  .check(
    "`x` must be a data frame with `time`, `node` and `community` columns." =
      is.data.frame(x) && all(c("time", "node", "community") %in% names(x)),
    "`measure` must be a character vector naming at least one measure." =
      is.character(measure) && length(measure) > 0L && !anyNA(measure)
  )
  known <- c("flexibility", "promiscuity", "persistence", "recruitment",
             "integration")
  unknown <- setdiff(measure, known)
  if (length(unknown) > 0L) {
    stop(errorCondition(sprintf(
      "Unknown measure %s. Available: %s.",
      paste(sQuote(unknown), collapse = ", "), paste(known, collapse = ", ")),
      class = "dynet_unknown_measure", call = NULL))
  }
  coupled <- isTRUE((attr(x, "omega") %||% 0) > 0)
  if (!coupled && !isTRUE(attr(x, "matched"))) {
    stop(errorCondition(
      "These community labels are not comparable across bins, so every measure here would be counting relabelling noise. Run match_communities() on this partition first, or detect it with temporal_communities(omega > 0), whose coupling matches the labels inside the objective.",
      class = "dynet_unmatched_labels", call = NULL))
  }
  wants_reference <- any(c("recruitment", "integration") %in% measure)
  groups <- if (wants_reference) .trajectory_reference(x, reference) else NULL
  blocked <- "session" %in% names(x)
  keys <- if (blocked) as.character(x$session) else rep("", nrow(x))
  nodes <- sort(unique(as.character(x$node)))
  if (length(nodes) > 2000L && wants_reference) {
    stop(errorCondition(sprintf(
      "Recruitment and integration are built from the %d x %d allegiance matrix, which is too large here. Compute them on a subset of the vertices.",
      length(nodes), length(nodes)),
      class = "dynet_too_large", call = NULL))
  }
  inactive <- if ("active" %in% names(x)) sum(!x$active) else 0L
  per_block <- lapply(unique(keys), function(block) {
    rows <- keys == block
    times <- sort(unique(x$time[rows]))
    labels <- matrix(NA_integer_, length(nodes), length(times),
                     dimnames = list(nodes, NULL))
    labels[cbind(match(as.character(x$node)[rows], nodes),
                 match(x$time[rows], times))] <- x$community[rows]
    if (anyNA(labels)) {
      stop(errorCondition(
        "`x` does not label every vertex in every bin, so a trajectory cannot be followed through the gaps.",
        class = "dynet_bad_input", call = NULL))
    }
    stats <- .trajectory_measures(labels)
    if (wants_reference) {
      same <- outer(groups[nodes], groups[nodes], "==")
      diag(same) <- NA
      stats$recruitment <- vapply(seq_along(nodes), function(i)
        mean(stats$allegiance[i, which(same[i, ])]), numeric(1L))
      stats$integration <- vapply(seq_along(nodes), function(i)
        mean(stats$allegiance[i, which(!same[i, ])]), numeric(1L))
    }
    list(session = block, times = times, stats = stats)
  })
  node_value <- function(stats, m) switch(m,
    flexibility = stats$flexibility, promiscuity = stats$promiscuity,
    persistence = stats$persistence_node, recruitment = stats$recruitment,
    integration = stats$integration)
  df <- do.call(rbind, lapply(per_block, function(b) data.frame(
    session = b$session, node = rep(nodes, times = length(measure)),
    measure = rep(measure, each = length(nodes)),
    value = unlist(lapply(measure, function(m) node_value(b$stats, m)),
                   use.names = FALSE),
    stringsAsFactors = FALSE)))
  if (!blocked) df$session <- NULL
  out <- .metric(df, level = "node", what = "Community trajectory",
                 dn = .communities_source(x), spec = attr(x, "spec"),
                 note = if (inactive > 0L) sprintf(
                   "%d inactive states carried their coupled label forward",
                   inactive))
  attr(out, "n_inactive_states") <- inactive
  attr(out, "blocks") <- per_block
  attr(out, "nodes") <- nodes
  attr(out, "blocked") <- blocked
  attr(out, "stability_ari") <- attr(x, "stability_ari")
  class(out) <- unique(c("dynet_trajectory", class(out)))
  out
}

#' Resolve the `reference` argument to one label per vertex
#'
#' @param x A `dynet_communities` frame.
#' @param reference A vertex attribute name, or one label per vertex.
#' @return A named character vector, one label per vertex name.
#' @keywords internal
.trajectory_reference <- function(x, reference) {
  nodes <- sort(unique(as.character(x$node)))
  table <- .communities_source(x)$nodes
  if (is.null(reference)) {
    have <- setdiff(names(table), c("id", "label", "name", "x", "y"))
    stop(errorCondition(sprintf(
      "Recruitment and integration compare a vertex's allegiance inside its own group against its allegiance outside it, so they need `reference`: a vertex attribute name, or one label per vertex. This network has %s.",
      if (length(have)) paste(sQuote(have), collapse = ", ") else
        "no vertex attributes"),
      class = "dynet_bad_input", call = NULL))
  }
  if (length(reference) == 1L && is.character(reference) &&
      reference %in% names(table)) {
    return(stats::setNames(as.character(table[[reference]]),
                           as.character(table$name))[nodes])
  }
  if (length(reference) == length(nodes)) {
    labelled <- if (!is.null(names(reference))) {
      stats::setNames(as.character(reference), names(reference))[nodes]
    } else {
      stats::setNames(as.character(reference), nodes)
    }
    if (!anyNA(labelled)) return(labelled)
  }
  have <- setdiff(names(table), c("id", "label", "name", "x", "y"))
  stop(errorCondition(sprintf(
    "No vertex attribute %s, and `reference` is not one label per vertex. This network has %s.",
    sQuote(as.character(reference)[[1L]]),
    if (length(have)) paste(sQuote(have), collapse = ", ") else
      "no vertex attributes"),
    class = "dynet_unknown_attribute", call = NULL))
}

#' Tidy data frame of community trajectories
#'
#' @param x A `dynet_trajectory` from [community_trajectory()].
#' @param row.names,optional Ignored, for method consistency.
#' @param what `"node"` for one row per vertex per measure, `"time"` for
#'   persistence per bin, `"global"` for persistence over the whole series, or
#'   `"allegiance"` for one row per ordered vertex pair.
#' @param ... Ignored.
#' @return A plain data frame.
#' @export
as.data.frame.dynet_trajectory <- function(x, row.names = NULL,
                                           optional = FALSE,
                                           what = c("node", "time", "global",
                                                    "allegiance"), ...) {
  what <- match.arg(what)
  blocks <- attr(x, "blocks")
  nodes <- attr(x, "nodes")
  blocked <- isTRUE(attr(x, "blocked"))
  drop_session <- function(df) {
    if (!blocked) df$session <- NULL
    rownames(df) <- NULL
    df
  }
  if (identical(what, "node")) {
    plain <- as.data.frame(unclass(x)[names(x)], stringsAsFactors = FALSE)
    rownames(plain) <- NULL
    return(plain)
  }
  drop_session(do.call(rbind, lapply(blocks, function(b) switch(what,
    time = data.frame(session = b$session, time = b$times,
                      measure = "persistence",
                      value = b$stats$persistence_time,
                      stringsAsFactors = FALSE),
    global = data.frame(session = b$session, measure = "persistence",
                        value = b$stats$persistence_global,
                        stringsAsFactors = FALSE),
    allegiance = data.frame(
      session = b$session,
      node = rep(nodes, times = length(nodes)),
      other = rep(nodes, each = length(nodes)),
      value = as.vector(b$stats$allegiance),
      stringsAsFactors = FALSE)
  ))))
}

#' Draw community membership as ribbons over time
#'
#' @description
#' One band per vertex per bin, stacked by community, so a community reads as
#' a block and a vertex changing community reads as a band crossing between
#' blocks. Communities are labelled directly on the plot as well as coloured,
#' because colour alone is not a channel every reader has.
#'
#' @param x A `dynet_communities` frame.
#' @param base_size Base text size.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @export
plot.dynet_communities <- function(x, base_size = 12, ...) {
  df <- as.data.frame(x)
  df$community <- factor(df$community)
  # Vertices are ordered by the community they spend most of their time in,
  # so a persistent community is a solid block rather than a comb.
  home <- vapply(split(df$community, df$node), function(v)
    names(sort(table(v), decreasing = TRUE))[[1L]], character(1L))
  order_key <- order(as.integer(home), names(home))
  df$node <- factor(df$node, levels = names(home)[order_key])
  labels <- do.call(rbind, lapply(split(df, df$community), function(part) {
    data.frame(time = stats::median(unique(part$time)),
               node = levels(df$node)[round(stats::median(
                 as.integer(part$node)))],
               community = part$community[[1L]], stringsAsFactors = FALSE)
  }))
  labels$node <- factor(labels$node, levels = levels(df$node))
  step <- if (length(unique(df$time)) > 1L) {
    min(diff(sort(unique(df$time))))
  } else 1
  ggplot2::ggplot(df) +
    ggplot2::geom_tile(
      ggplot2::aes(x = time, y = node, fill = community,
                   alpha = active), width = step, height = 0.92) +
    ggplot2::geom_label(
      data = labels,
      ggplot2::aes(x = time, y = node, label = community),
      size = base_size / 3.2, linewidth = 0, fill = "#FFFFFFCC",
      inherit.aes = FALSE) +
    ggplot2::scale_fill_manual(values = .okabe_ito(nlevels(df$community)),
                               name = "Community", guide = "none") +
    ggplot2::scale_alpha_manual(values = c(`FALSE` = 0.35, `TRUE` = 1),
                                name = "Active", breaks = c(TRUE, FALSE)) +
    ggplot2::labs(
      x = sprintf("Time (%s)", attr(x, "time_unit") %||% "step"),
      y = NULL,
      title = "Community membership over time",
      subtitle = if (!is.null(attr(x, "q"))) sprintf(
        "multislice Q = %.3f, omega = %s, run agreement ARI = %.2f",
        attr(x, "q"), format(attr(x, "omega")),
        attr(x, "stability_ari"))) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"))
}
