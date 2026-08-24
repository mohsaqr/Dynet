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
#' @param upper Latest admissible traversal time.
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
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_bfs(Dynet:::.encode(dn), source = 1L, t0 = 0)
#' @keywords internal
.temporal_bfs <- function(enc, source, t0, max_sweeps = NULL, upper = Inf) {
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
    candidate <- pmax(a_from, s)
    interval_usable <- if (isTRUE(enc$reversed)) a_from <= e else a_from < e
    usable <- is.finite(a_from) &
      ((enc$instant & a_from <= s) | (!enc$instant & interval_usable)) &
      candidate <= upper
    if (!any(usable)) break
    cand <- candidate
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

#' Latest-departure suprema into one target
#'
#' @param enc Encoded edge list from [.encode()].
#' @param target Integer index of the target vertex.
#' @param deadline Latest permitted arrival time at the target.
#' @param max_sweeps Iteration cap.
#' @param lower Earliest admissible traversal time.
#' @return A list with `arrival`, `attained`, `previous`, `source` and
#'   `origin`. Here `arrival` contains latest-departure suprema and `previous`
#'   points from each predecessor toward the target.
#'
#' @details
#' Backward traversal is evaluated in original time. For a positive-duration
#' interval `[start, end)`, the latest usable time can equal `end` only as an
#' unattained supremum. The `attained` state preserves that distinction so an
#' exact point event cannot incorrectly compose through the excluded endpoint.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.temporal_bfs_backward(
#'   Dynet:::.encode(dn), target = 1L, deadline = 10
#' )
#' @keywords internal
.temporal_bfs_backward <- function(enc, target, deadline,
                                   max_sweeps = NULL, lower = -Inf) {
  n <- enc$n
  latest <- rep(-Inf, n)
  attained <- rep(FALSE, n)
  previous <- rep(NA_integer_, n)
  latest[target] <- deadline
  attained[target] <- TRUE
  f <- enc$from; g <- enc$to; s <- enc$start; e <- enc$end
  cap <- max_sweeps %||% (2L * n + 1L)

  sweep <- 0L
  repeat {
    sweep <- sweep + 1L
    bound <- latest[g]
    bound_attained <- attained[g]
    feasible <- bound > s | (bound == s & bound_attained)
    usable <- is.finite(bound) & feasible
    if (!any(usable)) break

    candidate <- rep(-Inf, length(f))
    candidate[usable] <- ifelse(
      enc$instant[usable], s[usable], pmin(bound[usable], e[usable])
    )
    candidate_attained <- rep(FALSE, length(f))
    candidate_attained[usable] <- enc$instant[usable] |
      (bound[usable] < e[usable] & bound_attained[usable])
    usable <- usable & (candidate > lower |
      (candidate == lower & candidate_attained))
    if (!any(usable)) break

    groups <- split(which(usable), f[usable])
    vertices <- as.integer(names(groups))
    best_time <- vapply(groups, function(rows) {
      max(candidate[rows])
    }, numeric(1L))
    best_attained <- Map(function(rows, value) {
      any(candidate[rows] == value & candidate_attained[rows])
    }, groups, best_time)
    best_attained <- unlist(best_attained, use.names = FALSE)
    best_edge <- Map(function(rows, value, is_attained) {
      tied <- rows[candidate[rows] == value]
      if (is_attained) tied <- tied[candidate_attained[tied]]
      tied[which.min(g[tied])]
    }, groups, best_time, best_attained)
    best_edge <- unlist(best_edge, use.names = FALSE)

    improve <- best_time > latest[vertices] |
      (best_time == latest[vertices] & best_attained & !attained[vertices])
    if (!any(improve)) break
    changed <- vertices[improve]
    latest[changed] <- best_time[improve]
    attained[changed] <- best_attained[improve]
    previous[changed] <- g[best_edge[improve]]
    if (sweep >= cap) {
      warning(warningCondition(
        sprintf("Backward temporal reachability stopped after %d sweeps without settling.",
                cap),
        class = "dynet_no_converge", call = NULL))
      break
    }
  }
  list(arrival = latest, attained = attained, previous = previous,
       source = target, origin = deadline)
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
#' @param upper Latest admissible traversal time.
#' @return A BFS result list.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bfs_bounded(
#'   dn, Dynet:::.encode(dn), source = 1L, t0 = 0, bounded = FALSE
#' )
#' @keywords internal
.bfs_bounded <- function(dn, enc, source, t0, bounded, upper = Inf) {
  if (!bounded || is.null(dn$meta$sessions)) {
    return(.temporal_bfs(enc, source, t0, upper = upper))
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
    .temporal_bfs(sub, source, t0, upper = upper)
  })
  arr <- do.call(pmin, lapply(per, `[[`, "arrival"))
  best_sessions <- lapply(seq_along(arr), function(v) {
    cand <- vapply(per, function(p) p$arrival[v], numeric(1L))
    which(is.finite(cand) & cand == arr[v])
  })
  best_sessions[[source]] <- integer(0)
  previous <- vapply(seq_along(arr), function(v) {
    selected <- best_sessions[[v]]
    if (length(selected) != 1L) return(NA_integer_)
    per[[selected]]$previous[v]
  }, integer(1L))
  list(arrival = arr, previous = previous, source = source, origin = t0,
       per_session = per, best_sessions = best_sessions,
       session_names = names(per))
}

#' Run backward reachability with sessions acting as walls
#'
#' @param dn A `dynet` object.
#' @param enc Encoded edge list.
#' @param target Target vertex index.
#' @param deadline Latest permitted arrival time at the target.
#' @param bounded Whether a path must stay within one session.
#' @param lower Earliest admissible traversal time.
#' @return A backward BFS result list.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.bfs_backward_bounded(
#'   dn, Dynet:::.encode(dn), target = 1L, deadline = 10,
#'   bounded = FALSE
#' )
#' @keywords internal
.bfs_backward_bounded <- function(dn, enc, target, deadline, bounded,
                                  lower = -Inf) {
  if (!bounded || is.null(dn$meta$sessions)) {
    return(.temporal_bfs_backward(enc, target, deadline, lower = lower))
  }
  # A bounded journey is contained in one session. Search each session and
  # retain the greatest latest-departure supremum across those searches.
  per <- lapply(split(seq_along(enc$from), enc$session), function(rows) {
    sub <- enc
    sub$from <- enc$from[rows]; sub$to <- enc$to[rows]
    sub$start <- enc$start[rows]; sub$end <- enc$end[rows]
    sub$weight <- enc$weight[rows]
    sub$session <- enc$session[rows]
    sub$instant <- enc$instant[rows]
    .temporal_bfs_backward(sub, target, deadline, lower = lower)
  })
  latest <- do.call(pmax, lapply(per, `[[`, "arrival"))
  attained <- vapply(seq_along(latest), function(v) {
    any(vapply(per, function(result) {
      result$arrival[v] == latest[v] && result$attained[v]
    }, logical(1L)))
  }, logical(1L))
  best_sessions <- lapply(seq_along(latest), function(v) {
    candidate <- vapply(per, function(result) result$arrival[v], numeric(1L))
    candidate_attained <- vapply(per, function(result) {
      result$attained[v]
    }, logical(1L))
    which(is.finite(candidate) & candidate == latest[v] &
      candidate_attained == attained[v])
  })
  best_sessions[[target]] <- integer(0)
  previous <- vapply(seq_along(latest), function(v) {
    selected <- best_sessions[[v]]
    if (length(selected) != 1L) return(NA_integer_)
    per[[selected]]$previous[v]
  }, integer(1L))
  list(arrival = latest, attained = attained, previous = previous,
       source = target, origin = deadline, per_session = per,
       best_sessions = best_sessions, session_names = names(per))
}

#' Resolve a path traversal window
#'
#' @param dn A `dynet` object.
#' @param direction `"forward"` or `"backward"`.
#' @param at Directional compatibility alias for an anchor.
#' @param start,end Canonical traversal bounds.
#' @param default_start,default_end Default observed bounds for this encoding.
#' @param clamp_missing Whether an implicit bound may clamp to an explicit one
#'   for a non-overlapping separate session.
#' @return A list containing numeric `start` and `end`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.path_window(dn, "forward", start = 0, end = 10)
#' @keywords internal
.path_window <- function(dn, direction, at = NULL, start = NULL, end = NULL,
                         default_start = dn$meta$time_range[["start"]],
                         default_end = dn$meta$time_range[["end"]],
                         clamp_missing = FALSE) {
  direction <- match.arg(direction, c("forward", "backward"))
  stopifnot(is.logical(clamp_missing), length(clamp_missing) == 1L,
            !is.na(clamp_missing))
  if (!is.null(at) && (!is.null(start) || !is.null(end))) {
    stop(errorCondition(
      "`at` is an alias for one path bound; use `start` and `end` for a bounded window.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  at <- .as_time(at, dn, "at")
  start <- .as_time(start, dn, "start")
  end <- .as_time(end, dn, "end")
  if (identical(direction, "forward")) {
    lower <- start %||% at %||% default_start
    upper <- end %||% Inf
    if (clamp_missing && is.null(start) && is.null(at) && lower > upper) {
      lower <- upper
    }
  } else {
    lower <- start %||% -Inf
    upper <- end %||% at %||% default_end
    if (clamp_missing && is.null(end) && is.null(at) && lower > upper) {
      upper <- lower
    }
  }
  if (lower > upper) {
    stop(errorCondition(
      sprintf("Path `start` (%s) must not exceed `end` (%s).",
              format(lower), format(upper)),
      class = "dynet_bad_input", call = NULL
    ))
  }
  list(start = lower, end = upper)
}

#' Reconstruct endpoint-specific path routes
#'
#' @param bfs A forward or backward search result.
#' @param n Number of vertices.
#' @param direction `"forward"` or `"backward"`.
#' @return A list per endpoint; each element contains every best-session route.
#' @examples
#' dn <- dynet(school_contacts)
#' as.data.frame(dyn_paths(dn, from = "Ana"), what = "steps")
#' @keywords internal
.path_routes <- function(bfs, n, direction) {
  direction <- match.arg(direction, c("forward", "backward"))
  lapply(seq_len(n), function(endpoint) {
    if (!is.finite(bfs$arrival[endpoint])) return(list())
    if (endpoint == bfs$source) {
      return(list(list(vertices = bfs$source, path_session = NA_character_,
                            result = bfs)))
    }
    if (is.null(bfs$best_sessions)) {
      selected <- list(list(result = bfs, path_session = NA_character_))
    } else {
      indices <- bfs$best_sessions[[endpoint]]
      selected <- lapply(indices, function(index) list(
        result = bfs$per_session[[index]],
        path_session = bfs$session_names[index]
      ))
    }
    routes <- lapply(selected, function(choice) {
      vertices <- .trace(
        choice$result$previous, bfs$source, endpoint
      )
      if (identical(direction, "backward")) vertices <- rev(vertices)
      list(vertices = vertices, path_session = choice$path_session,
           result = choice$result)
    })
    routes[vapply(routes, function(route) length(route$vertices) > 0L,
                  logical(1L))]
  })
}

#' Build primary and step tables from one path search
#'
#' @param enc Encoded edge list.
#' @param bfs Forward or backward search result.
#' @param direction `"forward"` or `"backward"`.
#' @param mode Session mode for this result.
#' @param session_label Session label for a separate-session block.
#' @return A list with tidy `paths` and `steps` data frames.
#' @examples
#' dn <- dynet(school_contacts)
#' as.data.frame(dyn_paths(dn, from = "Ana"), what = "steps")
#' @keywords internal
.paths_tables <- function(enc, bfs, direction,
                          mode = c("collapse", "bounded", "separate"),
                          session_label = NULL) {
  direction <- match.arg(direction, c("forward", "backward"))
  mode <- match.arg(mode)
  routes <- .path_routes(bfs, enc$n, direction)
  reachable <- is.finite(bfs$arrival)
  hops <- vapply(seq_len(enc$n), function(endpoint) {
    if (endpoint == bfs$source) return(0L)
    if (!reachable[endpoint]) return(NA_integer_)
    values <- vapply(routes[[endpoint]], function(route) {
      length(route$vertices) - 1L
    }, integer(1L))
    if (length(values) == 0L || length(unique(values)) > 1L) {
      return(NA_integer_)
    }
    values[1L]
  }, integer(1L))
  path_session <- vapply(seq_len(enc$n), function(endpoint) {
    if (endpoint == bfs$source || !reachable[endpoint]) return(NA_character_)
    if (identical(mode, "separate")) return(as.character(session_label))
    labels <- unique(vapply(routes[[endpoint]], function(route) {
      route$path_session
    }, character(1L)))
    if (length(labels) == 1L && !is.na(labels)) labels else NA_character_
  }, character(1L))
  n_best_sessions <- if (identical(mode, "collapse")) {
    rep(NA_integer_, enc$n)
  } else {
    vapply(seq_len(enc$n), function(endpoint) {
      if (endpoint == bfs$source || !reachable[endpoint]) return(0L)
      length(routes[[endpoint]])
    }, integer(1L))
  }
  attained <- if (identical(direction, "backward")) {
    bfs$attained & reachable
  } else {
    reachable
  }
  latency <- if (identical(direction, "backward")) {
    bfs$origin - bfs$arrival
  } else {
    bfs$arrival - bfs$origin
  }
  latency[!reachable] <- NA_real_
  paths <- data.frame(
    node = enc$names,
    reachable = reachable,
    arrival_time = ifelse(reachable, bfs$arrival, NA_real_),
    attained = attained,
    latency = latency,
    n_hops = hops,
    stringsAsFactors = FALSE
  )
  if (identical(mode, "bounded")) {
    paths$path_session <- path_session
    paths$n_best_sessions <- n_best_sessions
  }
  if (identical(mode, "separate")) {
    paths <- data.frame(
      session = rep(as.character(session_label), enc$n),
      origin = rep(bfs$origin, enc$n), paths,
      stringsAsFactors = FALSE
    )
  }

  step_frames <- unlist(lapply(seq_len(enc$n), function(endpoint) {
    lapply(routes[[endpoint]], function(route) {
      vertices <- route$vertices
      route_session <- if (endpoint == bfs$source) {
        NA_character_
      } else if (identical(mode, "separate")) {
        as.character(session_label)
      } else {
        route$path_session
      }
      state_attained <- if (identical(direction, "backward")) {
        route$result$attained[vertices]
      } else {
        rep(TRUE, length(vertices))
      }
      frame <- data.frame(
        endpoint = rep(enc$names[endpoint], length(vertices)),
        path_session = rep(route_session, length(vertices)),
        step = seq_along(vertices) - 1L,
        node = enc$names[vertices],
        time = route$result$arrival[vertices],
        attained = state_attained,
        stringsAsFactors = FALSE
      )
      if (identical(mode, "separate")) {
        frame <- data.frame(
          session = rep(as.character(session_label), nrow(frame)), frame,
          stringsAsFactors = FALSE
        )
      }
      frame
    })
  }), recursive = FALSE)
  steps <- do.call(rbind, step_frames)
  rownames(paths) <- NULL
  rownames(steps) <- NULL
  list(paths = paths, steps = steps, routes = routes)
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
#' @param at Forward source-availability time or backward arrival deadline.
#'   Defaults to the start of the observation window for forward paths and its
#'   end for backward paths. Date and date-time values use the network's time
#'   scale. It cannot be combined with `start` or `end`.
#' @param direction `"forward"` traces where the vertex can reach;
#'   `"backward"` traces who could have reached it.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end Inclusive lower and upper traversal-time bounds. Interval
#'   spells remain terminus-exclusive. When these are supplied, use them
#'   instead of `at`.
#'
#' @return An object of class `"dynet_paths"`: a tidy data frame with one row
#'   per vertex and columns `node`, `reachable`, `arrival_time`, `attained`
#'   (whether that optimum itself is realized), `latency` (time taken from the
#'   source), and `n_hops`. Bounded mode adds `path_session` and
#'   `n_best_sessions`; separate mode adds `session` and `origin`. Use
#'   `as.data.frame(x, what = "steps")` for reconstructed routes.
#'
#' @details
#' A valid forward journey has distinct vertices and traversal times
#' `start <= t1 <= ... <= tk <= end`. At each hop, either an interval is active
#' at the traversal time or a point event occurs exactly then. The empty journey
#' reaches the source at the resolved `start`. With `at`, that value supplies
#' `start` for forward paths or `end` for backward paths. Cycles are unnecessary
#' for reach and earliest arrival because deleting a repeated-vertex section
#' and waiting at that vertex preserves every later hop. This contract defines
#' feasibility and arrival; optimal-journey ties and multiplicity are separate
#' quantities.
#'
#' `start` and `end` form a closed window for traversal times: a hop may occur
#' at either bound. This does not close interval spells on the right. An event
#' or interval onset at `end` is eligible, while an interval whose own terminus
#' equals `end` is not active at that instant. `start = end` computes the
#' equal-time closure at one timestamp.
#'
#' For backward paths, `arrival_time` is the latest-departure supremum for a
#' journey ending at the named target by the resolved `end`, and `latency` is
#' `end` minus that value. A supremum at an interval's excluded terminus need
#' not itself be an attainable departure.
#'
#' With `sessions = "bounded"`, each endpoint is optimized across complete
#' session-specific searches. A unique winner is named in `path_session`; ties
#' leave it missing and are counted in `n_best_sessions`. No merged predecessor
#' tree is exposed. The steps accessor retains a complete route from every tied
#' best session, so each route stays inside one session. With
#' `sessions = "separate"`, every session contributes a complete vertex block
#' and resolves its own default origin. In the steps table, `time` is the
#' optimal search label at that route vertex. For backward interval paths it
#' can be an unattained supremum, as indicated by `attained = FALSE`.
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
#' dyn_paths(dn, from = "Ana", start = 0, end = 10)
#' summary(dyn_paths(dn, from = "Ana"))
#'
#' @export
dyn_paths <- function(dn, from, at = NULL,
                      direction = c("forward", "backward"),
                      sessions = c("bounded", "collapse", "separate"),
                      start = NULL, end = NULL) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  .check("`from` must be a single vertex name." =
              length(from) == 1L && !is.na(from))

  base_enc <- .encode(dn)
  src <- match(as.character(from), base_enc$names)
  if (is.na(src)) {
    stop(errorCondition(
      sprintf("Vertex %s is not in this network. Vertices are: %s",
              sQuote(from), paste(utils::head(base_enc$names, 10), collapse = ", ")),
      class = "dynet_unknown_vertex", call = NULL))
  }

  if (identical(sessions, "separate")) {
    parts <- .split_sessions(dn, "separate")
    blocks <- Map(function(enc, label) {
      if (!dn$directed) {
        enc <- .undirect_or_reverse(enc, FALSE, "forward")
      }
      window <- .path_window(
        dn, direction, at, start, end,
        default_start = min(enc$start), default_end = max(enc$end),
        clamp_missing = TRUE
      )
      origin <- if (identical(direction, "backward")) {
        window$end
      } else {
        window$start
      }
      bfs <- if (identical(direction, "backward")) {
        .bfs_backward_bounded(
          dn, enc, src, origin, FALSE, lower = window$start
        )
      } else {
        .bfs_bounded(dn, enc, src, origin, FALSE, upper = window$end)
      }
      .paths_tables(enc, bfs, direction, "separate", label)
    }, parts, names(parts))
    out <- do.call(rbind, lapply(blocks, `[[`, "paths"))
    steps <- do.call(rbind, lapply(blocks, `[[`, "steps"))
    origins <- vapply(blocks, function(block) {
      unique(block$paths$origin)
    }, numeric(1L))
    names(origins) <- names(parts)
    path_mode <- "separate"
    tree_previous <- NULL
  } else {
    window <- .path_window(dn, direction, at, start, end)
    enc <- base_enc
    if (!dn$directed) enc <- .undirect_or_reverse(enc, FALSE, "forward")
    origin <- if (identical(direction, "backward")) {
      window$end
    } else {
      window$start
    }
    bounded <- identical(sessions, "bounded") && !is.null(dn$meta$sessions)
    bfs <- if (identical(direction, "backward")) {
      .bfs_backward_bounded(
        dn, enc, src, origin, bounded, lower = window$start
      )
    } else {
      .bfs_bounded(dn, enc, src, origin, bounded, upper = window$end)
    }
    path_mode <- if (bounded) "bounded" else "collapse"
    tables <- .paths_tables(enc, bfs, direction, path_mode)
    out <- tables$paths
    steps <- tables$steps
    origins <- origin
    tree_previous <- if (identical(path_mode, "collapse")) {
      bfs$previous
    } else {
      NULL
    }
  }
  rownames(out) <- NULL
  rownames(steps) <- NULL
  structure(out, class = c("dynet_paths", "data.frame"),
            source = base_enc$names[src], direction = direction,
            origin = origins, time_unit = dn$meta$time_unit,
            path_mode = path_mode, steps = steps,
            tree_previous = tree_previous)
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
#' @param at Forward source-availability time or backward arrival deadline.
#'   Defaults to the beginning or end of each observed period, respectively.
#'   Date and date-time values use the network's time scale. It cannot be
#'   combined with `start` or `end`.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param start,end Inclusive lower and upper traversal-time bounds. Interval
#'   spells remain terminus-exclusive.
#'
#' @return A `dynet_metric` at node level with measures `forward_reach` and
#'   `backward_reach`, each the proportion of other vertices involved.
#'
#' @details
#' Reachability uses [dyn_paths()] traversal semantics: nondecreasing times,
#' unlimited waiting, half-open interval spells, and a separate exact timestamp
#' rule for point events. For backward reachability, the resolved `end` is a
#' common deadline and latest-departure suprema determine whether a vertex can
#' reach the target. The canonical `start` and `end` bounds apply one closed
#' traversal-time window to both forward and backward queries.
#'
#' In separate-session output, a session entirely outside a one-sided bound
#' contributes zero-reach rows rather than aborting the complete result. Its
#' missing implicit bound is clamped to the supplied bound, producing the
#' empty journey at that boundary and no eligible hop.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_reachability(dn)
#' dyn_reachability(dn, start = 0, end = 10)
#' plot(dyn_reachability(dn))
#'
#' @export
dyn_reachability <- function(dn, direction = c("both", "forward", "backward"),
                             at = NULL,
                             sessions = c("bounded", "collapse", "separate"),
                             start = NULL, end = NULL) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  direction <- match.arg(direction)
  wanted <- if (identical(direction, "both")) c("forward", "backward") else direction

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    vals <- lapply(wanted, function(d) {
      e2 <- .undirect_or_reverse(enc, dn$directed, "forward")
      window <- .path_window(
        dn, d, at, start, end,
        default_start = min(enc$start), default_end = max(enc$end),
        clamp_missing = identical(sessions, "separate")
      )
      t0 <- if (identical(d, "backward")) window$end else window$start
      share <- vapply(seq_len(enc$n), function(s) {
        b <- if (identical(d, "backward")) {
          .bfs_backward_bounded(
            dn, e2, s, t0, identical(sessions, "bounded"),
            lower = window$start
          )
        } else {
          .bfs_bounded(
            dn, e2, s, t0, identical(sessions, "bounded"),
            upper = window$end
          )
        }
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
