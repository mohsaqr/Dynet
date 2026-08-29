# ===========================================================================
# Immutable temporal-tie mutation
# ===========================================================================

#' Normalize new temporal tie rows against an existing Dynet clock
#' @param dn Existing temporal network.
#' @param data Data frame supplied to [add_ties()].
#' @param loops Whether new self-loops are permitted.
#' @return A canonical spell table. Attribute `censor_explicit` records whether
#'   either censor column was supplied.
#' @noRd
.normalize_added_ties <- function(dn, data, loops) {
  .check("`data` must be a nonempty data frame." =
           is.data.frame(data) && nrow(data) > 0L)
  required <- c("from", "to", "start", "end")
  optional <- c("weight", "session", "onset_censored", "terminus_censored")
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    stop(errorCondition(
      sprintf("Missing required tie column(s): %s.", paste(missing, collapse = ", ")),
      class = c("dynet_missing_column", "dynet_bad_input"), call = NULL
    ))
  }
  extra <- setdiff(names(data), c(required, optional))
  n <- nrow(data)
  vector_column <- function(x) is.atomic(x) && is.null(dim(x)) && length(x) == n
  if (!vector_column(data$from) || !vector_column(data$to)) {
    stop(errorCondition("`from` and `to` must be atomic columns.",
                        class = "dynet_bad_input", call = NULL))
  }
  from <- as.character(data$from)
  to <- as.character(data$to)
  if (anyNA(from) || anyNA(to)) {
    stop(errorCondition("Tie endpoints must be complete node names.",
                        class = "dynet_bad_input", call = NULL))
  }
  known <- dn$nodes$name
  unknown <- setdiff(unique(c(from, to)), known)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown node(s): %s. Add nodes before adding their ties.",
              paste(sort(unknown), collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  if (any(from == to) && !loops) {
    stop(errorCondition(
      "New self-loops require `loops = TRUE`.",
      class = c("dynet_loop_not_allowed", "dynet_bad_input"), call = NULL
    ))
  }
  convert_time <- function(x, field) {
    if (!vector_column(x)) {
      stop(errorCondition(sprintf("`%s` must have one time per tie.", field),
                          class = "dynet_bad_input", call = NULL))
    }
    vapply(seq_along(x), function(i) {
      .as_time(x[i], dn, paste0("data$", field))
    }, numeric(1L))
  }
  start <- convert_time(data$start, "start")
  end <- convert_time(data$end, "end")
  if (any(end < start)) {
    stop(errorCondition("Every added tie must end at or after it starts.",
                        class = "dynet_bad_input", call = NULL))
  }
  weight <- if ("weight" %in% names(data)) data$weight else rep(1, n)
  if (!is.numeric(weight) || length(weight) != n || anyNA(weight) ||
      any(!is.finite(weight))) {
    stop(errorCondition("`weight` must contain one finite number per tie.",
                        class = "dynet_bad_input", call = NULL))
  }

  existing_sessions <- dn$meta$sessions
  has_session <- "session" %in% names(data)
  if (!is.null(existing_sessions) && !has_session) {
    stop(errorCondition(
      "A sessioned network requires a `session` value for every added tie.",
      class = c("dynet_missing_session", "dynet_bad_input"), call = NULL
    ))
  }
  if (is.null(existing_sessions) && has_session) {
    stop(errorCondition(
      "Cannot introduce sessions through tie mutation; rebuild the network with sessions.",
      class = c("dynet_incompatible_session", "dynet_bad_input"), call = NULL
    ))
  }
  session <- rep(NA_character_, n)
  if (has_session) {
    if (!vector_column(data$session)) {
      stop(errorCondition("`session` must have one label per tie.",
                          class = "dynet_bad_input", call = NULL))
    }
    session <- as.character(data$session)
    if (anyNA(session) || any(!nzchar(trimws(session)))) {
      stop(errorCondition("Session labels must be complete and nonempty.",
                          class = "dynet_bad_input", call = NULL))
    }
    unknown_session <- setdiff(unique(session), existing_sessions)
    if (length(unknown_session)) {
      stop(errorCondition(
        sprintf("Unknown session label(s): %s.",
                paste(sort(unknown_session), collapse = ", ")),
        class = c("dynet_unknown_session", "dynet_bad_input"), call = NULL
      ))
    }
  }
  censor_flag <- function(name) {
    if (!name %in% names(data)) return(rep(FALSE, n))
    value <- data[[name]]
    if (!is.logical(value) || !vector_column(value) || anyNA(value)) {
      stop(errorCondition(
        sprintf("`%s` must contain one non-missing logical per tie.", name),
        class = c("dynet_bad_censor", "dynet_bad_input"), call = NULL
      ))
    }
    value
  }
  onset_censored <- censor_flag("onset_censored")
  terminus_censored <- censor_flag("terminus_censored")
  if (any(start == end & (onset_censored | terminus_censored))) {
    stop(errorCondition("A point tie cannot carry a censor flag.",
                        class = c("dynet_bad_censor", "dynet_bad_input"),
                        call = NULL))
  }
  out <- data.frame(
    from = from, to = to, start = start, end = end, weight = as.numeric(weight),
    session = session, onset_censored = onset_censored,
    terminus_censored = terminus_censored, stringsAsFactors = FALSE
  )
  if (length(extra)) {
    valid_extra <- vapply(data[extra], function(value) {
      is.atomic(value) && is.null(dim(value)) && length(value) == n
    }, logical(1L))
    if (!all(valid_extra)) {
      stop(errorCondition(
        sprintf("Tie attribute column(s) must be atomic vectors: %s.",
                paste(extra[!valid_extra], collapse = ", ")),
        class = "dynet_bad_input", call = NULL
      ))
    }
    out[extra] <- data[extra]
  }
  attr(out, "censor_explicit") <- any(
    c("onset_censored", "terminus_censored") %in% names(data)
  )
  out
}

