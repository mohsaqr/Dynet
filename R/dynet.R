# ===========================================================================
# dynet() — temporal network construction
# ===========================================================================

#' Build a temporal network
#'
#' @description
#' Builds a temporal network from a relational log. One constructor covers the
#' four shapes relational data actually arrives in, and the shape is inferred
#' from the arguments you name:
#'
#' \describe{
#'   \item{interval}{Each row is an edge active over `[start, end)`. Used when
#'     the data carry an end time or a duration.}
#'   \item{contact}{Each row is an instantaneous event with a time and no
#'     duration -- a message, a click, a citation.}
#'   \item{threaded}{Forum, chat or email data. An edge is treated as active
#'     from its own post until the last post in the same thread, following
#'     Saqr and Nouri (2020). Name the `thread` argument to select this.}
#'   \item{copresence}{Two-mode attendance data. Actors sharing a group become
#'     connected for the span of that group. Name `actor` and `group`.}
#' }
#'
#' Column names are resolved case-insensitively from a table of aliases, so
#' `Sender`/`Receiver`, `source`/`target` and `onset`/`terminus` are all
#' understood without being spelled out. Times may be numeric, `Date`,
#' `POSIXct` or character date-time strings; character and date-time input is
#' converted to elapsed time since the first event in a readable unit.
#'
#' Vertices are addressed by name everywhere in this package. Integer vertex
#' indices are used internally for speed but are never part of any result.
#'
#' Explicit observation bounds are administrative measurement limits, not a
#' destructive filter. A positive spell `[s,e)` contributes the half-open
#' intersection `[max(s,L),min(e,U))` when it has positive duration, while a
#' genuine instantaneous event is retained at either `L` or `U`. Original
#' endpoints remain the only formation and dissolution events, censoring is
#' never inferred from equality with a limit, and temporal paths must both
#' start and finish inside the declared interval.
#'
#' Vertex activity is a separate declaration. A vertex with at least one row
#' in `vertex_spells` is eligible only on the union of those half-open positive
#' spells and exact points; a vertex with no row remains eligible at all times.
#' Snapshot measurements independently union eligible vertices and active
#' edges over each positive window and then induce on eligible endpoints;
#' point snapshots evaluate both at the exact time. Explicit vertex censor
#' flags describe raw outer-boundary state and are never inferred from
#' observation limits or used to alter eligibility.
#'
#' @param data Data frame holding one relational event per row.
#' @param from,to Column names for the source and target vertex. Auto-detected
#'   from `from`/`to`, `source`/`target`, `sender`/`receiver`, `tail`/`head`,
#'   `ego`/`alter`.
#' @param start,end Column names for the start and end of an edge spell.
#'   Auto-detected from `start`/`end`, `onset`/`terminus`, `begin`/`finish`.
#' @param duration Column name for a spell duration, used in place of `end`.
#' @param time Column name for an event time, used in place of `start`.
#'   Auto-detected from `time`, `timestamp`, `date`, `datetime`.
#' @param thread Column name identifying a conversation thread. Naming it
#'   selects the threaded format.
#' @param actor,group Column names for the actor and the shared group. Naming
#'   both selects the co-presence format.
#' @param session Column name for a session or period grouping. Sessions act
#'   as walls that time-respecting paths do not cross.
#' @param weight Column name for event multiplicity. Defaults to one event per
#'   row.
#' @param nodes Optional data frame of vertex attributes. The vertex key is
#'   auto-detected, or given as the first column.
#' @param groups Name of a column in `nodes` to use as the vertex partition.
#'   Written into the places cograph looks for it, so `cograph::splot()`
#'   colours and groups by it without further argument.
#' @param format One of `"auto"`, `"interval"`, `"contact"`, `"threaded"`,
#'   `"copresence"`. `"auto"` infers the format from the arguments you name
#'   and the columns present.
#' @param directed Whether edges are directed. Co-presence networks are always
#'   undirected.
#' @param interval Width of one time bin, in the network's time unit.
#' @param time_unit Unit for converting `Date`/`POSIXct`/character times:
#'   `"auto"`, `"seconds"`, `"minutes"`, `"hours"`, `"days"` or `"weeks"`.
#'   Numeric times are left alone and reported as `"step"`.
#' @param observation_start,observation_end Optional bounds of the continuous
#'   observation interval. Supply numeric values in the network's internal
#'   time scale, or `Date`/`POSIXct` values for a calendar network. Either
#'   bound may be omitted, in which case the corresponding raw event limit is
#'   used. Positive spells are measured on their half-open intersection with
#'   this interval; instantaneous events are retained at either boundary.
#'   Raw spell endpoints returned by [as.data.frame()] are never changed.
#' @param observation_spells Optional data frame with `start` and `end` columns
#'   defining discontinuous observed support. Overlapping and adjacent positive
#'   intervals are merged; isolated points are retained. This is mutually
#'   exclusive with `observation_start` and `observation_end`.
#' @param loops Whether to keep self-loops. `FALSE` drops them with a message,
#'   which is almost always what relational logs need.
#' @param onset_censored,terminus_censored Optional logical column names for
#'   explicit raw interval-boundary censor state. These selectors are available
#'   only for interval input, are never auto-detected, and may not flag a
#'   zero-duration point.
#' @param vertex_spells Optional tidy vertex-activity table with exact columns
#'   `node`, `start`, and `end`, plus optional `session`, `onset_censored`, and
#'   `terminus_censored`. Positive spells use `[start,end)` and points are exact.
#'   Overlapping and adjacent positive spells are unioned independently by node
#'   and session. A vertex absent from this table remains active at all times.
#'
#' @return An object of class `c("dynet", "netobject", "cograph_network")`.
#'   It is a cograph network, so `cograph::splot()` draws it directly and
#'   every cograph rendering argument applies. Use [as.data.frame()] for the
#'   tidy spell table, `as.data.frame(x, what = "nodes")` for the vertex
#'   table, `as.data.frame(x, what = "network")` for the aggregate edge list,
#'   [summary()] for the description and [plot()] for a picture. Nothing in
#'   this package requires you to reach into the object.
#'
#' @references
#' Saqr, M., & Nouri, J. (2020). High resolution temporal network analysis to
#' understand and improve collaborative learning. *Proceedings of the Tenth
#' International Conference on Learning Analytics & Knowledge*, 314-319.
#'
#' Holme, P., & Saramaki, J. (2012). Temporal networks. *Physics Reports*,
#' 519(3), 97-125.
#'
#' Butts, C. T. (2008). network: a package for managing relational data in R.
#' *Journal of Statistical Software*, 24(2), 1-36.
#'
#' @examples
#' # An interval log: each row carries its own start and end
#' dynet(school_contacts)
#'
#' # A threaded log: edge stays active until its thread falls silent
#' dynet(forum_posts, thread = "thread")
#'
#' # A co-presence log: actors sharing a group become connected
#' dynet(seminar_attendance, actor = "student", group = "seminar")
#'
#' # Declare observation time without rewriting the source spell.
#' bounded <- dynet(data.frame(
#'   from = "A", to = "B", start = -2, end = 8
#' ), observation_start = 0, observation_end = 5)
#' as.data.frame(bounded)
#'
#' # Declare changing vertex eligibility without altering edge spells.
#' scheduled <- dynet(data.frame(
#'   from = "A", to = "B", start = 0, end = 10
#' ), vertex_spells = data.frame(
#'   node = c("A", "A"), start = c(0, 7), end = c(4, 10)
#' ))
#' as.data.frame(scheduled, what = "vertex_spells")
#'
#' @export
dynet <- function(data,
                  from = NULL, to = NULL,
                  start = NULL, end = NULL, duration = NULL, time = NULL,
                  thread = NULL, actor = NULL, group = NULL,
                  session = NULL, weight = NULL, nodes = NULL, groups = NULL,
                  format = c("auto", "interval", "contact", "threaded",
                             "copresence"),
                  directed = TRUE, interval = 1, time_unit = "auto",
                  observation_start = NULL, observation_end = NULL,
                  observation_spells = NULL,
                  loops = FALSE,
                  onset_censored = NULL, terminus_censored = NULL,
                  vertex_spells = NULL) {

  format <- match.arg(format)
  observation_conflict <- !is.null(observation_spells) &&
    (!is.null(observation_start) || !is.null(observation_end))
  if (observation_conflict) {
    stop(errorCondition(
      "`observation_spells` is mutually exclusive with scalar observation bounds.",
      class = c("dynet_conflicting_observation", "dynet_bad_input"), call = NULL
    ))
  }
  .check(
    "`data` must be a data frame."                          = is.data.frame(data),
    "`data` must have at least one row."                    = nrow(data) > 0L,
    "`directed` must be a single TRUE or FALSE."            =
      is.logical(directed) && length(directed) == 1L && !is.na(directed),
    "`loops` must be a single TRUE or FALSE."               =
      is.logical(loops) && length(loops) == 1L && !is.na(loops),
    "`interval` must be a single positive number."          =
      is.numeric(interval) && length(interval) == 1L && is.finite(interval) &&
      interval > 0,
    "`time_unit` must be one of auto, seconds, minutes, hours, days, weeks." =
      is.character(time_unit) && length(time_unit) == 1L &&
      time_unit %in% c("auto", "seconds", "minutes", "hours", "days", "weeks")
  )

  format <- .infer_format(data, format, thread = thread, actor = actor,
                          group = group, end = end, duration = duration)
  censor_explicit <- !is.null(onset_censored) || !is.null(terminus_censored)
  if (censor_explicit && !identical(format, "interval")) {
    stop(errorCondition(
      "Explicit censor columns are available only for interval-format input.",
      class = c("dynet_incompatible_censor", "dynet_bad_input"), call = NULL
    ))
  }

  built <- switch(format,
    copresence = .build_copresence(data, actor, group, time, start, end,
                                   session, time_unit),
    threaded   = .build_threaded(data, from, to, time, thread, session,
                                 time_unit),
    contact    = .build_contact(data, from, to, time, session, time_unit),
    interval   = .build_interval(data, from, to, start, end, duration, session,
                                 time_unit)
  )

  if (identical(format, "copresence") && directed) directed <- FALSE

  e <- built$edges
  e$weight <- .resolve_weight(data, weight, built$row_index, nrow(e))
  e$onset_censored <- .resolve_censor_flag(
    data, onset_censored, built$row_index, nrow(e), "onset_censored"
  )
  e$terminus_censored <- .resolve_censor_flag(
    data, terminus_censored, built$row_index, nrow(e), "terminus_censored"
  )
  flagged_point <- e$end == e$start &
    (e$onset_censored | e$terminus_censored)
  if (any(flagged_point)) {
    stop(errorCondition(
      "A zero-duration point cannot carry an onset or terminus censor flag.",
      class = c("dynet_bad_censor", "dynet_bad_input"), call = NULL
    ))
  }

  # Self-loops carry no relational information in a temporal log; drop unless
  # the caller insists.
  is_loop <- e$from == e$to
  if (any(is_loop)) {
    if (loops) {
      message(sprintf("Keeping %d self-loop event(s); they are excluded from degree.",
                      sum(is_loop)))
    } else {
      message(sprintf("Dropped %d self-loop event(s). Use loops = TRUE to keep them.",
                      sum(is_loop)))
      e <- e[!is_loop, , drop = FALSE]
    }
  }
  if (nrow(e) == 0L) {
    stop(errorCondition("No edge events remain after cleaning.",
                        class = "dynet_empty_network", call = NULL))
  }

  # This identifier belongs to the raw canonical row and survives sorting and
  # observation fragmentation. It is intentionally absent from the raw public
  # accessor, whose one-row-per-input-derived-spell contract is unchanged.
  e$.raw_spell <- seq_len(nrow(e))

  e <- e[order(e$start, e$end, e$from, e$to), , drop = FALSE]
  rownames(e) <- NULL

  edge_sessions <- if (all(is.na(e$session))) NULL else sort(unique(e$session))
  vertex_activity <- .normalize_vertex_spells(
    vertex_spells, built$origin, built$time_unit, edge_sessions
  )
  node_table <- .build_nodes(
    e, nodes, c(built$node_pool, vertex_activity$spells$node)
  )

  # Undirected spells are stored once, with endpoints in a canonical order, so
  # that A-B and B-A are the same edge.
  if (!directed) {
    lo <- pmin(e$from, e$to)
    hi <- pmax(e$from, e$to)
    e$from <- lo
    e$to   <- hi
  }

  t_min <- min(e$start)
  t_max <- max(e$end)

  observation_explicit <- !is.null(observation_start) ||
    !is.null(observation_end) || !is.null(observation_spells)
  raw_range <- c(start = t_min, end = t_max)
  observations <- if (!is.null(observation_spells)) {
    .normalize_observation_spells(
      observation_spells, built$origin, built$time_unit
    )
  } else NULL
  observation <- if (!is.null(observations)) {
    c(start = min(observations$start), end = max(observations$end))
  } else if (observation_explicit) {
    .observation_bounds(
      raw_range, built$origin, built$time_unit,
      observation_start, observation_end
    )
  } else {
    raw_range
  }

  metadata <- list(
    type       = "temporal",
    source     = "dynet",
    format     = format,
    time_range = observation,
    time_unit  = built$time_unit,
    origin     = built$origin,
    interval   = interval,
    n_bins     = max(1L, as.integer(ceiling(
      (observation[["end"]] - observation[["start"]]) / interval
    ))),
    sessions   = if (all(is.na(e$session))) NULL else sort(unique(e$session)),
    call       = match.call()
  )
  if (observation_explicit) {
    metadata$event_range <- raw_range
    metadata$observation <- observation
    metadata$observation_explicit <- TRUE
    metadata$observation_interval <- "positive_half_open_instant_closed"
    metadata$observation_clipping <- "non_destructive_measurement_view"
    metadata$boundary_events <- "raw_not_fabricated"
    metadata$censoring <- "not_inferred"
  }
  if (!is.null(observations)) {
    metadata$observations <- observations
    metadata$observation_duration <- sum(observations$duration)
    metadata$observation_spells_explicit <- TRUE
    metadata$observation_gap_waiting <- "allowed"
    metadata$latency_clock <- "calendar"
    metadata$n_bins <- sum(pmax(
      1L, as.integer(ceiling(observations$duration / interval - 1e-9))
    ))
  }
  metadata$raw_censoring <- if (censor_explicit) "explicit" else "none"
  if (censor_explicit) {
    metadata$raw_censoring_columns <- list(
      onset = onset_censored, terminus = terminus_censored
    )
    metadata$n_onset_censored <- sum(e$onset_censored)
    metadata$n_terminus_censored <- sum(e$terminus_censored)
    metadata$n_both_censored <- sum(
      e$onset_censored & e$terminus_censored
    )
  }
  metadata$vertex_activity <- if (nrow(vertex_activity$spells)) {
    "explicit"
  } else "static"
  metadata$vertex_activity_supplied <- !is.null(vertex_spells)
  metadata$vertex_activity_default <- "always_for_unlisted_nodes"
  metadata$vertex_activity_interval <- "positive_half_open_instant_closed"
  metadata$vertex_activity_scope <- vertex_activity$scope
  metadata$vertex_activity_input_rows <- vertex_activity$input_rows
  metadata$vertex_activity_components <- nrow(vertex_activity$spells)
  metadata$n_dynamic_vertices <- length(unique(vertex_activity$spells$node))
  metadata$n_implicit_static_vertices <- nrow(node_table) -
    metadata$n_dynamic_vertices
  metadata$vertex_sessions <- vertex_activity$sessions
  metadata$vertex_censoring <- if (vertex_activity$censor_explicit) {
    "explicit_not_inferred"
  } else "none"
  metadata$n_vertex_onset_censored <- vertex_activity$n_onset_censored
  metadata$n_vertex_terminus_censored <- vertex_activity$n_terminus_censored
  metadata$vertex_observation_clipping <- "derived_non_destructive"
  metadata$edge_vertex_activity_policy <-
    "snapshot_induced_v02_paths_endpoint_gated_v03"
  metadata$snapshot_vertex_population <- "eligible_window_any_induced"
  metadata$snapshot_inactive_vertex_value <- "NA"
  metadata$temporal_risk_population <- "eligible_at_time"
  metadata$temporal_risk_integration <- "exact_change_point"
  metadata$temporal_risk_session_aggregation <-
    "calendar_union_after_session_erasure"

  .as_netobject(
    spells   = e,
    nodes    = node_table,
    directed = directed,
    groups   = groups,
    meta = metadata,
    vertex_spells = vertex_activity$spells
  )
}

