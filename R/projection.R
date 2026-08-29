# ===========================================================================
# Time-projected network
# ===========================================================================

#' Prepare collision-safe copied node attributes
#' @param dn Parent temporal network.
#' @param reserved Structural projection column names.
#' @return A list with the copied attribute table and a named rename vector.
#' @keywords internal
.projection_node_attributes <- function(dn, reserved) {
  nodes <- as.data.frame(dn, what = "nodes")
  attributes <- nodes[, setdiff(names(nodes), "name"), drop = FALSE]
  if (!ncol(attributes)) {
    return(list(data = attributes, renames = stats::setNames(character(), character())))
  }
  original <- names(attributes)
  final <- original
  fixed <- original[!original %in% reserved]
  used <- unique(c(reserved, fixed))
  # Sequential dependency: collision renames reserve each generated name.
  for (i in which(original %in% reserved)) {
    candidate <- paste0("node_", original[[i]])
    while (candidate %in% used) candidate <- paste0("node_", candidate)
    final[[i]] <- candidate
    used <- c(used, candidate)
  }
  names(attributes) <- final
  changed <- original != final
  list(
    data = attributes,
    renames = stats::setNames(final[changed], original[changed])
  )
}

#' Empty time-projection edge table
#' @param include_session Whether to include the session key.
#' @return A typed zero-row data frame.
#' @keywords internal
.empty_projection_edges <- function(include_session = FALSE) {
  out <- data.frame(
    from_state = integer(), to_state = integer(),
    from_node = character(), to_node = character(),
    from_slice = integer(), to_slice = integer(),
    from_time = numeric(), to_time = numeric(),
    edge_type = character(), weight = numeric(), n_spells = integer(),
    lag = numeric(), stringsAsFactors = FALSE
  )
  if (include_session) {
    out <- cbind(out[1:4], session = character(), out[5:ncol(out)])
  }
  out
}

#' Build one edge row for a time projection
#' @param from_state,to_state Integer projected-state identifiers.
#' @param from_node,to_node Original vertex names.
#' @param session Optional session label.
#' @param from_slice,to_slice Integer slice identifiers.
#' @param from_time,to_time Numeric slice times.
#' @param edge_type Either `"within_slice"` or `"identity_arc"`.
#' @param weight Edge weight.
#' @param n_spells Number of raw snapshot rows represented.
#' @param include_session Whether the public session key is present.
#' @return A one-row data frame.
#' @keywords internal
.projection_edge_row <- function(
    from_state, to_state, from_node, to_node, session,
    from_slice, to_slice, from_time, to_time, edge_type, weight, n_spells,
    include_session) {
  out <- data.frame(
    from_state = as.integer(from_state), to_state = as.integer(to_state),
    from_node = as.character(from_node), to_node = as.character(to_node),
    from_slice = as.integer(from_slice), to_slice = as.integer(to_slice),
    from_time = as.numeric(from_time), to_time = as.numeric(to_time),
    edge_type = as.character(edge_type), weight = as.numeric(weight),
    n_spells = as.integer(n_spells),
    lag = as.numeric(to_time - from_time), stringsAsFactors = FALSE
  )
  if (include_session) {
    out <- cbind(out[1:4], session = as.character(session), out[5:ncol(out)])
  }
  out
}

