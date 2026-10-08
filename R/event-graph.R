# ===========================================================================
# event_graph() — events as vertices, temporal adjacency as arcs
# ===========================================================================

#' The event graph of a temporal network
#'
#' @description
#' Builds the event graph: every spell becomes a vertex, and an arc joins two
#' events that share a vertex and follow one another in time there. A
#' directed path in it is a time-respecting chain of events, so questions
#' about temporal reachability, waiting times and cascades become questions
#' about an ordinary static directed acyclic graph. It needs no time grid.
#' The time-expanded graph of [projection()] is the other static
#' representation; it has one vertex per vertex and time slice instead.
#'
#' @param dn A temporal network from [dynet()].
#' @param sessions How to treat sessions: `"bounded"` (the default) and
#'   `"separate"` never join events across a session boundary, `"collapse"`
#'   ignores sessions. `"separate"` also reports a `session` column, and on
#'   a network built without a session column it raises `dynet_no_sessions`.
#' @param delta The longest admissible wait at the shared vertex, in the
#'   network's time unit: an arc requires the later event to start no more
#'   than `delta` after the earlier one ends. `Inf`, the default, admits any
#'   wait; zero admits none, since a wait is always positive. A single
#'   non-negative number, or `dynet_bad_input` is raised.
#' @param adjacency `"all"` (the default) joins an event to every admissible
#'   successor; `"next"` joins it only to the earliest admissible successors
#'   at each shared vertex (every successor starting at that earliest time).
#'   See Details for what each one preserves.
#' @param direction On a directed network, `"respect"` (the default) joins
#'   an event to a successor only through the earlier event's target and the
#'   later event's source, so an arc is a hop that could pass something
#'   along. `"ignore"` joins through any shared endpoint. An undirected
#'   network is read as `"ignore"` either way.
#' @param events `"ties"` (the default) makes every spell an event.
#'   `"messages"` merges the spells that share their source, start, end and
#'   session into one event, a message from one source to several targets,
#'   such as an email to several recipients or an action addressed to a whole
#'   group (`dynet(format = "broadcast")`). A message arrives at all its
#'   targets and leaves from its source, so a later event follows it when it
#'   leaves any one of the targets.
#' @param loops Whether self-loop spells take part. `FALSE`, the default,
#'   drops them before adjacency is computed; a kept self-loop is adjacent at
#'   its one vertex.
#'
#' @return An object of class `dynet_event_graph`. Take its tables with
#'   `as.data.frame(x)` for the events, one row per spell (or per message),
#'   with `event`, `session` (under `sessions = "separate"`), `from`, `to`
#'   (for a message, its targets joined by commas), `n_targets` (messages
#'   only), `start`, `end`, `duration`, `weight`, `spell` (the spell the
#'   event came from, or a message's first spell, numbered in the order
#'   [dynet()] built them) and the tie attributes of that spell, except one
#'   whose name is already among these columns; and `as.data.frame(x, what = "adjacencies")` for the
#'   arcs, one row per pair of events and shared vertex, with `from_event`,
#'   `to_event` (the numbers of the two events in the event table), `via`
#'   (the shared vertex), `first` and `second` (the two events written as
#'   `from->to`, or `from--to` on an undirected network; a message to
#'   several targets as `from->9 targets`), `from_time` (when
#'   the earlier event ends), `to_time` (when the later one starts), `wait`,
#'   under `sessions = "separate"` `session`, and each tie attribute of the
#'   two events as `first_<name>` and `second_<name>`. [summary()] gives one row per event
#'   and [plot()] draws the graph.
#'
#' @details
#' Events are ordered by `start`, then `end`, `from` and `to`, and numbered in
#' that order. Event `e1` precedes `e2` at a shared vertex `v` when `e2`
#' starts strictly after `e1` ends, and no more than `delta` later. An event
#' therefore occupies its whole spell, as in the event graphs of Kivela et
#' al. (2018): something carried by it is available at its endpoints once it
#' has ended. Because the later event must start strictly after, two
#' instantaneous events at the same instant are never adjacent, nor is an
#' event that starts at the very instant another ends; every wait is
#' positive, the graph is acyclic, and numbering events by start is a
#' topological order. This is the rule of Reticula (Badie-Modiri and
#' Kivela, 2023), the reference implementation of the construct.
#'
#' Two events that share both endpoints are joined once per shared vertex,
#' so they produce two adjacency rows with different `via`. This is correct:
#' each row is a different way the second event can follow the first.
#'
#' With `adjacency = "all"` every arc is an admissible hop and every chain of
#' admissible hops is a path, so a path from an event leaving `u` to an event
#' arriving at `w` exists exactly when `w` can be reached from `u` through
#' events taken one after another. On contact data (instantaneous events),
#' that is the reachability of [paths()] with a `traversal_time` shorter than
#' the smallest gap between distinct contact times. It is not the
#' reachability of [paths()] on interval spells, which may be entered at any
#' instant while they are active rather than only as a whole. `"next"`
#' keeps the earliest successors only, the consecutive-event adjacency of
#' Kovanen et al. (2011) used for temporal motifs. It is much sparser, and
#' with `delta = Inf` on an undirected network of instantaneous contacts it
#' reaches the same events as `"all"`. Otherwise it can lose reachability: on
#' a directed network the earliest departure from a vertex need not lead
#' where a later one does, and with interval spells the earliest successor
#' can end after a later one has started.
#'
#' No R package computes this construct, so it is checked against Dynet's own
#' path search and against direct enumeration of event pairs.
#'
#' @section Conditions:
#' Errors: `dynet_bad_input` for a `dn` that is not a `dynet`, a `delta` that
#' is not one non-negative number, or a `loops` that is not one logical
#' value; `dynet_no_sessions` for `sessions = "separate"` without a session
#' column; `dynet_empty_network` when no spell remains once self-loops are
#' dropped.
#'
#' @references
#' Kivela, M., Cambe, J., Saramaki, J., & Karsai, M. (2018). Mapping temporal-
#' network percolation to weighted, static event graphs. *Scientific
#' Reports*, 8, 12357. \doi{10.1038/s41598-018-29577-2}
#'
#' Mellor, A. (2018). The temporal event graph. *Journal of Complex Networks*,
#' 6(4), 639-659. \doi{10.1093/comnet/cnx048}
#'
#' Badie-Modiri, A., & Kivela, M. (2023). Reticula: A temporal network and
#' hypergraph analysis software package. *SoftwareX*, 21, 101301.
#' \doi{10.1016/j.softx.2022.101301}
#'
#' Kovanen, L., Karsai, M., Kaski, K., Kertesz, J., & Saramaki, J. (2011).
#' Temporal motifs in time-dependent networks. *Journal of Statistical
#' Mechanics: Theory and Experiment*, P11005.
#' \doi{10.1088/1742-5468/2011/11/P11005}
#'
#' @examples
#' dn <- dynet(school_contacts)
#' eg <- event_graph(dn, delta = 1)
#' eg
#' as.data.frame(eg, what = "adjacencies")
#' summary(eg)
#'
#' # Only the earliest successors, as for temporal motifs
#' sparse <- event_graph(dn, delta = 1, adjacency = "next")
#' sparse
#' @seealso [projection()] for the time-expanded graph, [paths()] for
#'   time-respecting paths between vertices.
#' @export
event_graph <- function(dn, sessions = c("bounded", "collapse", "separate"),
                        delta = Inf, adjacency = c("all", "next"),
                        direction = c("respect", "ignore"), loops = FALSE,
                        events = c("ties", "messages")) {
  sessions <- match.arg(sessions)
  adjacency <- match.arg(adjacency)
  direction <- match.arg(direction)
  unit <- match.arg(events)
  .check_dynet(dn, sessions)
  .check(
    "`delta` must be a single non-negative number; `Inf` admits any wait." =
      is.numeric(delta) && length(delta) == 1L && !is.na(delta) && delta >= 0,
    "`loops` must be a single TRUE or FALSE." =
      is.logical(loops) && length(loops) == 1L && !is.na(loops)
  )

  spells <- dn$spells
  if (!loops) spells <- spells[spells$from != spells$to, , drop = FALSE]
  if (!nrow(spells)) {
    stop(errorCondition(
      "No events remain to build an event graph from; every spell is a self-loop, which `loops = FALSE` drops.",
      class = "dynet_empty_network", call = NULL))
  }
  # A deterministic total order, never input order: the raw spell id breaks
  # the last ties between identical rows.
  spells <- spells[order(spells$start, spells$end, spells$from, spells$to,
                         spells$.raw_spell), , drop = FALSE]
  walled <- !is.null(dn$meta$sessions) && !identical(sessions, "collapse")
  tie_block <- if (walled) {
    ifelse(is.na(spells$session), "\r", as.character(spells$session))
  } else rep("", nrow(spells))

  # The event each tie belongs to. A message is every tie from one source
  # over one spell in one session: one action addressed to several targets.
  # Ties are in time order, so numbering events by first appearance keeps
  # events in time order too.
  tie_event <- if (identical(unit, "messages")) {
    key <- paste(spells$session, spells$from, spells$start, spells$end,
                 sep = "\r")
    match(key, unique(key))
  } else seq_len(nrow(spells))
  n <- max(tie_event)
  lead <- match(seq_len(n), tie_event)
  start <- spells$start[lead]
  end <- spells$end[lead]
  block <- tie_block[lead]
  targets <- if (identical(unit, "messages")) {
    as.character(tapply(spells$to, factor(tie_event, levels = seq_len(n)),
                        function(v) paste(sort(unique(v)), collapse = ",")))
  } else spells$to
  n_targets <- tabulate(tie_event, nbins = n)

  events <- data.frame(
    event = seq_len(n),
    session = spells$session[lead],
    from = spells$from[lead], to = targets,
    start = start, end = end,
    duration = end - start,
    weight = spells$weight[lead],
    spell = spells$.raw_spell[lead],
    stringsAsFactors = FALSE
  )
  if (identical(unit, "messages")) {
    events <- data.frame(events[c("event", "session", "from", "to")],
                         n_targets = n_targets,
                         events[c("start", "end", "duration", "weight",
                                  "spell")],
                         stringsAsFactors = FALSE)
  }
  if (!identical(sessions, "separate")) events$session <- NULL
  # Tie attributes ride along, so an event can be read by what it was. A name
  # the event table already uses keeps its event-graph meaning. A message
  # takes them from its first tie.
  attributes_kept <- setdiff(names(spells), c(.event_spell_fields, names(events)))
  events[attributes_kept] <- spells[lead, attributes_kept, drop = FALSE]

  oriented <- dn$directed && identical(direction, "respect")
  # Where something carried by an event is available afterwards (`arrive`),
  # and where an event can pick it up (`leave`): the targets and the source
  # of each of its ties. An undirected or direction-ignoring event does both
  # at every endpoint; an endpoint shared by several ties counts once.
  ends_of <- function(event, vertex) {
    pairs <- unique(data.frame(event = event, vertex = vertex,
                               stringsAsFactors = FALSE))
    list(event = pairs$event, vertex = pairs$vertex)
  }
  arrive <- if (oriented) ends_of(tie_event, spells$to) else
    ends_of(c(tie_event, tie_event), c(spells$from, spells$to))
  leave <- if (oriented) ends_of(tie_event, spells$from) else arrive

  arrive_key <- paste(block[arrive$event], arrive$vertex, sep = "\r")
  leave_key <- paste(block[leave$event], leave$vertex, sep = "\r")
  arrivals <- split(arrive$event, arrive_key)
  departures <- split(leave$event, leave_key)
  vertex_of <- stats::setNames(leave$vertex, leave_key)
  shared <- intersect(names(arrivals), names(departures))

  arcs <- lapply(shared, function(key) {
    .event_successors(arrivals[[key]], sort(departures[[key]]),
                      start, end, delta, adjacency, vertex_of[[key]])
  })
  adjacencies <- do.call(rbind, c(list(.empty_event_arcs()), arcs))
  adjacencies <- adjacencies[order(adjacencies$from_event,
                                   adjacencies$to_event, adjacencies$via),
                             , drop = FALSE]
  from_time <- end[adjacencies$from_event]
  to_time <- start[adjacencies$to_event]
  wait <- to_time - from_time
  adjacencies$from_time <- from_time
  adjacencies$to_time <- to_time
  adjacencies$wait <- wait
  if (identical(sessions, "separate")) {
    adjacencies$session <- events$session[adjacencies$from_event]
  }
  # Each arc says what its two events were, so a row reads without a lookup
  # in the event table: who reached whom in each, and their tie attributes.
  joint <- if (isTRUE(dn$directed)) "->" else "--"
  reached <- ifelse(n_targets > 1L, sprintf("%d targets", n_targets), targets)
  tie <- paste(events$from, reached, sep = joint)
  described <- data.frame(first = tie[adjacencies$from_event],
                          second = tie[adjacencies$to_event],
                          stringsAsFactors = FALSE)
  adjacencies <- data.frame(
    adjacencies[c("from_event", "to_event", "via")], described,
    adjacencies[setdiff(names(adjacencies), c("from_event", "to_event", "via"))],
    stringsAsFactors = FALSE)
  adjacencies[paste0("first_", attributes_kept)] <-
    lapply(events[attributes_kept], function(v) v[adjacencies$from_event])
  adjacencies[paste0("second_", attributes_kept)] <-
    lapply(events[attributes_kept], function(v) v[adjacencies$to_event])
  rownames(adjacencies) <- NULL
  .check("Internal event graph produced a wait that is not positive." =
           all(adjacencies$wait > 0))

  meta <- list(
    n_events = n, n_adjacencies = nrow(adjacencies), delta = delta,
    adjacency = adjacency, direction = if (oriented) "respect" else "ignore",
    loops = loops, sessions = sessions, source_directed = dn$directed,
    events = unit,
    time_unit = dn$meta$time_unit, origin = dn$meta$origin,
    event_rule = "whole_spell_end_to_start",
    simultaneity_rule = "strictly_later_start",
    session_rule = if (walled) "no_arc_across_sessions" else "sessions_ignored"
  )
  structure(list(events = events, adjacencies = adjacencies, meta = meta),
            class = "dynet_event_graph")
}