#' Rebuild every derived Dynet and cograph field after tie mutation
#' @param dn Source network whose nodes, activity, and observation contract are
#'   retained.
#' @param spells Complete replacement canonical tie table.
#' @param censor_explicit Whether the resulting raw censor schema is explicit.
#' @param nodes Optional complete replacement public node table.
#' @param vertex_spells Optional complete replacement vertex-activity table.
#' @param format Optional replacement source-format label; node and removal
#'   operations preserve the existing label.
#' @param call Mutation call stored in metadata.
#' @return A new internally consistent `dynet` object.
#' @noRd
.rebuild_ties <- function(dn, spells, censor_explicit, call,
                          nodes = NULL, vertex_spells = NULL, format = NULL) {
  if (!nrow(spells)) {
    stop(errorCondition("Tie mutation cannot leave a Dynet object edgeless.",
                        class = "dynet_empty_network", call = NULL))
  }
  if (!dn$directed) {
    lo <- pmin(spells$from, spells$to)
    hi <- pmax(spells$from, spells$to)
    spells$from <- lo
    spells$to <- hi
  }
  canonical <- c("from", "to", "start", "end", "weight", "session",
                 "onset_censored", "terminus_censored")
  extras <- setdiff(names(spells), c(canonical, ".raw_spell"))
  spells <- spells[order(spells$start, spells$end, spells$from, spells$to),
                   c(canonical, extras), drop = FALSE]
  rownames(spells) <- NULL
  spells$.raw_spell <- seq_len(nrow(spells))

  meta <- dn$meta
  raw_range <- c(start = min(spells$start), end = max(spells$end))
  explicit_observation <- isTRUE(meta$observation_explicit) ||
    !is.null(meta$observations)
  if (explicit_observation) {
    meta$event_range <- raw_range
  } else {
    meta$time_range <- raw_range
    meta$n_bins <- max(1L, as.integer(ceiling(
      (raw_range[["end"]] - raw_range[["start"]]) / meta$interval
    )))
  }
  meta$sessions <- if (all(is.na(spells$session))) {
    NULL
  } else sort(unique(spells$session[!is.na(spells$session)]))
  if (!is.null(format)) meta$format <- format
  meta$call <- call
  meta$raw_censoring <- if (censor_explicit) "explicit" else "none"
  if (censor_explicit) {
    meta$raw_censoring_columns <- list(
      onset = "onset_censored", terminus = "terminus_censored"
    )
    meta$n_onset_censored <- as.integer(sum(spells$onset_censored))
    meta$n_terminus_censored <- as.integer(sum(spells$terminus_censored))
    meta$n_both_censored <- as.integer(sum(
      spells$onset_censored & spells$terminus_censored
    ))
  } else {
    meta$raw_censoring_columns <- NULL
    meta$n_onset_censored <- NULL
    meta$n_terminus_censored <- NULL
    meta$n_both_censored <- NULL
  }
  nodes <- nodes %||% as.data.frame(dn, what = "nodes")
  numeric_names <- all(grepl("^[+-]?[0-9]+(\\.[0-9]+)?$", nodes$name))
  node_order <- if (numeric_names) {
    order(as.numeric(nodes$name))
  } else order(nodes$name)
  nodes <- nodes[node_order, , drop = FALSE]
  rownames(nodes) <- NULL
  vertex_spells <- vertex_spells %||% dn$vertex_spells
  orphaned_vertex_session <- setdiff(
    unique(vertex_spells$session[!is.na(vertex_spells$session)]),
    meta$sessions %||% character()
  )
  if (length(orphaned_vertex_session)) {
    stop(errorCondition(
      sprintf("Mutation would orphan vertex-activity session(s): %s.",
              paste(sort(orphaned_vertex_session), collapse = ", ")),
      class = c("dynet_orphaned_vertex_session", "dynet_bad_input"),
      call = NULL
    ))
  }
  meta$vertex_activity_components <- nrow(vertex_spells)
  meta$n_dynamic_vertices <- length(unique(vertex_spells$node))
  meta$n_implicit_static_vertices <- nrow(nodes) - meta$n_dynamic_vertices
  meta$vertex_activity <- if (nrow(vertex_spells)) "explicit" else "static"
  meta$vertex_activity_supplied <- nrow(vertex_spells) > 0L
  meta$vertex_activity_scope <- if (!nrow(vertex_spells)) {
    "none"
  } else if (any(!is.na(vertex_spells$session))) "session" else "global"
  meta$vertex_sessions <- if (nrow(vertex_spells) &&
                              any(!is.na(vertex_spells$session))) {
    sort(unique(vertex_spells$session[!is.na(vertex_spells$session)]))
  } else NULL
  meta$n_vertex_onset_censored <- as.integer(sum(vertex_spells$onset_censored))
  meta$n_vertex_terminus_censored <-
    as.integer(sum(vertex_spells$terminus_censored))
  out <- .as_netobject(
    spells = spells, nodes = nodes, directed = dn$directed, groups = NULL,
    meta = meta, vertex_spells = vertex_spells
  )
  out$node_groups <- if ("groups" %in% names(nodes)) {
    data.frame(node = nodes$name, group = as.character(nodes$groups),
               stringsAsFactors = FALSE)
  } else NULL
  out
}