#' Resolve one explicit raw censor flag
#' @param data Source data frame.
#' @param column Optional selected column.
#' @param row_index Mapping from canonical rows to source rows.
#' @param n Number of canonical rows.
#' @param arg Public selector name.
#' @return A strict logical vector.
#' @keywords internal
.resolve_censor_flag <- function(data, column, row_index, n, arg) {
  if (is.null(column)) return(rep(FALSE, n))
  resolved <- .resolve_column(data, column, role = "", arg = arg)
  values <- data[[resolved]]
  if (!is.logical(values) || !is.null(dim(values)) ||
      length(values) != nrow(data) || anyNA(values)) {
    stop(errorCondition(
      sprintf("`%s` must select a logical column without missing values.", arg),
      class = c("dynet_bad_censor", "dynet_bad_input"), call = NULL
    ))
  }
  if (is.null(row_index)) {
    stop(errorCondition(
      "Explicit censor flags require a one-to-one source spell mapping.",
      class = c("dynet_incompatible_censor", "dynet_bad_input"), call = NULL
    ))
  }
  values[row_index]
}

#' Typed canonical vertex-spell table
#' @return A zero-row data frame with the public vertex-spell schema.
#' @keywords internal
.empty_vertex_spells <- function() {
  data.frame(
    vertex_spell = integer(), node = character(), start = numeric(),
    end = numeric(), duration = numeric(), instant = logical(),
    session = character(), onset_censored = logical(),
    terminus_censored = logical(), stringsAsFactors = FALSE
  )
}