#' Project a temporal network into directed vertex-time states
#'
#' `projection()` discretizes a temporal network into snapshot slices and
#' connects each vertex state to its realization in the next slice. Within a
#' slice it uses the same independently aggregated, endpoint-induced snapshot
#' as [snapshots()]. Identity arcs always point forward and have weight
#' one. The result is a tidy projection object rather than a bare matrix.
#'
#' Every fixed-universe vertex receives one state in every emitted slice.
#' `active` records whether the vertex was eligible in that slice. Identity
#' arcs are retained through inactive slices because Dynet permits waiting
#' through vertex inactivity; inactive states simply have no incident
#' endpoint-induced within-slice edge. Consecutive observed slices are also
#' linked across an observation gap, matching Dynet's calendar-time waiting
#' convention.
#'
#' Directed source edges produce one within-slice arc. An undirected nonloop
#' edge produces reciprocal arcs, while an undirected loop is emitted once.
#' Parallel active spells are one within-slice pair whose `weight` is their
#' summed weight and whose `n_spells` records their count. Identity arcs have
#' `weight = 1` and `n_spells = 0`.
#'
#' @param dn A temporal network from [dynet()].
#' @param sessions Session handling. `"collapse"` erases labels. For a
#'   sessioned network, `"bounded"` and `"separate"` both preserve disjoint
#'   session-local projection blocks so identity arcs never cross a wall.
#' @param start,end First and last slice times. Defaults to observed support.
#' @param step Spacing between slice starts. `NULL` uses the construction
#'   interval.
#' @param window Width represented by each slice. `NULL` uses `step`; zero
#'   samples an exact point; `"all"` represents the whole observed period as a
#'   single slice, closed on the right.
#' @param omega Weight on the identity arcs that carry a vertex from one slice
#'   to the next, that is, the interlayer coupling of the time-expanded
#'   network. One keeps an identity arc as heavy as a unit contact; zero
#'   leaves the slices uncoupled. Must be a single non-negative number.
#' @param coupling Which slices an identity arc may join. `"ordinal"`, the
#'   default and the only temporally meaningful choice, joins each slice to
#'   the next one only, so a vertex is tied to its immediate past and future.
#'   `"categorical"` joins every pair of slices, which is the convention for
#'   unordered aspect-layers such as phone, email and face-to-face; it is
#'   offered so a multiplex analysis can be reproduced and compared, and it
#'   asserts that time has no order. See Mucha et al. (2010), Figure 1.
#'
#' @return An object of class `dynet_projection`. Use
#'   `as.data.frame(x, what = "vertices")` for vertex states and
#'   `as.data.frame(x, what = "edges")` for directed projected arcs.
#'
#' @references
#' Bender-deMoll, S., & Moody, J. `timeProjectedNetwork()` in the `tsna`
#' package, version 0.3.6.
#'
#' Butts, C. T., Leslie-Cook, A., Krivitsky, P. N., & Bender-deMoll, S.
#' (2024). *networkDynamic: Dynamic Extensions for Network Objects*, version
#' 0.11.5. \doi{10.32614/CRAN.package.networkDynamic}
#'
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "B", "C"), to = c("B", "C", "A"),
#'   start = 0:2, end = 1:3
#' ), observation_start = 0, observation_end = 3)
#' projected <- projection(dn, step = 1, window = 1)
#' as.data.frame(projected, what = "vertices")
#' as.data.frame(projected, what = "edges")
#'
#' @export
projection <- function(
    dn, sessions = c("bounded", "collapse", "separate"),
    start = NULL, end = NULL, step = NULL, window = NULL, omega = 1,
    coupling = c("ordinal", "categorical")) {
  sessions <- match.arg(sessions)
  coupling <- match.arg(coupling)
  .check_dynet(dn, sessions)
  .check("`omega` must be one non-negative number." =
           length(omega) == 1L && is.numeric(omega) && is.finite(omega) &&
           omega >= 0)
  spec <- .window_spec(dn, start, end, step, window)
  has_sessions <- !is.null(dn$meta$sessions)
  effective_sessions <- if (!has_sessions && identical(sessions, "bounded")) {
    "collapse"
  } else sessions
  session_blocks <- has_sessions && !identical(effective_sessions, "collapse")
  parts <- if (session_blocks) {
    .split_sessions(dn, "separate")
  } else list(all = .encode(dn))
  block_labels <- names(parts)
  n <- nrow(dn$nodes)

  vertex_reserved <- c(
    "state", "session", "observation", "slice", "time", "start", "end",
    "closed", "node", "active"
  )
  copied <- .projection_node_attributes(dn, vertex_reserved)
  vertex_frames <- vector("list", length(parts))
  edge_frames <- vector("list", length(parts))
  grids <- vector("list", length(parts))
  state_offset <- 0L

  for (block in seq_along(parts)) {
    enc <- parts[[block]]
    label <- block_labels[[block]]
    grid <- .grid_for(enc, dn, spec)
    grids[[block]] <- grid
    local_session_mode <- if (session_blocks) "separate" else "collapse"
    slice_frames <- vector("list", nrow(grid))
    within_rows <- list()
    within_index <- 0L

    for (slice in seq_len(nrow(grid))) {
      bin <- grid[slice, , drop = FALSE]
      state <- .snapshot_state(
        dn, enc, bin, spec$window, local_session_mode, label
      )
      ids <- state_offset + (slice - 1L) * n + seq_len(n)
      vertices <- data.frame(
        state = as.integer(ids), slice = rep.int(as.integer(slice), n),
        time = rep.int(as.numeric(bin$time), n),
        start = rep.int(as.numeric(bin$lo), n),
        end = rep.int(as.numeric(bin$hi), n),
        closed = rep.int(isTRUE(bin$closed), n),
        node = enc$names, active = as.logical(state$eligible),
        stringsAsFactors = FALSE
      )
      if (session_blocks) {
        vertices <- cbind(vertices["state"], session = label,
                          vertices[setdiff(names(vertices), "state")])
      }
      if ("observation" %in% names(grid)) {
        before <- intersect(c("state", "session"), names(vertices))
        vertices <- cbind(
          vertices[before], observation = as.integer(bin$observation),
          vertices[setdiff(names(vertices), before)]
        )
      }
      if (ncol(copied$data)) vertices <- cbind(vertices, copied$data)
      slice_frames[[slice]] <- vertices

      active_rows <- which(state$active)
      if (length(active_rows)) {
        pair_key <- (enc$from[active_rows] - 1L) * enc$n + enc$to[active_rows]
        by_pair <- split(active_rows, pair_key)
        pair_order <- order(
          vapply(by_pair, function(rows) enc$from[rows[[1L]]], integer(1L)),
          vapply(by_pair, function(rows) enc$to[rows[[1L]]], integer(1L))
        )
        by_pair <- by_pair[pair_order]
        for (rows in by_pair) {
          from <- enc$from[rows[[1L]]]
          to <- enc$to[rows[[1L]]]
          directions <- if (!dn$directed && from != to) {
            list(c(from, to), c(to, from))
          } else list(c(from, to))
          for (direction in directions) {
            within_index <- within_index + 1L
            within_rows[[within_index]] <- .projection_edge_row(
              ids[[direction[[1L]]]], ids[[direction[[2L]]]],
              enc$names[[direction[[1L]]]], enc$names[[direction[[2L]]]],
              label, slice, slice, bin$time, bin$time, "within_slice",
              sum(enc$weight[rows]), length(rows), session_blocks
            )
          }
        }
      }
    }

    vertices <- do.call(rbind, slice_frames)
    rownames(vertices) <- NULL
    vertex_frames[[block]] <- vertices

    identity_rows <- list()
    identity_index <- 0L
    if (nrow(grid) > 1L) {
      # Ordinal coupling ties a slice to the next one only; categorical ties
      # every ordered pair, which is what an unordered aspect-layer needs and
      # what a temporal network must not have.
      for (slice in seq_len(nrow(grid) - 1L)) {
        reach <- if (identical(coupling, "ordinal")) {
          slice + 1L
        } else {
          seq.int(slice + 1L, nrow(grid))
        }
        from_ids <- state_offset + (slice - 1L) * n + seq_len(n)
        for (later in reach) {
          to_ids <- state_offset + (later - 1L) * n + seq_len(n)
          for (node in seq_len(n)) {
            identity_index <- identity_index + 1L
            identity_rows[[identity_index]] <- .projection_edge_row(
              from_ids[[node]], to_ids[[node]],
              enc$names[[node]], enc$names[[node]],
              label, slice, later, grid$time[[slice]],
              grid$time[[later]], "identity_arc", omega, 0L,
              session_blocks
            )
          }
        }
      }
    }
    rows <- c(within_rows, identity_rows)
    edges <- if (length(rows)) do.call(rbind, rows) else
      .empty_projection_edges(session_blocks)
    if (nrow(edges)) {
      type_order <- match(edges$edge_type, c("within_slice", "identity_arc"))
      edges <- edges[order(edges$from_slice, type_order,
                           edges$from_state, edges$to_state), , drop = FALSE]
    }
    rownames(edges) <- NULL
    edge_frames[[block]] <- edges
    state_offset <- state_offset + nrow(grid) * n
  }

  vertices <- do.call(rbind, vertex_frames)
  edges <- do.call(rbind, edge_frames)
  rownames(vertices) <- NULL
  rownames(edges) <- NULL
  slices_per_block <- stats::setNames(
    vapply(grids, nrow, integer(1L)), block_labels
  )
  meta <- list(
    source_directed = dn$directed, directed = TRUE,
    time_unit = dn$meta$time_unit, origin = dn$meta$origin,
    step = spec$step, window = spec$window,
    sessions = sessions, n_nodes = n, n_slices = sum(slices_per_block),
    n_blocks = length(parts),
    vertex_rule = "fixed_states_with_eligibility_flag",
    within_slice_rule = if (spec$window == 0) {
      "snapshot_exact_induced"
    } else "snapshot_any_union_induced",
    identity_rule = if (identical(coupling, "ordinal")) {
      "forward_unconditional_waiting_consecutive_slices"
    } else "forward_unconditional_waiting_all_slice_pairs",
    omega = omega,
    coupling = coupling,
    identity_weight = omega,
    undirected_rule = if (dn$directed) {
      "one_directed_arc_per_pair"
    } else "reciprocal_nonloop_arcs_loop_once",
    observation_gap_waiting = "allowed",
    session_aggregation = switch(
      effective_sessions,
      collapse = "labels_erased_single_block",
      bounded = "session_walled_disjoint_union",
      separate = "session_local_disjoint_union"
    ),
    node_attribute_names = names(copied$data),
    node_attribute_renames = copied$renames
  )
  structure(
    list(vertices = vertices, edges = edges, meta = meta),
    class = "dynet_projection"
  )
}