#' Bind new node rows while preserving the public attribute schema
#' @param existing Existing public node table.
#' @param added New node rows.
#' @return The combined node table.
#' @noRd
.bind_added_nodes <- function(existing, added) {
  columns <- union(names(existing), names(added))
  fill <- function(x, prototype, n) {
    missing <- setdiff(columns, names(x))
    values <- lapply(missing, function(name) {
      source <- prototype[[name]]
      source[rep(NA_integer_, n)]
    })
    if (length(missing)) x[missing] <- values
    x[, columns, drop = FALSE]
  }
  existing <- fill(existing, added, nrow(existing))
  added <- fill(added, existing, nrow(added))
  out <- rbind(existing, added)
  rownames(out) <- NULL
  out
}

.bind_added_ties <- function(existing, added) {
  columns <- union(names(existing), names(added))
  fill <- function(x, prototype) {
    missing <- setdiff(columns, names(x))
    if (length(missing)) {
      x[missing] <- lapply(missing, function(name) {
        prototype[[name]][rep(NA_integer_, nrow(x))]
      })
    }
    x[, columns, drop = FALSE]
  }
  existing <- fill(existing, added)
  added <- fill(added, existing)
  rbind(existing, added)
}

#' Add nodes to a temporal network
#'
#' @param dn A temporal network from [dynet()].
#' @param data A character vector of new node names or a data frame containing
#'   a `name` column and optional static attributes.
#' @return A new `dynet` object with the added nodes represented as implicit
#'   always-active isolates until ties or vertex activity are supplied.
#' @details Existing nodes and attributes are unchanged. Missing attribute
#'   values are filled with typed `NA`. If the source has a cograph grouping,
#'   each new node must supply its group through `groups` or through the source
#'   attribute from which that grouping was derived.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
#' add_nodes(dn, "C")
#' @export
add_nodes <- function(dn, data) {
  .check_dynet(dn, "bounded")
  added <- if (is.character(data) && is.null(dim(data))) {
    data.frame(name = data, stringsAsFactors = FALSE)
  } else data
  if (!is.data.frame(added) || !"name" %in% names(added) || !nrow(added)) {
    stop(errorCondition(
      "`data` must be nonempty node names or a data frame with `name`.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (anyDuplicated(names(added))) {
    stop(errorCondition("New node columns must have unique names.",
                        class = "dynet_bad_input", call = NULL))
  }
  forbidden <- intersect(names(added), c("id", "label", "x", "y"))
  if (length(forbidden)) {
    stop(errorCondition(
      sprintf("Cograph structural column(s) cannot be supplied: %s.",
              paste(forbidden, collapse = ", ")),
      class = "dynet_bad_input", call = NULL
    ))
  }
  added$name <- as.character(added$name)
  if (anyNA(added$name) || anyDuplicated(added$name)) {
    stop(errorCondition("New node names must be unique and complete.",
                        class = "dynet_bad_input", call = NULL))
  }
  existing <- as.data.frame(dn, what = "nodes")
  duplicate <- intersect(added$name, existing$name)
  if (length(duplicate)) {
    stop(errorCondition(
      sprintf("Node(s) already exist: %s.", paste(sort(duplicate), collapse = ", ")),
      class = c("dynet_duplicate_node", "dynet_bad_input"), call = NULL
    ))
  }
  if ("groups" %in% names(existing) && !"groups" %in% names(added)) {
    candidates <- setdiff(names(existing), c("name", "groups"))
    source <- candidates[vapply(candidates, function(name) {
      identical(as.character(existing[[name]]), as.character(existing$groups))
    }, logical(1L))]
    if (length(source) == 1L && source %in% names(added)) {
      added$groups <- as.character(added[[source]])
    } else {
      stop(errorCondition(
        "New nodes in a grouped network must supply their group.",
        class = c("dynet_missing_group", "dynet_bad_input"), call = NULL
      ))
    }
  }
  nodes <- .bind_added_nodes(existing, added)
  .rebuild_ties(
    dn, dn$spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), nodes = nodes
  )
}

#' Remove nodes from a temporal network
#'
#' @param dn A temporal network from [dynet()].
#' @param nodes Character node names.
#' @param cascade Whether to remove every incident temporal tie and vertex
#'   activity spell. The safe default rejects nodes that are not isolates.
#' @return A new internally consistent `dynet` object.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
#' dn <- add_nodes(dn, "C")
#' remove_nodes(dn, "C")
#' @export
remove_nodes <- function(dn, nodes, cascade = FALSE) {
  .check_dynet(dn, "bounded")
  .check("`cascade` must be one non-missing logical value." =
           is.logical(cascade) && length(cascade) == 1L && !is.na(cascade))
  if (!is.character(nodes) || !length(nodes) || anyNA(nodes)) {
    stop(errorCondition("`nodes` must contain complete node names.",
                        class = "dynet_bad_input", call = NULL))
  }
  nodes <- unique(nodes)
  unknown <- setdiff(nodes, dn$nodes$name)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown node(s): %s.", paste(sort(unknown), collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  incident <- dn$spells$from %in% nodes | dn$spells$to %in% nodes
  active <- dn$vertex_spells$node %in% nodes
  if (!cascade && (any(incident) || any(active))) {
    stop(errorCondition(
      "Removing a node with ties or vertex activity requires `cascade = TRUE`.",
      class = c("dynet_node_not_isolate", "dynet_bad_input"), call = NULL
    ))
  }
  kept_spells <- dn$spells[!incident, , drop = FALSE]
  if (!nrow(kept_spells)) {
    stop(errorCondition("Node removal cannot leave a Dynet object edgeless.",
                        class = "dynet_empty_network", call = NULL))
  }
  kept_nodes <- as.data.frame(dn, what = "nodes")
  kept_nodes <- kept_nodes[!kept_nodes$name %in% nodes, , drop = FALSE]
  kept_activity <- dn$vertex_spells[!active, , drop = FALSE]
  .rebuild_ties(
    dn, kept_spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), nodes = kept_nodes, vertex_spells = kept_activity
  )
}