#' Normalize declared vertex activity
#'
#' @param vertex_spells Optional fixed-schema vertex activity table.
#' @param origin,time_unit The already resolved edge clock.
#' @param edge_sessions Existing canonical edge-session labels, or `NULL`.
#' @return A list containing canonical spells and construction metadata.
#' @keywords internal
.normalize_vertex_spells <- function(vertex_spells, origin, time_unit,
                                     edge_sessions = NULL) {
  fail <- function(message, subclass = "dynet_bad_vertex_spells") {
    stop(errorCondition(
      message, class = c(subclass, "dynet_bad_vertex_spells",
                         "dynet_bad_input"), call = NULL
    ))
  }
  if (is.null(vertex_spells)) {
    return(list(
      spells = .empty_vertex_spells(), input_rows = 0L, scope = "none",
      sessions = NULL, censor_explicit = FALSE,
      n_onset_censored = 0L, n_terminus_censored = 0L
    ))
  }
  if (!is.data.frame(vertex_spells)) {
    fail("`vertex_spells` must be a data frame.")
  }
  if (anyDuplicated(names(vertex_spells))) {
    fail("`vertex_spells` column names must be unique.")
  }
  required <- c("node", "start", "end")
  optional <- c("session", "onset_censored", "terminus_censored")
  missing <- setdiff(required, names(vertex_spells))
  if (length(missing)) {
    fail(sprintf(
      "`vertex_spells` is missing required column(s): %s.",
      paste(missing, collapse = ", ")
    ), "dynet_missing_column")
  }
  extra <- setdiff(names(vertex_spells), c(required, optional))
  if (length(extra)) {
    fail(sprintf(
      "`vertex_spells` has unsupported column(s): %s.",
      paste(extra, collapse = ", ")
    ))
  }
  n <- nrow(vertex_spells)
  vector_column <- function(values) {
    is.atomic(values) && is.null(dim(values)) && length(values) == n
  }
  if (!vector_column(vertex_spells$node)) {
    fail("`vertex_spells$node` must be an atomic vector.")
  }
  node <- as.character(vertex_spells$node)
  if (anyNA(node) || any(!nzchar(trimws(node)))) {
    fail("`vertex_spells$node` must contain complete, nonempty names.")
  }

  prototype <- list(meta = list(origin = origin, time_unit = time_unit))
  convert_time <- function(values, field) {
    valid_type <- is.numeric(values) || inherits(values, "Date") ||
      inherits(values, "POSIXt")
    if (!vector_column(values) || !valid_type) {
      fail(sprintf(
        "`vertex_spells$%s` must use the network's numeric or calendar clock.",
        field
      ))
    }
    if (!length(values)) return(numeric())
    tryCatch(
      vapply(seq_along(values), function(i) {
        .as_time(values[i], prototype, paste0("vertex_spells$", field))
      }, numeric(1L)),
      error = function(e) fail(conditionMessage(e))
    )
  }
  start <- convert_time(vertex_spells$start, "start")
  end <- convert_time(vertex_spells$end, "end")
  if (any(!is.finite(start)) || any(!is.finite(end))) {
    fail("Vertex-spell times must be finite.")
  }
  if (any(end < start)) {
    fail("Every vertex spell must end at or after it starts.")
  }

  has_session <- "session" %in% names(vertex_spells)
  session <- rep(NA_character_, n)
  if (has_session) {
    if (n > 0L && is.null(edge_sessions)) {
      fail(
        "A vertex-spell session column requires an edge-session column.",
        "dynet_incompatible_vertex_spells"
      )
    }
    if (!vector_column(vertex_spells$session)) {
      fail("`vertex_spells$session` must be an atomic vector.")
    }
    session <- as.character(vertex_spells$session)
    if (anyNA(session) || any(!nzchar(trimws(session)))) {
      fail("`vertex_spells$session` must contain complete, nonempty labels.")
    }
    unknown <- setdiff(unique(session), edge_sessions)
    if (length(unknown)) {
      fail(sprintf(
        "Unknown vertex-spell session label(s): %s.",
        paste(sort(unknown), collapse = ", ")
      ), "dynet_unknown_session")
    }
  }

  resolve_flag <- function(field) {
    if (!field %in% names(vertex_spells)) return(rep(FALSE, n))
    value <- vertex_spells[[field]]
    if (!is.logical(value) || !vector_column(value) || anyNA(value)) {
      fail(sprintf(
        "`vertex_spells$%s` must be a logical vector without missing values.",
        field
      ), "dynet_bad_vertex_censor")
    }
    value
  }
  onset_censored <- resolve_flag("onset_censored")
  terminus_censored <- resolve_flag("terminus_censored")
  if (any(start == end & (onset_censored | terminus_censored))) {
    fail("A vertex point spell cannot carry a censor flag.",
         "dynet_bad_vertex_censor")
  }
  raw <- data.frame(
    node = node, start = start, end = end, session = session,
    onset_censored = onset_censored,
    terminus_censored = terminus_censored,
    stringsAsFactors = FALSE
  )
  if (!n) {
    return(list(
      spells = .empty_vertex_spells(), input_rows = 0L,
      scope = if (has_session) "session" else "global",
      sessions = if (has_session) character() else NULL,
      censor_explicit = any(c("onset_censored", "terminus_censored") %in%
                              names(vertex_spells)),
      n_onset_censored = 0L, n_terminus_censored = 0L
    ))
  }

  normalize_group <- function(rows) {
    positive <- rows[rows$end > rows$start, , drop = FALSE]
    positive <- positive[order(positive$start, positive$end), , drop = FALSE]
    components <- list()
    if (nrow(positive)) {
      members <- 1L
      running_end <- positive$end[1L]
      if (nrow(positive) > 1L) {
        # Sequential dependency: component membership depends on the running
        # union endpoint, so each sorted interval must be considered in turn.
        for (i in seq.int(2L, nrow(positive))) {
          if (positive$start[i] <= running_end) {
            members <- c(members, i)
            running_end <- max(running_end, positive$end[i])
          } else {
            components[[length(components) + 1L]] <- members
            members <- i
            running_end <- positive$end[i]
          }
        }
      }
      components[[length(components) + 1L]] <- members
    }
    intervals <- if (length(components)) {
      do.call(rbind, lapply(components, function(i) {
        left <- min(positive$start[i])
        right <- max(positive$end[i])
        data.frame(
          start = left, end = right, instant = FALSE,
          onset_censored = any(
            positive$onset_censored[i][positive$start[i] == left]
          ),
          terminus_censored = any(
            positive$terminus_censored[i][positive$end[i] == right]
          )
        )
      }))
    } else data.frame(
      start = numeric(), end = numeric(), instant = logical(),
      onset_censored = logical(), terminus_censored = logical()
    )
    points <- sort(unique(rows$start[rows$start == rows$end]))
    if (length(points) && nrow(intervals)) {
      covered <- vapply(points, function(point) {
        any(point >= intervals$start & point < intervals$end)
      }, logical(1L))
      points <- points[!covered]
    }
    rbind(intervals, data.frame(
      start = points, end = points, instant = rep(TRUE, length(points)),
      onset_censored = rep(FALSE, length(points)),
      terminus_censored = rep(FALSE, length(points))
    ))
  }
  key <- if (has_session) {
    interaction(
      match(raw$session, unique(raw$session)),
      match(raw$node, unique(raw$node)), drop = TRUE, lex.order = TRUE
    )
  } else raw$node
  grouped <- split(seq_len(nrow(raw)), key)
  canonical <- lapply(grouped, function(i) {
    one <- normalize_group(raw[i, , drop = FALSE])
    one$node <- raw$node[i[1L]]
    one$session <- raw$session[i[1L]]
    one
  })
  canonical <- do.call(rbind, canonical)
  canonical <- canonical[order(
    is.na(canonical$session), canonical$session, canonical$node,
    canonical$start, canonical$end
  ), , drop = FALSE]
  rownames(canonical) <- NULL
  canonical <- data.frame(
    vertex_spell = seq_len(nrow(canonical)), node = canonical$node,
    start = canonical$start, end = canonical$end,
    duration = canonical$end - canonical$start,
    instant = canonical$instant, session = canonical$session,
    onset_censored = canonical$onset_censored,
    terminus_censored = canonical$terminus_censored,
    stringsAsFactors = FALSE
  )
  list(
    spells = canonical, input_rows = as.integer(n),
    scope = if (has_session) "session" else "global",
    sessions = if (has_session) sort(unique(session)) else NULL,
    censor_explicit = any(c("onset_censored", "terminus_censored") %in%
                            names(vertex_spells)),
    n_onset_censored = as.integer(sum(onset_censored)),
    n_terminus_censored = as.integer(sum(terminus_censored))
  )
}