# Spell columns that the event table already represents or that only the
# spell table owns; every other spell column is a tie attribute.
.event_spell_fields <- c("from", "to", "start", "end", "duration", "weight",
                         "session", "onset_censored", "terminus_censored",
                         ".raw_spell")

#' Successors of the events arriving at one vertex
#'
#' The departures are sorted by start, so the admissible successors of an
#' arrival form one contiguous run, found by two `findInterval()` calls.
#'
#' @param arriving Event ids that make the vertex available when they end.
#' @param leaving Event ids that can leave the vertex, sorted by start.
#' @param start,end Start and end of every event, indexed by id.
#' @param delta Longest admissible wait.
#' @param adjacency `"all"` or `"next"`.
#' @param vertex Name of the shared vertex.
#' @return A data frame with `from_event`, `to_event` and `via`.
#' @noRd
.event_successors <- function(arriving, leaving, start, end, delta,
                              adjacency, vertex) {
  s <- start[leaving]
  a_end <- end[arriving]
  # Earliest admissible start: strictly after the arrival's end, beyond
  # time tolerance of it.
  first <- findInterval(a_end + .time_tol_each(a_end, a_end), s) + 1L
  last <- if (is.finite(delta)) {
    findInterval(a_end + delta + .time_tol_each(a_end + delta, a_end), s)
  } else rep(length(s), length(arriving))
  if (identical(adjacency, "next")) {
    has <- first <= last
    earliest <- s[pmin(first, length(s))]
    tie_end <- findInterval(earliest + .time_tol_each(earliest, earliest), s)
    last[has] <- pmin(last[has], tie_end[has])
  }
  count <- pmax(0L, last - first + 1L)
  if (!sum(count)) return(.empty_event_arcs())
  data.frame(
    from_event = rep(arriving, count),
    to_event = leaving[sequence(count, from = first)],
    via = vertex,
    stringsAsFactors = FALSE
  )
}