#' Tidy tables from a time-projected network
#'
#' @param x A projection returned by [projection()].
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"vertices"` returns vertex-time states and `"edges"` returns
#'   directed within-slice and identity arcs.
#' @param ... Ignored.
#' @return A plain data frame. Vertex rows contain `state`, optional `session`
#'   and `observation`, `slice`, `time`, `start`, `end`, `closed`, `node`,
#'   `active`, and copied node attributes. Edge rows contain `from_state`,
#'   `to_state`, `from_node`, `to_node`, optional `session`, `from_slice`,
#'   `to_slice`, `from_time`, `to_time`, `edge_type`, `weight`, `n_spells`,
#'   and `lag`.
#' @export
as.data.frame.dynet_projection <- function(
    x, row.names = NULL, optional = FALSE,
    what = c("vertices", "edges"), ...) {
  what <- match.arg(what)
  out <- x[[what]]
  attributes(out) <- list(
    names = names(out), row.names = seq_len(nrow(out)), class = "data.frame"
  )
  out
}

#' Print a time-projected network
#' @param x A projection returned by [projection()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_projection <- function(x, ...) {
  cat(sprintf(
    "# Time-projected network | %d states | %d arcs | %d slice block(s)\n",
    nrow(x$vertices), nrow(x$edges), x$meta$n_blocks
  ))
  cat(sprintf(
    "# step %s | window %s | %s\n",
    format(x$meta$step), format(x$meta$window), x$meta$session_aggregation
  ))
  print(utils::head(x$vertices, 6L), row.names = FALSE)
  invisible(x)
}
