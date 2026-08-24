# ===========================================================================
# Time-respecting paths and reachability
# ===========================================================================

#' Earliest-arrival times from one source
#'
#' Relaxation continues until no arrival time improves. A single forward sweep
#' is not enough: an edge with an early onset but a late terminus can be
#' boarded long after it first appears, so its usefulness may only become
#' apparent once a later edge has been relaxed.
#'
#' @param enc Encoded edge list from [.encode()].
#' @param source Integer index of the source vertex.
#' @param t0 Time at which the source becomes active.
#' @param max_sweeps Iteration cap.
#' @return A list with `arrival`, `previous`, `source` and `origin`.
#'
#' @details
#' Forward traversal follows non-strict, vertex-simple temporal journeys.
#' Waiting is allowed and traversal itself takes zero time. A positive-duration
#' interval `[start, end)` can be boarded after arrival only while arrival is
#' strictly before `end`; its earliest traversal time is the later of arrival
#' and `start`. An instantaneous event is a separate case: it can be used when
#' arrival is at or before its timestamp, and arrival at the next vertex is
#' that timestamp. Consequently, several events at the same time can compose
#' into a journey, independent of input row order.
#'
#' A reversed-time encoding retains the supremum convention used by backward
#' latest-departure paths; it does not inherit the forward end predicate.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_bfs(Dynet:::.encode(dn), source = 1L, t0 = 0)
#' @keywords internal
.temporal_bfs <- function(enc, source, t0, max_sweeps = NULL) {
  n <- enc$n
  arrival  <- rep(Inf, n)
  previous <- rep(NA_integer_, n)
  arrival[source] <- t0
  f <- enc$from; g <- enc$to; s <- enc$start; e <- enc$end
  cap <- max_sweeps %||% (n + 1L)

  sweep <- 0L
  # Fixpoint relaxation; each sweep depends on the arrivals the last one set.
  repeat {
    sweep <- sweep + 1L
    a_from <- arrival[f]
    interval_usable <- if (isTRUE(enc$reversed)) a_from <= e else a_from < e
    usable <- is.finite(a_from) &
      ((enc$instant & a_from <= s) | (!enc$instant & interval_usable))
    if (!any(usable)) break
    cand <- pmax(a_from, s)
    cand[!usable] <- Inf
    improve <- which(cand < arrival[g])
    if (length(improve) == 0L) break
    # Keep, per target, only the edge that arrives first.
    ord   <- order(g[improve], cand[improve])
    best  <- improve[ord][!duplicated(g[improve][ord])]
    arrival[g[best]]  <- cand[best]
    previous[g[best]] <- f[best]
    if (sweep >= cap) {
      warning(warningCondition(
        sprintf("Temporal reachability stopped after %d sweeps without settling.", cap),
        class = "dynet_no_converge", call = NULL))
      break
    }
  }
  list(arrival = arrival, previous = previous, source = source, origin = t0)
}

#' Follow a predecessor chain back to the source
#' @param previous Integer vector of predecessors.
#' @param source Source vertex index.
#' @param target Target vertex index.
#' @return An integer vector from source to target, or `integer(0)`.
#' @keywords internal
.trace <- function(previous, source, target) {
  path <- target
  seen <- rep(FALSE, length(previous))
  cur <- target
  while (!identical(cur, source)) {
    if (is.na(previous[cur]) || seen[cur]) return(integer(0))
    seen[cur] <- TRUE
    cur <- previous[cur]
    path <- c(cur, path)
  }
  path
}

#' Reverse a network in time, for latest-departure computations
#' @param enc Encoded edge list.
#' @return An encoded edge list with direction and time both reversed.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.reverse_time(Dynet:::.encode(dn))
#' @keywords internal
.reverse_time <- function(enc) {
  out <- enc
  out$from  <- enc$to
  out$to    <- enc$from
  out$start <- -enc$end
  out$end   <- -enc$start
  out$reversed <- !isTRUE(enc$reversed)
  out
}