#' A zero-row adjacency table with the right columns
#' @return A data frame with `from_event`, `to_event` and `via`.
#' @noRd
.empty_event_arcs <- function() {
  data.frame(from_event = integer(), to_event = integer(),
             via = character(), stringsAsFactors = FALSE)
}

#' Tidy tables from an event graph
#'
#' @param x An event graph returned by [event_graph()].
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param what `"events"`, the default, returns one row per event;
#'   `"adjacencies"` returns one row per arc and shared vertex.
#' @param ... Ignored.
#' @return A plain data frame; the columns are listed under [event_graph()].
#' @examples
#' dn <- dynet(school_contacts)
#' eg <- event_graph(dn, delta = 1)
#' as.data.frame(eg)
#' as.data.frame(eg, what = "adjacencies")
#' @export
as.data.frame.dynet_event_graph <- function(
    x, row.names = NULL, optional = FALSE,
    what = c("events", "adjacencies"), ...) {
  what <- match.arg(what)
  out <- x[[what]]
  attributes(out) <- list(
    names = names(out), row.names = seq_len(nrow(out)), class = "data.frame"
  )
  out
}

#' Print an event graph
#' @param x An event graph returned by [event_graph()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' dn <- dynet(school_contacts)
#' event_graph(dn, delta = 1)
#' @export
print.dynet_event_graph <- function(x, ...) {
  meta <- x$meta
  cat(sprintf("# Event graph | %d events | %d adjacencies\n",
              meta$n_events, meta$n_adjacencies))
  cat(sprintf("# delta %s | adjacency \"%s\" | direction \"%s\" | %s\n",
              format(meta$delta), meta$adjacency, meta$direction,
              meta$session_rule))
  if (meta$n_adjacencies) {
    shown <- intersect(c("from_event", "to_event", "first", "second", "via",
                         "wait", "session"), names(x$adjacencies))
    print(utils::head(x$adjacencies[shown], 6L), row.names = FALSE)
    cat("# as.data.frame(x, what = \"adjacencies\") adds the times and the tie attributes of both events.\n")
  } else {
    cat("# No two events follow one another within `delta`.\n")
  }
  invisible(x)
}

