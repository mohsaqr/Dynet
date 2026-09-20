# ===========================================================================
# Participation shifts (Gibson's thirteen consecutive-turn classes)
# ===========================================================================

.pshift_labels <- c(
  "AB-BA", "AB-B0", "AB-BY", "A0-X0", "A0-XA", "A0-XY",
  "AB-X0", "AB-XA", "AB-XB", "AB-XY", "A0-AY", "AB-A0", "AB-AY"
)
.pshift_families <- c(
  rep("turn_receiving", 3L), rep("turn_claiming", 3L),
  rep("turn_usurping", 4L), rep("turn_continuing", 3L)
)

.pshift_classify <- function(previous, current) {
  if (is.null(previous) || is.null(current) || current$loop || previous$loop) {
    return(NA_integer_)
  }
  a <- previous$speaker
  b <- previous$target
  c <- current$speaker
  d <- current$target
  pg <- previous$group
  cg <- current$group
  if (!pg && identical(c, b)) {
    if (!cg && identical(d, a)) return(1L)
    if (cg) return(2L)
    if (!identical(d, b)) return(3L)
  }
  if (pg && !identical(c, a)) {
    if (cg) return(4L)
    if (identical(d, a)) return(5L)
    return(6L)
  }
  if (!pg && !identical(c, a) && !identical(c, b)) {
    if (cg) return(7L)
    if (identical(d, a)) return(8L)
    if (identical(d, b)) return(9L)
    return(10L)
  }
  if (identical(c, a)) {
    if (pg && !cg) return(11L)
    if (!pg && cg) return(12L)
    if (!pg && !cg && !identical(d, b)) return(13L)
  }
  NA_integer_
}

