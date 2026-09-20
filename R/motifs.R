# ===========================================================================
# motifs()
# ===========================================================================
# A delta-temporal three-edge, three-node motif census following Paranjape,
# Benson & Leskovec (2017), in raphtory 0.17.0's class ordering.
#
# pshifts() cannot be parameterised into this: it is a DYADIC census that
# classifies exactly two consecutive turns into one of Gibson's 13 labels. A
# three-edge pattern is invisible to it.

#' Family and representative pattern for each motif index
#'
#' Derived from `.motif_lookup` rather than written out, so the labels cannot
#' drift from the table the counts are produced with.
#' @return A data frame with `motif`, `family` and `pattern`, 40 rows.
#' @noRd
.motif_catalogue <- function() {
  words <- c("III", "IIO", "IOI", "IOO", "OII", "OIO", "OOI", "OOO")
  family <- c(rep("star_pre", 8L), rep("star_mid", 8L), rep("star_post", 8L),
              rep("two_node", 8L), rep("triangle", 8L))
  representative <- vapply(seq_len(40L), function(index) {
    hit <- Filter(function(entry) index %in% entry$global, .motif_lookup)
    if (!length(hit)) return(NA_character_)
    key <- names(hit)[[1L]]
    parts <- substring(key, seq(1L, 5L, by = 2L), seq(2L, 6L, by = 2L))
    paste(vapply(parts, function(one) {
      sprintf("%s>%s", substr(one, 1L, 1L), substr(one, 2L, 2L))
    }, character(1L)), collapse = ",")
  }, character(1L))
  pattern <- ifelse(family == "triangle", representative,
                    rep(words, times = 5L))
  data.frame(motif = seq_len(40L), family = family, pattern = pattern,
             stringsAsFactors = FALSE)
}

#' Canonical lookup keys for a set of candidate event triples
#'
#' Node labels are assigned by order of first appearance across the six
#' endpoints of the three events in time order, which is what makes two
#' structurally identical triples on different vertices share a key.
#'
#' @param from,to Integer matrices with three columns, one row per triple.
#' @return A character vector of keys, `NA` where the triple spans more than
#'   three distinct vertices and is therefore not a three-node motif.
#' @noRd
.motif_keys <- function(from, to) {
  six <- cbind(from[, 1L], to[, 1L], from[, 2L], to[, 2L],
               from[, 3L], to[, 3L])
  first <- six[, 1L]
  second <- six[, 2L]
  # The third label is the first endpoint that is neither of the first two.
  third <- rep(NA_integer_, nrow(six))
  invisible(lapply(3:6, function(j) {
    candidate <- six[, j]
    fresh <- is.na(third) & candidate != first & candidate != second
    third[fresh] <<- candidate[fresh]
    NULL
  }))
  label_of <- function(value) {
    ifelse(value == first, 0L,
           ifelse(value == second, 1L,
                  ifelse(!is.na(third) & value == third, 2L, NA_integer_)))
  }
  columns <- lapply(seq_len(6L), function(j) label_of(six[, j]))
  key <- do.call(paste0, columns)
  # A triple spanning four or more vertices is not a three-node motif.
  key[Reduce(`|`, lapply(columns, is.na))] <- NA_character_
  key
}

#' Every candidate triple inside the delta windows of a sorted event list
#'
#' @param time Sorted event times.
#' @param delta Window width.
#' @param block Integer block id: no triple may straddle a change in it.
#' @return An integer matrix of three column indices per row, or a zero-row
#'   matrix when no window holds three events.
#' @noRd
.motif_triples <- function(time, delta, block) {
  n <- length(time)
  if (n < 3L) return(matrix(integer(0), ncol = 3L))
  # The earliest event still inside the window closing at k.
  lo <- findInterval(time - delta, time, left.open = TRUE) + 1L
  per_k <- lapply(seq_len(n), function(k) {
    low <- lo[[k]]
    if (k - low < 2L) return(NULL)
    candidates <- seq.int(low, k - 1L)
    candidates <- candidates[block[candidates] == block[[k]]]
    if (length(candidates) < 2L) return(NULL)
    pairs <- utils::combn(candidates, 2L)
    cbind(pairs[1L, ], pairs[2L, ], k)
  })
  per_k <- Filter(Negate(is.null), per_k)
  if (!length(per_k)) return(matrix(integer(0), ncol = 3L))
  do.call(rbind, per_k)
}