#' Add temporal ties
#'
#' @param dn A temporal network from [dynet()].
#' @param data A nonempty data frame with `from`, `to`, `start`, and `end`.
#'   Optional columns are `weight`, `session`, `onset_censored`, and
#'   `terminus_censored`. Endpoints must already exist in `dn`.
#' @param loops Whether added self-loops are permitted.
#' @return A new `dynet` object. The input is unchanged; canonical temporal
#'   ties and every flattened cograph field are rebuilt together.
#' @details Added times use the existing network clock. A sessioned network
#' requires an existing session label on every row; mutation does not create a
#' new session scheme. Implicit observation support expands to include the new
#' raw ties, while explicit observation support remains fixed. Added raw rows
#' are interval-format tie identities even when the source was originally a
#' contact, threaded, or co-presence log.
#' @examples
#' dn <- dynet(data.frame(
#'   from = "A", to = "B", start = 0, end = 1
#' ))
#' dn <- add_nodes(dn, "C")
#' add_ties(dn, data.frame(from = "B", to = "C", start = 1, end = 2))
#' @export
add_ties <- function(dn, data, loops = FALSE) {
  .check_dynet(dn, "bounded")
  .check("`loops` must be one non-missing logical value." =
           is.logical(loops) && length(loops) == 1L && !is.na(loops))
  added <- .normalize_added_ties(dn, data, loops)
  explicit <- identical(dn$meta$raw_censoring, "explicit") ||
    isTRUE(attr(added, "censor_explicit"))
  attr(added, "censor_explicit") <- NULL
  existing <- dn$spells[, setdiff(names(dn$spells), ".raw_spell"), drop = FALSE]
  .rebuild_ties(
    dn, .bind_added_ties(existing, added), explicit, match.call(),
    format = "interval"
  )
}

