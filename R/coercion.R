# ===========================================================================
# Import temporal networks from established R representations
# ===========================================================================

#' Convert an object to a Dynet temporal network
#'
#' @param x An object representing a temporal network.
#' @param ... Passed to a class-specific method.
#' @return A [dynet()] temporal network.
#' @export
as_dynet <- function(x, ...) {
  UseMethod("as_dynet")
}

#' @export
as_dynet.dynet <- function(x, ...) {
  x
}

#' Import a networkDynamic object
#'
#' Converts the edge-activity spell ledger, observation support, explicit
#' vertex activity, weights, static vertex attributes, and static edge
#' attributes of a `networkDynamic` object. Integer vertex identifiers are
#' replaced by a complete unique vertex attribute. By default Dynet tries
#' `Name`, `Label`, and then `vertex.names`, in that order.
#'
#' Dynamic edge attributes other than activity itself are not part of the
#' `networkDynamic` spell-list interface and are therefore not imported.
#' Ordinary per-edge attributes are repeated onto every imported spell of the
#' corresponding aggregate edge.
#'
#' @param x A `networkDynamic` object.
#' @param name_attribute Optional vertex attribute holding the public node
#'   names. `NULL` chooses the first complete unique attribute among `Name`,
#'   `Label`, and `vertex.names`.
#' @param group_attribute Optional static vertex attribute used as the cograph
#'   grouping variable.
#' @param weight_attribute Static edge attribute used as spell weight. Supply
#'   `NULL` to use unit weights.
#' @param session_attribute Optional static edge attribute used as the spell
#'   session label.
#' @param interval Positive measurement interval. `NULL` uses the legacy
#'   observation time increment when available, otherwise one.
#' @param active_default Whether legacy edges with no explicit activity spell
#'   are active over the observation period, matching the same argument in
#'   `networkDynamic`.
#' @param import_edge_attributes Whether to retain compatible static legacy
#'   edge attributes on the raw Dynet spell ledger.
#' @param ... Ignored.
#' @return A `dynet` object carrying `legacy_source = "networkDynamic"` in
#'   its metadata.
#' @export
as_dynet.networkDynamic <- function(
    x, name_attribute = NULL, group_attribute = NULL,
    weight_attribute = "weight", session_attribute = NULL,
    interval = NULL, active_default = TRUE,
    import_edge_attributes = TRUE, ...) {
  if (!requireNamespace("network", quietly = TRUE) ||
      !requireNamespace("networkDynamic", quietly = TRUE)) {
    stop(errorCondition(
      "Importing a networkDynamic object needs the network and networkDynamic packages.",
      class = "dynet_needs_networkDynamic", call = NULL
    ))
  }
  .check(
    "`active_default` must be one non-missing logical value." =
      is.logical(active_default) && length(active_default) == 1L &&
        !is.na(active_default),
    "`import_edge_attributes` must be one non-missing logical value." =
      is.logical(import_edge_attributes) &&
        length(import_edge_attributes) == 1L &&
        !is.na(import_edge_attributes)
  )

  n <- network::network.size(x)
  vertex_attributes <- network::list.vertex.attributes(x)
  get_vertex <- function(attribute) {
    network::get.vertex.attribute(x, attribute)
  }
  valid_names <- function(attribute) {
    if (!attribute %in% vertex_attributes) return(FALSE)
    value <- get_vertex(attribute)
    length(value) == n && is.atomic(value) && is.null(dim(value)) &&
      !anyNA(value) && !anyDuplicated(as.character(value))
  }
  if (is.null(name_attribute)) {
    candidates <- c("Name", "Label", "vertex.names")
    chosen <- candidates[vapply(candidates, valid_names, logical(1L))]
    if (!length(chosen)) {
      stop(errorCondition(
        "No complete unique vertex naming attribute was found. Supply `name_attribute`.",
        class = c("dynet_missing_node_names", "dynet_bad_input"), call = NULL
      ))
    }
    name_attribute <- chosen[[1L]]
  } else if (!is.character(name_attribute) || length(name_attribute) != 1L ||
             !valid_names(name_attribute)) {
    stop(errorCondition(
      "`name_attribute` must name a complete unique atomic vertex attribute.",
      class = c("dynet_bad_node_names", "dynet_bad_input"), call = NULL
    ))
  }
  node_names <- as.character(get_vertex(name_attribute))

  internal_vertex <- c("na", "active", "vertex.names", name_attribute)
  retained_vertex <- setdiff(vertex_attributes, internal_vertex)
  retained_vertex <- retained_vertex[vapply(retained_vertex, function(attribute) {
    value <- get_vertex(attribute)
    length(value) == n && is.atomic(value) && is.null(dim(value))
  }, logical(1L))]
  nodes <- data.frame(name = node_names, stringsAsFactors = FALSE)
  for (attribute in retained_vertex) nodes[[attribute]] <- get_vertex(attribute)
  if (!is.null(group_attribute) && !group_attribute %in% names(nodes)) {
    stop(errorCondition(
      sprintf("Unknown static vertex group attribute %s.", sQuote(group_attribute)),
      class = c("dynet_unknown_attribute", "dynet_bad_input"), call = NULL
    ))
  }

  edge_spells <- networkDynamic::get.edge.activity(
    x, as.spellList = TRUE, active.default = active_default
  )
  if (!nrow(edge_spells)) {
    stop(errorCondition(
      "The networkDynamic object has no retained edge activity spells.",
      class = "dynet_empty_network", call = NULL
    ))
  }
  required <- c("onset", "terminus", "tail", "head", "edge.id")
  if (!all(required %in% names(edge_spells))) {
    stop(errorCondition(
      "The networkDynamic edge spell list is missing required columns.",
      class = c("dynet_bad_legacy_object", "dynet_bad_input"), call = NULL
    ))
  }

  edge_count <- network::network.edgecount(x)
  edge_attributes <- network::list.edge.attributes(x)
  get_edge <- function(attribute) {
    network::get.edge.attribute(x, attribute)
  }
  static_edge_attribute <- function(attribute) {
    value <- get_edge(attribute)
    is.atomic(value) && is.null(dim(value)) && length(value) == edge_count
  }
  edge_value <- function(attribute, default = NULL) {
    if (is.null(attribute)) return(default)
    if (!attribute %in% edge_attributes || !static_edge_attribute(attribute)) {
      stop(errorCondition(
        sprintf("Unknown or non-static legacy edge attribute %s.",
                sQuote(attribute)),
        class = c("dynet_unknown_attribute", "dynet_bad_input"), call = NULL
      ))
    }
    get_edge(attribute)[edge_spells$edge.id]
  }
  weights <- if (is.null(weight_attribute)) {
    rep(1, nrow(edge_spells))
  } else if (weight_attribute %in% edge_attributes &&
             static_edge_attribute(weight_attribute)) {
    edge_value(weight_attribute)
  } else {
    rep(1, nrow(edge_spells))
  }
  if (!is.numeric(weights) || anyNA(weights) || any(!is.finite(weights))) {
    stop(errorCondition(
      "The imported edge weight attribute must be finite and numeric.",
      class = c("dynet_bad_weight", "dynet_bad_input"), call = NULL
    ))
  }
  sessions <- if (is.null(session_attribute)) {
    NULL
  } else as.character(edge_value(session_attribute))

  onset_censored <- if ("onset.censored" %in% names(edge_spells)) {
    as.logical(edge_spells$onset.censored)
  } else rep(FALSE, nrow(edge_spells))
  terminus_censored <- if ("terminus.censored" %in% names(edge_spells)) {
    as.logical(edge_spells$terminus.censored)
  } else rep(FALSE, nrow(edge_spells))
  onset_censored[is.na(onset_censored)] <- FALSE
  terminus_censored[is.na(terminus_censored)] <- FALSE

  imported <- data.frame(
    from = node_names[edge_spells$tail],
    to = node_names[edge_spells$head],
    start = as.numeric(edge_spells$onset),
    end = as.numeric(edge_spells$terminus),
    weight = as.numeric(weights),
    onset_censored = onset_censored,
    terminus_censored = terminus_censored,
    stringsAsFactors = FALSE
  )
  if (!is.null(sessions)) imported$session <- sessions

  internal_edge <- c(
    "na", "active", "duration.active", "onset.censored.active",
    "terminus.censored.active", weight_attribute, session_attribute
  )
  retained_edge <- character()
  edge_attribute_renames <- stats::setNames(character(), character())
  if (import_edge_attributes) {
    retained_edge <- setdiff(edge_attributes, internal_edge)
    retained_edge <- retained_edge[vapply(retained_edge, static_edge_attribute,
                                           logical(1L))]
    reserved <- c(names(imported), "duration", ".raw_spell")
    used <- reserved
    for (attribute in retained_edge) {
      final <- attribute
      while (final %in% used) final <- paste0("edge_", final)
      imported[[final]] <- get_edge(attribute)[edge_spells$edge.id]
      if (!identical(final, attribute)) {
        edge_attribute_renames[[attribute]] <- final
      }
      used <- c(used, final)
    }
  }

  vertex_activity <- networkDynamic::get.vertex.activity(
    x, as.spellList = TRUE, active.default = FALSE
  )
  vertex_spells <- NULL
  if (nrow(vertex_activity)) {
    vertex_spells <- data.frame(
      node = node_names[vertex_activity$vertex.id],
      start = as.numeric(vertex_activity$onset),
      end = as.numeric(vertex_activity$terminus),
      onset_censored = as.logical(vertex_activity$onset.censored),
      terminus_censored = as.logical(vertex_activity$terminus.censored),
      stringsAsFactors = FALSE
    )
    vertex_spells$onset_censored[is.na(vertex_spells$onset_censored)] <- FALSE
    vertex_spells$terminus_censored[
      is.na(vertex_spells$terminus_censored)
    ] <- FALSE
  }

  observed <- network::get.network.attribute(x, "net.obs.period")
  observation_spells <- NULL
  legacy_unit <- NULL
  legacy_mode <- NULL
  legacy_increment <- NULL
  if (is.list(observed)) {
    legacy_unit <- observed$time.unit
    legacy_mode <- observed$mode
    legacy_increment <- observed$time.increment
    components <- observed$observations
    if (length(components)) {
      observation_spells <- do.call(rbind, lapply(components, function(value) {
        data.frame(start = as.numeric(value[[1L]]),
                   end = as.numeric(value[[2L]]))
      }))
    }
  }
  if (is.null(interval)) {
    interval <- if (length(legacy_increment) == 1L &&
                    is.numeric(legacy_increment) &&
                    is.finite(legacy_increment) && legacy_increment > 0) {
      as.numeric(legacy_increment)
    } else 1
  }
  .check("`interval` must be one positive finite number." =
           is.numeric(interval) && length(interval) == 1L &&
             is.finite(interval) && interval > 0)

  canonical <- c(
    "from", "to", "start", "end", "weight", "session",
    "onset_censored", "terminus_censored"
  )
  extras <- setdiff(names(imported), canonical)
  raw_for_build <- imported[, intersect(canonical, names(imported)), drop = FALSE]
  out <- dynet(
    raw_for_build, from = "from", to = "to", start = "start", end = "end",
    weight = "weight", session = if ("session" %in% names(raw_for_build)) {
      "session"
    } else NULL,
    nodes = nodes, groups = group_attribute, format = "interval",
    directed = network::is.directed(x), interval = interval,
    observation_spells = observation_spells,
    loops = any(edge_spells$tail == edge_spells$head),
    onset_censored = "onset_censored",
    terminus_censored = "terminus_censored",
    vertex_spells = vertex_spells
  )
  if (length(extras)) {
    ordering <- order(imported$start, imported$end, imported$from, imported$to)
    for (attribute in extras) out$spells[[attribute]] <- imported[[attribute]][ordering]
  }
  out$meta$source <- "networkDynamic"
  out$meta$legacy_source <- "networkDynamic"
  out$meta$legacy_name_attribute <- name_attribute
  out$meta$legacy_edge_attributes <- retained_edge
  out$meta$legacy_edge_attribute_renames <- edge_attribute_renames
  out$meta$legacy_time_unit <- legacy_unit
  out$meta$legacy_observation_mode <- legacy_mode
  out$meta$legacy_time_increment <- legacy_increment
  out$meta$call <- match.call()
  out
}

