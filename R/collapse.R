# ===========================================================================
# Exact temporal collapse to a static cograph network
# ===========================================================================

.clip_collapse_fragments <- function(fragments, start, end) {
  if (!nrow(fragments)) return(fragments)
  point <- fragments$instant
  keep_point <- point & fragments$start >= start & fragments$start <= end
  positive <- !point
  fragments$start[positive] <- pmax(fragments$start[positive], start)
  fragments$end[positive] <- pmin(fragments$end[positive], end)
  keep <- keep_point | (positive & fragments$end > fragments$start)
  fragments[keep, , drop = FALSE]
}

.collapse_pair_opportunity <- function(vertex_fragments, from, to, start, end) {
  one <- .clip_collapse_fragments(
    vertex_fragments[vertex_fragments$node == from, , drop = FALSE], start, end
  )
  two <- .clip_collapse_fragments(
    vertex_fragments[vertex_fragments$node == to, , drop = FALSE], start, end
  )
  one <- one[!one$instant, , drop = FALSE]
  two <- two[!two$instant, , drop = FALSE]
  if (!nrow(one) || !nrow(two)) return(0)
  cross <- merge(one[c("start", "end")], two[c("start", "end")],
                 by = NULL, suffixes = c("_from", "_to"))
  lo <- pmax(cross$start_from, cross$start_to)
  hi <- pmin(cross$end_from, cross$end_to)
  keep <- hi > lo
  if (!any(keep)) return(0)
  .union_duration(lo[keep], hi[keep])
}

.collapsed_netobject <- function(dn, edges, nodes, weight, start, end,
                                 sessions, session_label = NULL) {
  node_names <- nodes$name
  from_id <- match(edges$from, node_names)
  to_id <- match(edges$to, node_names)
  edge_table <- data.frame(
    from = from_id, to = to_id, weight = edges[[weight]],
    edges[, setdiff(names(edges), c("from", "to", weight)), drop = FALSE],
    check.names = FALSE, stringsAsFactors = FALSE
  )
  weights <- matrix(0, nrow(nodes), nrow(nodes),
                    dimnames = list(node_names, node_names))
  if (nrow(edges)) {
    weights[cbind(from_id, to_id)] <- edges[[weight]]
    if (!dn$directed) {
      weights[cbind(to_id, from_id)] <- edges[[weight]]
    }
  }
  node_table <- data.frame(
    id = seq_len(nrow(nodes)), label = node_names, name = node_names,
    x = NA_real_, y = NA_real_, stringsAsFactors = FALSE
  )
  extras <- setdiff(names(nodes), "name")
  if (length(extras)) node_table <- cbind(node_table, nodes[extras])
  node_groups <- if ("groups" %in% names(nodes)) {
    data.frame(node = node_names, group = as.character(nodes$groups),
               stringsAsFactors = FALSE)
  } else NULL
  structure(
    list(
      nodes = node_table, edges = edge_table, directed = dn$directed,
      weights = weights, data = edges,
      meta = list(
        type = "static_collapse", source = "dynet", start = start, end = end,
        duration = end - start, time_unit = dn$meta$time_unit,
        weight = weight, sessions = sessions, session = session_label,
        edge_duration = "endpoint_valid_observed_support",
        edge_occupancy = "binary_pair_calendar_union"
      ),
      node_groups = node_groups
    ),
    class = c("dynet_collapsed", "netobject", "cograph_network")
  )
}