#' Run reachability with sessions acting as walls
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param source Source vertex index.
#' @param t0 Start time.
#' @param bounded Whether a path must stay within one session.
#' @return A BFS result list.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bfs_bounded(
#'   dn, Dynet:::.encode(dn), source = 1L, t0 = 0, bounded = FALSE
#' )
#' @keywords internal
.bfs_bounded <- function(dn, enc, source, t0, bounded) {
  if (!bounded || is.null(dn$meta$sessions)) {
    return(.temporal_bfs(enc, source, t0))
  }
  # A bounded path may not cross a session wall, so each session is searched
  # on its own and the earliest arrival across sessions wins.
  per <- lapply(split(seq_along(enc$from), enc$session), function(rows) {
    sub <- enc
    sub$from <- enc$from[rows]; sub$to <- enc$to[rows]
    sub$start <- enc$start[rows]; sub$end <- enc$end[rows]
    sub$weight <- enc$weight[rows]
    sub$session <- enc$session[rows]
    sub$instant <- enc$instant[rows]
    .temporal_bfs(sub, source, t0)
  })
  arr <- do.call(pmin, lapply(per, `[[`, "arrival"))
  prev <- vapply(seq_along(arr), function(v) {
    cand <- vapply(per, function(p) p$arrival[v], numeric(1L))
    if (all(is.infinite(cand))) return(NA_integer_)
    per[[which.min(cand)]]$previous[v]
  }, integer(1L))
  list(arrival = arr, previous = prev, source = source, origin = t0)
}


# ===========================================================================
# dyn_paths()
# ===========================================================================