#' Delta-temporal three-node motif census
#'
#' @description
#' Counts the 40 Paranjape three-edge, three-node temporal motif classes, in
#' the class ordering of raphtory 0.17.0 so a census can be checked against an
#' independent implementation index by index.
#'
#' @param dn A directed temporal network from [dynet()].
#' @param delta Window width, in the network's time unit. A triple of events
#'   is a motif instance when its last event is no later than `delta` after
#'   its first. **Required, with no default**: there is no principled default
#'   width, and a silent one would make every count an artefact of a number
#'   the user never chose. [gaps()] is the honest way to pick one.
#' @param output `"global"`, the default, for the 40-row network census, or
#'   `"local"` for 40 rows per vertex.
#' @param sessions How to treat sessions, as in [pshifts()].
#' @param start,end Optional inclusive query limits.
#'
#' @return A `dynet_motifs` data frame. Under `output = "global"` the columns
#'   are `motif` (the 1-based raphtory index), `family`, `pattern` and
#'   `count`; under `"local"` a `node` column precedes them. A leading
#'   `session` column is present under `sessions = "separate"`. All 40 classes
#'   are always present, zeros included -- a census with rows silently missing
#'   is not a census. Print it, [summary()] it, [plot()] it, or take the plain
#'   frame with [as.data.frame()].
#'
#' @details
#' **The definition.** Three incompatible motif families exist in the
#' literature. This adopts Paranjape, Benson & Leskovec (2017): exactly three
#' edge events on at most three distinct vertices, with
#' `t_last - t_first <= delta` over the three times in sorted order. Kovanen et
#' al. (2011) instead allow arbitrary size and bound *consecutive* gaps, which
#' is a strictly weaker condition and agrees only for two-edge patterns; that
#' family's instance count is unbounded and does not reduce to a fixed census.
#'
#' The three edges are three distinct *events*; the same pair may repeat,
#' which is exactly what the two-node classes are. Loops are excluded, and
#' instances may share edges -- every qualifying triple is counted, as in the
#' reference implementations. Edge-disjoint counting is a different and much
#' harder problem, and is not what any reference computes.
#'
#' **Local counting is not uniform across families**, and this is raphtory's
#' rule, adopted verbatim. For a star only the centre counts the instance; for
#' a triangle all three vertices do; for a two-node motif the global census
#' itself already records one count at each endpoint's class. So the local
#' counts sum to the global counts for stars and two-node motifs, and to three
#' times the global counts for triangles.
#'
#' **Simultaneous events** are ordered by the deterministic key
#' `(time, from, to, spell)`. Paranjape assumes distinct timestamps; this is
#' Dynet's choice, so that a census never depends on input row order.
#'
#' The enumeration is the direct one, quadratic in the number of events
#' sharing a window. Paranjape's incremental algorithm is linear; this is not
#' it, and a very large `delta` on a bursty network will be slow.
#'
#' @section Conditions:
#' Errors: `dynet_needs_directed` on an undirected network, since the 40-class
#' taxonomy is defined by edge directions and has no honest undirected
#' reading; `dynet_bad_input` when `delta` is missing, not a single finite
#' non-negative number, or when `dn` is not a `dynet`; `dynet_no_sessions`
#' under `sessions = "separate"` without a session column;
#' `dynet_count_overflow` when a class exceeds `2^53`.
#'
#' @references
#' Paranjape, A., Benson, A. R., & Leskovec, J. (2017). Motifs in temporal
#' networks. *WSDM '17*, 601-610. \doi{10.1145/3018661.3018731}
#'
#' Kovanen, L., Karsai, M., Kaski, K., Kertesz, J., & Saramaki, J. (2011).
#' Temporal motifs in time-dependent networks. *Journal of Statistical
#' Mechanics*, P11005. \doi{10.1088/1742-5468/2011/11/P11005}
#'
#' @seealso [gaps()] for choosing `delta`, and [pshifts()] for the dyadic
#'   turn-taking census, which counts the same events with a different arity.
#'
#' @examples
#' dn <- dynet(school_contacts)
#' census <- motifs(dn, delta = 2)
#' census
#'
#' @export
motifs <- function(dn, delta, output = c("global", "local"),
                   sessions = c("bounded", "collapse", "separate"),
                   start = NULL, end = NULL) {
  output <- match.arg(output)
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  if (missing(delta)) {
    stop(errorCondition(
      paste0("`delta` is required: a motif is defined by the window its three ",
             "events share. Use gaps() to choose one."),
      class = "dynet_bad_input", call = NULL))
  }
  .check("`delta` must be a single finite non-negative number." =
           length(delta) == 1L && is.numeric(delta) && is.finite(delta) &&
           delta >= 0)
  if (!dn$directed) {
    stop(errorCondition(
      paste0("Temporal motifs are defined by edge direction; this network is ",
             "undirected."),
      class = c("dynet_needs_directed", "dynet_bad_input"), call = NULL))
  }

  catalogue <- .motif_catalogue()
  parts <- .split_sessions(
    dn, if (identical(sessions, "separate")) "separate" else "collapse"
  )
  bounded <- identical(sessions, "bounded") && !is.null(dn$meta$sessions)

  per_session <- Map(function(enc, label) {
    keep <- .time_in_observation(dn, enc$raw_event_start) &
      !enc$raw_event_onset_censored & enc$raw_from != enc$raw_to
    if (!is.null(start)) keep <- keep & enc$raw_event_start >= start
    if (!is.null(end)) keep <- keep & enc$raw_event_start <= end
    rows <- which(keep)
    counts <- matrix(0, nrow = enc$n, ncol = 40L)
    totals <- numeric(40L)
    if (length(rows) >= 3L) {
      time <- enc$raw_event_start[rows]
      from <- enc$raw_from[rows]
      to <- enc$raw_to[rows]
      # Deterministic tie rule: simultaneous events must not be ordered by the
      # order rows happened to arrive in.
      ordering <- order(time, from, to, rows)
      time <- time[ordering]; from <- from[ordering]; to <- to[ordering]
      block <- if (bounded) {
        as.integer(factor(enc$raw_event_session[rows][ordering]))
      } else rep(1L, length(rows))

      triples <- .motif_triples(time, delta, block)
      if (nrow(triples)) {
        keys <- .motif_keys(
          matrix(from[triples], ncol = 3L), matrix(to[triples], ncol = 3L)
        )
        usable <- which(!is.na(keys) & keys %in% names(.motif_lookup))
        entries <- .motif_lookup[keys[usable]]
        global_index <- unlist(lapply(entries, `[[`, "global"),
                               use.names = FALSE)
        # `unlist(list())` is NULL, and tabulate() rejects it. An empty window
        # is the common case for a small delta, not an anomaly.
        if (is.null(global_index)) global_index <- integer(0)
        # Counts accumulate in double so the 2^53 guard below is meaningful;
        # tabulate() alone would cap at .Machine$integer.max.
        totals <- as.numeric(tabulate(global_index, nbins = 40L))
        if (identical(output, "local")) {
          node_rows <- triples[usable, , drop = FALSE]
          # Each entry names which canonical node takes which class; map the
          # canonical labels back to the actual vertices of that triple.
          attribution <- lapply(seq_along(usable), function(i) {
            spec <- strsplit(strsplit(entries[[i]]$local, ",",
                                      fixed = TRUE)[[1L]], ":", fixed = TRUE)
            six <- c(from[node_rows[i, 1L]], to[node_rows[i, 1L]],
                     from[node_rows[i, 2L]], to[node_rows[i, 2L]],
                     from[node_rows[i, 3L]], to[node_rows[i, 3L]])
            actual <- unique(six)
            vapply(spec, function(one) {
              c(actual[[as.integer(one[[1L]])]], as.integer(one[[2L]]))
            }, numeric(2L))
          })
          flat <- do.call(cbind, attribution)
          if (length(flat)) {
            counts <- matrix(
              as.numeric(tabulate((flat[1L, ] - 1L) * 40L + flat[2L, ],
                                  nbins = enc$n * 40L)),
              nrow = enc$n, byrow = TRUE
            )
          }
        }
      }
    }
    list(label = label, totals = totals, counts = counts, names = enc$names)
  }, parts, names(parts))

  frames <- lapply(per_session, function(one) {
    if (identical(output, "global")) {
      data.frame(session = one$label, motif = catalogue$motif,
                 family = catalogue$family, pattern = catalogue$pattern,
                 count = one$totals, stringsAsFactors = FALSE)
    } else {
      data.frame(
        session = one$label,
        node = rep(one$names, each = 40L),
        motif = rep(catalogue$motif, times = length(one$names)),
        family = rep(catalogue$family, times = length(one$names)),
        pattern = rep(catalogue$pattern, times = length(one$names)),
        count = as.vector(t(one$counts)), stringsAsFactors = FALSE
      )
    }
  })
  out <- do.call(rbind, frames)
  # `.split_sessions()` returns one block unless `sessions = "separate"`, and
  # session walls are already applied inside it, so there is nothing to sum:
  # the session label is simply noise outside the separate case.
  if (!identical(sessions, "separate")) out$session <- NULL
  if (any(out$count > 2^53)) {
    stop(errorCondition(
      "A motif class exceeded 2^53 and can no longer be counted exactly.",
      class = "dynet_count_overflow", call = NULL))
  }
  front <- intersect(c("session", "node", "motif", "family", "pattern",
                       "count"), names(out))
  out <- out[, front, drop = FALSE]
  rownames(out) <- NULL
  structure(out, class = c("dynet_motifs", "data.frame"),
            delta = delta, output = output,
            motif_family = "paranjape_2017_3_3",
            motif_order = "raphtory_0.17",
            event_identity = "uncensored_observed_raw_spell_start",
            tie_rule = "time_from_to_raw_spell",
            overlapping_instances = "counted",
            loops = "excluded",
            algorithm = "direct_quadratic_window",
            time_unit = dn$meta$time_unit,
            session_aggregation = sessions,
            n_nodes = nrow(dn$nodes))
}

