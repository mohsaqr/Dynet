# ===========================================================================
# Honest visual representations of endpoint-local temporal path families
# ===========================================================================

.path_hops <- function(x) {
  steps <- as.data.frame(x, what = "steps")
  if (!nrow(steps)) return(data.frame(
    from = character(), to = character(), time = numeric(),
    endpoint = character(), path_id = numeric(), path_session = character(),
    stringsAsFactors = FALSE
  ))
  session <- if ("session" %in% names(steps)) steps$session else
    rep("all", nrow(steps))
  key <- paste(session, steps$endpoint, steps$path_id, sep = "\r")
  groups <- split(seq_len(nrow(steps)), key)
  rows <- lapply(groups, function(index) {
    one <- steps[index, , drop = FALSE]
    one <- one[order(one$step), , drop = FALSE]
    if (nrow(one) < 2L) return(NULL)
    out <- data.frame(
      from = utils::head(one$node, -1L), to = utils::tail(one$node, -1L),
      time = utils::tail(one$time, -1L), endpoint = one$endpoint[[1L]],
      path_id = one$path_id[[1L]], path_session = one$path_session[[1L]],
      stringsAsFactors = FALSE
    )
    if ("session" %in% names(one)) out$session <- one$session[[1L]]
    out
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) return(data.frame(
    from = character(), to = character(), time = numeric(),
    endpoint = character(), path_id = numeric(), path_session = character(),
    stringsAsFactors = FALSE
  ))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Build the union network of optimal temporal paths
#'
#' `paths()` uses an endpoint-local foremost-then-shortest criterion, so
#' its routes need not form one predecessor tree. This function therefore
#' returns the honest union of all expanded optimal route hops. Edge `weight`
#' is the number of endpoint/path families using the hop; `first_time` and
#' `last_time` retain its temporal range.
#'
#' @param x A result from [paths()].
#' @return A static `dynet_path_network` cograph netobject.
#' @export
path_network <- function(x) {
  if (!inherits(x, "dynet_paths")) {
    stop(errorCondition("`x` must be a result from `paths()`.",
                        class = "dynet_bad_input", call = NULL))
  }
  hops <- .path_hops(x)
  paths <- as.data.frame(x)
  nodes <- paths[paths$reachable, c("node", "arrival_time", "latency",
                                    "n_hops", "n_paths"), drop = FALSE]
  if (!nrow(nodes)) {
    stop(errorCondition("The path result has no reachable vertices.",
                        class = "dynet_empty_result", call = NULL))
  }
  if (nrow(hops)) {
    key <- paste(hops$from, hops$to, sep = "\r")
    groups <- split(seq_len(nrow(hops)), key)
    edges <- do.call(rbind, lapply(groups, function(index) data.frame(
      from = hops$from[index[[1L]]], to = hops$to[index[[1L]]],
      weight = length(index), first_time = min(hops$time[index]),
      last_time = max(hops$time[index]),
      n_endpoints = length(unique(hops$endpoint[index])),
      stringsAsFactors = FALSE
    )))
    edges <- edges[order(edges$from, edges$to), , drop = FALSE]
    rownames(edges) <- NULL
  } else {
    edges <- data.frame(
      from = character(), to = character(), weight = numeric(),
      first_time = numeric(), last_time = numeric(), n_endpoints = integer(),
      stringsAsFactors = FALSE
    )
  }
  names <- nodes$node
  from_id <- match(edges$from, names)
  to_id <- match(edges$to, names)
  weights <- matrix(0, nrow(nodes), nrow(nodes),
                    dimnames = list(names, names))
  if (nrow(edges)) weights[cbind(from_id, to_id)] <- edges$weight
  node_table <- data.frame(
    id = seq_len(nrow(nodes)), label = names, name = names,
    x = NA_real_, y = NA_real_,
    arrival_time = nodes$arrival_time, latency = nodes$latency,
    n_hops = nodes$n_hops, n_paths = nodes$n_paths,
    groups = as.character(nodes$n_hops), stringsAsFactors = FALSE
  )
  edge_table <- data.frame(
    from = from_id, to = to_id, weight = edges$weight,
    edges[, setdiff(names(edges), c("from", "to", "weight")), drop = FALSE],
    stringsAsFactors = FALSE
  )
  structure(list(
    nodes = node_table, edges = edge_table,
    directed = TRUE, weights = weights, data = edges,
    meta = list(
      source = "dynet", type = "temporal_path_union",
      path_source = attr(x, "source"), direction = attr(x, "direction"),
      criterion = attr(x, "criterion"), path_mode = attr(x, "path_mode"),
      time_unit = attr(x, "time_unit")
    ),
    node_groups = data.frame(node = names, group = as.character(nodes$n_hops),
                             stringsAsFactors = FALSE)
  ), class = c("dynet_path_network", "netobject", "cograph_network"))
}

#' Tidy tables from a temporal path-union network
#' @param x A network returned by [path_network()].
#' @param row.names,optional Ignored.
#' @param what `"edges"` or `"nodes"`.
#' @param ... Ignored.
#' @return A plain data frame.
#' @export
as.data.frame.dynet_path_network <- function(
    x, row.names = NULL, optional = FALSE, what = c("edges", "nodes"), ...) {
  what <- match.arg(what)
  out <- if (identical(what, "edges")) x$data else
    x$nodes[, setdiff(names(x$nodes), c("id", "label", "x", "y")), drop = FALSE]
  rownames(out) <- NULL
  out
}

