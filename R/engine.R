#' Validate arguments, raising a classed condition
#'
#' Used exactly like a named `.check()`: the name of each argument is the
#' message shown when it fails. Unlike `.check()` the error carries the
#' class `dynet_bad_input`, so a caller or a test can catch it precisely
#' rather than matching on message text.
#'
#' @param ... Named logical conditions.
#' @return `TRUE`, invisibly.
#' @noRd
.check <- function(...) {
  conds <- list(...)
  ok <- vapply(conds, isTRUE, logical(1L))
  if (all(ok)) return(invisible(TRUE))
  stop(errorCondition(paste(names(conds)[!ok], collapse = "\n"),
                      class = "dynet_bad_input", call = NULL))
}

#' Default value for `NULL`
#'
#' Identical in behaviour to the `%||%` that base R gained in 4.4.0. It is
#' defined here so the package's 93 call sites can keep using the operator
#' while the dependency floor stays at the 4.1 the native pipe requires;
#' without it, `Depends: R (>= 4.4)` would exclude every R older than
#' April 2024 for the sake of one operator. On R 4.4 and later this
#' definition simply shadows the identical base one inside the namespace.
#'
#' @param x A value that may be `NULL`.
#' @param y Replacement used when `x` is `NULL`.
#' @return `x` unless it is `NULL`, in which case `y`.
#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x

# ===========================================================================
# Tolerant time comparison
# ===========================================================================
# Path feasibility asks whether an arrival lands inside a closed interval, and
# an arrival is a SUM of a start and one traversal_time per hop. That sum is
# not representable exactly: with times 0, 0.1, 0.2 and traversal_time 0.1 the
# third arrival is 0.30000000000000004, so a bare `<= 0.3` rejects a path that
# is mathematically valid, while the integer-scaled version of the same
# problem accepts it. Every time comparison against a domain boundary
# therefore goes through these helpers rather than a bare operator.
#
# The tolerance is relative to the magnitude of the values being compared, not
# a fixed epsilon: temporal networks are routinely built on Unix timestamps
# (~1.7e9), where a double's own spacing is already ~2e-7, and a fixed
# absolute tolerance would be meaningless there.

#' Scale-relative tolerance for comparing two times
#'
#' Sized to absorb accumulated rounding from a realistic number of arithmetic
#' operations while staying far below any meaningful temporal separation.
#'
#' @param ... Times entering the comparison. Non-finite values are ignored.
#' @return A single non-negative tolerance on the scale of the inputs.
#' @noRd
.time_tol <- function(...) {
  values <- abs(unlist(list(...), use.names = FALSE))
  values <- values[is.finite(values)]
  scale <- if (length(values)) max(1, values) else 1
  128 * .Machine$double.eps * scale
}

#' Tolerant equality of two times
#'
#' @param a,b Numeric times, recycled as usual.
#' @return A logical vector, `TRUE` where the two times agree to within
#'   `.time_tol()`.
#' @noRd
.time_eq <- function(a, b) abs(a - b) <= .time_tol(a, b)

#' Tolerant "at or before" comparison of two times
#'
#' @param a,b Numeric times, recycled as usual.
#' @return A logical vector, `TRUE` where `a` is below `b` or within
#'   `.time_tol()` of it.
#' @noRd
.time_leq <- function(a, b) a <= b + .time_tol(a, b)

#' Tolerant "at or after" comparison of two times
#'
#' @param a,b Numeric times, recycled as usual.
#' @return A logical vector, `TRUE` where `a` is above `b` or within
#'   `.time_tol()` of it.
#' @noRd
.time_geq <- function(a, b) a >= b - .time_tol(a, b)

# ===========================================================================
# Internal compute engine: encoding, time bins, activity, adjacency
# ===========================================================================
# Nothing in this file is exported. Vertex names are turned into integers
# here and turned back into names before any result leaves the package.

#' Validate a dynet object and its session argument
#' @param dn Object to check.
#' @param sessions Session handling mode.
#' @return The matched session mode, invisibly.
#' @noRd
.check_dynet <- function(dn, sessions = "bounded") {
  if (!inherits(dn, "dynet")) {
    stop(errorCondition(
      "`dn` must be a temporal network built with dynet().",
      class = "dynet_bad_input", call = NULL))
  }
  sessions <- match.arg(sessions, c("bounded", "collapse", "separate"))
  if (identical(sessions, "separate") && is.null(dn$meta$sessions)) {
    stop(errorCondition(
      "sessions = \"separate\" needs a session column; build the network with `session = `.",
      class = "dynet_no_sessions", call = NULL))
  }
  invisible(sessions)
}