#' Normalize discontinuous observation support
#'
#' @param spells Data frame with `start` and `end`.
#' @param origin,time_unit Network clock description.
#' @return Canonical observation components.
#' @keywords internal
.normalize_observation_spells <- function(spells, origin, time_unit) {
  .check(
    "`observation_spells` must be a nonempty data frame." =
      is.data.frame(spells) && nrow(spells) > 0L,
    "`observation_spells` must contain only `start` and `end` columns." =
      is.data.frame(spells) && identical(sort(names(spells)), c("end", "start"))
  )
  prototype <- list(meta = list(origin = origin, time_unit = time_unit))
  convert <- function(values, name) {
    vapply(seq_along(values), function(i) {
      .as_time(values[i], prototype, paste0("observation_spells$", name))
    }, numeric(1L))
  }
  start <- convert(spells$start, "start")
  end <- convert(spells$end, "end")
  .check("Every observation spell must end at or after it starts." =
           all(end >= start))

  positive <- which(end > start)
  merged <- list()
  if (length(positive)) {
    ord <- positive[order(start[positive], end[positive])]
    current_start <- start[ord[1L]]
    current_end <- end[ord[1L]]
    # Sequential dependency: each interval is compared with the running union
    # endpoint, so this normalization cannot be vectorized independently.
    for (i in ord[-1L]) {
      if (start[i] <= current_end) {
        current_end <- max(current_end, end[i])
      } else {
        merged[[length(merged) + 1L]] <- c(current_start, current_end)
        current_start <- start[i]
        current_end <- end[i]
      }
    }
    merged[[length(merged) + 1L]] <- c(current_start, current_end)
  }
  positive_table <- if (length(merged)) {
    data.frame(
      start = vapply(merged, `[[`, numeric(1L), 1L),
      end = vapply(merged, `[[`, numeric(1L), 2L)
    )
  } else data.frame(start = numeric(), end = numeric())

  points <- sort(unique(start[end == start]))
  if (length(points) && nrow(positive_table)) {
    covered <- vapply(points, function(point) {
      any(point >= positive_table$start & point <= positive_table$end)
    }, logical(1L))
    points <- points[!covered]
  }
  point_table <- data.frame(start = points, end = points)
  out <- rbind(positive_table, point_table)
  out <- out[order(out$start, out$end), , drop = FALSE]
  rownames(out) <- NULL
  out <- data.frame(
    observation = seq_len(nrow(out)), start = out$start, end = out$end,
    duration = out$end - out$start, instant = out$end == out$start
  )
  out
}

