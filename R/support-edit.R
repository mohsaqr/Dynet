# ===========================================================================
# Editing vertex activity, observation support, and sessions
# ===========================================================================

.vertex_spells_input <- function(spells) {
  keep <- c("node", "start", "end")
  if (nrow(spells) && any(!is.na(spells$session))) keep <- c(keep, "session")
  keep <- c(keep, "onset_censored", "terminus_censored")
  spells[, keep, drop = FALSE]
}

.normalize_edited_vertex_spells <- function(dn, data) {
  normalized <- .normalize_vertex_spells(
    data, dn$meta$origin, dn$meta$time_unit, dn$meta$sessions
  )
  unknown <- setdiff(unique(normalized$spells$node), dn$nodes$name)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown vertex-activity node(s): %s.",
              paste(sort(unknown), collapse = ", ")),
      class = c("dynet_unknown_node", "dynet_bad_input"), call = NULL
    ))
  }
  normalized$spells
}

#' Each vertex's span from its first tie to its last
#' @param dn A temporal network.
#' @return A data frame with `node`, `start` (the earliest start among the
#'   vertex's tie spells) and `end` (the latest end), one row per vertex that
#'   has a tie. A `dynet` object is never edgeless, so every vertex has one.
#' @noRd
.tie_spans <- function(dn) {
  spells <- dn$spells
  node <- c(spells$from, spells$to)
  first <- tapply(rep(spells$start, 2L), node, min)
  last <- tapply(rep(spells$end, 2L), node, max)
  data.frame(node = names(first), start = as.numeric(first),
             end = as.numeric(last[names(first)]), stringsAsFactors = FALSE)
}