#' Integer-encode a canonical edge frame against the vertex table
#'
#' @param dn A `dynet` object.
#' @param rows Optional row subset of the spell table.
#' @return A list of parallel vectors, one element per observation fragment,
#'   plus two scalars. The fragment vectors are: integer `from`/`to`;
#'   observation-clipped numeric `start`/`end`; preserved `raw_start`/
#'   `raw_end`; numeric `weight`; `session`; logical raw `instant`; logical
#'   `observed_activity`; the `raw_spell`, `observation` and `fragment`
#'   identifiers locating the fragment; the censor flags
#'   `left_observation_censored`, `right_observation_censored`,
#'   `onset_censored` and `terminus_censored`; and the
#'   `raw_from`/`raw_to`/`raw_event_*` family, which carries the *unclipped*
#'   raw event so that `events()` and `metrics()` can count formations and
#'   dissolutions against what was recorded rather than against the clipped
#'   fragment. The two scalars are the vertex `names` and their count `n`.
#' @noRd
.encode <- function(dn, rows = NULL) {
  e <- if (is.null(rows)) dn$spells else dn$spells[rows, , drop = FALSE]
  nm <- dn$nodes$name
  fragments <- .observed_fragments(dn, e)
  observed_activity <- rep(TRUE, nrow(fragments))
  positive <- e$end > e$start
  absent <- positive & !e$.raw_spell %in% fragments$raw_spell
  endpoint_seen <- .time_in_observation(dn, e$start) |
    .time_in_observation(dn, e$end)
  endpoint_only <- e[absent & endpoint_seen, , drop = FALSE]
  if (nrow(endpoint_only)) {
    use_start <- .time_in_observation(dn, endpoint_only$start)
    point <- ifelse(use_start, endpoint_only$start, endpoint_only$end)
    observations <- .observation_table(dn)
    observation <- if (is.null(observations)) rep(1L, length(point)) else
      vapply(point, function(one) {
        observations$observation[
          which(one >= observations$start & one <= observations$end)[1L]
        ]
      }, integer(1L))
    administrative <- data.frame(
      raw_spell = endpoint_only$.raw_spell, observation = observation,
      fragment = 0L, from = endpoint_only$from, to = endpoint_only$to,
      start = point, end = point, raw_start = endpoint_only$start,
      raw_end = endpoint_only$end, weight = endpoint_only$weight,
      session = as.character(endpoint_only$session), instant = FALSE,
      onset_censored = endpoint_only$onset_censored,
      terminus_censored = endpoint_only$terminus_censored,
      left_observation_censored = point > endpoint_only$start,
      right_observation_censored = point < endpoint_only$end,
      stringsAsFactors = FALSE
    )
    fragments <- rbind(fragments, administrative)
    observed_activity <- c(observed_activity, rep(FALSE, nrow(administrative)))
  }
  list(
    from    = match(fragments$from, nm),
    to      = match(fragments$to, nm),
    start   = fragments$start,
    end     = fragments$end,
    raw_start = fragments$raw_start,
    raw_end = fragments$raw_end,
    weight  = fragments$weight,
    session = fragments$session,
    instant = fragments$instant,
    observed_activity = observed_activity,
    raw_spell = fragments$raw_spell,
    observation = fragments$observation,
    fragment = fragments$fragment,
    left_observation_censored = fragments$left_observation_censored,
    right_observation_censored = fragments$right_observation_censored,
    onset_censored = fragments$onset_censored,
    terminus_censored = fragments$terminus_censored,
    raw_from = match(e$from, nm),
    raw_to = match(e$to, nm),
    raw_event_start = e$start,
    raw_event_end = e$end,
    raw_event_instant = e$end == e$start,
    raw_event_session = e$session,
    raw_event_spell = e$.raw_spell,
    raw_event_onset_censored = e$onset_censored,
    raw_event_terminus_censored = e$terminus_censored,
    names   = nm,
    n       = length(nm)
  )
}

#' Intersect declared vertex activity with observed support
#'
#' Positive vertex spells are intersected with positive observation
#' components and retain half-open endpoints. Genuine vertex points survive
#' when they lie on the closed support. No administrative point is fabricated
#' when an observation boundary cuts a positive spell.
#'
#' @param dn A `dynet` object.
#' @return A data frame of observed vertex-activity fragments.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
#'             vertex_spells = data.frame(node = "A", start = 0, end = 1))
#' Dynet:::.observed_vertex_fragments(dn)
#' @noRd
.observed_vertex_fragments <- function(dn) {
  spells <- dn$vertex_spells %||% .empty_vertex_spells()
  empty <- data.frame(
    vertex_spell = integer(), observation = integer(), node = character(),
    start = numeric(), end = numeric(), instant = logical(),
    session = character(), stringsAsFactors = FALSE
  )
  if (!nrow(spells)) return(empty)
  observations <- .observation_table(dn)
  if (is.null(observations)) {
    return(data.frame(
      vertex_spell = spells$vertex_spell, observation = 1L,
      node = spells$node, start = spells$start, end = spells$end,
      instant = spells$instant, session = spells$session,
      stringsAsFactors = FALSE
    ))
  }
  positive_spells <- spells[!spells$instant, , drop = FALSE]
  positive_observations <- observations[!observations$instant, , drop = FALSE]
  positive <- empty
  if (nrow(positive_spells) && nrow(positive_observations)) {
    cross <- merge(
      positive_spells,
      positive_observations[, c("observation", "start", "end")],
      by = NULL, suffixes = c("_vertex", "_observation"), sort = FALSE
    )
    cross$start <- pmax(cross$start_vertex, cross$start_observation)
    cross$end <- pmin(cross$end_vertex, cross$end_observation)
    cross <- cross[cross$end > cross$start, , drop = FALSE]
    if (nrow(cross)) {
      positive <- data.frame(
        vertex_spell = cross$vertex_spell, observation = cross$observation,
        node = cross$node, start = cross$start, end = cross$end,
        instant = FALSE, session = cross$session, stringsAsFactors = FALSE
      )
    }
  }
  points <- spells[spells$instant, , drop = FALSE]
  point_fragments <- empty
  if (nrow(points)) {
    observation <- vapply(points$start, function(one) {
      hit <- which(one >= observations$start & one <= observations$end)
      if (length(hit)) observations$observation[hit[1L]] else NA_integer_
    }, integer(1L))
    keep <- !is.na(observation)
    if (any(keep)) {
      point_fragments <- data.frame(
        vertex_spell = points$vertex_spell[keep],
        observation = observation[keep], node = points$node[keep],
        start = points$start[keep], end = points$end[keep], instant = TRUE,
        session = points$session[keep], stringsAsFactors = FALSE
      )
    }
  }
  out <- rbind(positive, point_fragments)
  if (!nrow(out)) return(empty)
  out <- out[order(out$vertex_spell, out$observation, out$start, out$end), ]
  rownames(out) <- NULL
  out
}