#' Resolve a continuous observation interval on the stored time scale
#'
#' @param raw_range Named numeric raw event limits `start` and `end`.
#' @param origin Stored numeric or calendar origin.
#' @param time_unit Stored time unit.
#' @param observation_start,observation_end Optional user bounds.
#' @return A named numeric vector with `start` and `end`.
#' @examples
#' Dynet:::.observation_bounds(c(start = 0, end = 10), 0, "step", 2, 8)
#' @keywords internal
.observation_bounds <- function(raw_range, origin, time_unit,
                                observation_start = NULL,
                                observation_end = NULL) {
  prototype <- list(meta = list(origin = origin, time_unit = time_unit))
  lower <- .as_time(observation_start, prototype, "observation_start") %||%
    raw_range[["start"]]
  upper <- .as_time(observation_end, prototype, "observation_end") %||%
    raw_range[["end"]]
  if (upper < lower) {
    stop(errorCondition(
      sprintf(
        "`observation_end` (%s) is earlier than `observation_start` (%s).",
        upper, lower
      ),
      class = "dynet_bad_input", call = NULL
    ))
  }
  c(start = lower, end = upper)
}


# ---------------------------------------------------------------------------
# The cograph netobject
# ---------------------------------------------------------------------------

#' Assemble a temporal network as a cograph netobject
#'
#' A `dynet` object is a cograph network: it carries cograph's canonical
#' fields (`nodes`, `edges`, `directed`, `weights`, `data`, `meta`,
#' `node_groups`) describing the aggregate network, so that
#' `cograph::splot()` renders it with no conversion, plus a `spells` table
#' holding the temporal detail cograph has no notion of.
#'
#' The aggregate `edges` table uses integer endpoints because that is
#' cograph's schema. Nothing in Dynet's public surface exposes them: the
#' spell table, and every measurement result, carry vertex names.
#'
#' @param spells Canonical spell table with character endpoints.
#' @param nodes Vertex table with a `name` column and any attributes.
#' @param directed Whether the network is directed.
#' @param groups Name of the vertex attribute to use as the partition, or
#'   `NULL`.
#' @param meta Metadata list.
#' @param vertex_spells Canonical declared vertex-activity components.
#' @return An object of class `c("dynet", "netobject", "cograph_network")`.
#' @keywords internal
.as_netobject <- function(spells, nodes, directed, groups, meta,
                          vertex_spells = NULL) {
  nm <- nodes$name
  n <- length(nm)

  from_id <- match(spells$from, nm)
  to_id   <- match(spells$to, nm)
  w <- matrix(0, n, n, dimnames = list(nm, nm))
  cell <- (to_id - 1L) * n + from_id
  agg <- tapply(spells$weight, cell, sum)
  w[as.integer(names(agg))] <- as.numeric(agg)
  if (!directed) w <- w + t(w) - diag(diag(w), n, n)

  idx <- which(w > 0, arr.ind = TRUE)
  if (!directed) idx <- idx[idx[, 1L] <= idx[, 2L], , drop = FALSE]

  node_tbl <- data.frame(id = seq_len(n), label = nm, name = nm,
                         x = NA_real_, y = NA_real_, stringsAsFactors = FALSE)
  extra <- setdiff(names(nodes), "name")
  if (length(extra) > 0L) node_tbl <- cbind(node_tbl, nodes[, extra, drop = FALSE])

  node_groups <- NULL
  if (!is.null(groups)) {
    if (!groups %in% names(nodes)) {
      stop(errorCondition(
        sprintf("`groups = %s` is not a vertex attribute. Supply it through `nodes = `.",
                sQuote(groups)),
        class = "dynet_unknown_attribute", call = NULL))
    }
    # cograph finds the partition at $nodes$groups and $node_groups.
    node_tbl$groups <- as.character(nodes[[groups]])
    node_groups <- data.frame(node = nm, group = node_tbl$groups,
                              stringsAsFactors = FALSE)
  }

  structure(
    list(
      nodes       = node_tbl,
      edges       = data.frame(from = idx[, 1L], to = idx[, 2L],
                               weight = w[idx], row.names = NULL),
      directed    = directed,
      weights     = w,
      data        = NULL,
      meta        = meta,
      node_groups = node_groups,
      spells      = spells,
      vertex_spells = vertex_spells %||% .empty_vertex_spells()
    ),
    class = c("dynet", "netobject", "cograph_network")
  )
}