#' Replace declared vertex activity
#'
#' @param dn A temporal network.
#' @param data A vertex-spell data frame with `node`, `start`, and `end`, plus
#'   optional `session`, `onset_censored`, and `terminus_censored`; or the
#'   string `"ties"`, which declares each vertex present from the start of
#'   its first tie spell to the end of its last, so that a vertex is absent
#'   before it has had a tie and after it has had its last. Default
#'   `NULL`, which clears explicit activity, making every retained node
#'   implicitly active over observation support.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, whose declared vertex
#'   activity is exactly `data` and whose edge spells, node attributes and
#'   metadata are those of `dn`. Overlapping or adjacent spells are
#'   canonicalised exactly as in [dynet()], so canonical spell identifiers may
#'   change. Read the result back with
#'   `as.data.frame(x, what = "vertex_spells")`. Raises `dynet_unknown_node`
#'   when `data` names a vertex the network does not have, and
#'   `dynet_bad_input` for a string other than `"ties"`.
#' @examples
#' dn <- dynet(school_contacts)
#' present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
#' enrolled <- set_vertex_spells(dn, present)
#' as.data.frame(enrolled, what = "vertex_spells")
#'
#' # Present from the first contact to the last, vertex by vertex.
#' spanned <- set_vertex_spells(dn, "ties")
#' as.data.frame(spanned, what = "vertex_spells")
#' @export
set_vertex_spells <- function(dn, data = NULL) {
  .check_dynet(dn, "bounded")
  if (is.character(data)) {
    if (!identical(data, "ties")) {
      stop(errorCondition(
        "`data` must be a vertex-spell data frame, NULL, or the string \"ties\".",
        class = "dynet_bad_input", call = NULL))
    }
    data <- .tie_spans(dn)
  }
  vertex_spells <- if (is.null(data)) .empty_vertex_spells() else
    .normalize_edited_vertex_spells(dn, data)
  .rebuild_ties(
    dn, dn$spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

#' Add declared vertex-activity spells
#' @param dn A temporal network.
#' @param data A nonempty vertex-spell data frame with `node`, `start`, and
#'   `end`, plus optional `session`, `onset_censored`, and
#'   `terminus_censored`. Unlike [set_vertex_spells()] this argument is
#'   required; `NULL` is an error.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, with the network's existing
#'   activity and `data` canonicalised together, so an added spell that
#'   overlaps or abuts an existing one for the same vertex is merged into it
#'   and canonical spell identifiers may change. Raises `dynet_unknown_node`
#'   for a vertex the network does not have, and `dynet_bad_input` when `data`
#'   is not a nonempty data frame.
#' @examples
#' dn <- dynet(school_contacts)
#' present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
#' enrolled <- set_vertex_spells(dn, present)
#' extended <- add_vertex_spells(enrolled,
#'                               data.frame(node = "Cara", start = 5, end = 20))
#' as.data.frame(extended, what = "vertex_spells")
#' @export
add_vertex_spells <- function(dn, data) {
  .check_dynet(dn, "bounded")
  if (!is.data.frame(data) || !nrow(data)) {
    stop(errorCondition("`data` must be a nonempty vertex-spell data frame.",
                        class = "dynet_bad_input", call = NULL))
  }
  existing <- .vertex_spells_input(dn$vertex_spells)
  # Reconcile optional columns before binding; the normalizer supplies false
  # censor flags and a global session when they are absent.
  canonical <- c("node", "start", "end", "session",
                 "onset_censored", "terminus_censored")
  bind_vertex <- function(x, prototype) {
    missing <- setdiff(canonical, names(x))
    for (name in missing) {
      x[[name]] <- if (identical(name, "session")) {
        rep(NA_character_, nrow(x))
      } else if (name %in% c("onset_censored", "terminus_censored")) {
        rep(FALSE, nrow(x))
      } else prototype[[name]][rep(NA_integer_, nrow(x))]
    }
    x[canonical]
  }
  existing <- bind_vertex(existing, data)
  added <- bind_vertex(data, existing)
  combined <- rbind(existing, added)
  if (is.null(dn$meta$sessions)) combined$session <- NULL
  set_vertex_spells(dn, combined)
}

#' Remove declared vertex-activity components
#'
#' @param dn A temporal network.
#' @param spells Integer positions or a logical mask over
#'   `as.data.frame(dn, what = "vertex_spells")`. A logical mask must have one
#'   element per declared component and no `NA`.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, with the selected activity
#'   components dropped and the rest canonicalised again, so the remaining
#'   spell identifiers renumber. A node with no remaining declaration becomes
#'   implicitly always active over observation support. Raises
#'   `dynet_bad_input` when `spells` is not a valid selection.
#' @examples
#' dn <- dynet(school_contacts)
#' present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
#' enrolled <- set_vertex_spells(dn, present)
#' trimmed <- remove_vertex_spells(enrolled, spells = 1)
#' as.data.frame(trimmed, what = "vertex_spells")
#' @export
remove_vertex_spells <- function(dn, spells) {
  .check_dynet(dn, "bounded")
  index <- .edit_row_selector(spells, nrow(dn$vertex_spells), "spells")
  kept <- dn$vertex_spells[-index, , drop = FALSE]
  set_vertex_spells(
    dn, if (nrow(kept)) .vertex_spells_input(kept) else NULL
  )
}

#' Update declared vertex-activity components
#'
#' @param dn A temporal network.
#' @param spells Integer positions or a logical mask over canonical vertex
#'   activity, as returned by `as.data.frame(dn, what = "vertex_spells")`.
#' @param data A data frame with one row, or one row per selected component,
#'   containing the fields to replace: `node`, `start`, `end`, `session`,
#'   `onset_censored` or `terminus_censored`.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`. Updated components are
#'   canonicalised with the retained components, so overlaps can merge and
#'   spell identifiers can change. Raises `dynet_bad_input` when `spells` is
#'   not a valid selection, when `data` is malformed or of the wrong height,
#'   or when it names the read-only derived columns `vertex_spell`,
#'   `duration` or `instant`.
#' @examples
#' dn <- dynet(school_contacts)
#' present <- data.frame(node = c("Ana", "Ben"), start = 0, end = 10)
#' enrolled <- set_vertex_spells(dn, present)
#' extended <- update_vertex_spells(enrolled, spells = 1,
#'                                  data = data.frame(end = 12))
#' as.data.frame(extended, what = "vertex_spells")
#' @export
update_vertex_spells <- function(dn, spells, data) {
  .check_dynet(dn, "bounded")
  index <- .edit_row_selector(spells, nrow(dn$vertex_spells), "spells")
  if (!is.data.frame(data) || !nrow(data) || !ncol(data) ||
      anyDuplicated(names(data))) {
    stop(errorCondition("`data` must be a nonempty update data frame.",
                        class = "dynet_bad_input", call = NULL))
  }
  if (any(names(data) %in% c("vertex_spell", "duration", "instant"))) {
    stop(errorCondition(
      "`vertex_spell`, `duration`, and `instant` are derived and read-only.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (nrow(data) != 1L && nrow(data) != length(index)) {
    stop(errorCondition(
      "`data` must have one row or one row per selected component.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (nrow(data) == 1L && length(index) > 1L) {
    data <- data[rep(1L, length(index)), , drop = FALSE]
  }
  current <- .vertex_spells_input(dn$vertex_spells)
  for (attribute in names(data)) current[[attribute]][index] <- data[[attribute]]
  set_vertex_spells(dn, current)
}

.set_observation_meta <- function(dn, observations, call) {
  meta <- dn$meta
  meta$event_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
  meta$observations <- observations
  meta$time_range <- c(start = min(observations$start), end = max(observations$end))
  meta$observation <- meta$time_range
  meta$observation_explicit <- TRUE
  meta$observation_interval <- "positive_half_open_instant_closed"
  meta$observation_clipping <- "non_destructive_measurement_view"
  meta$boundary_events <- "raw_not_fabricated"
  meta$censoring <- "not_inferred"
  meta$observation_duration <- sum(observations$duration)
  meta$observation_spells_explicit <- TRUE
  meta$observation_gap_waiting <- "allowed"
  meta$latency_clock <- "calendar"
  meta$n_bins <- sum(pmax(
    1L, as.integer(ceiling(observations$duration / meta$interval - 1e-9))
  ))
  meta$call <- call
  out <- dn
  out$meta <- meta
  out
}

#' Replace observation support
#'
#' @param dn A temporal network.
#' @param data Optional data frame with `start` and `end` observation
#'   components. Overlapping and adjacent positive components are merged.
#'   Default `NULL`.
#' @param start,end Optional scalar continuous bounds used instead of `data`,
#'   each defaulting to `NULL`. Supply exactly one of `data` or the
#'   `start`/`end` pair; supplying both, or neither, is an error.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`. Raw edge and vertex spells
#'   are unchanged -- `as.data.frame(x)` still returns the originals -- and
#'   only the non-destructive measurement view is replaced, so every verb now
#'   clips exposure and path horizons to this support. Read the components
#'   back with `as.data.frame(x, what = "observations")`, one row per
#'   component with `observation`, `start`, `end`, `duration` and `instant`.
#'   Raises `dynet_bad_input` when neither or both of `data` and the bounds
#'   are given.
#' @examples
#' dn <- dynet(school_contacts)
#' first_week <- set_observations(dn, start = 0, end = 7)
#' as.data.frame(first_week, what = "observations")
#' @export
set_observations <- function(dn, data = NULL, start = NULL, end = NULL) {
  .check_dynet(dn, "bounded")
  use_data <- !is.null(data)
  use_bounds <- !is.null(start) || !is.null(end)
  if (use_data == use_bounds) {
    stop(errorCondition(
      "Supply either `data` or scalar `start`/`end` bounds.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  observations <- if (use_data) {
    .normalize_observation_spells(data, dn$meta$origin, dn$meta$time_unit)
  } else {
    raw_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
    bounds <- .observation_bounds(
      raw_range, dn$meta$origin, dn$meta$time_unit, start, end
    )
    data.frame(
      observation = 1L, start = bounds[["start"]], end = bounds[["end"]],
      duration = bounds[["end"]] - bounds[["start"]],
      instant = bounds[["start"]] == bounds[["end"]]
    )
  }
  .set_observation_meta(dn, observations, match.call())
}

#' Restore implicit observation support
#'
#' @param dn A temporal network.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, observed continuously from
#'   its earliest raw start through its latest raw end. Every explicit
#'   observation field is dropped from the metadata and the bin count is
#'   recomputed over the raw range; spells and attributes are untouched. Safe
#'   on a network that never had explicit observations, which is returned with
#'   only its recorded call changed.
#' @examples
#' dn <- dynet(school_contacts)
#' first_week <- set_observations(dn, start = 0, end = 7)
#' restored <- clear_observations(first_week)
#' restored
#' @export
clear_observations <- function(dn) {
  .check_dynet(dn, "bounded")
  meta <- dn$meta
  raw_range <- c(start = min(dn$spells$start), end = max(dn$spells$end))
  fields <- c(
    "event_range", "observation", "observation_explicit",
    "observation_interval", "observation_clipping", "boundary_events",
    "censoring", "observations", "observation_duration",
    "observation_spells_explicit", "observation_gap_waiting", "latency_clock"
  )
  meta[fields] <- NULL
  meta$time_range <- raw_range
  meta$n_bins <- max(1L, as.integer(ceiling(
    (raw_range[["end"]] - raw_range[["start"]]) / meta$interval
  )))
  meta$call <- match.call()
  out <- dn
  out$meta <- meta
  out
}

#' Assign or remove tie sessions
#'
#' @param dn A temporal network.
#' @param session A complete, nonempty character vector of length one or the
#'   raw tie count; a length-one value labels every spell. Default `NULL`,
#'   which removes all tie-session walls and erases session labels on vertex
#'   activity.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, with a `session` column on
#'   the spell table and the session scheme recorded in its metadata, or with
#'   both removed when `session = NULL`. Raises `dynet_bad_input` when
#'   `session` has neither length one nor the raw tie count, or carries `NA`
#'   or blank labels.
#' @examples
#' dn <- dynet(school_contacts)
#' weeks <- with(school_contacts, ifelse(start < 7, "week_1", "later"))
#' labelled <- set_tie_sessions(dn, session = weeks)
#' labelled
#' @export
set_tie_sessions <- function(dn, session = NULL) {
  .check_dynet(dn, "bounded")
  n <- nrow(dn$spells)
  if (is.null(session)) {
    value <- rep(NA_character_, n)
  } else {
    if (!is.atomic(session) || is.null(dim(session)) == FALSE ||
        !length(session) || !(length(session) %in% c(1L, n))) {
      stop(errorCondition(
        "`session` must have length one or the raw tie count.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    value <- rep(as.character(session), length.out = n)
    if (anyNA(value) || any(!nzchar(trimws(value)))) {
      stop(errorCondition("Session labels must be complete and nonempty.",
                          class = "dynet_bad_input", call = NULL))
    }
  }
  spells <- dn$spells
  spells$session <- value
  vertex_spells <- dn$vertex_spells
  if (is.null(session) && nrow(vertex_spells)) {
    vertex_spells$session <- NA_character_
  }
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

#' Rename session walls
#'
#' @param dn A sessioned temporal network.
#' @param mapping A named character vector from old to new labels, or an
#'   `old`/`new` data frame.
#' @return A new `dynet` object, class
#'   `c("dynet", "netobject", "cograph_network")`, with edge and vertex
#'   session labels renamed together and the session scheme in its metadata
#'   updated. Labels absent from `mapping` are left alone. Raises
#'   `dynet_unknown_session` when an old label is not a session, and
#'   `dynet_bad_input` when the network has no session scheme, when `mapping`
#'   is malformed, or when the renaming would produce duplicate labels.
#' @examples
#' dn <- dynet(school_contacts)
#' weeks <- with(school_contacts, ifelse(start < 7, "week_1", "later"))
#' labelled <- set_tie_sessions(dn, session = weeks)
#' renamed <- rename_sessions(labelled, c(week_1 = "opening"))
#' renamed
#' @export
rename_sessions <- function(dn, mapping) {
  .check_dynet(dn, "bounded")
  if (is.null(dn$meta$sessions)) {
    stop(errorCondition("This temporal network has no session scheme.",
                        class = "dynet_bad_input", call = NULL))
  }
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
      any(!nzchar(trimws(new)))) {
    stop(errorCondition("Session rename mappings must be complete and unique.",
                        class = "dynet_bad_input", call = NULL))
  }
  unknown <- setdiff(old, dn$meta$sessions)
  if (length(unknown)) {
    stop(errorCondition(
      sprintf("Unknown session label(s): %s.", paste(unknown, collapse = ", ")),
      class = c("dynet_unknown_session", "dynet_bad_input"), call = NULL
    ))
  }
  unaffected <- setdiff(dn$meta$sessions, old)
  if (anyDuplicated(c(unaffected, new))) {
    stop(errorCondition("Session renaming would create duplicate labels.",
                        class = "dynet_bad_input", call = NULL))
  }
  translate <- function(value) {
    hit <- match(value, old)
    value[!is.na(hit)] <- new[hit[!is.na(hit)]]
    value
  }
  spells <- dn$spells
  spells$session <- translate(spells$session)
  vertex_spells <- dn$vertex_spells
  vertex_spells$session <- translate(vertex_spells$session)
  .rebuild_ties(
    dn, spells, identical(dn$meta$raw_censoring, "explicit"),
    match.call(), vertex_spells = vertex_spells
  )
}