#' Encode observed vertex activity against the fixed vertex universe
#' @param dn A `dynet` object.
#' @param names Fixed vertex names.
#' @return Collision-safe integer activity rows and a declared-vertex mask.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.encode_vertex_activity(dn, c("A", "B"))
#' @noRd
.encode_vertex_activity <- function(dn, names = dn$nodes$name) {
  fragments <- .observed_vertex_fragments(dn)
  declared <- names %in% unique((dn$vertex_spells %||%
                                   .empty_vertex_spells())$node)
  list(
    node = match(fragments$node, names), start = fragments$start,
    end = fragments$end, instant = fragments$instant,
    session = fragments$session, observation = fragments$observation,
    declared = declared
  )
}

#' Canonical observation table for measurement
#' @param dn A `dynet` object.
#' @return Observation components, or `NULL` for an unbounded legacy object.
#' @noRd
.observation_table <- function(dn) {
  if (!is.null(dn$meta$observations)) return(dn$meta$observations)
  if (!is.null(dn$meta$observation)) {
    bounds <- dn$meta$observation
    return(data.frame(
      observation = 1L, start = bounds[["start"]], end = bounds[["end"]],
      duration = bounds[["end"]] - bounds[["start"]],
      instant = bounds[["end"]] == bounds[["start"]]
    ))
  }
  NULL
}

#' Test punctual membership in observed support
#' @param dn A `dynet` object.
#' @param time Numeric times.
#' @return Logical membership vector; component endpoints are closed.
#' @noRd
.time_in_observation <- function(dn, time) {
  observations <- .observation_table(dn)
  if (is.null(observations)) return(rep(TRUE, length(time)))
  vapply(time, function(one) {
    any(one >= observations$start & one <= observations$end)
  }, logical(1L))
}

#' Map calendar times to cumulative positive observed exposure
#' @param dn A `dynet` object.
#' @param time Numeric times.
#' @return Numeric cumulative observed-time coordinates.
#' @noRd
.observed_time <- function(dn, time) {
  observations <- .observation_table(dn)
  if (is.null(observations)) return(time)
  positive <- observations[!observations$instant, , drop = FALSE]
  if (!nrow(positive)) return(rep(0, length(time)))
  vapply(time, function(one) {
    sum(pmax(0, pmin(one, positive$end) - positive$start))
  }, numeric(1L))
}

#' Intersect raw spells with canonical observed support
#' @param dn A `dynet` object.
#' @param spells Raw canonical spell rows.
#' @return Tidy observed fragments with raw provenance.
#' @noRd
.observed_fragments <- function(dn, spells = dn$spells) {
  base_names <- c(
    "raw_spell", "observation", "fragment", "from", "to", "start", "end",
    "raw_start", "raw_end", "weight", "session", "instant",
    "onset_censored", "terminus_censored",
    "left_observation_censored", "right_observation_censored"
  )
  empty <- data.frame(
    raw_spell = integer(), observation = integer(), fragment = integer(),
    from = character(), to = character(), start = numeric(), end = numeric(),
    raw_start = numeric(), raw_end = numeric(), weight = numeric(),
    session = character(), instant = logical(),
    onset_censored = logical(), terminus_censored = logical(),
    left_observation_censored = logical(),
    right_observation_censored = logical(), stringsAsFactors = FALSE
  )
  if (!nrow(spells)) return(empty)
  observations <- .observation_table(dn)
  if (is.null(observations)) {
    observations <- data.frame(
      observation = 1L, start = -Inf, end = Inf, duration = Inf,
      instant = FALSE
    )
  }
  raw <- data.frame(
    raw_spell = spells$.raw_spell, from = spells$from, to = spells$to,
    raw_start = spells$start, raw_end = spells$end,
    weight = spells$weight, session = as.character(spells$session),
    onset_censored = spells$onset_censored,
    terminus_censored = spells$terminus_censored,
    raw_instant = spells$end == spells$start,
    stringsAsFactors = FALSE
  )
  positive_raw <- raw[!raw$raw_instant, , drop = FALSE]
  positive_obs <- observations[!observations$instant, , drop = FALSE]
  positive <- empty
  if (nrow(positive_raw) && nrow(positive_obs)) {
    cross <- merge(positive_raw, positive_obs[, c("observation", "start", "end")],
                   by = NULL, sort = FALSE)
    cross$start <- pmax(cross$raw_start, cross$start)
    cross$end <- pmin(cross$raw_end, cross$end)
    cross <- cross[cross$end > cross$start, , drop = FALSE]
    if (nrow(cross)) {
      cross <- cross[order(cross$raw_spell, cross$observation,
                           cross$start, cross$end), , drop = FALSE]
      cross$fragment <- stats::ave(cross$raw_spell, cross$raw_spell,
                                   FUN = seq_along)
      cross$instant <- FALSE
      cross$left_observation_censored <- cross$start > cross$raw_start
      cross$right_observation_censored <- cross$end < cross$raw_end
      positive <- cross[, base_names, drop = FALSE]
    }
  }
  point_raw <- raw[raw$raw_instant, , drop = FALSE]
  points <- empty
  if (nrow(point_raw)) {
    component <- vapply(point_raw$raw_start, function(one) {
      hit <- which(one >= observations$start & one <= observations$end)
      if (length(hit)) observations$observation[hit[1L]] else NA_integer_
    }, integer(1L))
    point_raw <- point_raw[!is.na(component), , drop = FALSE]
    component <- component[!is.na(component)]
    if (nrow(point_raw)) {
      points <- data.frame(
        raw_spell = point_raw$raw_spell, observation = component,
        fragment = 1L, from = point_raw$from, to = point_raw$to,
        start = point_raw$raw_start, end = point_raw$raw_end,
        raw_start = point_raw$raw_start, raw_end = point_raw$raw_end,
        weight = point_raw$weight, session = point_raw$session,
        onset_censored = point_raw$onset_censored,
        terminus_censored = point_raw$terminus_censored,
        instant = TRUE, left_observation_censored = FALSE,
        right_observation_censored = FALSE, stringsAsFactors = FALSE
      )
    }
  }
  out <- rbind(positive, points)
  if (!nrow(out)) return(empty)
  out <- out[order(out$raw_spell, out$fragment), base_names, drop = FALSE]
  rownames(out) <- NULL
  out
}