# ---------------------------------------------------------------------------
# Format inference
# ---------------------------------------------------------------------------

#' Infer the construction format from named arguments and available columns
#' @param data Data frame.
#' @param format User-supplied format, possibly `"auto"`.
#' @param thread,actor,group,end,duration User-supplied column names.
#' @return A single character format name.
#' @keywords internal
.infer_format <- function(data, format, thread, actor, group, end, duration) {
  if (!identical(format, "auto")) return(format)
  if (!is.null(actor) && !is.null(group)) return("copresence")
  if (!is.null(thread)) return("threaded")
  has_end <- !is.null(end) || !is.null(duration) ||
    !is.null(.match_column(data, "end")) ||
    !is.null(.match_column(data, "duration"))
  if (has_end) "interval" else "contact"
}


# ---------------------------------------------------------------------------
# Format builders. Each returns a list with a canonical `edges` frame
# (character `from`/`to`, numeric `start`/`end`, character `session`), the
# resolved time unit and origin, and the source row index.
# ---------------------------------------------------------------------------

#' Resolve the vertex pair columns shared by all edge-list formats
#' @param data Data frame.
#' @param from,to User-supplied column names or `NULL`.
#' @return A list with `from` and `to` character vectors.
#' @keywords internal
.resolve_dyad <- function(data, from, to) {
  f <- .resolve_column(data, from, "from", arg = "from")
  if (is.null(f)) {
    stop(errorCondition(
      sprintf("Could not find a source column. Name it with `from = `. Available: %s",
              paste(names(data), collapse = ", ")),
      class = "dynet_missing_column", call = NULL))
  }
  t <- .resolve_column(data, to, "to", exclude = f, arg = "to")
  if (is.null(t)) {
    stop(errorCondition(
      sprintf("Could not find a target column. Name it with `to = `. Available: %s",
              paste(setdiff(names(data), f), collapse = ", ")),
      class = "dynet_missing_column", call = NULL))
  }
  vals <- list(from = as.character(data[[f]]), to = as.character(data[[t]]))
  if (anyNA(vals$from) || anyNA(vals$to)) {
    stop(errorCondition("Source and target columns must not contain NA values.",
                        class = "dynet_bad_input", call = NULL))
  }
  vals
}