#' Summarise an event graph
#'
#' @param object An event graph returned by [event_graph()].
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per event: `event`, its `session`
#'   (under `sessions = "separate"`), its start `time`, its endpoints `from` and `to`, `in_degree` (the distinct events
#'   it follows), `out_degree` (the distinct events that follow it), and
#'   `mean_wait`, the mean wait before those successors start, followed by the
#'   event's tie attributes. `mean_wait` is `NA` for an event with no
#'   successor, where no wait is defined.
#' @examples
#' dn <- dynet(school_contacts)
#' summary(event_graph(dn, delta = 1))
#' @export
summary.dynet_event_graph <- function(object, ...) {
  events <- object$events
  n <- nrow(events)
  # A pair joined through two shared vertices is one neighbour, not two.
  pairs <- unique(object$adjacencies[, c("from_event", "to_event", "wait")])
  out_degree <- tabulate(pairs$from_event, nbins = n)
  total_wait <- vapply(split(pairs$wait, factor(pairs$from_event,
                                                levels = seq_len(n))),
                       sum, numeric(1L))
  out <- data.frame(
    event = events$event,
    time = events$start,
    from = events$from,
    to = events$to,
    in_degree = tabulate(pairs$to_event, nbins = n),
    out_degree = out_degree,
    mean_wait = ifelse(out_degree > 0L, total_wait / pmax(out_degree, 1L),
                       NA_real_),
    stringsAsFactors = FALSE
  )
  if ("session" %in% names(events)) {
    out <- data.frame(out[1L], session = events$session, out[-1L],
                      stringsAsFactors = FALSE)
  }
  attributes_kept <- setdiff(names(events), c("event", "session", "from", "to",
                                              "start", "end", "duration",
                                              "weight", "spell"))
  out[attributes_kept] <- events[attributes_kept]
  out
}