.pshift_raw_turns <- function(dn, enc, start, end, group_events) {
  onset <- enc$raw_event_start
  keep <- !enc$raw_event_onset_censored &
    .time_in_observation(dn, onset)
  if (!is.null(start)) keep <- keep & onset >= start
  if (!is.null(end)) keep <- keep & onset <= end
  rows <- which(keep)
  if (!length(rows)) return(data.frame())
  observations <- .observation_table(dn)
  component <- if (is.null(observations)) {
    rep.int(1L, length(rows))
  } else vapply(onset[rows], function(time) {
    hit <- which(
      (observations$end > observations$start &
         observations$start <= time & observations$end >= time) |
      (observations$end == observations$start & observations$start == time)
    )
    if (length(hit)) hit[[1L]] else NA_integer_
  }, integer(1L))
  base <- data.frame(
    time = onset[rows], speaker = enc$raw_from[rows],
    target = enc$raw_to[rows], group = FALSE,
    loop = enc$raw_from[rows] == enc$raw_to[rows],
    session = enc$raw_event_session[rows], component = component,
    stringsAsFactors = FALSE
  )
  if (identical(group_events, "none")) return(base)
  keys <- paste(base$time, base$speaker, sep = "\r")
  groups <- lapply(unique(keys), function(key) {
    ix <- which(keys == key)
    named <- unique(base$target[ix][!base$loop[ix]])
    if (length(named) >= 2L) {
      group_row <- base[ix[!base$loop[ix]][1L], , drop = FALSE] |>
        transform(target = NA_integer_, group = TRUE, loop = FALSE)
      rbind(base[ix[base$loop[ix]], , drop = FALSE], group_row)
    } else base[ix, , drop = FALSE]
  })
  out <- do.call(rbind, groups)
  out <- out[order(out$time, out$speaker, out$group, out$target,
                   seq_len(nrow(out))), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.pshift_sequence <- function(turns) {
  counts <- setNames(integer(length(.pshift_labels)), .pshift_labels)
  cumulative <- vector("list", nrow(turns))
  previous <- NULL
  previous_component <- NA_integer_
  sequence_id <- 1L
  sequence_event <- 0L
  if (!nrow(turns)) return(list(counts = counts, cumulative = cumulative))
  # Sequential dependency: each class uses the immediately preceding turn.
  for (i in seq_len(nrow(turns))) {
    current <- as.list(turns[i, , drop = FALSE])
    current$speaker <- turns$speaker[[i]]
    current$target <- turns$target[[i]]
    current$group <- turns$group[[i]]
    current$loop <- turns$loop[[i]]
    current$component <- turns$component[[i]]
    if (!is.na(previous_component) &&
        !identical(previous_component, current$component)) {
      previous <- NULL
      sequence_id <- sequence_id + 1L
      sequence_event <- 0L
    }
    sequence_event <- sequence_event + 1L
    class_id <- .pshift_classify(previous, current)
    if (is.finite(class_id)) counts[[class_id]] <- counts[[class_id]] + 1L
    cumulative[[i]] <- list(index = class_id, counts = counts,
                             turn = current, sequence = sequence_id,
                             event = sequence_event)
    previous <- if (current$loop) NULL else current
    if (current$loop) {
      # A loop is a sequence wall for the public cumulative coordinates.
      sequence_id <- sequence_id + 1L
      sequence_event <- 0L
      previous_component <- NA_integer_
    } else {
      previous_component <- current$component
    }
  }
  list(counts = counts, cumulative = cumulative)
}

#' Gibson participation shifts from raw temporal turns
#'
#' @param dn A directed temporal network from [dynet()]. An undirected network
#'   raises an error of class `dynet_needs_directed`.
#' @param sessions Session aggregation policy: `"bounded"` (the default) reads
#'   each session as its own turn sequence and pools the counts, `"collapse"`
#'   erases session labels and reads one calendar-ordered sequence, and
#'   `"separate"` reports each session on its own rows. `"separate"` needs a
#'   network built with a session column and raises `dynet_no_sessions`
#'   otherwise.
#' @param output `"final"` (the default) for one row per shift class,
#'   `"cumulative"` for the running class vector at every turn.
#' @param start,end Optional inclusive query limits; each query is a fresh
#'   sequence and never uses a predecessor outside the range. A network built
#'   from dates may be addressed with dates.
#' @param group_events Infer one group-directed turn from simultaneous distinct
#'   recipients (`"simultaneous"`, the default), or retain every dyadic row
#'   (`"none"`).
#'   Several turns at one instant are ordered by speaker, then group turn
#'   before dyadic turn, then target, each in the network's vertex order; the
#'   classification of consecutive turns depends on that order, so under
#'   `"none"` a batch of simultaneous replies is read in vertex order.
#' @param plot Whether to draw the result as well as return it. Drawing is a
#'   side effect in the manner of [graphics::hist()]: the verb still returns
#'   its tidy table, invisibly when it has drawn, so `plot = TRUE` saves the
#'   wrapping `plot()` call without changing what comes back. Use `plot()` on
#'   the result when the figure needs arguments of its own.
#' @return A `dynet_pshifts` data frame whose shape follows `output`, carrying
#'   the `measure`/`value` pair every other measurement verb returns, so a
#'   participation-shift census composes with the verbs that consume one;
#'   `measure` is the constant `"count"` and `value` is the integer count.
#'   `"final"` gives one row per shift class -- thirteen rows, always all
#'   thirteen even when a class never occurred -- with columns `shift` (the
#'   Gibson label), `family` (the label's group), `measure` and `value`.
#'   `"cumulative"` gives one row per turn and class, that is thirteen rows
#'   per classified turn, with `sequence` and `event` locating the turn in its
#'   sequence, `time`, `speaker`, `target` and `group` describing the turn,
#'   and `shift`, `family`, `measure` and `value` carrying the running total
#'   of that class up to and including the turn. Either shape gains a leading
#'   `session` column under `sessions = "separate"`, which reports each
#'   session on its own rows; `"bounded"` and `"collapse"` carry no session
#'   column. Print it, [summary()] it, [plot()] it, or take the plain frame
#'   with [as.data.frame()].
#' @details Only uncensored raw spell onsets inside the observed query and
#' observation components are turns; duration, weights, fragments and
#' terminus censoring are ignored. Consecutive turns are classified using
#' Gibson's fixed thirteen labels. Session and component walls, loops, ties,
#' duplicate multiplicity, and simultaneous-recipient group inference are
#' retained in metadata. `output = "final"` emits one typed row per class;
#' `output = "cumulative"` emits the running class vector for each turn.
#' @section Conditions:
#' Errors: `dynet_needs_directed` (an undirected network; the class vector is
#' `c("dynet_needs_directed", "dynet_bad_input")`), `dynet_no_sessions`
#' (`sessions = "separate"` without a session column),
#' `dynet_outside_observation` (the requested range misses observed support;
#' it also carries `dynet_bad_input`),
#' and `dynet_bad_input` for every other broken contract -- `dn` not a
#' `dynet`, and a `start` or `end` that is not a single finite time. An
#' unmatched `sessions`, `output` or `group_events` is rejected by
#' [match.arg()] and is a plain error, not a classed one.
#' @references Gibson, D. R. (2003). Participation shifts and institutional
#'   change in relational systems. *Social Forces*, 81, 1335--1380.
#'   \doi{10.1353/sof.2003.0055}
#' @examples
#' dn <- dynet(data.frame(
#'   from = c("A", "B"), to = c("B", "A"), start = c(1, 2), end = c(1, 2)
#' ))
#' pshifts(dn)
#' @export
pshifts <- function(
    dn, sessions = c("bounded", "collapse", "separate"),
    output = c("final", "cumulative"), start = NULL, end = NULL,
    group_events = c("simultaneous", "none"), plot = FALSE) {
  sessions <- match.arg(sessions)
  output <- match.arg(output)
  group_events <- match.arg(group_events)
  .check_dynet(dn, sessions)
  if (!isTRUE(dn$directed)) {
    stop(errorCondition(
      "pshifts() requires a directed network.",
      class = c("dynet_needs_directed", "dynet_bad_input"), call = NULL
    ))
  }
  spec <- .window_spec(dn, start, end, step = 1, window = 0)
  start <- spec$start %||% dn$meta$time_range[["start"]]
  end <- spec$end %||% dn$meta$time_range[["end"]]
  parts <- if (sessions %in% c("bounded", "separate") &&
               !is.null(dn$meta$sessions)) {
    .split_sessions(dn, "separate")
  } else list(all = .encode(dn))
  sequences <- lapply(parts, function(enc) {
    turns <- .pshift_raw_turns(dn, enc, start, end, group_events)
    .pshift_sequence(turns)
  })
  counts <- Reduce(`+`, lapply(sequences, `[[`, "counts"),
                   init = setNames(integer(13L), .pshift_labels))
  if (identical(output, "final")) {
    out <- data.frame(
      shift = .pshift_labels, family = .pshift_families,
      measure = "count", value = as.integer(counts), stringsAsFactors = FALSE
    )
    if (identical(sessions, "separate")) {
      rows <- lapply(names(sequences), function(label) {
        data.frame(session = label, shift = .pshift_labels,
                   family = .pshift_families, measure = "count",
                   value = as.integer(sequences[[label]]$counts),
                   stringsAsFactors = FALSE)
      })
      out <- do.call(rbind, rows)
    }
  } else {
    running <- setNames(integer(13L), .pshift_labels)
    sequence_offset <- 0L
    rows <- lapply(names(sequences), function(label) {
      seqs <- sequences[[label]]$cumulative
      if (!length(seqs)) return(data.frame())
      result <- do.call(rbind, lapply(seq_along(seqs), function(i) {
        state <- seqs[[i]]
        shown_counts <- if (identical(sessions, "separate")) {
          state$counts
        } else state$counts + running
        data.frame(
          session = if (identical(sessions, "separate")) label else "all",
          sequence = state$sequence + if (identical(sessions, "separate")) 0L else sequence_offset,
          event = state$event, time = state$turn$time,
          speaker = dn$nodes$name[[state$turn$speaker]],
          target = if (state$turn$group) NA_character_ else {
            dn$nodes$name[[state$turn$target]]
          },
          group = state$turn$group, shift = .pshift_labels,
          family = .pshift_families, measure = "count",
          value = as.integer(shown_counts), stringsAsFactors = FALSE
        )
      }))
      if (!identical(sessions, "separate")) {
        running <<- running + sequences[[label]]$counts
        sequence_offset <<- sequence_offset + max(vapply(seqs, `[[`, integer(1), "sequence"), 0L)
      }
      result
    })
    out <- do.call(rbind, rows)
    if (is.null(out)) out <- data.frame()
    if (!nrow(out)) {
      out <- data.frame(
        session = character(), sequence = integer(), event = integer(),
        time = numeric(), speaker = character(), target = character(),
        group = logical(), shift = character(), family = character(),
        measure = character(), value = integer(), stringsAsFactors = FALSE
      )
      if (!identical(sessions, "separate")) out$session <- NULL
    }
  }
  if ("session" %in% names(out) && !identical(sessions, "separate")) {
    out$session <- NULL
  }
  out <- structure(out, class = c("dynet_pshifts", "data.frame"),
            event_identity = "uncensored_observed_raw_spell_start",
            classification = "gibson_13", interval_contribution = "onset_only",
            group_target = if (identical(group_events, "simultaneous")) {
              "simultaneous_distinct_recipients_collapsed_once"
            } else "none",
            tie_rule = "time_speaker_target_group_last",
            duplicates = "distinct_turns", termini = "ignored",
            weights = "ignored", vertex_activity = "ignored",
            loops = "unclassified_sequence_break",
            observation_walls = "components_and_gaps",
            query_walls = "inclusive_query_starts_fresh_sequence",
            session_aggregation = switch(
              sessions, collapse = "labels_erased_calendar_sequence",
              bounded = "session_local_sequences_pooled",
              separate = "session_local_rows"
            ))
  .maybe_plot(out, plot)
}

#' Tidy data frame of participation shift counts
#'
#' @param x A `dynet_pshifts` result.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param ... Ignored.
#' @return A plain `data.frame` carrying the same rows and columns as `x`. For
#'   a result built with `output = "final"` that is one row per shift type --
#'   `shift`, `family` and `count` -- preceded by `session` when the result is
#'   session-local; the thirteen Gibson shift types are always present,
#'   including those with a count of zero. For `output = "cumulative"` it is
#'   thirteen rows per classified turn, adding `sequence`, `event`, `time`,
#'   `speaker`, `target` and `group` ahead of `shift`, `family` and `count`.
#' @examples
#' dn <- dynet(school_contacts)
#' shifts <- pshifts(dn)
#' as.data.frame(shifts)
#' @export
as.data.frame.dynet_pshifts <- function(x, row.names = NULL, optional = FALSE,
                                        ...) {
  out <- x
  attributes(out) <- list(names = names(x), row.names = seq_len(nrow(x)),
                          class = "data.frame")
  out
}

#' Number of classified turn transitions behind a pshift table
#'
#' The `"final"` layout holds one row per shift type, so its counts add up.
#' The `"cumulative"` layout repeats a *running* total for every turn, so
#' summing the column counts each transition once for every later turn --
#' 27831 instead of 235 on `school_contacts`. The totals are the running
#' counts carried by the last turn of each session block.
#' @param x A `dynet_pshifts` result.
#' @return One non-negative number.
#' @noRd
.pshift_observed <- function(x) {
  if (!"event" %in% names(x)) return(sum(x$value))
  key <- if ("session" %in% names(x)) x$session else rep("all", nrow(x))
  blocks <- vapply(split(seq_len(nrow(x)), key), function(rows) {
    latest <- rows[x$sequence[rows] == max(x$sequence[rows])]
    latest <- latest[x$event[latest] == max(x$event[latest])]
    sum(x$value[latest])
  }, numeric(1L))
  sum(blocks)
}

#' Print participation shift counts
#'
#' @param x A `dynet_pshifts` result.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @examples
#' dn <- dynet(school_contacts)
#' shifts <- pshifts(dn)
#' shifts
#' @export
print.dynet_pshifts <- function(x, ...) {
  observed <- .pshift_observed(x)
  cat(sprintf("# Participation shifts (Gibson 2003, %d types)
",
              length(unique(x$shift))))
  cat(sprintf("# %d classified turn transition%s across %d famil%s\n",
              observed, if (isTRUE(all.equal(observed, 1))) "" else "s",
              length(unique(x$family)),
              if (length(unique(x$family)) == 1L) "y" else "ies"))
  print(as.data.frame(x), row.names = FALSE)
  invisible(x)
}

#' Summarise participation shifts by family
#'
#' @param object A `dynet_pshifts` result.
#' @param ... Ignored.
#' @return A plain `data.frame`, one row per shift family, ordered by
#'   descending `count`: `family`, its `count`, the `share` of all classified
#'   transitions it accounts for, and `top_shift`, the single most frequent
#'   shift type within it. `share` is `NaN` when nothing was classified. The
#'   family totals are sums of the `count` column as it stands, so they are
#'   transition counts for an `output = "final"` result.
#' @examples
#' dn <- dynet(school_contacts)
#' shifts <- pshifts(dn)
#' summary(shifts)
#' @export
summary.dynet_pshifts <- function(object, ...) {
  flat <- as.data.frame(object)
  total <- sum(flat$value)
  by_family <- lapply(split(flat, flat$family), function(part) {
    best <- part$shift[which.max(part$value)]
    data.frame(
      family = part$family[[1L]], count = sum(part$value),
      share = sum(part$value) / total,
      top_shift = if (sum(part$value) > 0) best else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, by_family)
  out <- out[order(-out$count, out$family), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Plot participation shift counts
#'
#' One horizontal bar per shift type, grouped and coloured by family. Families
#' are distinguished by a direct axis grouping as well as by fill, so the
#' figure does not rely on colour alone.
#'
#' @param x A `dynet_pshifts` result.
#' @param ... Ignored.
#' @return A `ggplot` object.
#' @examples
#' dn <- dynet(school_contacts)
#' shifts <- pshifts(dn)
#' plot(shifts)
#' @export
plot.dynet_pshifts <- function(x, ...) {
  flat <- as.data.frame(x)
  if ("session" %in% names(flat)) {
    flat <- stats::aggregate(value ~ shift + family, data = flat, FUN = sum)
  }
  flat$shift <- factor(flat$shift, levels = rev(unique(flat$shift)))
  ggplot2::ggplot(flat, ggplot2::aes(x = value, y = shift, fill = family)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::facet_grid(rows = ggplot2::vars(family), scales = "free_y",
                        space = "free_y", switch = "y") +
    ggplot2::scale_fill_manual(values = .okabe_ito(), guide = "none") +
    ggplot2::labs(x = "Turn transitions", y = NULL,
                  title = "Participation shifts") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      strip.placement = "outside",
      strip.text.y.left = ggplot2::element_text(angle = 0, hjust = 1),
      panel.grid.major.y = ggplot2::element_blank()
    )
}