#' Resolve the session column, returning all-NA when absent
#' @param data Data frame.
#' @param session User-supplied column name or `NULL`.
#' @return A character vector of length `nrow(data)`.
#' @keywords internal
.resolve_session <- function(data, session) {
  s <- .resolve_column(data, session, "session", arg = "session")
  if (is.null(s)) return(rep(NA_character_, nrow(data)))
  values <- as.character(data[[s]])
  if (anyNA(values)) {
    stop(errorCondition(
      "Session labels must not contain missing values.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  values
}

#' Build an interval-format edge table
#' @param data Data frame.
#' @param from,to,start,end,duration,session User-supplied column names.
#' @param time_unit Requested time unit.
#' @return A list with `edges`, `time_unit`, `origin`, `row_index`, `node_pool`.
#' @keywords internal
.build_interval <- function(data, from, to, start, end, duration, session,
                            time_unit) {
  dyad <- .resolve_dyad(data, from, to)

  s_col <- .resolve_column(data, start, "start", arg = "start")
  if (is.null(s_col)) s_col <- .resolve_column(data, NULL, "time")
  if (is.null(s_col)) {
    stop(errorCondition(
      "Could not find a start-time column. Name it with `start = ` or `time = `.",
      class = "dynet_missing_column", call = NULL))
  }
  e_col <- .resolve_column(data, end, "end", exclude = s_col, arg = "end")
  d_col <- .resolve_column(data, duration, "duration", exclude = s_col,
                           arg = "duration")

  parsed_start <- .parse_time(data[[s_col]], time_unit)
  starts <- parsed_start$values

  ends <- if (!is.null(e_col)) {
    .parse_time(data[[e_col]], parsed_start$unit,
                origin = parsed_start$origin)$values
  } else if (!is.null(d_col)) {
    dur <- data[[d_col]]
    if (!is.numeric(dur)) {
      stop(errorCondition("The duration column must be numeric.",
                          class = "dynet_bad_input", call = NULL))
    }
    starts + dur
  } else {
    stop(errorCondition(
      "Interval format needs an end time or a duration. Name it with `end = ` or `duration = `.",
      class = "dynet_missing_column", call = NULL))
  }

  if (any(ends < starts)) {
    stop(errorCondition("Every edge must end at or after it starts.",
                        class = "dynet_bad_input", call = NULL))
  }

  list(
    edges = data.frame(from = dyad$from, to = dyad$to, start = starts,
                       end = ends, session = .resolve_session(data, session),
                       stringsAsFactors = FALSE),
    time_unit = parsed_start$unit,
    origin    = parsed_start$origin,
    row_index = seq_len(nrow(data)),
    node_pool = character()
  )
}

#' Build a contact-format edge table
#' @param data Data frame.
#' @param from,to,time,session User-supplied column names.
#' @param time_unit Requested time unit.
#' @return A list with `edges`, `time_unit`, `origin`, `row_index`, `node_pool`.
#' @keywords internal
.build_contact <- function(data, from, to, time, session, time_unit) {
  dyad <- .resolve_dyad(data, from, to)
  t_col <- .resolve_column(data, time, "time", arg = "time")
  if (is.null(t_col)) t_col <- .resolve_column(data, NULL, "start")
  if (is.null(t_col)) {
    stop(errorCondition(
      sprintf("Could not find an event-time column. Name it with `time = `. Available: %s",
              paste(names(data), collapse = ", ")),
      class = "dynet_missing_column", call = NULL))
  }
  parsed <- .parse_time(data[[t_col]], time_unit)
  list(
    edges = data.frame(from = dyad$from, to = dyad$to,
                       start = parsed$values, end = parsed$values,
                       session = .resolve_session(data, session),
                       stringsAsFactors = FALSE),
    time_unit = parsed$unit,
    origin    = parsed$origin,
    row_index = seq_len(nrow(data)),
    node_pool = character()
  )
}

#' Build a threaded-format edge table
#'
#' A post is treated as active from the moment it appears until the last post
#' in the same thread, so that a reply is concurrent with everything it went
#' on to provoke.
#'
#' @param data Data frame.
#' @param from,to,time,thread,session User-supplied column names.
#' @param time_unit Requested time unit.
#' @return A list with `edges`, `time_unit`, `origin`, `row_index`, `node_pool`.
#' @keywords internal
.build_threaded <- function(data, from, to, time, thread, session, time_unit) {
  base <- .build_contact(data, from, to, time, session, time_unit)
  th_col <- .resolve_column(data, thread, "thread", arg = "thread")
  if (is.null(th_col)) {
    stop(errorCondition(
      sprintf("Could not find a thread column. Name it with `thread = `. Available: %s",
              paste(names(data), collapse = ", ")),
      class = "dynet_missing_column", call = NULL))
  }
  th <- as.character(data[[th_col]])
  if (anyNA(th)) {
    stop(errorCondition("The thread column must not contain NA values.",
                        class = "dynet_bad_input", call = NULL))
  }
  last_post <- tapply(base$edges$start, th, max)
  base$edges$end <- as.numeric(last_post[th])
  base$edges$thread <- th
  base
}

#' Build a co-presence edge table from two-mode attendance data
#'
#' Every pair of actors recorded in the same group becomes one undirected
#' spell covering that group's time span.
#'
#' @param data Data frame.
#' @param actor,group,time,start,end,session User-supplied column names.
#' @param time_unit Requested time unit.
#' @return A list with `edges`, `time_unit`, `origin`, `row_index`, `node_pool`.
#' @keywords internal
.build_copresence <- function(data, actor, group, time, start, end, session,
                              time_unit) {
  a_col <- .resolve_column(data, actor, "actor", arg = "actor")
  if (is.null(a_col)) {
    stop(errorCondition(
      "Could not find an actor column. Name it with `actor = `.",
      class = "dynet_missing_column", call = NULL))
  }
  g_col <- .resolve_column(data, group, "group", exclude = a_col, arg = "group")
  if (is.null(g_col)) {
    stop(errorCondition(
      "Could not find a group column. Name it with `group = `.",
      class = "dynet_missing_column", call = NULL))
  }

  actors <- as.character(data[[a_col]])
  groups <- as.character(data[[g_col]])
  if (anyNA(actors) || anyNA(groups)) {
    stop(errorCondition("Actor and group columns must not contain NA values.",
                        class = "dynet_bad_input", call = NULL))
  }

  s_col <- .resolve_column(data, start, "start", exclude = c(a_col, g_col))
  t_col <- .resolve_column(data, time, "time", exclude = c(a_col, g_col),
                           arg = "time")
  e_col <- .resolve_column(data, end, "end", exclude = c(a_col, g_col),
                           arg = "end")
  clock <- s_col %||% t_col

  if (is.null(clock)) {
    # No clock at all: groups are ordered by first appearance and each occupies
    # one unit of time.
    lvl <- unique(groups)
    g_start <- setNames(seq_along(lvl) - 1, lvl)
    g_end   <- setNames(seq_along(lvl), lvl)
    unit <- "step"
    origin <- 0
  } else {
    parsed <- .parse_time(data[[clock]], time_unit)
    ends <- if (!is.null(e_col)) {
      .parse_time(data[[e_col]], parsed$unit, origin = parsed$origin)$values
    } else {
      parsed$values
    }
    g_start <- tapply(parsed$values, groups, min)
    g_end   <- tapply(ends, groups, max)
    unit <- parsed$unit
    origin <- parsed$origin
  }

  sess <- .resolve_session(data, session)
  members <- split(seq_along(actors), groups)

  pairs <- lapply(names(members), function(g) {
    idx <- members[[g]]
    who <- sort(unique(actors[idx]))
    if (length(who) < 2L) return(NULL)
    cb <- utils::combn(who, 2L)
    data.frame(
      from    = cb[1L, ], to = cb[2L, ],
      start   = as.numeric(g_start[[g]]),
      end     = as.numeric(g_end[[g]]),
      session = sess[idx[1L]],
      group   = g,
      stringsAsFactors = FALSE
    )
  })
  pairs <- pairs[!vapply(pairs, is.null, logical(1L))]
  if (length(pairs) == 0L) {
    stop(errorCondition(
      "No group contains two or more actors, so no co-presence edge can be formed.",
      class = "dynet_empty_network", call = NULL))
  }

  list(
    edges     = do.call(rbind, pairs),
    time_unit = unit,
    origin    = origin,
    row_index = NULL,
    node_pool = unique(actors)
  )
}


# ---------------------------------------------------------------------------
# Shared assembly helpers
# ---------------------------------------------------------------------------

#' Resolve the per-event weight column
#' @param data Source data frame.
#' @param weight User-supplied column name or `NULL`.
#' @param row_index Mapping from built rows back to `data`, or `NULL`.
#' @param n Number of built rows.
#' @return A numeric vector of length `n`.
#' @keywords internal
.resolve_weight <- function(data, weight, row_index, n) {
  if (is.null(weight)) return(rep(1, n))
  if (is.null(row_index)) {
    warning("`weight` is ignored for co-presence networks, where each pair counts once.",
            call. = FALSE)
    return(rep(1, n))
  }
  w <- data[[.resolve_column(data, weight, "duration", arg = "weight")]]
  if (!is.numeric(w)) {
    stop(errorCondition("The weight column must be numeric.",
                        class = "dynet_bad_input", call = NULL))
  }
  w[row_index]
}

#' Assemble the vertex table, merging any supplied attributes
#' @param edges Canonical edge frame.
#' @param nodes Optional data frame of vertex attributes.
#' @param pool Extra vertex names that must appear even without an edge.
#' @return A data frame with `name` first, one row per vertex.
#' @keywords internal
.build_nodes <- function(edges, nodes, pool = character()) {
  observed <- unique(c(edges$from, edges$to, pool))
  # Vertices named with numbers sort numerically, so v10 does not land before
  # v2. Detected by pattern rather than by coercion, which would need its
  # warning suppressed.
  all_numeric <- all(grepl("^[+-]?[0-9]+(\\.[0-9]+)?$", observed))
  observed <- if (all_numeric) observed[order(as.numeric(observed))] else sort(observed)
  out <- data.frame(name = observed, stringsAsFactors = FALSE)

  if (is.null(nodes)) return(out)
  if (!is.data.frame(nodes)) {
    stop(errorCondition("`nodes` must be a data frame of vertex attributes.",
                        class = "dynet_bad_input", call = NULL))
  }
  key <- .match_column(nodes, "actor") %||% .match_column(nodes, "from") %||%
    names(nodes)[1L]
  attrs <- nodes
  key_values <- as.character(attrs[[key]])
  if (!identical(key, "name")) attrs[[key]] <- NULL
  attrs$name <- key_values
  dup <- duplicated(attrs$name)
  if (any(dup)) {
    warning(sprintf("`nodes` has %d duplicate vertex row(s); the first is kept.",
                    sum(dup)), call. = FALSE)
    attrs <- attrs[!dup, , drop = FALSE]
  }
  merged <- merge(out, attrs, by = "name", all.x = TRUE, sort = FALSE)
  merged[match(out$name, merged$name), , drop = FALSE]
}