.collapse_one <- function(dn, fragments, vertex_fragments, weight,
                          start, end, sessions, session_label = NULL) {
  fragments <- .clip_collapse_fragments(fragments, start, end)
  raw <- dn$spells
  if (!nrow(fragments)) {
    edge_summary <- data.frame(
      from = character(), to = character(), binary = numeric(),
      union_duration = numeric(), total_duration = numeric(),
      duration_fraction = numeric(), spell_count = integer(),
      weight_sum = numeric(), weighted_duration = numeric(),
      latest_weight = numeric(), first = numeric(), last = numeric(),
      activity.duration = numeric(), activity.count = integer(),
      stringsAsFactors = FALSE
    )
  } else {
    key <- paste(fragments$from, fragments$to, sep = "\r")
    groups <- split(seq_len(nrow(fragments)), key)
    rows <- lapply(groups, function(index) {
      piece <- fragments[index, , drop = FALSE]
      identities <- split(seq_len(nrow(piece)), piece$raw_spell)
      identity <- do.call(rbind, lapply(identities, function(rows) {
        raw_spell <- piece$raw_spell[rows[[1L]]]
        raw_index <- match(raw_spell, raw$.raw_spell)
        data.frame(
          raw_spell = raw_spell,
          duration = sum(piece$end[rows] - piece$start[rows]),
          first = min(piece$start[rows]), last = max(piece$end[rows]),
          weight = raw$weight[raw_index], stringsAsFactors = FALSE
        )
      }))
      positive <- piece[!piece$instant, , drop = FALSE]
      union_duration <- if (nrow(positive)) {
        .union_duration(positive$start, positive$end)
      } else 0
      opportunity <- .collapse_pair_opportunity(
        vertex_fragments, piece$from[[1L]], piece$to[[1L]], start, end
      )
      latest <- identity[order(identity$last, identity$raw_spell), , drop = FALSE]
      data.frame(
        from = piece$from[[1L]], to = piece$to[[1L]], binary = 1,
        union_duration = union_duration,
        total_duration = sum(identity$duration),
        duration_fraction = if (opportunity > 0) union_duration / opportunity else NA_real_,
        spell_count = nrow(identity), weight_sum = sum(identity$weight),
        weighted_duration = sum(identity$weight * identity$duration),
        latest_weight = latest$weight[[nrow(latest)]],
        first = min(identity$first), last = max(identity$last),
        activity.duration = union_duration, activity.count = nrow(identity),
        stringsAsFactors = FALSE
      )
    })
    edge_summary <- do.call(rbind, rows)
    edge_summary <- edge_summary[order(edge_summary$from, edge_summary$to), ]
    rownames(edge_summary) <- NULL
  }

  vertex_fragments <- .clip_collapse_fragments(vertex_fragments, start, end)
  public_nodes <- as.data.frame(dn, what = "nodes")
  public_nodes$activity_duration <- vapply(public_nodes$name, function(node) {
    one <- vertex_fragments[
      vertex_fragments$node == node & !vertex_fragments$instant, , drop = FALSE
    ]
    if (nrow(one)) .union_duration(one$start, one$end) else 0
  }, numeric(1L))
  public_nodes$activity.duration <- public_nodes$activity_duration
  .collapsed_netobject(
    dn, edge_summary, public_nodes, weight, start, end, sessions, session_label
  )
}

