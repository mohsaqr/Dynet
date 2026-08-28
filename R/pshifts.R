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
#' @param dn A directed temporal network from [dynet()].
#' @param sessions Session aggregation policy.
#' @param output Return final class totals or cumulative rows.
#' @param start,end Optional inclusive query limits; each query is a fresh
#'   sequence and never uses a predecessor outside the range.
#' @param group_events Infer one group-directed turn from simultaneous distinct
#'   recipients, or retain every dyadic row.
#' @return A `dynet_pshifts` data frame with the thirteen fixed classes,
#'   carrying columns `shift`, `family`, `measure` and `value` — the same
#'   `measure`/`value` pair every other measurement verb returns, so a
#'   participation-shift census composes with the verbs that consume one.
#'   `measure` is the constant `"count"`; `value` is the integer count.
#'   `output = "cumulative"` prepends the turn columns; `sessions =
#'   "separate"` prepends `session`.
#' @details Only uncensored raw spell onsets inside the observed query and
#' observation components are turns; duration, weights, fragments and
#' terminus censoring are ignored. Consecutive turns are classified using
#' Gibson's fixed thirteen labels. Session and component walls, loops, ties,
#' duplicate multiplicity, and simultaneous-recipient group inference are
#' retained in metadata. `output = "final"` emits one typed row per class;
#' `output = "cumulative"` emits the running class vector for each turn.
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
    group_events = c("simultaneous", "none")) {
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
  structure(out, class = c("dynet_pshifts", "data.frame"),
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
}
