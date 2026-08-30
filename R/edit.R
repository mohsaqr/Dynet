# ===========================================================================
# Immutable attribute editing and temporal subgraphs
# ===========================================================================

.edit_row_selector <- function(selector, n, argument = "rows") {
  if (is.logical(selector)) {
    if (length(selector) != n || anyNA(selector)) {
      stop(errorCondition(
        sprintf("A logical `%s` mask must have length %d.", argument, n),
        class = "dynet_bad_input", call = NULL
      ))
    }
    return(which(selector))
  }
  if (!is.numeric(selector) || !length(selector) || any(!is.finite(selector)) ||
      any(selector != as.integer(selector)) || any(selector < 1L | selector > n)) {
    stop(errorCondition(
      sprintf("`%s` must contain valid integer row positions.", argument),
      class = "dynet_bad_input", call = NULL
    ))
  }
  unique(as.integer(selector))
}

.replace_attribute_values <- function(existing, index, value, n) {
  if (length(value) == 1L) value <- value[rep(1L, length(index))]
  if (length(value) != length(index)) {
    stop(errorCondition(
      "Each update column must have one value or one value per selected row.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (is.null(existing)) {
    existing <- value[rep(NA_integer_, n)]
  }
  if (is.factor(existing)) {
    levels <- union(levels(existing), unique(as.character(value)))
    existing <- factor(as.character(existing), levels = levels,
                       ordered = is.ordered(existing))
    value <- factor(as.character(value), levels = levels,
                    ordered = is.ordered(existing))
  }
  existing[index] <- value
  existing
}

#' Update static node attributes
#'
#' @param dn A temporal network.
#' @param data A nonempty data frame with a `name` key and one or more
#'   attributes to add or replace. Only named nodes are changed.
#' @return A new internally consistent `dynet` object.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 1))
#' update_nodes(dn, data.frame(name = "A", role = "initiator"))
#' @export
update_nodes <- function(dn, data) {
  .check_dynet(dn, "bounded")
  if (!is.data.frame(data) || !nrow(data) || !"name" %in% names(data) ||
      ncol(data) < 2L || anyDuplicated(names(data))) {
    stop(errorCondition(
      "`data` must be a nonempty data frame with `name` and attributes.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  forbidden <- intersect(names(data), c("id", "label", "x", "y"))
  if (length(forbidden)) {
    stop(errorCondition(
      sprintf("Cograph structural column(s) cannot be updated: %s.",
              paste(forbidden, collapse = ", ")),
      class = "dynet_bad_input", call = NULL
    ))
  }
  key <- as.character(data$name)
  if (anyNA(key) || anyDuplicated(key)) {
    stop(errorCondition("Update node names must be unique and complete.",
                        class = "dynet_bad_input", call = NULL))
  }
  nodes <- as.data.frame(dn, what = "nodes")
  index <- match(key, nodes$name)
  if (anyNA(index)) {
    stop(errorCondition(
      sprintf("Unknown node(s): %s.", paste(key[is.na(index)], collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  for (attribute in setdiff(names(data), "name")) {
    value <- data[[attribute]]
    if (!is.atomic(value) || !is.null(dim(value))) {
      stop(errorCondition(
        sprintf("Node attribute %s must be an atomic vector.", sQuote(attribute)),
        class = "dynet_bad_input", call = NULL
      ))
    }
    nodes[[attribute]] <- .replace_attribute_values(
      nodes[[attribute]], index, value, nrow(nodes)
    )
  }
  .rebuild_ties(
    dn, dn$spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), nodes = nodes
  )
}

#' Rename nodes everywhere in a temporal network
#'
#' @param dn A temporal network.
#' @param mapping A named character vector whose names are old node names and
#'   values are replacements, or a two-column data frame named `old` and
#'   `new`.
#' @return A new `dynet` object with edge endpoints, node attributes, vertex
#'   activity, cograph labels, and groups renamed together.
#' @export
rename_nodes <- function(dn, mapping) {
  .check_dynet(dn, "bounded")
  if (is.data.frame(mapping) && all(c("old", "new") %in% names(mapping))) {
    old <- as.character(mapping$old)
    new <- as.character(mapping$new)
  } else if (is.character(mapping) && !is.null(names(mapping))) {
    old <- names(mapping)
    new <- as.character(mapping)
  } else {
    stop(errorCondition(
      "`mapping` must be a named character vector or an old/new data frame.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (!length(old) || anyNA(old) || anyNA(new) || anyDuplicated(old) ||
      anyDuplicated(new)) {
    stop(errorCondition("Rename mappings must be nonempty, complete, and unique.",
                        class = "dynet_bad_input", call = NULL))
  }
  unknown <- setdiff(old, dn$nodes$name)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown node(s): %s.", paste(unknown, collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  collision <- intersect(new, setdiff(dn$nodes$name, old))
  if (length(collision)) {
    stop(errorCondition(
      sprintf("Replacement node name(s) already exist: %s.",
              paste(collision, collapse = ", ")),
      class = c("dynet_duplicate_node", "dynet_bad_input"), call = NULL
    ))
  }
  translate <- function(value) {
    hit <- match(value, old)
    value[!is.na(hit)] <- new[hit[!is.na(hit)]]
    value
  }
  spells <- dn$spells
  spells$from <- translate(spells$from)
  spells$to <- translate(spells$to)
  nodes <- as.data.frame(dn, what = "nodes")
  nodes$name <- translate(nodes$name)
  vertex_spells <- dn$vertex_spells
  vertex_spells$node <- translate(vertex_spells$node)
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), nodes = nodes, vertex_spells = vertex_spells
  )
}

#' Update temporal ties and their attributes
#'
#' @param dn A temporal network.
#' @param ties Integer row positions or a logical mask referring to
#'   `as.data.frame(dn, what = "edges")`.
#' @param data A data frame with one row or one row per selected tie. Columns
#'   may be canonical tie fields or arbitrary atomic spell attributes.
#' @param loops Whether an endpoint update may introduce a new self-loop.
#'   Existing loops may always be retained.
#' @return A new internally consistent `dynet` object.
#' @export
update_ties <- function(dn, ties, data, loops = FALSE) {
  .check_dynet(dn, "bounded")
  .check("`loops` must be one non-missing logical value." =
           is.logical(loops) && length(loops) == 1L && !is.na(loops))
  index <- .edit_row_selector(ties, nrow(dn$spells), "ties")
  if (!is.data.frame(data) || !nrow(data) || anyDuplicated(names(data)) ||
      !ncol(data)) {
    stop(errorCondition("`data` must be a nonempty update data frame.",
                        class = "dynet_bad_input", call = NULL))
  }
  if (nrow(data) != 1L && nrow(data) != length(index)) {
    stop(errorCondition(
      "`data` must have one row or one row per selected tie.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (any(names(data) %in% c("duration", ".raw_spell"))) {
    stop(errorCondition("`duration` and `.raw_spell` are derived and read-only.",
                        class = "dynet_bad_input", call = NULL))
  }
  if (nrow(data) == 1L && length(index) > 1L) {
    data <- data[rep(1L, length(index)), , drop = FALSE]
  }
  all_spells <- dn$spells[, setdiff(names(dn$spells), ".raw_spell"), drop = FALSE]
  selected <- all_spells[index, , drop = FALSE]
  old_loop <- selected$from == selected$to
  for (attribute in names(data)) {
    value <- data[[attribute]]
    if (!is.atomic(value) || !is.null(dim(value))) {
      stop(errorCondition(
        sprintf("Tie attribute %s must be an atomic vector.", sQuote(attribute)),
        class = "dynet_bad_input", call = NULL
      ))
    }
    selected[[attribute]] <- value
  }
  new_loop <- as.character(selected$from) == as.character(selected$to)
  if (any(new_loop & !old_loop) && !loops) {
    stop(errorCondition(
      "An endpoint update that creates a self-loop requires `loops = TRUE`.",
      class = c("dynet_loop_not_allowed", "dynet_bad_input"), call = NULL
    ))
  }
  if (is.null(dn$meta$sessions)) selected$session <- NULL
  normalized <- .normalize_added_ties(dn, selected, loops = TRUE)
  explicit <- identical(dn$meta$raw_censoring, "explicit") ||
    any(c("onset_censored", "terminus_censored") %in% names(data))
  attr(normalized, "censor_explicit") <- NULL
  remaining <- all_spells[-index, , drop = FALSE]
  rebuilt <- .bind_added_ties(remaining, normalized)
  .rebuild_ties(dn, rebuilt, explicit, match.call(), format = "interval")
}

#' Turn whatever the caller wrote for `nodes` into vertex names
#'
#' A vertex selection is nearly always a condition on the vertices -- the busy
#' ones, the ones in a room, the ones that broker. Making the caller compute a
#' table, filter it and unpack a column first is three steps for one thought,
#' so a condition is evaluated here against the vertex table, exactly as
#' [subset()] evaluates its own. Any centrality the condition names is computed
#' over the whole observed period and dropped in as a column before the
#' condition is evaluated.
#'
#' Anything else the caller might hold -- a character vector, a factor, a
#' logical mask, a filtered result frame -- resolves from the calling frame,
#' which is consulted after the vertex table. A variable named after a measure
#' is therefore shadowed by the measure, exactly as a variable named after a
#' column is shadowed inside [subset()].
#'
#' @param dn A `dynet` object.
#' @param expr The unevaluated `nodes` argument.
#' @param env The calling frame.
#' @return A character vector of node names, or `NULL`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.select_nodes(dn, quote(degree > 16), parent.frame())
#' @noRd
.select_nodes <- function(dn, expr, env) {
  if (is.null(expr)) return(NULL)
  table <- as.data.frame(dn, what = "nodes")
  # A measure named in the condition becomes a column, and the table is the
  # first environment the condition sees -- the same precedence `subset()`
  # gives a data frame's own columns over anything in the calling frame.
  wanted <- intersect(all.vars(expr), .node_measures)
  if (length(wanted) > 0L) {
    table <- as.data.frame(dn, what = "nodes", measure = wanted)
  }
  value <- eval(expr, table, env)
  if (is.null(value)) return(NULL)
  if (is.logical(value)) {
    if (length(value) != nrow(table)) {
      stop(errorCondition(sprintf(
        "A logical `nodes` selection must have one value per vertex; got %d for %d vertices.",
        length(value), nrow(table)),
        class = "dynet_bad_input", call = NULL))
    }
    return(table$name[!is.na(value) & value])
  }
  .node_names(value, "nodes")
}

#' Resolve a `ties` selection, evaluating a condition over the spell table
#'
#' The counterpart of `.select_nodes()` for edges. The spell table is the first
#' environment the condition sees, so a tie attribute named in the condition
#' resolves to its column, the same precedence `subset()` gives a data frame's
#' own columns over the calling frame.
#'
#' Whatever the expression evaluates to is handed on unchanged to
#' `.edit_row_selector()`, so row positions and a logical mask keep working
#' exactly as before; the only new capability is that a bare condition on a tie
#' attribute now resolves instead of raising "object not found".
#'
#' @param dn A `dynet` object.
#' @param expr The unevaluated `ties` argument, from `substitute()`.
#' @param env The caller's frame.
#' @return Whatever the selection evaluates to, or `NULL`.
#' @noRd
.select_ties <- function(dn, expr, env) {
  if (is.null(expr)) return(NULL)
  eval(expr, as.data.frame(dn), env)
}

#' Read vertex names out of whatever the caller had to hand
#'
#' A vertex selection usually arrives as the result of a measurement that has
#' been filtered, not as a bare character vector. Accepting that frame directly
#' is what keeps the caller from reaching into it with `$` to extract the one
#' column this function was going to read anyway.
#'
#' @param value A character vector, factor, or data frame with a `name` or
#'   `node` column.
#' @param arg The argument name, for the error message.
#' @return A character vector of node names.
#' @examples
#' Dynet:::.node_names(data.frame(node = c("A", "B"), value = 1:2), "nodes")
#' @noRd
.node_names <- function(value, arg) {
  if (is.null(value) || is.character(value)) return(value)
  if (is.factor(value)) return(as.character(value))
  if (is.data.frame(value)) {
    column <- intersect(c("name", "node"), names(value))
    if (!length(column)) {
      stop(errorCondition(sprintf(
        "`%s` is a data frame with no `name` or `node` column to read vertices from.",
        arg), class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL))
    }
    return(as.character(value[[column[[1L]]]]))
  }
  value
}

#' Extract an induced temporal subgraph
#'
#' @param dn A temporal network.
#' @param nodes Which vertices to keep. Either a condition on the vertex
#'   table, evaluated the way [subset()] evaluates one -- `degree > 20`,
#'   `room == "A" & betweenness > 0` -- with any centrality it names computed
#'   over the whole observed period; or a character vector of names, a factor,
#'   a logical mask, or any data frame carrying a `name` or `node` column. Only
#'   ties whose two endpoints are in this set are eligible.
#' @param ties Which ties to keep. Either a condition on the spell table,
#'   evaluated the way [subset()] evaluates one -- `course == "g1"`,
#'   `duration > 2 & weight >= 1` -- over the columns `as.data.frame(dn)`
#'   returns, tie attributes included; or integer row positions or a logical
#'   mask over that same table, in that order, a mask having exactly as many
#'   elements as there are spells.
#' @param keep_isolates Whether named nodes without a selected tie remain.
#' @return A new `dynet` object with selected ties, nodes, vertex activity, and
#'   all static attributes retained.
#' @examples
#' dn <- dynet(school_contacts)
#'
#' # A condition on the vertex table, in one call.
#' induce_subgraph(dn, degree > 16)
#'
#' # Names still work, as does anything carrying them.
#' induce_subgraph(dn, nodes = c("Ana", "Ben", "Cara"))
#' @export
induce_subgraph <- function(dn, nodes = NULL, ties = NULL,
                            keep_isolates = FALSE) {
  .check_dynet(dn, "bounded")
  nodes <- .select_nodes(dn, substitute(nodes), parent.frame())
  ties <- .select_ties(dn, substitute(ties), parent.frame())
  .check("`keep_isolates` must be one non-missing logical value." =
           is.logical(keep_isolates) && length(keep_isolates) == 1L &&
             !is.na(keep_isolates))
  if (is.null(nodes) && is.null(ties)) {
    stop(errorCondition("Supply `nodes`, `ties`, or both.",
                        class = "dynet_bad_input", call = NULL))
  }
  keep <- rep(TRUE, nrow(dn$spells))
  requested_nodes <- dn$nodes$name
  if (!is.null(nodes)) {
    if (is.character(nodes) && length(nodes) == 0L) {
      stop(errorCondition(
        "No vertex satisfies the `nodes` selection.",
        class = c("dynet_empty_network", "dynet_bad_input"), call = NULL))
    }
    if (!is.character(nodes) || !length(nodes) || anyNA(nodes)) {
      stop(errorCondition("`nodes` must contain complete node names.",
                          class = "dynet_bad_input", call = NULL))
    }
    requested_nodes <- unique(nodes)
    unknown <- setdiff(requested_nodes, dn$nodes$name)
    if (length(unknown)) {
      stop(errorCondition(
        sprintf("Unknown node(s): %s.", paste(unknown, collapse = ", ")),
        class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
      ))
    }
    keep <- keep & dn$spells$from %in% requested_nodes &
      dn$spells$to %in% requested_nodes
  }
  if (!is.null(ties)) {
    tie_index <- .edit_row_selector(ties, nrow(dn$spells), "ties")
    tie_keep <- rep(FALSE, nrow(dn$spells))
    tie_keep[tie_index] <- TRUE
    keep <- keep & tie_keep
  }
  spells <- dn$spells[keep, , drop = FALSE]
  if (!nrow(spells)) {
    stop(errorCondition("The requested temporal subgraph has no ties.",
                        class = "dynet_empty_network", call = NULL))
  }
  endpoint_nodes <- unique(c(spells$from, spells$to))
  kept_names <- if (keep_isolates && !is.null(nodes)) {
    unique(c(requested_nodes, endpoint_nodes))
  } else endpoint_nodes
  public_nodes <- as.data.frame(dn, what = "nodes")
  public_nodes <- public_nodes[public_nodes$name %in% kept_names, , drop = FALSE]
  vertex_spells <- dn$vertex_spells[
    dn$vertex_spells$node %in% kept_names, , drop = FALSE
  ]
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), nodes = public_nodes, vertex_spells = vertex_spells
  )
}
