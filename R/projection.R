# ===========================================================================
# Time-projected network
# ===========================================================================

#' Prepare collision-safe copied node attributes
#' @param dn Parent temporal network.
#' @param reserved Structural projection column names.
#' @return A list with the copied attribute table and a named rename vector.
#' @noRd
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
#' @noRd
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
#' @noRd
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

#' Build the vertex states and arcs of one projection block
#'
#' Vectorised over slices and vertices: each slice's snapshot state is read
#' once, its active spells are pooled by pair with `split()`, and every
#' identity arc of the block is laid out in one table. The final sort fixes the
#' row order, so construction order does not leak into the result.
#'
#' @param dn Parent temporal network.
#' @param enc The block's encoding.
#' @param label The block label (session name or `"all"`).
#' @param grid The block's slice grid from `.grid_for()`.
#' @param state_offset States already used by earlier blocks.
#' @param spec The resolved grid specification.
#' @param session_blocks Whether the public `session` key is present.
#' @param copied The copied node attributes from
#'   `.projection_node_attributes()`.
#' @param coupling `"ordinal"` or `"categorical"`.
#' @param omega Identity-arc weight.
#' @return A list with `vertices` and `edges` data frames for the block.
#' @noRd
.projection_block <- function(dn, enc, label, grid, state_offset, spec,
                              session_blocks, copied, coupling, omega) {
  n <- nrow(dn$nodes)
  n_slices <- nrow(grid)
  local_session_mode <- if (session_blocks) "separate" else "collapse"
  per_slice <- lapply(seq_len(n_slices), function(slice) {
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

    active_rows <- which(state$active)
    within <- NULL
    if (length(active_rows)) {
      from <- enc$from[active_rows]
      to <- enc$to[active_rows]
      key <- (from - 1L) * enc$n + to
      first <- !duplicated(key)
      group <- match(key, key[first])
      # Parallel spells of one pair sum in their original order.
      weight <- vapply(split(enc$weight[active_rows], group), sum,
                       numeric(1L))
      count <- tabulate(group, sum(first))
      pair_from <- from[first]
      pair_to <- to[first]
      # An undirected nonloop pair gives reciprocal arcs; a loop gives one.
      back <- !dn$directed & pair_from != pair_to
      arc_from <- c(pair_from, pair_to[back])
      arc_to <- c(pair_to, pair_from[back])
      within <- .projection_edge_row(
        ids[arc_from], ids[arc_to], enc$names[arc_from], enc$names[arc_to],
        label, slice, slice, bin$time, bin$time, "within_slice",
        c(weight, weight[back]), c(count, count[back]), session_blocks
      )
    }
    list(vertices = vertices, within = within)
  })
  vertices <- do.call(rbind, lapply(per_slice, `[[`, "vertices"))
  rownames(vertices) <- NULL

  identity <- NULL
  if (n_slices > 1L) {
    # Ordinal coupling ties a slice to the next one only; categorical ties
    # every ordered pair, which is what an unordered aspect-layer needs and
    # what a temporal network must not have.
    links <- if (identical(coupling, "ordinal")) {
      data.frame(from = seq_len(n_slices - 1L), to = seq.int(2L, n_slices))
    } else {
      upper <- which(upper.tri(diag(n_slices)), arr.ind = TRUE)
      data.frame(from = upper[, "row"], to = upper[, "col"])
    }
    from_slice <- rep(links$from, each = n)
    to_slice <- rep(links$to, each = n)
    node <- rep.int(seq_len(n), nrow(links))
    identity <- .projection_edge_row(
      state_offset + (from_slice - 1L) * n + node,
      state_offset + (to_slice - 1L) * n + node,
      enc$names[node], enc$names[node], label, from_slice, to_slice,
      grid$time[from_slice], grid$time[to_slice], "identity_arc",
      omega, 0L, session_blocks
    )
  }
  rows <- c(lapply(per_slice, `[[`, "within"), list(identity))
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  edges <- if (length(rows)) do.call(rbind, rows) else
    .empty_projection_edges(session_blocks)
  if (nrow(edges)) {
    type_order <- match(edges$edge_type, c("within_slice", "identity_arc"))
    edges <- edges[order(edges$from_slice, type_order,
                         edges$from_state, edges$to_state), , drop = FALSE]
  }
  rownames(edges) <- NULL
  list(vertices = vertices, edges = edges)
}

