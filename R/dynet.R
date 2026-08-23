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
#' @param loops Whether to keep self-loops. `FALSE` drops them with a message,
#'   which is almost always what relational logs need.
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
#' @export
dynet <- function(data,
                  from = NULL, to = NULL,
                  start = NULL, end = NULL, duration = NULL, time = NULL,
                  thread = NULL, actor = NULL, group = NULL,
                  session = NULL, weight = NULL, nodes = NULL, groups = NULL,
                  format = c("auto", "interval", "contact", "threaded",
                             "copresence"),
                  directed = TRUE, interval = 1, time_unit = "auto",
                  loops = FALSE) {

  format <- match.arg(format)
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

  e <- e[order(e$start, e$end, e$from, e$to), , drop = FALSE]
  rownames(e) <- NULL

  node_table <- .build_nodes(e, nodes, built$node_pool)

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

  .as_netobject(
    spells   = e,
    nodes    = node_table,
    directed = directed,
    groups   = groups,
    meta = list(
      type       = "temporal",
      source     = "dynet",
      format     = format,
      time_range = c(start = t_min, end = t_max),
      time_unit  = built$time_unit,
      origin     = built$origin,
      interval   = interval,
      n_bins     = max(1L, as.integer(ceiling((t_max - t_min) / interval))),
      sessions   = if (all(is.na(e$session))) NULL else sort(unique(e$session)),
      call       = match.call()
    )
  )
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
#' @return An object of class `c("dynet", "netobject", "cograph_network")`.
#' @keywords internal
.as_netobject <- function(spells, nodes, directed, groups, meta) {
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
      spells      = spells
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
  if (is.null(s)) rep(NA_character_, nrow(data)) else as.character(data[[s]])
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