#' Plot an event graph
#'
#' `type = "storyline"`, the default, draws the event graph as a storyline
#' (Tanahashi and Ma, 2012): every actor
#' is a line through time, and every event is a column that gathers the lines
#' of its two endpoints in a light crimson capsule. The stretch of an actor's
#' line between two of its events is solid when the event graph joins them
#' through that actor, so something the actor received in the first could be
#' passed on in the second, and dashed when it does not, because the wait
#' exceeds `delta` or the direction of the events forbids it. On a directed
#' network an arrow in each column runs from the source to the target.
#'
#' Columns are events in time order, spaced by order rather than by elapsed
#' time, and labelled with their start. Lines are ordered by the barycentre
#' rule (Sugiyama et al., 1981) over repeated sweeps, keeping the ordering
#' with the fewest crossings, as in the storyline of the `hypergraphs`
#' package. Each actor has its own colour and point shape, so no actor is
#' told by colour alone.
#'
#' `type = "events"` draws the events themselves as the vertices. Each event
#' is a point at its start time, and each adjacency is a line from the
#' earlier event to the later one. With `rows = "actor"`, the default, every
#' source has its own row, in the order of its first event, so a line runs
#' from the row of the actor whose event was taken further to the row of the
#' actor who took it. With `rows = "chain"`, events are grouped into relay
#' chains, the weakly connected components of the event graph among the
#' events drawn, every chain has its own row ordered by its first event, and
#' adjacencies are arcs above the row; a row of one point is an event that
#' relays nothing and continues nothing within `delta`. `color_by` colours
#' and shapes the points by a column of the event table, such as a tie
#' attribute. An event graph of messages (`events = "messages"`) is drawn
#' this way by default, because a message gathers several actors at once
#' and has no storyline.
#'
#' @param x An event graph returned by [event_graph()].
#' @param type `"storyline"` (the default for ties) draws actors as lines
#'   through the events; `"events"` (the default for messages) draws events
#'   as points joined by lines. A storyline of messages raises
#'   `dynet_bad_input`.
#' @param top The number of actors drawn, those in the most events (ties by
#'   name); `8` by default. `NULL` draws every actor. In a storyline, columns
#'   are the events that involve at least one drawn actor; in the events view
#'   with `rows = "actor"`, the events whose source is drawn. Ignored by
#'   `rows = "chain"`, which draws every event in the period.
#' @param rows For `type = "events"`, `"actor"` (the default) gives every
#'   source a row; `"chain"` gives every relay chain a row.
#' @param color_by For `type = "events"`, the name of a column of
#'   `as.data.frame(x)` (for example a tie attribute, `"from"` or `"to"`)
#'   whose values colour and shape the points. `NULL`, the default, draws
#'   every point alike.
#' @param labels For `type = "events"`, whether to write the event under
#'   each point: `->to` with `rows = "actor"`, whose row already names the
#'   source, and `from->to` with `rows = "chain"`. `FALSE` by default.
#' @param start,end Draw only events starting in this period. Default to the
#'   whole network.
#' @param palette Actor line colours, or under `type = "events"` the
#'   colours of the `color_by` values: `"okabe"` (the default; Okabe-Ito
#'   without its yellow, which is too faint for a thin line), `"extended"`,
#'   `"many"`, a vector of colours recycled over the actors, or a function of
#'   `n` returning `n` colours.
#' @param node_size Size of the points where a line meets its events; `2.5`
#'   by default.
#' @param node_shape Point shapes, recycled over the actors (or the
#'   `color_by` values); ggplot shape codes. The default cycles nine shapes,
#'   so the first 72 actors differ in their pair of colour and shape.
#' @param line_width,line_alpha Width and opacity of the actor lines, or of
#'   the arcs under `type = "events"`; `0.9` and `1` by default.
#' @param relay_style,no_relay_style Line types of a stretch that is an
#'   adjacency of the event graph and of one that is not; `"solid"` and
#'   `"22"` (dashed) by default. Any ggplot line type.
#' @param capsule_color,capsule_alpha,capsule_width Colour, opacity and width
#'   of the capsule gathering the endpoints of an event; a light crimson
#'   (`"#DC143C"` at `0.16`) of width `6` by default.
#' @param arrows Whether to draw the source-to-target arrow in each column of
#'   a directed network; `TRUE` by default.
#' @param arrow_color,arrow_width,arrow_size Colour, line width and head
#'   length (in centimetres) of those arrows; `"grey40"`, `0.4` and `0.12` by
#'   default. Under `type = "events"`, `arrow_color` and `arrow_size` style
#'   the arcs and their heads, and `arrows = FALSE` drops the heads.
#' @param base_size Base font size of the theme; `12` by default.
#' @param label_size Size, in points, of the time labels under the columns,
#'   or of the `labels` text under `type = "events"`; `7` by default.
#' @param ... Ignored.
#' @return A `ggplot` object, so titles, themes and scales can be added with
#'   `+`. Raises `dynet_bad_input` for a malformed `top`, `start`, `end`,
#'   `color_by`, `labels` or styling argument, `dynet_bad_palette` for an unusable `palette`,
#'   `capsule_color` or `arrow_color`, and `dynet_empty_result` when no event
#'   starts in the period.
#' @references
#' Tanahashi, Y., & Ma, K.-L. (2012). Design considerations for optimizing
#' storyline visualizations. *IEEE Transactions on Visualization and Computer
#' Graphics*, 18(12), 2679-2688. \doi{10.1109/TVCG.2012.212}
#'
#' Sugiyama, K., Tagawa, S., & Toda, M. (1981). Methods for visual
#' understanding of hierarchical system structures. *IEEE Transactions on
#' Systems, Man, and Cybernetics*, 11(2), 109-125.
#' \doi{10.1109/TSMC.1981.4308636}
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "B", "C", "A", "B"), to = c("B", "C", "D", "C", "D"),
#'   time = c(1, 2, 3, 4, 5)
#' ))
#' eg <- event_graph(dn, delta = 1.5)
#' plot(eg)
#' plot(eg, type = "events", labels = TRUE)
#' @export
plot.dynet_event_graph <- function(x, type = c("storyline", "events"),
                                   top = 8L, start = NULL, end = NULL,
                                   rows = c("actor", "chain"),
                                   color_by = NULL, labels = FALSE,
                                   palette = "okabe", node_size = 2.5,
                                   node_shape = c(16, 17, 15, 18, 8, 4, 3, 1, 0),
                                   line_width = 0.9, line_alpha = 1,
                                   relay_style = "solid",
                                   no_relay_style = "22",
                                   capsule_color = "#DC143C",
                                   capsule_alpha = 0.16, capsule_width = 6,
                                   arrows = TRUE, arrow_color = "grey40",
                                   arrow_width = 0.4, arrow_size = 0.12,
                                   base_size = 12, label_size = 7, ...) {
  positive <- function(v) is.numeric(v) && length(v) == 1L && is.finite(v) &&
    v > 0
  unit_interval <- function(v) is.numeric(v) && length(v) == 1L &&
    is.finite(v) && v >= 0 && v <= 1
  one_string <- function(v) is.character(v) && length(v) == 1L && !is.na(v)
  messages <- identical(x$meta$events, "messages")
  type <- if (missing(type) && messages) "events" else match.arg(type)
  rows <- match.arg(rows)
  if (messages && identical(type, "storyline")) {
    stop(errorCondition(
      "A storyline draws events between two actors; a message reaches several at once. Use `type = \"events\"`.",
      class = "dynet_bad_input", call = NULL))
  }
  .check(
    "`color_by` must be NULL or the name of one column of the event table." =
      is.null(color_by) || (one_string(color_by) &&
                              color_by %in% names(x$events)),
    "`labels` must be TRUE or FALSE." =
      is.logical(labels) && length(labels) == 1L && !is.na(labels),
    "`top` must be NULL or one positive whole number." =
      is.null(top) || (is.numeric(top) && length(top) == 1L &&
                         is.finite(top) && top >= 1 && top == round(top)),
    "`start` must be NULL or one number." =
      is.null(start) || (is.numeric(start) && length(start) == 1L &&
                           !is.na(start)),
    "`end` must be NULL or one number." =
      is.null(end) || (is.numeric(end) && length(end) == 1L && !is.na(end)),
    "`node_size` must be one positive number." = positive(node_size),
    "`node_shape` must be one or more ggplot shape codes." =
      is.numeric(node_shape) && length(node_shape) >= 1L &&
        all(is.finite(node_shape)),
    "`line_width` must be one positive number." = positive(line_width),
    "`line_alpha` must be one number between 0 and 1." =
      unit_interval(line_alpha),
    "`relay_style` must be one line type." = one_string(relay_style),
    "`no_relay_style` must be one line type." = one_string(no_relay_style),
    "`capsule_alpha` must be one number between 0 and 1." =
      unit_interval(capsule_alpha),
    "`capsule_width` must be one positive number." = positive(capsule_width),
    "`arrows` must be TRUE or FALSE." =
      is.logical(arrows) && length(arrows) == 1L && !is.na(arrows),
    "`arrow_width` must be one positive number." = positive(arrow_width),
    "`arrow_size` must be one positive number." = positive(arrow_size),
    "`base_size` must be one positive number." = positive(base_size),
    "`label_size` must be one positive number." = positive(label_size)
  )
  capsule_color <- .check_colours(capsule_color[1L])
  arrow_color <- .check_colours(arrow_color[1L])
  events <- x$events
  in_period <- .time_geq(events$start, start %||% -Inf) &
    .time_leq(events$start, end %||% Inf)
  events <- events[in_period, , drop = FALSE]
  if (!nrow(events)) {
    stop(errorCondition("No event starts between `start` and `end`.",
                        class = "dynet_empty_result", call = NULL))
  }
  if (identical(type, "events")) {
    return(.plot_event_chains(
      x, events, rows = rows, top = top, color_by = color_by,
      labels = labels, palette = palette,
      node_size = node_size, node_shape = node_shape,
      line_width = line_width, line_alpha = line_alpha,
      arrows = arrows, arrow_color = arrow_color, arrow_size = arrow_size,
      base_size = base_size, label_size = label_size))
  }
  # One membership per event and endpoint; a self-loop has one.
  m <- unique(data.frame(
    node = c(events$from, events$to),
    event = rep(events$event, 2L),
    stringsAsFactors = FALSE
  ))
  counts <- table(m$node)
  ranked <- names(counts)[order(-as.integer(counts), names(counts))]
  chosen <- if (is.null(top)) ranked else utils::head(ranked, top)
  m <- m[m$node %in% chosen, , drop = FALSE]
  columns <- sort(unique(m$event))
  m$col <- match(m$event, columns)
  n_col <- length(columns)
  rows <- .storyline_layout(m$node, m$col, n_col)
  hits <- merge(m[, c("node", "col", "event")], rows, by = c("node", "col"))

  # Each stretch of a line joins two consecutive events of one actor; it is
  # solid when the event graph has that adjacency through the actor.
  arcs <- paste(x$adjacencies$from_event, x$adjacencies$to_event,
                x$adjacencies$via)
  stretches <- do.call(rbind, c(list(NULL), lapply(chosen, function(v) {
    own <- sort(hits$col[hits$node == v])
    if (length(own) < 2L) return(NULL)
    line <- rows[rows$node == v, , drop = FALSE]
    do.call(rbind, lapply(seq_len(length(own) - 1L), function(k) {
      a <- own[[k]]
      b <- own[[k + 1L]]
      inner <- line[line$col > a & line$col < b, , drop = FALSE]
      relay <- paste(columns[[a]], columns[[b]], v) %in% arcs
      data.frame(
        part = paste(v, a, b, sep = "\r"), node = v,
        x = c(a, rep(inner$col, each = 2L) + c(-0.3, 0.3), b),
        y = c(line$y[line$col == a], rep(inner$y, each = 2L),
              line$y[line$col == b]),
        lt = if (relay) "relay" else "no relay",
        stringsAsFactors = FALSE
      )
    }))
  })))

  bars <- stats::aggregate(y ~ col, hits, function(v) c(low = min(v), high = max(v)))
  bars <- data.frame(x = bars$col, low = bars$y[, "low"],
                     high = bars$y[, "high"])
  bars <- bars[bars$high > bars$low, , drop = FALSE]
  shown <- events[match(columns, events$event), , drop = FALSE]
  arrow_rows <- if (arrows && isTRUE(x$meta$source_directed)) {
    both <- shown$from %in% chosen & shown$to %in% chosen &
      shown$from != shown$to
    k <- which(both)
    data.frame(
      x = k,
      y = rows$y[match(paste(shown$from[k], k), paste(rows$node, rows$col))],
      yend = rows$y[match(paste(shown$to[k], k), paste(rows$node, rows$col))]
    )
  } else data.frame(x = numeric(), y = numeric(), yend = numeric())

  colours <- stats::setNames(if (identical(palette, "okabe")) {
    rep_len(setdiff(.okabe, "#F0E442"), length(chosen))
  } else .dyn_palette(palette, length(chosen)), chosen)
  shapes <- stats::setNames(rep_len(node_shape, length(chosen)), chosen)
  # Label at most about 40 columns, evenly, so the axis stays legible.
  every <- max(1L, ceiling(n_col / 40L))
  breaks <- seq(1L, n_col, by = every)
  labels <- format(signif(shown$start[breaks], 4L), trim = TRUE)
  delta <- x$meta$delta

  plot <- ggplot2::ggplot()
  if (nrow(bars)) {
    plot <- plot + ggplot2::geom_segment(
      data = bars,
      ggplot2::aes(x = x, xend = x, y = low - 0.25, yend = high + 0.25),
      # A light crimson wash, in a hue no actor line takes, so the capsule
      # reads as the meeting without competing with the lines through it.
      linewidth = capsule_width, lineend = "round", colour = capsule_color,
      alpha = capsule_alpha)
  }
  if (nrow(arrow_rows)) {
    plot <- plot + ggplot2::geom_segment(
      data = arrow_rows, ggplot2::aes(x = x, xend = x, y = y, yend = yend),
      colour = arrow_color, linewidth = arrow_width,
      arrow = ggplot2::arrow(length = ggplot2::unit(arrow_size, "cm"),
                             type = "closed"))
  }
  if (!is.null(stretches)) {
    plot <- plot + ggplot2::geom_path(
      data = stretches,
      ggplot2::aes(x = x, y = y, group = part, colour = node, linetype = lt),
      linewidth = line_width, alpha = line_alpha)
  }
  plot +
    ggplot2::geom_point(
      data = hits, ggplot2::aes(x = col, y = y, colour = node, shape = node),
      size = node_size) +
    ggplot2::scale_colour_manual(values = colours, breaks = chosen,
                                 name = NULL) +
    ggplot2::scale_shape_manual(values = shapes, breaks = chosen,
                                name = NULL) +
    ggplot2::scale_linetype_manual(
      values = c(relay = relay_style, `no relay` = no_relay_style),
      breaks = c("relay", "no relay"),
      labels = c(sprintf("relay within delta = %s", format(delta)),
                 "no relay"),
      name = NULL, drop = FALSE) +
    ggplot2::guides(
      colour = ggplot2::guide_legend(nrow = 2L, byrow = TRUE, order = 1L),
      shape = ggplot2::guide_legend(nrow = 2L, byrow = TRUE, order = 1L),
      linetype = ggplot2::guide_legend(order = 2L,
        override.aes = list(colour = "grey30"))) +
    ggplot2::scale_y_reverse(breaks = NULL,
                             expand = ggplot2::expansion(add = c(0.6, 0.9))) +
    ggplot2::scale_x_continuous(breaks = breaks, labels = labels,
                                expand = ggplot2::expansion(add = 0.8)) +
    ggplot2::labs(
      x = sprintf("Event start (%s); columns in time order",
                  x$meta$time_unit %||% "time"),
      y = NULL, title = "Event graph as a storyline",
      subtitle = sprintf(
        "%d events, %d actors drawn; a solid stretch is an adjacency of the event graph",
        n_col, length(chosen))) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey45", size = 9),
      axis.text.x = ggplot2::element_text(size = label_size, angle = 90,
                                          hjust = 1,
                                          vjust = 0.5),
      legend.position = "bottom", legend.box = "vertical")
}