#' Project a temporal network into directed vertex-time states
#'
#' `projection()` discretises a temporal network into snapshot slices and
#' connects each vertex state to its realisation in the next slice. Within a
#' slice it uses the same independently aggregated, endpoint-induced snapshot
#' as [snapshots()]. Identity arcs always point forward and carry the coupling
#' weight `omega`. The result is a tidy projection object rather than a bare
#' matrix.
#'
#' Every fixed-universe vertex receives one state in every emitted slice.
#' `active` records whether the vertex was eligible in that slice. Identity
#' arcs are retained through inactive slices because Dynet permits waiting
#' through vertex inactivity; inactive states have no incident
#' endpoint-induced within-slice edge. Consecutive observed slices are also
#' linked across an observation gap, matching Dynet's calendar-time waiting
#' convention.
#'
#' Directed source edges produce one within-slice arc. An undirected nonloop
#' edge produces reciprocal arcs, while an undirected loop is emitted once.
#' Parallel active spells are one within-slice pair whose `weight` is their
#' summed weight and whose `n_spells` records their count. Identity arcs have
#' `weight = omega` and `n_spells = 0`, and `meta$identity_weight` reports the
#' same value.
#'
#' @param dn A temporal network from [dynet()].
#' @param sessions Session handling: `"bounded"` (the default), `"collapse"`
#'   or `"separate"`. `"collapse"` erases labels. For a sessioned network,
#'   `"bounded"` and `"separate"` both preserve disjoint session-local
#'   projection blocks so identity arcs never cross a wall.
#' @param start,end First and last slice times. Defaults to observed support.
#' @param step Spacing between slice starts. `NULL` uses the construction
#'   interval.
#' @param window Width represented by each slice. `NULL` uses `step`; zero
#'   samples an exact point; `"all"` represents the whole observed period as a
#'   single slice, closed on the right.
#' @param omega Weight on the identity arcs that carry a vertex from one slice
#'   to the next, that is, the interlayer coupling of the time-expanded
#'   network. One, the default, keeps an identity arc as heavy as a unit
#'   contact; zero leaves the slices uncoupled. Must be a single finite
#'   non-negative number, or a `dynet_bad_input` error is raised.
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
  sessions <- .match_choice(sessions)
  coupling <- .match_choice(coupling)
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
  grids <- lapply(parts, function(enc) .grid_for(enc, dn, spec))
  # Each block's states follow the previous block's, so the offsets are a
  # running total of slices times vertices.
  slice_counts <- vapply(grids, nrow, integer(1L))
  offsets <- c(0L, cumsum(slice_counts * n))[seq_along(parts)]
  blocks <- Map(function(enc, label, grid, state_offset) {
    .projection_block(
      dn, enc, label, grid, state_offset, spec, session_blocks, copied,
      coupling, omega
    )
  }, parts, block_labels, grids, offsets)
  vertex_frames <- lapply(blocks, `[[`, "vertices")
  edge_frames <- lapply(blocks, `[[`, "edges")

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
#' @param what `"vertices"`, the default, returns vertex-time states, and
#'   `"edges"` returns directed within-slice and identity arcs.
#' @param ... Ignored.
#' @return A plain data frame. Vertex rows contain `state`, optional `session`
#'   and `observation`, `slice`, `time`, `start`, `end`, `closed`, `node`,
#'   `active`, and copied node attributes. Edge rows contain `from_state`,
#'   `to_state`, `from_node`, `to_node`, optional `session`, `from_slice`,
#'   `to_slice`, `from_time`, `to_time`, `edge_type`, `weight`, `n_spells`,
#'   and `lag`.
#' @examples
#' dn <- dynet(school_contacts)
#' projected <- projection(dn, step = 4, window = 4)
#' as.data.frame(projected)
#' as.data.frame(projected, what = "edges")
#' @export
as.data.frame.dynet_projection <- function(
    x, row.names = NULL, optional = FALSE,
    what = c("vertices", "edges"), ...) {
  what <- .match_choice(what)
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
#' @examples
#' dn <- dynet(school_contacts)
#' projected <- projection(dn, step = 4, window = 4)
#' projected
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

#' Summarise a time projection
#'
#' @param object A `dynet_projection` result.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per slice: `slice`, its `time`, the
#'   number of `active` vertex states, the `within_slice` arcs induced in it,
#'   and the `identity_arcs` leaving it for the next slice. The final slice
#'   emits no identity arcs, so its count is zero.
#' @examples
#' dn <- dynet(school_contacts)
#' slices <- projection(dn, step = 5, window = 5)
#' summary(slices)
#' @export
summary.dynet_projection <- function(object, ...) {
  vertices <- as.data.frame(object, what = "vertices")
  edges <- as.data.frame(object, what = "edges")
  within <- edges[edges$edge_type == "within_slice", , drop = FALSE]
  identity <- edges[edges$edge_type == "identity_arc", , drop = FALSE]
  parts <- lapply(sort(unique(vertices$slice)), function(s) {
    data.frame(
      slice = s,
      time = vertices$time[vertices$slice == s][[1L]],
      active = sum(vertices$active[vertices$slice == s]),
      within_slice = sum(within$from_slice == s),
      identity_arcs = sum(identity$from_slice == s)
    )
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

#' Draw a time-projected network
#'
#' Each vertex state is a point at its slice's time on its vertex's row.
#' Within-slice arcs are drawn as solid curves and identity arcs, which carry
#' a vertex into the next slice, as dashed straight segments, so the two arc
#' types differ by line type and geometry, never by colour alone.
#'
#' @param x A `dynet_projection` from [projection()].
#' @param base_size Base font size.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @export
plot.dynet_projection <- function(x, base_size = 12, ...) {
  vertices <- as.data.frame(x, what = "vertices")
  edges <- as.data.frame(x, what = "edges")
  rows <- unique(vertices$node)
  vertices$y <- match(vertices$node, rows)
  edges$x <- edges$from_time
  edges$xend <- edges$to_time
  edges$y <- match(edges$from_node, rows)
  edges$yend <- match(edges$to_node, rows)
  within <- edges[edges$edge_type == "within_slice", , drop = FALSE]
  identity <- edges[edges$edge_type != "within_slice", , drop = FALSE]
  ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = identity,
      ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
      linetype = "22", colour = "#999999", linewidth = 0.3) +
    ggplot2::geom_curve(
      data = within,
      ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
      curvature = 0.3, colour = "#0072B2", alpha = 0.5, linewidth = 0.4) +
    ggplot2::geom_point(
      data = vertices, ggplot2::aes(x = time, y = y),
      shape = 21, fill = "#E69F00", colour = "white", size = 2.4) +
    ggplot2::scale_y_continuous(breaks = seq_along(rows), labels = rows) +
    ggplot2::labs(x = sprintf("Time (%s)", x$meta$time_unit %||% ""),
                  y = NULL, title = "Time-projected network",
                  subtitle = "curves: within-slice arcs; dashed: identity arcs") +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}