# ---------------------------------------------------------------------------
# The measurement grid: start, end, step, window
# ---------------------------------------------------------------------------
# Four arguments describe when a temporal network is measured, following the
# convention of `tsna::tSnaStats()`:
#
#   start   first measurement point          (tsna: start)
#   end     last measurement point           (tsna: end)
#   step    spacing between measurements     (tsna: time.interval)
#   window  width each measurement covers    (tsna: aggregate.dur)
#
# Separating `step` from `window` is what makes a rolling window expressible.
# `window == step` tiles the period into disjoint bins; `window > step` slides
# an overlapping window along it; `window == 0` samples the network at an
# instant, exactly as `tsna::tSnaStats(aggregate.dur = 0)` does.

#' Convert a user-supplied time to the network's internal numeric scale
#'
#' Times inside a `dynet` are numeric offsets from `dn$meta$origin`, measured
#' in `dn$meta$time_unit`. A network built from `Date` or `POSIXct` input may
#' therefore be addressed with a date, which is converted here; a network
#' built from plain numbers must be addressed with numbers.
#'
#' @param v The value supplied by the caller, or `NULL`.
#' @param dn A `dynet` object.
#' @param arg Argument name, used in the error message.
#' @return A single number, or `NULL` when `v` was `NULL`.
#' @noRd
.as_time <- function(v, dn, arg) {
  if (is.null(v)) return(NULL)
  if (length(v) != 1L) {
    stop(errorCondition(sprintf("`%s` must be a single time point.", arg),
                        class = "dynet_bad_input", call = NULL))
  }
  dated <- inherits(v, "Date") || inherits(v, "POSIXt")
  origin <- dn$meta$origin
  if (dated) {
    if (!inherits(origin, "POSIXt")) {
      stop(errorCondition(sprintf(
        "`%s` was given as a date, but this network's times are plain numbers.",
        arg), class = "dynet_bad_input", call = NULL))
    }
    secs <- as.numeric(as.POSIXct(v, tz = "UTC")) - as.numeric(origin)
    return(secs / .unit_seconds(dn$meta$time_unit))
  }
  if (!is.numeric(v) || !is.finite(v)) {
    stop(errorCondition(sprintf("`%s` must be a single finite number.", arg),
                        class = "dynet_bad_input", call = NULL))
  }
  as.numeric(v)
}