#' Relay chains of an event graph: its weakly connected components
#'
#' @param n Number of events, indexed `1..n`.
#' @param a,b Endpoints of the arcs, as event indices.
#' @return An integer vector of length `n`: the smallest index in each
#'   event's component.
#' @noRd
.event_chains <- function(n, a, b) {
  chain <- seq_len(n)
  if (!length(a)) return(chain)
  ends <- c(a, b)
  # Minimum-label propagation with pointer jumping, to a fixed point. Each
  # pass is vectorised; the passes are sequential by nature, and a component
  # of k events settles in at most k passes, so n bounds the iterations.
  passes <- 0L
  repeat {
    low <- rep(pmin(chain[a], chain[b]), 2L)
    by_end <- order(ends, low)
    first <- !duplicated(ends[by_end])
    settled <- chain
    hit <- ends[by_end][first]
    settled[hit] <- pmin(settled[hit], low[by_end][first])
    settled <- settled[settled]
    passes <- passes + 1L
    if (identical(settled, chain)) break
    .check("Internal relay-chain labelling did not settle." = passes <= n)
    chain <- settled
  }
  chain
}

#' Draw an event graph with events as points and adjacencies as arcs
#'
#' @param x An event graph.
#' @param events The rows of its event table to draw.
#' @param rows,top,color_by,labels,palette,node_size,node_shape As in
#'   `plot.dynet_event_graph()`.
#' @param line_width,line_alpha As there.
#' @param arrows,arrow_color,arrow_size,base_size,label_size As there.
#' @return A ggplot object.
#' @noRd
.plot_event_chains <- function(x, events, rows, top, color_by, labels,
                               palette, node_size, node_shape, line_width,
                               line_alpha, arrows, arrow_color, arrow_size,
                               base_size, label_size) {
  events <- events[order(events$start, events$event), , drop = FALSE]
  n_actors <- length(unique(events$from))
  if (identical(rows, "actor")) {
    # The most active sources, ties broken by name; each gets a row, in the
    # order of their first event.
    counts <- table(events$from)
    ranked <- names(counts)[order(-as.integer(counts), names(counts))]
    chosen <- if (is.null(top)) ranked else utils::head(ranked, top)
    events <- events[events$from %in% chosen, , drop = FALSE]
  }
  n <- nrow(events)
  # Arcs among the events drawn; two shared vertices are still one arc.
  adj <- x$adjacencies
  arcs <- unique(adj[adj$from_event %in% events$event &
                       adj$to_event %in% events$event,
                     c("from_event", "to_event"), drop = FALSE])
  a <- match(arcs$from_event, events$event)
  b <- match(arcs$to_event, events$event)
  chain <- .event_chains(n, a, b)
  n_chains <- length(unique(chain))
  # Events are in time order, so a chain's smallest index is its first event
  # and ranking those indices orders the rows by first event; actors are
  # ordered by their first event the same way.
  lanes <- if (identical(rows, "actor")) unique(events$from) else NULL
  row <- if (identical(rows, "actor")) match(events$from, lanes) else
    match(chain, sort(unique(chain)))
  n_targets <- events$n_targets %||% rep(1L, n)
  reached <- ifelse(n_targets > 1L, sprintf("%d targets", n_targets),
                    events$to)
  points <- data.frame(event = events$event, time = events$start, row = row,
                       label = if (identical(rows, "actor")) {
                         paste0("->", reached)
                       } else paste(events$from, reached, sep = "->"),
                       stringsAsFactors = FALSE)

  # An arc within one row is a half-ellipse above it, higher the longer it
  # spans and never more than half a row high, so it cannot reach the next
  # row; an arc between rows is a straight line from event to event.
  span <- events$start[b] - events$start[a]
  longest <- max(c(span, 0))
  height <- if (longest > 0) 0.15 + 0.3 * span / longest else rep(0.15, length(a))
  height[row[a] != row[b]] <- 0
  theta <- seq(0, pi, length.out = 25L)
  arc_paths <- data.frame(
    arc = rep(seq_along(a), each = length(theta)),
    x = rep(events$start[a], each = length(theta)) +
      rep(span, each = length(theta)) * (1 - cos(theta)) / 2,
    y = rep(row[a], each = length(theta)) +
      rep(row[b] - row[a], each = length(theta)) * (1 - cos(theta)) / 2 -
      rep(height, each = length(theta)) * sin(theta)
  )

  plot <- ggplot2::ggplot()
  if (nrow(arc_paths)) {
    plot <- plot + ggplot2::geom_path(
      data = arc_paths, ggplot2::aes(x = x, y = y, group = arc),
      colour = arrow_color, linewidth = line_width * 0.5, alpha = line_alpha,
      arrow = if (arrows) ggplot2::arrow(
        length = ggplot2::unit(arrow_size, "cm"), type = "closed") else NULL)
  }
  if (is.null(color_by)) {
    plot <- plot + ggplot2::geom_point(
      data = points, ggplot2::aes(x = time, y = row), size = node_size,
      shape = node_shape[[1L]], colour = "#0072B2")
  } else {
    value <- as.character(events[[color_by]])
    # Colours and shapes come from every value in the graph, not only those
    # in the period drawn, so a value keeps its look from one figure to the
    # next.
    kinds <- sort(unique(as.character(x$events[[color_by]])))
    colours <- stats::setNames(if (identical(palette, "okabe")) {
      rep_len(setdiff(.okabe, "#F0E442"), length(kinds))
    } else .dyn_palette(palette, length(kinds)), kinds)
    shapes <- stats::setNames(rep_len(node_shape, length(kinds)), kinds)
    points$kind <- value
    plot <- plot +
      ggplot2::geom_point(
        data = points, ggplot2::aes(x = time, y = row, colour = kind,
                                    shape = kind),
        size = node_size) +
      ggplot2::scale_colour_manual(values = colours, breaks = kinds,
                                   name = color_by) +
      ggplot2::scale_shape_manual(values = shapes, breaks = kinds,
                                  name = color_by)
  }
  if (labels) {
    # Events seconds apart would print their labels over one another, so a
    # run of close neighbours on one row steps its labels down through three
    # tiers below the row, clear of the arcs of the next row.
    near <- 0.06 * max(diff(range(points$time)), .Machine$double.eps)
    by_row <- order(points$row, points$time)
    close <- c(FALSE, diff(points$time[by_row]) < near &
                 diff(points$row[by_row]) == 0)
    run <- cumsum(!close)
    tier <- (stats::ave(run, run, FUN = seq_along) - 1L) %% 3L
    points$label_y <- NA_real_
    points$label_y[by_row] <- points$row[by_row] + 0.17 + 0.13 * tier
    plot <- plot + ggplot2::geom_text(
      data = points, ggplot2::aes(x = time, y = label_y, label = label),
      size = label_size / ggplot2::.pt, colour = "grey30")
  }
  y_scale <- if (identical(rows, "actor")) {
    ggplot2::scale_y_reverse(breaks = seq_along(lanes), labels = lanes,
                             expand = ggplot2::expansion(add = c(0.7, 0.6)))
  } else {
    ggplot2::scale_y_reverse(breaks = NULL,
                             expand = ggplot2::expansion(add = c(0.7, 0.6)))
  }
  plot +
    y_scale +
    ggplot2::labs(
      x = sprintf("Event start (%s)", x$meta$time_unit %||% "time"),
      y = if (identical(rows, "actor")) "Actor" else
        "Relay chains, by first event",
      title = "Event graph",
      subtitle = if (identical(rows, "actor")) {
        sprintf(paste0("%d events by %d of %d actors, one row each; a line ",
                       "joins two events within delta = %s"),
                n, length(lanes), n_actors, format(x$meta$delta))
      } else {
        sprintf(paste0("%d events in %d relay chains; an arc joins two ",
                       "events within delta = %s"),
                n, n_chains, format(x$meta$delta))
      }) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey45", size = 9),
      legend.position = "bottom")
}