#' Remove temporal ties
#'
#' @param dn A temporal network from [dynet()].
#' @param ties Optional integer positions or logical mask referring to the rows
#'   of `as.data.frame(dn, what = "edges")`.
#' @param from,to,start,end,session Optional selectors combined by conjunction.
#'   When `ties` is supplied, these selectors must be omitted. On undirected
#'   networks `from` and `to` must be supplied together and their order is
#'   ignored.
#' @return A new internally consistent `dynet` object. At least one temporal
#'   tie must remain.
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "B"), to = c("B", "C"),
#'   start = c(0, 1), end = c(1, 2)
#' ))
#' remove_ties(dn, ties = 1)
#' @export
remove_ties <- function(dn, ties = NULL, from = NULL, to = NULL,
                        start = NULL, end = NULL, session = NULL) {
  .check_dynet(dn, "bounded")
  selectors <- list(from = from, to = to, start = start, end = end,
                    session = session)
  has_selector <- !vapply(selectors, is.null, logical(1L))
  if (is.null(ties) && !any(has_selector)) {
    stop(errorCondition("Supply `ties` or at least one explicit tie selector.",
                        class = c("dynet_missing_tie_selector", "dynet_bad_input"),
                        call = NULL))
  }
  if (!is.null(ties) && any(has_selector)) {
    stop(errorCondition("`ties` cannot be combined with other tie selectors.",
                        class = "dynet_bad_input", call = NULL))
  }
  n <- nrow(dn$spells)
  remove <- rep(FALSE, n)
  if (!is.null(ties)) {
    if (is.logical(ties)) {
      if (length(ties) != n || anyNA(ties)) {
        stop(errorCondition("A logical `ties` mask must match the tie count.",
                            class = "dynet_bad_input", call = NULL))
      }
      remove <- ties
    } else if (is.numeric(ties) && all(is.finite(ties)) &&
               all(ties == as.integer(ties)) && all(ties >= 1L & ties <= n)) {
      remove[unique(as.integer(ties))] <- TRUE
    } else {
      stop(errorCondition("`ties` must contain valid integer row positions.",
                          class = "dynet_bad_input", call = NULL))
    }
  } else {
    if (!dn$directed && xor(is.null(from), is.null(to))) {
      stop(errorCondition(
        "Undirected endpoint selection requires both `from` and `to`.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    if (!dn$directed && !is.null(from) &&
        (length(from) != 1L || length(to) != 1L)) {
      stop(errorCondition(
        "Undirected endpoint selection accepts one unordered pair at a time.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    remove[] <- TRUE
    if (!is.null(from) && !is.null(to) && !dn$directed) {
      a <- pmin(as.character(from), as.character(to))
      b <- pmax(as.character(from), as.character(to))
      remove <- remove & dn$spells$from %in% a & dn$spells$to %in% b
    } else {
      if (!is.null(from)) remove <- remove & dn$spells$from %in% as.character(from)
      if (!is.null(to)) remove <- remove & dn$spells$to %in% as.character(to)
    }
    convert_selector_time <- function(value, name) {
      if (is.null(value)) return(NULL)
      vapply(seq_along(value), function(i) {
        .as_time(value[i], dn, name)
      }, numeric(1L))
    }
    selected_start <- convert_selector_time(start, "start")
    selected_end <- convert_selector_time(end, "end")
    if (!is.null(selected_start)) remove <- remove & dn$spells$start %in% selected_start
    if (!is.null(selected_end)) remove <- remove & dn$spells$end %in% selected_end
    if (!is.null(session)) remove <- remove & dn$spells$session %in% as.character(session)
  }
  if (!any(remove)) {
    stop(errorCondition("No temporal ties matched the removal request.",
                        class = c("dynet_tie_not_found", "dynet_bad_input"),
                        call = NULL))
  }
  kept <- dn$spells[
    !remove, setdiff(names(dn$spells), ".raw_spell"), drop = FALSE
  ]
  remaining_sessions <- unique(kept$session[!is.na(kept$session)])
  orphaned_vertex_session <- setdiff(
    unique(dn$vertex_spells$session[!is.na(dn$vertex_spells$session)]),
    remaining_sessions
  )
  if (length(orphaned_vertex_session)) {
    stop(errorCondition(
      sprintf("Removal would orphan vertex-activity session(s): %s.",
              paste(sort(orphaned_vertex_session), collapse = ", ")),
      class = c("dynet_orphaned_vertex_session", "dynet_bad_input"),
      call = NULL
    ))
  }
  .rebuild_ties(
    dn, kept, identical(dn$meta$raw_censoring, "explicit"), match.call()
  )
}

#' Add directed temporal arcs
#'
#' The same operation as [add_ties()], with one extra guarantee: the network
#' must already be directed, so `from` and `to` keep the direction the caller
#' means. Adding an arc to an undirected network raises a condition of class
#' `dynet_needs_directed` rather than silently recording a symmetric tie.
#'
#' @inheritParams add_ties
#' @return A new directed `dynet` object carrying the added spells, with the
#'   same structure as the input.
#' @seealso [add_ties()], which does not require a directed network.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
#' dn <- add_nodes(dn, "C")
#' add_arcs(dn, data.frame(from = "B", to = "C", start = 1, end = 2))
#' @export
add_arcs <- function(dn, data, loops = FALSE) {
  .check_dynet(dn, "bounded")
  if (!dn$directed) {
    stop(errorCondition("`add_arcs()` requires a directed network.",
                        class = c("dynet_needs_directed", "dynet_bad_input"),
                        call = NULL))
  }
  add_ties(dn, data, loops = loops)
}

#' Remove directed temporal arcs
#'
#' The same operation as [remove_ties()], with one extra guarantee: the
#' network must already be directed, so a `from`/`to` pair names one arc and
#' not both orientations. Removing an arc from an undirected network raises a
#' condition of class `dynet_needs_directed`.
#'
#' @inheritParams remove_ties
#' @return A new directed `dynet` object without the matched spells, with the
#'   same structure as the input.
#' @seealso [remove_ties()], which does not require a directed network.
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "B"), to = c("B", "C"),
#'   start = c(0, 1), end = c(1, 2)
#' ))
#' remove_arcs(dn, ties = 1)
#' @export
remove_arcs <- function(dn, ties = NULL, from = NULL, to = NULL,
                        start = NULL, end = NULL, session = NULL) {
  .check_dynet(dn, "bounded")
  if (!dn$directed) {
    stop(errorCondition("`remove_arcs()` requires a directed network.",
                        class = c("dynet_needs_directed", "dynet_bad_input"),
                        call = NULL))
  }
  remove_ties(dn, ties = ties, from = from, to = to, start = start,
              end = end, session = session)
}