#' Collapse temporal activity to a static weighted network
#'
#' Creates a static cograph network from the exact observed, endpoint-valid
#' activity in a requested time range. Every collapsed edge retains all common
#' duration summaries, so choosing one weighting does not discard the others.
#'
#' @param dn A temporal network from [dynet()] or [as_dynet()].
#' @param start,end Collapse bounds. Defaults to the observed range. Positive
#'   intervals are clipped to `[start, end)`; genuine points at either bound
#'   are retained.
#' @param weight Edge field used as the cograph weight: `"binary"`,
#'   `"union_duration"`, `"total_duration"`, `"duration_fraction"`,
#'   `"spell_count"`, `"weight_sum"`, `"weighted_duration"`, or
#'   `"latest_weight"`.
#' @param sessions Session handling. `"collapse"` erases session labels,
#'   `"bounded"` respects session-specific endpoint activity before pooling,
#'   and `"separate"` returns one collapsed cograph network per session.
#' @param censored Whether raw edge and vertex identities carrying an explicit
#'   censor flag are included.
#' @return A `dynet_collapsed` cograph netobject, whose two tidy tables are
#'   reached with `as.data.frame(x, what = "edges")` and
#'   `as.data.frame(x, what = "nodes")`. With `sessions = "separate"`, a named
#'   `dynet_collapsed_list` of such objects, one per session.
#'
#'   The edge table carries one row per collapsed pair and every weighting at
#'   once, so choosing one does not discard the others: `from`, `to`,
#'   `binary` (1 for a pair that was ever active), `union_duration` (time the
#'   pair was active, overlaps counted once), `total_duration` (summed spell
#'   lengths, overlaps counted twice), `duration_fraction` (`union_duration`
#'   over the pair's joint activity opportunity, `NA` when that opportunity is
#'   zero), `spell_count`, `weight_sum`, `weighted_duration` (weight times
#'   duration, summed), `latest_weight` (the weight of the last spell to end),
#'   `first` and `last` (the pair's earliest onset and latest terminus), and
#'   the `activity.duration` and `activity.count` aliases for compatibility
#'   with `networkDynamic::network.collapse()`.
#'
#'   The node table carries one row per vertex, with `name`,
#'   `activity_duration` (time the vertex was active, overlaps counted once)
#'   and its `activity.duration` alias.
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "A"), to = c("B", "B"),
#'   start = c(0, 1), end = c(2, 3)
#' ))
#' flat <- collapse_network(dn, weight = "union_duration")
#' as.data.frame(flat)
#' @export
collapse_network <- function(
    dn, start = NULL, end = NULL,
    weight = c("binary", "union_duration", "total_duration",
               "duration_fraction", "spell_count", "weight_sum",
               "weighted_duration", "latest_weight"),
    sessions = c("bounded", "collapse", "separate"),
    censored = c("include", "exclude")) {
  weight <- match.arg(weight)
  sessions <- match.arg(sessions)
  censored <- match.arg(censored)
  .check_dynet(dn, sessions)
  start <- if (is.null(start)) dn$meta$time_range[["start"]] else
    .as_time(start, dn, "start")
  end <- if (is.null(end)) dn$meta$time_range[["end"]] else
    .as_time(end, dn, "end")
  if (end < start) {
    stop(errorCondition("`end` must be at or after `start`.",
                        class = "dynet_bad_input", call = NULL))
  }
  edge_blocks <- .duration_fragment_blocks(dn, sessions, censored)
  vertex_blocks <- .vertex_duration_blocks(dn, sessions, censored)
  out <- Map(function(edges, vertices, label) {
    .collapse_one(
      dn, edges, vertices, weight, start, end, sessions,
      if (identical(sessions, "separate")) label else NULL
    )
  }, edge_blocks, vertex_blocks, names(edge_blocks))
  if (!identical(sessions, "separate")) return(out[[1L]])
  structure(out, class = c("dynet_collapsed_list", "list"))
}

#' Tidy tables from a collapsed temporal network
#' @param x A network returned by [collapse_network()].
#' @param row.names,optional Ignored; present for compatibility.
#' @param what `"edges"` or `"nodes"`.
#' @param ... Ignored.
#' @return A plain `data.frame`. For `"edges"`, one row per collapsed vertex
#'   pair carrying every weighting side by side: `from`, `to`, `binary`,
#'   `union_duration`, `total_duration`, `duration_fraction`, `spell_count`,
#'   `weight_sum`, `weighted_duration`, `latest_weight`, `first`, `last`, and
#'   the `activity.duration` and `activity.count` aliases. For `"nodes"`, one
#'   row per vertex with `name`, `activity_duration` and its
#'   `activity.duration` alias, plus any static vertex attributes the network
#'   carries. See [collapse_network()] for what each weighting means.
#' @export
as.data.frame.dynet_collapsed <- function(
    x, row.names = NULL, optional = FALSE, what = c("edges", "nodes"), ...) {
  what <- match.arg(what)
  out <- if (identical(what, "edges")) x$data else {
    x$nodes[, setdiff(names(x$nodes), c("id", "label", "x", "y")), drop = FALSE]
  }
  rownames(out) <- NULL
  out
}

#' Print a collapsed temporal network
#' @param x A network returned by [collapse_network()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_collapsed <- function(x, ...) {
  cat(sprintf(
    "# Collapsed temporal network | %d vertices | %d edges | weight: %s\n",
    nrow(x$nodes), nrow(x$edges), x$meta$weight
  ))
  cat(sprintf("# %s to %s %s\n", format(x$meta$start), format(x$meta$end),
              x$meta$time_unit))
  print(utils::head(as.data.frame(x), 6L), row.names = FALSE)
  invisible(x)
}