#' Storyline rows: one per actor and column between its first and last event
#'
#' Ported from the storyline of the `hypergraphs` package. One sweep carries
#' an ordering of the actors through the columns; at each column the members
#' of its event move to the median of their current positions and keep their
#' relative order (the barycentre rule of Sugiyama et al., 1981), and an
#' actor between them moves aside. An actor's row is its rank among the
#' actors alive at that column. The sweep starts from the order of first
#' appearance and then, `sweeps` times, from each actor's mean row in the
#' previous layout; the layout with the fewest crossings is kept (the
#' earliest on ties), so the result is deterministic.
#'
#' @param node Actor of each membership.
#' @param col Column of each membership.
#' @param n_col Number of columns.
#' @param sweeps Number of re-started sweeps.
#' @return A data frame with `node`, `col` and `y`, carrying the crossing
#'   count as attribute `crossings`.
#' @noRd
.storyline_layout <- function(node, col, n_col, sweeps = 4L) {
  nodes <- sort(unique(node))
  members <- split(node, factor(col, levels = seq_len(n_col)))
  first <- tapply(col, node, min)
  last <- tapply(col, node, max)
  alive <- lapply(seq_len(n_col), \(j) nodes[first[nodes] <= j & last[nodes] >= j])

  gather <- function(pos, j) {
    mem <- members[[j]]
    if (length(mem) < 2L) return(pos)
    centre <- stats::median(pos[mem])
    offsets <- rank(pos[mem], ties.method = "first") - (length(mem) + 1) / 2
    key <- ifelse(pos == centre, pos + 0.5, pos)
    key[mem] <- centre + offsets * 1e-3
    stats::setNames(rank(key, ties.method = "first"), names(pos))
  }
  sweep <- function(start) {
    orders <- Reduce(gather, seq_len(n_col), accumulate = TRUE,
                     init = start)[-1L]
    rows <- do.call(rbind, lapply(seq_len(n_col), \(j) {
      data.frame(node = alive[[j]], col = j,
                 y = as.numeric(rank(orders[[j]][alive[[j]]])),
                 stringsAsFactors = FALSE)
    }))
    rows[order(rows$node, rows$col), , drop = FALSE]
  }
  crossings <- function(rows) {
    pairs <- lapply(seq_len(n_col - 1L), \(j) {
      here <- rows[rows$col == j, , drop = FALSE]
      there <- rows[rows$col == j + 1L, , drop = FALSE]
      both <- intersect(here$node, there$node)
      if (length(both) < 2L) return(0)
      a <- here$y[match(both, here$node)]
      b <- there$y[match(both, there$node)]
      flips <- sign(outer(a, a, "-")) != sign(outer(b, b, "-"))
      sum(flips) / 2
    })
    sum(unlist(pairs))
  }
  next_start <- function(rows) {
    mean_row <- tapply(rows$y, rows$node, mean)
    key <- mean_row[nodes] + first[nodes] * 1e-6
    stats::setNames(rank(key, ties.method = "first"), nodes)
  }
  appearance <- stats::setNames(
    rank(first[nodes] + seq_along(nodes) * 1e-9, ties.method = "first"), nodes
  )
  first_layout <- sweep(appearance)
  layouts <- if (sweeps < 1L) list(first_layout) else
    Reduce(\(previous, i) sweep(next_start(previous)), seq_len(sweeps),
           accumulate = TRUE, init = first_layout)
  counts <- vapply(layouts, crossings, numeric(1L))
  best <- layouts[[which.min(counts)]]
  rownames(best) <- NULL
  attr(best, "crossings") <- min(counts)
  best
}