#' Resolve a per-hop traversal duration
#'
#' Numeric values are expressed in the network's stored time unit. A
#' `difftime` is converted for calendar networks; a numeric-step network has no
#' calendar unit with which to interpret it.
#'
#' @param value Requested traversal duration.
#' @param dn A `dynet` object.
#' @return One finite nonnegative numeric duration in network units.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.as_traversal_time(1, dn)
#' @noRd
.as_traversal_time <- function(value, dn) {
  if (inherits(value, "Date") || inherits(value, "POSIXt")) {
    stop(errorCondition(
      "`traversal_time` is a duration, not a date or date-time.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  if (inherits(value, "difftime")) {
    if (length(value) != 1L || is.na(value)) {
      stop(errorCondition(
        "`traversal_time` must be one finite nonnegative duration.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    if (identical(dn$meta$time_unit, "step")) {
      stop(errorCondition(
        "A numeric-step network needs `traversal_time` in numeric steps, not `difftime`.",
        class = "dynet_bad_input", call = NULL
      ))
    }
    value <- as.numeric(value, units = "secs") /
      .unit_seconds(dn$meta$time_unit)
  }
  if (!is.numeric(value) || length(value) != 1L ||
      !is.finite(value) || value < 0) {
    stop(errorCondition(
      "`traversal_time` must be one finite nonnegative duration.",
      class = "dynet_bad_input", call = NULL
    ))
  }
  as.numeric(value)
}

#' Resolve and validate the four measurement-grid arguments
#'
#' Called once at the top of every verb that measures over time, so the
#' contract is checked in one place rather than at each use.
#'
#' `start` and `end` are left `NULL` when the caller did not supply them, so
#' that each session can fall back to its own observed range; an explicit
#' value applies to every session alike.
#'
#' @param dn A `dynet` object.
#' @param start,end Measurement range, or `NULL` for the observed range.
#' @param step Spacing between measurements, or `NULL` for the network's
#'   construction interval.
#' @param window Width of each measurement, or `NULL` for `step`.
#' @return A list with `start` and `end` (each possibly `NULL`, meaning "use
#'   this session's own observed range"), `phase_start` (the caller-supplied
#'   `start`, or `NULL`, kept separately because `.observation_bins()` phases
#'   every observation component's grid onto it so bins line up across
#'   components), `step`, `window`, and `whole` (whether `window = "all"` was
#'   asked for). `.observation_bins()` reads `phase_start` and `whole`, so
#'   neither is optional.
#' @noRd
.window_spec <- function(dn, start = NULL, end = NULL, step = NULL,
                         window = NULL) {
  whole <- .is_whole_window(window)
  if (whole) {
    if (!is.null(step)) {
      stop(errorCondition(
        "`step` has no meaning with `window = \"all\"`, which measures one window.",
        class = "dynet_bad_input", call = NULL))
    }
    window <- NULL
  }
  start <- .as_time(start, dn, "start")
  end   <- .as_time(end,   dn, "end")
  phase_start <- start
  step  <- step %||% dn$meta$interval
  .check(
    "`step` must be a single positive number." =
      is.numeric(step) && length(step) == 1L && is.finite(step) && step > 0,
    "`window` must be a single non-negative number, or the string \"all\"." =
      is.null(window) || (is.numeric(window) && length(window) == 1L &&
                          is.finite(window) && window >= 0)
  )
  window <- as.numeric(window %||% step)
  if (!is.null(start) && !is.null(end) && end < start) {
    stop(errorCondition(
      sprintf("`end` (%s) is earlier than `start` (%s).", end, start),
      class = "dynet_bad_input", call = NULL))
  }
  if (isTRUE(dn$meta$observation_explicit)) {
    observed <- .observation_table(dn)
    query_start <- start %||% min(observed$start)
    query_end <- end %||% max(observed$end)
    intersects <- any(query_start <= observed$end & query_end >= observed$start)
    if (!intersects) {
      stop(errorCondition(
        "The requested measurement range does not intersect observed support.",
        class = c("dynet_outside_observation", "dynet_bad_input"),
        call = NULL
      ))
    }
    hull <- dn$meta$observation
    if (!is.null(start)) start <- max(start, hull[["start"]])
    if (!is.null(end)) end <- min(end, hull[["end"]])
  }
  if (whole) {
    hull <- .network_span(dn)
    span <- max(0, (end %||% hull[["end"]]) - (start %||% hull[["start"]]))
    window <- span
    step <- if (span > 0) span else as.numeric(dn$meta$interval)
  }
  list(start = start, end = end, phase_start = phase_start,
       step = as.numeric(step), window = window, whole = whole)
}

#' Whether a `window` argument asked for one window over the whole period
#'
#' `window = "all"` is the only non-numeric spelling the measurement grid
#' accepts. Anything else that is not a number is a caller error, reported
#' where the width itself is validated rather than here.
#'
#' @param window The `window` argument as supplied.
#' @return A single logical.
#' @noRd
.is_whole_window <- function(window) {
  is.character(window) && length(window) == 1L && !is.na(window) &&
    identical(window, "all")
}

#' The outer time range of a network, ignoring the measurement grid
#'
#' Explicit observation bounds win when declared, because they are the limit of
#' what was measured; otherwise the raw spell extrema stand in.
#'
#' @param dn A `dynet` object.
#' @return A named numeric vector with `start` and `end`.
#' @examples
#' Dynet:::.network_span(dynet(school_contacts))
#' @noRd
.network_span <- function(dn) {
  if (isTRUE(dn$meta$observation_explicit)) return(dn$meta$observation)
  c(start = min(dn$spells$start), end = max(dn$spells$end))
}

#' Translate the retired sampling argument to a window width
#'
#' `sample = "instant"` was the pre-0.3 spelling of `window = 0`. Keep it as
#' a deprecated bridge so existing analysis scripts do not fail merely because
#' the measurement-grid API became more expressive.
#'
#' @param window A window width supplied through the current API.
#' @param sample `NULL`, `"window"` or `"instant"`.
#' @return `window`, possibly translated to zero.
#' @noRd
.legacy_sample <- function(window = NULL, sample = NULL) {
  if (is.null(sample)) return(window)
  sample <- match.arg(sample, c("window", "instant"))
  warning("`sample` is deprecated; use `window = 0` for point sampling and a positive `window` for window sampling.",
          call. = FALSE)
  if (identical(sample, "instant")) {
    if (!is.null(window) && !isTRUE(all.equal(as.numeric(window), 0))) {
      stop(errorCondition(
        "`sample = \"instant\"` conflicts with a positive `window`.",
        class = "dynet_bad_input", call = NULL))
    }
    return(0)
  }
  if (!is.null(window) && is.numeric(window) && length(window) == 1L &&
      is.finite(window) && window == 0) {
    stop(errorCondition(
      "`sample = \"window\"` conflicts with `window = 0`.",
      class = "dynet_bad_input", call = NULL))
  }
  window
}

#' The last measurement point that still begins inside the observed period
#'
#' The default `end`. Chosen so that windows of width `step` tile the period
#' without a trailing window that opens at the very moment the data stop.
#'
#' @param t_min,t_max Observed time range.
#' @param step Spacing between measurements.
#' @return A single number.
#' @noRd
.default_end <- function(t_min, t_max, step) {
  t_min + (.grid_bins(t_max - t_min, step) - 1L) * step
}

#' Number of bins of width `step` needed to cover a span
#'
#' A span that is an exact multiple of `step` must not gain a spurious
#' trailing bin from representation error, so a ratio within rounding error of
#' a whole number is taken to be that whole number. Anything genuinely above
#' it takes the ceiling.
#'
#' The tolerance is per element and relative to the ratio. The previous form,
#' `ceiling(span / step - 1e-9)`, subtracted a fixed epsilon from the ratio
#' itself, which is a tolerance on the bin COUNT rather than on time: it
#' discarded any event landing up to `1e-9 * step` above an exact multiple,
#' silently dropping it from every measurement built on the grid.
#'
#' @param span,step Numeric widths, recycled as usual.
#' @return An integer vector of bin counts, at least one.
#' @noRd
.grid_bins <- function(span, step) {
  ratio <- span / step
  nearest <- round(ratio)
  tol <- 128 * .Machine$double.eps * pmax(1, abs(ratio))
  exact <- abs(ratio - nearest) <= tol
  pmax(1L, as.integer(ifelse(exact, nearest, ceiling(ratio))))
}

#' Build the measurement grid
#'
#' Measurements are taken at `start, start + step, ...` up to `end`, and each
#' one covers `[lo, hi)` with `hi = lo + window`. Windows overlap whenever
#' `window > step`, are disjoint when the two are equal, and degenerate to
#' sampling the network at a point when `window` is zero.
#'
#' On the default grid the final window is closed on the right, so an event
#' landing exactly on the last observed time is counted rather than silently
#' dropped. A grid whose `end` the caller supplied is taken literally instead,
#' as `tsna::tSnaStats()` does -- which is what makes a truncated range an
#' exact subset of the full series rather than an almost-subset.
#'
#' @param t_min,t_max Observed time range, used for whichever of `start` and
#'   `end` the caller left to the default.
#' @param spec A resolved grid from `.window_spec()`.
#' @return A data frame with `bin`, `lo`, `hi`, `time` (the point at which the
#'   measurement is reported, which is the window's left edge) and `closed`
#'   (whether the window includes its right endpoint).
#' @noRd
.bins <- function(t_min, t_max, spec) {
  start <- spec$start %||% t_min
  if (isTRUE(spec$whole)) {
    hi <- max(spec$end %||% t_max, start)
    return(data.frame(bin = 1L, lo = start, hi = hi, time = start,
                      closed = TRUE, stringsAsFactors = FALSE))
  }
  end   <- spec$end   %||% .default_end(t_min, t_max, spec$step)
  # A grid whose end precedes its start still yields the single measurement
  # at `start`, so that a verb never returns zero rows for a valid network.
  lo <- if (end < start) start else seq(from = start, to = end, by = spec$step)
  closed <- rep(FALSE, length(lo))
  if (is.null(spec$end)) closed[length(lo)] <- TRUE
  data.frame(bin = seq_along(lo), lo = lo, hi = lo + spec$window, time = lo,
             closed = closed, stringsAsFactors = FALSE)
}

#' Build component-qualified measurement bins
#' @param dn A `dynet` object with explicit discontinuous observations.
#' @param spec Resolved measurement specification.
#' @return A grid with an `observation` identifier.
#' @noRd
.observation_bins <- function(dn, spec) {
  observations <- dn$meta$observations
  lower <- spec$start %||% min(observations$start)
  upper <- spec$end %||% max(observations$end)
  observations <- observations[
    lower <= observations$end & upper >= observations$start, , drop = FALSE
  ]
  frames <- lapply(seq_len(nrow(observations)), function(i) {
    component <- observations[i, , drop = FALSE]
    component_start <- max(component$start, lower)
    component_end <- min(component$end, upper)
    if (is.null(spec$phase_start)) {
      first <- component_start
    } else {
      phase <- ceiling(
        (component_start - spec$phase_start) / spec$step - 1e-12
      )
      first <- spec$phase_start + max(0, phase) * spec$step
    }
    if (isTRUE(spec$whole)) {
      return(data.frame(
        observation = component$observation, bin = 1L,
        lo = component_start, hi = max(component_end, component_start),
        time = component_start, closed = TRUE, stringsAsFactors = FALSE
      ))
    }
    last <- if (is.null(spec$end)) {
      .default_end(first, component_end, spec$step)
    } else component_end
    times <- if (first > component_end) numeric() else
      seq(first, last, by = spec$step)
    if (!length(times)) return(NULL)
    closed <- rep(FALSE, length(times))
    if (is.null(spec$end)) closed[length(closed)] <- TRUE
    data.frame(
      observation = component$observation,
      bin = seq_along(times), lo = times,
      hi = pmin(times + spec$window, component_end), time = times,
      closed = closed, stringsAsFactors = FALSE
    )
  })
  frames <- Filter(Negate(is.null), frames)
  out <- if (length(frames)) do.call(rbind, frames) else data.frame(
    observation = integer(), bin = integer(), lo = numeric(), hi = numeric(),
    time = numeric(), closed = logical()
  )
  if (nrow(out)) out$bin <- seq_len(nrow(out))
  rownames(out) <- NULL
  out
}

#' Which edges are active in a given window
#'
#' A spell counts when it overlaps the window at all, so no observed event is
#' lost between windows. The result is then gated on `enc$observed_activity`,
#' so a spell that overlaps the window but falls outside the network's
#' observed support is still excluded.
#' A zero-width window (`spec$window == 0`) instead samples the network at the
#' window's time point, matching `tsna::tSnaStats(aggregate.dur = 0)`; an edge
#' that starts and ends between two sample points is invisible to it.
#'
#' Instantaneous events -- contact logs, and the final post of a thread --
#' belong to the window that contains them under either rule.
#'
#' @param enc Encoded edge list from `.encode()`.
#' @param lo,hi Window boundaries.
#' @param last Whether the window is closed on the right.
#' @param window The window width, which selects the rule.
#' @return A logical vector, one element per edge.
#' @noRd
.active <- function(enc, lo, hi, last = FALSE, window = NULL) {
  inst <- enc$instant
  at_point <- is.numeric(window) && length(window) == 1L && window == 0
  in_bin <- if (last || at_point) {
    enc$start >= lo & enc$start <= hi
  } else {
    enc$start >= lo & enc$start < hi
  }
  out <- if (at_point) {
    enc$start <= lo & enc$end > lo
  } else {
    enc$start < hi & enc$end > lo
  }
  out[inst] <- in_bin[inst]
  out & enc$observed_activity
}

#' Eligible vertices in one reporting window and session scope
#'
#' @param activity Encoded activity from `.encode_vertex_activity()`.
#' @param bin One row from the measurement grid.
#' @param window Reporting-window width.
#' @param session Optional session label. `NULL` applies global rows; a label
#'   applies global rows and matching session rows.
#' @param erase_sessions Whether all session labels are calendar-unioned.
#' @return A fixed-order logical vector.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2),
#'             vertex_spells = data.frame(node = "A", start = 0, end = 1))
#' va <- Dynet:::.encode_vertex_activity(dn)
#' Dynet:::.vertex_eligibility(va,
#'   data.frame(lo = 0, hi = 0, closed = TRUE), 0)
#' @noRd
.vertex_eligibility <- function(activity, bin, window, session = NULL,
                                erase_sessions = FALSE) {
  eligible <- !activity$declared
  if (!length(activity$node)) return(eligible)
  session_rows <- if (erase_sessions || all(is.na(activity$session))) {
    rep(TRUE, length(activity$node))
  } else if (is.null(session)) {
    is.na(activity$session)
  } else {
    is.na(activity$session) | activity$session == session
  }
  instant <- activity$instant
  if (window == 0) {
    active <- activity$start <= bin$lo & activity$end > bin$lo
    active[instant] <- activity$start[instant] == bin$lo
  } else {
    active <- activity$start < bin$hi & activity$end > bin$lo
    point <- activity$start >= bin$lo & activity$start < bin$hi
    if (isTRUE(bin$closed)) point <- point | activity$start == bin$hi
    active[instant] <- point[instant]
  }
  eligible[unique(activity$node[session_rows & active])] <- TRUE
  eligible
}

#' Build the common endpoint-valid state for one snapshot
#'
#' Positive windows independently union vertex and edge activity before
#' inducing; point windows evaluate both at the exact time. Bounded sessions
#' induce within each session before union, collapsed sessions erase labels
#' before induction, and separate sessions return one local state.
#'
#' @param dn Parent `dynet` object.
#' @param enc Encoded observed edge rows.
#' @param bin One-row measurement window.
#' @param window Reporting-window width.
#' @param sessions Session aggregation mode.
#' @param label Current output-session label.
#' @return A list with fixed-order `eligible`, endpoint-filtered edge `active`,
#'   and eligible integer `index`.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' enc <- Dynet:::.encode(dn)
#' Dynet:::.snapshot_state(dn, enc,
#'   data.frame(lo = 1, hi = 1, closed = TRUE, time = 1), 0,
#'   "bounded", "all")
#' @noRd
.snapshot_state <- function(dn, enc, bin, window, sessions, label) {
  raw_active <- .active(
    enc, bin$lo, bin$hi, last = isTRUE(bin$closed), window = window
  )
  activity <- .encode_vertex_activity(dn, enc$names)
  observations <- .observation_table(dn)
  enforce_observation <- any(activity$declared) ||
    isTRUE(dn$meta$observation_explicit) || !is.null(dn$meta$observations)
  if (is.null(observations)) {
    observations <- data.frame(
      start = dn$meta$time_range[["start"]],
      end = dn$meta$time_range[["end"]]
    )
  }
  observed <- if (window == 0) {
    any(bin$lo >= observations$start & bin$lo <= observations$end)
  } else {
    positive <- observations$end > observations$start &
      bin$lo < observations$end & bin$hi > observations$start
    points <- observations$end == observations$start &
      observations$start >= bin$lo &
      (observations$start < bin$hi |
         (isTRUE(bin$closed) & observations$start == bin$hi))
    any(positive | points)
  }
  if (enforce_observation && !observed) {
    eligible <- rep(FALSE, enc$n)
    return(list(eligible = eligible, active = rep(FALSE, length(raw_active)),
                index = integer()))
  }
  if (!any(activity$declared)) {
    eligible <- rep(TRUE, enc$n)
    return(list(eligible = eligible, active = raw_active,
                index = seq_len(enc$n)))
  }
  valid_endpoints <- function(eligible) {
    eligible[enc$from] & eligible[enc$to]
  }
  if (identical(sessions, "collapse")) {
    eligible <- .vertex_eligibility(
      activity, bin, window, erase_sessions = TRUE
    )
    active <- raw_active & valid_endpoints(eligible)
  } else if (identical(sessions, "separate")) {
    eligible <- .vertex_eligibility(activity, bin, window, session = label)
    active <- raw_active & valid_endpoints(eligible)
  } else if (is.null(dn$meta$sessions)) {
    eligible <- .vertex_eligibility(activity, bin, window)
    active <- raw_active & valid_endpoints(eligible)
  } else {
    session_labels <- dn$meta$sessions
    local <- lapply(session_labels, function(one) {
      .vertex_eligibility(activity, bin, window, session = one)
    })
    eligible <- Reduce(`|`, local)
    valid <- rep(FALSE, length(raw_active))
    vapply(seq_along(session_labels), function(i) {
      rows <- enc$session == session_labels[i]
      valid[rows] <<- valid_endpoints(local[[i]])[rows]
      0
    }, numeric(1L))
    active <- raw_active & valid
  }
  list(eligible = eligible, active = active, index = which(eligible))
}

#' Adjacency matrix for one set of active edges
#'
#' Multi-edges are collapsed by summing. With `weighted = TRUE` a cell holds
#' the summed edge weights; otherwise it holds the *number of active spells*
#' joining the pair, which every measure that wants presence rather than
#' volume reduces with `.binary()`.
#'
#' Undirected output is symmetrised with `a + t(a)`, and that changes two
#' things a caller must not assume away. Unweighted undirected cells are
#' forced back to 0/1 afterwards, so the spell count above is a *directed*
#' guarantee only. And the diagonal is summed with itself, so a self-loop kept
#' by `loops = TRUE` appears on an undirected weighted diagonal at twice its
#' recorded weight -- the usual convention for undirected loops, but not the
#' recorded number.
#'
#' @param enc Encoded edge list.
#' @param active Logical vector selecting active edges.
#' @param directed Whether to keep edge direction.
#' @param weighted Whether cells hold summed weights or spell counts.
#' @return A square numeric matrix with vertex names on both margins.
#' @noRd
.adjacency <- function(enc, active, directed, weighted = FALSE) {
  n <- enc$n
  a <- matrix(0, n, n, dimnames = list(enc$names, enc$names))
  if (!any(active)) return(a)
  i <- enc$from[active]
  j <- enc$to[active]
  w <- if (weighted) enc$weight[active] else rep(1, length(i))
  # Aggregating over the linear cell index in one pass is far faster than a
  # loop and keeps multi-edge accumulation exact.
  cell <- (j - 1L) * n + i
  agg <- tapply(w, cell, sum)
  a[as.integer(names(agg))] <- as.numeric(agg)
  if (!directed) {
    a <- a + t(a)
    if (!weighted) a[a > 0] <- 1
  }
  a
}

#' Split a network into per-session encodings
#'
#' @param dn A `dynet` object.
#' @param sessions Session mode.
#' @return A named list of encodings. Length one and named `"all"` unless
#'   `sessions = "separate"`.
#' @noRd
.split_sessions <- function(dn, sessions) {
  if (!identical(sessions, "separate")) {
    return(list(all = .encode(dn)))
  }
  idx <- split(seq_len(nrow(dn$spells)), dn$spells$session)
  lapply(idx, function(rows) .encode(dn, rows))
}

#' The time grid an encoding should be measured on
#' @param enc Encoded edge list.
#' @param dn The parent network, for the default grid.
#' @param spec A resolved grid from `.window_spec()`; the network's own
#'   construction interval is used when absent.
#' @return A data frame of windows from `.bins()`.
#' @noRd
.grid_for <- function(enc, dn, spec = NULL) {
  spec <- spec %||% .window_spec(dn)
  if (!is.null(dn$meta$observations)) {
    return(.observation_bins(dn, spec))
  }
  if (isTRUE(dn$meta$observation_explicit)) {
    return(.bins(
      dn$meta$observation[["start"]], dn$meta$observation[["end"]], spec
    ))
  }
  .bins(min(enc$start), max(enc$end), spec)
}

#' Resolve the default time range for one encoding
#'
#' Explicit observation is one global calendar shared by every session,
#' including sessions whose observed edge view is empty. Legacy objects retain
#' their encoding-local event extrema.
#'
#' @param dn Parent `dynet` object.
#' @param enc Encoded edge list.
#' @return A named numeric vector with `start` and `end`.
#' @examples
#' dn <- dynet(school_contacts)
#' Dynet:::.encoding_time_range(dn, Dynet:::.encode(dn))
#' @noRd
.encoding_time_range <- function(dn, enc) {
  if (isTRUE(dn$meta$observation_explicit)) return(dn$meta$observation)
  c(start = min(enc$start), end = max(enc$end))
}

#' Apply a function across every window of every session
#'
#' The workhorse behind every time-series verb. `fun` receives the encoding,
#' the active-edge mask and the window row, and returns either a single value
#' or a named vector of values; the result is stacked into one long frame.
#'
#' @param dn A `dynet` object.
#' @param sessions Session mode.
#' @param fun Function of `(enc, active, bin)`, plus `state` when `snapshot`
#'   is true.
#' @param spec A resolved measurement grid from `.window_spec()`.
#' @param node_level Whether `fun` returns one value per vertex.
#' @param snapshot Whether to apply declared vertex eligibility and pass the
#'   resulting snapshot state to `fun`.
#' @return A long data frame with `session`, `time`, optionally `node`, plus
#'   `measure` and `value`.
#' @examples
#' dn <- dynet(data.frame(from = "A", to = "B", start = 0, end = 2))
#' Dynet:::.over_bins(dn, "bounded", function(enc, active, bin) {
#'   c(active_edges = sum(active))
#' })
#' @noRd
.over_bins <- function(dn, sessions, fun, spec = NULL, node_level = FALSE,
                       snapshot = FALSE) {
  spec  <- spec %||% .window_spec(dn)
  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    grid <- .grid_for(enc, dn, spec)
    n_bin <- nrow(grid)
    per_bin <- lapply(seq_len(n_bin), function(k) {
      bin <- grid[k, , drop = FALSE]
      if (snapshot) {
        state <- .snapshot_state(dn, enc, bin, spec$window, sessions, label)
        val <- fun(enc, state$active, bin, state)
      } else {
        act <- .active(enc, bin$lo, bin$hi, last = bin$closed,
                       window = spec$window)
        val <- fun(enc, act, bin)
      }
      if (node_level) {
        if ("observation" %in% names(grid)) {
          data.frame(
            session = label, observation = grid$observation[k],
            time = grid$time[k], node = enc$names,
            measure = rep(names(val), each = enc$n),
            value = unlist(val, use.names = FALSE), stringsAsFactors = FALSE
          )
        } else {
          data.frame(
            session = label, time = grid$time[k], node = enc$names,
            measure = rep(names(val), each = enc$n),
            value = unlist(val, use.names = FALSE), stringsAsFactors = FALSE
          )
        }
      } else {
        if ("observation" %in% names(grid)) {
          data.frame(
            session = label, observation = grid$observation[k],
            time = grid$time[k], measure = names(val), value = unname(val),
            stringsAsFactors = FALSE
          )
        } else {
          data.frame(
            session = label, time = grid$time[k],
            measure = names(val), value = unname(val),
            stringsAsFactors = FALSE
          )
        }
      }
    })
    do.call(rbind, per_bin)
  }, parts, names(parts))
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  out
}