#' Print a temporal motif census
#'
#' @param x A `dynet_motifs` result.
#' @param n Number of rows to show; the non-zero classes come first.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.dynet_motifs <- function(x, n = 10L, ...) {
  total <- sum(x$count)
  cat(sprintf("# Temporal motifs (Paranjape 2017, 40 classes), delta = %s %s\n",
              format(attr(x, "delta")), attr(x, "time_unit") %||% ""))
  cat(sprintf("# %s instances across %d non-zero classes | %s output\n",
              format(total), sum(x$count > 0), attr(x, "output")))
  shown <- x[order(-x$count, x$motif), , drop = FALSE]
  print(utils::head(as.data.frame(shown), n), row.names = FALSE)
  if (nrow(x) > n) {
    cat(sprintf("# %d more rows; as.data.frame() for the whole census\n",
                nrow(x) - n))
  }
  invisible(x)
}

#' Summarise a temporal motif census by family
#'
#' @param object A `dynet_motifs` result.
#' @param by `"family"`, the default, or `"node"` for a local census.
#' @param ... Ignored.
#' @return A plain `data.frame` with one row per group: the group, its
#'   `count`, its `share` of all instances, and the `top_motif` index within
#'   it.
#' @export
summary.dynet_motifs <- function(object, by = c("family", "node"), ...) {
  by <- match.arg(by)
  if (identical(by, "node") && !"node" %in% names(object)) {
    stop(errorCondition(
      "by = \"node\" needs a census built with output = \"local\".",
      class = "dynet_bad_input", call = NULL))
  }
  total <- sum(object$count)
  key <- object[[by]]
  rows <- lapply(split(seq_len(nrow(object)), key), function(index) {
    block <- object[index, , drop = FALSE]
    data.frame(
      group = as.character(block[[by]][[1L]]), count = sum(block$count),
      share = if (total > 0) sum(block$count) / total else 0,
      top_motif = if (sum(block$count) > 0) {
        block$motif[[which.max(block$count)]]
      } else NA_integer_,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  names(out)[[1L]] <- by
  out <- out[order(-out$count), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Plot a temporal motif census
#'
#' @param x A `dynet_motifs` result.
#' @param ... Passed to [graphics::barplot()].
#' @return `x`, invisibly; a bar plot is drawn as a side effect.
#' @export
plot.dynet_motifs <- function(x, ...) {
  by_family <- vapply(split(x$count, x$family), sum, numeric(1L))
  palette <- .palette_extended(length(by_family))
  graphics::barplot(by_family, col = palette,
                    main = sprintf("Temporal motifs (delta = %s)",
                                   format(attr(x, "delta"))),
                    ylab = "instances", las = 2, ...)
  invisible(x)
}

#' Tidy frame of a temporal motif census
#'
#' @param x A `dynet_motifs` result.
#' @param row.names Ignored; present for compatibility with the generic.
#' @param optional Ignored; present for compatibility with the generic.
#' @param ... Ignored.
#' @return A plain `data.frame` carrying the same rows and columns as `x`:
#'   `motif`, `family`, `pattern` and `count`, preceded by `node` for a local
#'   census and by `session` when the census is session-local.
#' @export
as.data.frame.dynet_motifs <- function(x, row.names = NULL, optional = FALSE,
                                       ...) {
  out <- x
  attributes(out) <- NULL
  out <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  rownames(out) <- NULL
  out
}