#' Time-respecting paths from a vertex
#'
#' @description
#' Follows every time-respecting path out of (or into) one vertex and reports
#' where it gets to, when, and through whom. A path may only use edges whose
#' timing runs forward, so unlike a path in a flattened network it can never
#' travel back in time.
#'
#' The source vertex is named, not numbered. `dyn_paths(dn, from = "Ana")`
#' works; there is no vertex index to look up first.
#'
#' Forward paths use nondecreasing traversal times, so relations active at the
#' same instant may form a multi-hop chain. Waiting is allowed. Interval spells
#' are onset-inclusive and terminus-exclusive; point events are traversable at
#' their exact timestamp through a distinct event rule. Reach and arrival do
#' not depend on edge-row order or duplicate spell rows.
#'
#' @param dn A temporal network from [dynet()].
#' @param from Name of the vertex to start from.
#' @param at Time at which the source becomes active. Defaults to the start of
#'   the observation window.
#' @param direction `"forward"` traces where the vertex can reach;
#'   `"backward"` traces who could have reached it.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#'
#' @return An object of class `"dynet_paths"`: a tidy data frame with one row
#'   per vertex and columns `node`, `reachable`, `arrival_time`, `latency`
#'   (time taken from the source), `n_hops` and `previous` (the vertex
#'   arrived from, by name).
#'
#' @details
#' A valid forward journey has distinct vertices and traversal times
#' `at <= t1 <= ... <= tk`. At each hop, either an interval is active at the
#' traversal time or a point event occurs exactly then. The empty journey
#' reaches the source at `at`. Cycles are unnecessary for reach and earliest
#' arrival because deleting a repeated-vertex section and waiting at that
#' vertex preserves every later hop. This contract defines feasibility and
#' arrival; optimal-journey ties and multiplicity are separate quantities.
#'
#' Backward paths retain their existing latest-departure boundary convention;
#' it is not the forward interval predicate applied without transformation.
#'
#' @references
#' Kempe, D., Kleinberg, J., & Kumar, A. (2002). Connectivity and inference
#' problems for temporal networks. *Journal of Computer and System Sciences*,
#' 64(4), 820-842.
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' Casteigts, A., Corsini, A., & Sarkar, W. (2024). Simple, strict, proper,
#' happy: A study of reachability in temporal graphs. *Theoretical Computer
#' Science*, 991, 114434.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_paths(dn, from = "Ana")
#' summary(dyn_paths(dn, from = "Ana"))
#'
#' @export
dyn_paths <- function(dn, from, at = NULL,
                      direction = c("forward", "backward"),
                      sessions = c("bounded", "collapse", "separate")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  .check("`from` must be a single vertex name." =
              length(from) == 1L && !is.na(from))

  enc <- .encode(dn)
  src <- match(as.character(from), enc$names)
  if (is.na(src)) {
    stop(errorCondition(
      sprintf("Vertex %s is not in this network. Vertices are: %s",
              sQuote(from), paste(utils::head(enc$names, 10), collapse = ", ")),
      class = "dynet_unknown_vertex", call = NULL))
  }
  if (!dn$directed || identical(direction, "backward")) {
    enc <- .undirect_or_reverse(enc, dn$directed, direction)
  }

  t0 <- at %||% if (identical(direction, "backward")) {
    -dn$meta$time_range[["end"]]
  } else {
    dn$meta$time_range[["start"]]
  }

  bfs <- .bfs_bounded(dn, enc, src, t0, identical(sessions, "bounded"))
  reach <- is.finite(bfs$arrival)
  hops <- vapply(seq_len(enc$n), function(v) {
    if (v == src) return(0L)
    if (!reach[v]) return(NA_integer_)
    p <- .trace(bfs$previous, src, v)
    if (length(p) > 0L) length(p) - 1L else NA_integer_
  }, integer(1L))

  arrival <- if (identical(direction, "backward")) -bfs$arrival else bfs$arrival
  latency <- abs(bfs$arrival - t0)
  latency[!reach] <- NA_real_

  out <- data.frame(
    node         = enc$names,
    reachable    = reach,
    arrival_time = ifelse(reach, arrival, NA_real_),
    latency      = latency,
    n_hops       = hops,
    previous     = ifelse(is.na(bfs$previous), NA_character_,
                          enc$names[bfs$previous]),
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  structure(out, class = c("dynet_paths", "data.frame"),
            source = enc$names[src], direction = direction,
            origin = if (identical(direction, "backward")) -t0 else t0,
            time_unit = dn$meta$time_unit)
}

#' Adapt an encoding for undirected traversal or backward search
#' @param enc Encoded edge list.
#' @param directed Whether the network is directed.
#' @param direction `"forward"` or `"backward"`.
#' @return An encoded edge list.
#' @keywords internal
.undirect_or_reverse <- function(enc, directed, direction) {
  if (!directed) {
    both <- enc
    both$from   <- c(enc$from, enc$to)
    both$to     <- c(enc$to, enc$from)
    both$start  <- rep(enc$start, 2L)
    both$end    <- rep(enc$end, 2L)
    both$weight <- rep(enc$weight, 2L)
    both$session <- rep(enc$session, 2L)
    both$instant <- rep(enc$instant, 2L)
    enc <- both
  }
  if (identical(direction, "backward")) enc <- .reverse_time(enc)
  enc
}


# ===========================================================================
# dyn_reachability()
# ===========================================================================

#' Reachability of every vertex
#'
#' @description
#' The share of the network each vertex can reach along time-respecting paths,
#' and the share that can reach it. Reachability is the temporal replacement
#' for component membership: in a static network two vertices in the same
#' component reach each other by definition, whereas in a temporal network
#' reach depends on whether the timing lines up.
#'
#' @param dn A temporal network from [dynet()].
#' @param direction `"forward"`, `"backward"` or `"both"`.
#' @param at Time at which sources become active.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at node level with measures `forward_reach` and
#'   `backward_reach`, each the proportion of other vertices involved.
#'
#' @details
#' Reachability uses [dyn_paths()] traversal semantics: nondecreasing times,
#' unlimited waiting, half-open interval spells, and a separate exact timestamp
#' rule for point events.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_reachability(dn)
#' plot(dyn_reachability(dn))
#'
#' @export
dyn_reachability <- function(dn, direction = c("both", "forward", "backward"),
                             at = NULL,
                             sessions = c("bounded", "collapse", "separate")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  wanted <- if (identical(direction, "both")) c("forward", "backward") else direction

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    vals <- lapply(wanted, function(d) {
      e2 <- .undirect_or_reverse(enc, dn$directed, d)
      t0 <- at %||% if (identical(d, "backward")) -max(enc$end) else min(enc$start)
      share <- vapply(seq_len(enc$n), function(s) {
        b <- .bfs_bounded(dn, e2, s, t0, identical(sessions, "bounded"))
        (sum(is.finite(b$arrival)) - 1) / max(1, enc$n - 1)
      }, numeric(1L))
      share
    })
    data.frame(session = label, node = enc$names,
               measure = rep(paste0(wanted, "_reach"), each = enc$n),
               value = unlist(vals, use.names = FALSE),
               stringsAsFactors = FALSE)
  }, parts, names(parts))

  .metric(do.call(rbind, frames), level = "node", what = "Reachability",
          dn = dn, note = "share of other vertices joined by a time-respecting path")
}
