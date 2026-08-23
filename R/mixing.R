# ===========================================================================
# dyn_mixing() — who interacts with whom, over time
# ===========================================================================

#' Mixing between vertex groups over time
#'
#' @description
#' How much each kind of vertex interacted with each other kind, in every time
#' bin. This is the question a temporal network answers that a static one
#' cannot: not whether high and low achievers mixed, but *when* they did, and
#' whether the pattern held or decayed.
#'
#' The grouping variable comes from the vertex attributes supplied to
#' [dynet()] through its `nodes` argument.
#'
#' @param dn A temporal network from [dynet()] built with vertex attributes.
#' @param attribute Name of a column in the vertex table.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param sample `"window"` or `"instant"`, as in [dyn_centrality()].
#'
#' @return A `dynet_metric` at graph level with one row per time point and
#'   ordered group pair. Alongside `measure` (rendered as `"A -> B"`) and
#'   `value` (the edge count) it carries `from_group` and `to_group` columns,
#'   so a single pairing can be pulled out with [subset()].
#'
#' @examples
#' dn <- dynet(forum_posts, thread = "thread", nodes = forum_people)
#' dyn_mixing(dn, attribute = "role")
#' plot(dyn_mixing(dn, attribute = "role"))
#'
#' @export
dyn_mixing <- function(dn, attribute,
                       sessions = c("bounded", "collapse", "separate"),
                       sample = c("window", "instant")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  sample <- match.arg(sample)
  .check("`attribute` must be a single column name." =
              is.character(attribute) && length(attribute) == 1L)

  if (!attribute %in% names(dn$nodes)) {
    have <- setdiff(names(dn$nodes), "name")
    stop(errorCondition(
      sprintf("No vertex attribute %s. This network has %s. Supply attributes through dynet(nodes = ).",
              sQuote(attribute),
              if (length(have)) paste(have, collapse = ", ") else "no attributes"),
      class = "dynet_unknown_attribute", call = NULL))
  }

  grp <- as.character(dn$nodes[[attribute]])
  grp[is.na(grp)] <- "(missing)"
  levs <- sort(unique(grp))
  pairs <- expand.grid(from_group = levs, to_group = levs,
                       stringsAsFactors = FALSE)
  if (!dn$directed) pairs <- pairs[pairs$from_group <= pairs$to_group, , drop = FALSE]

  # Counting is done on the same binary adjacency the other verbs use, so a
  # pair connected by two spells in one bin is one edge here as well.
  df <- .over_bins(dn, sessions, node_level = FALSE, sample = sample,
    fun = function(enc, act, bin) {
      a <- .binary(.adjacency(enc, act, dn$directed), dn$directed)
      counts <- vapply(seq_len(nrow(pairs)), function(k) {
        block <- a[grp == pairs$from_group[k], grp == pairs$to_group[k],
                   drop = FALSE]
        halve <- !dn$directed && identical(pairs$from_group[k], pairs$to_group[k])
        if (halve) sum(block) / 2 else sum(block)
      }, numeric(1L))
      stats::setNames(counts,
                      sprintf("%s -> %s", pairs$from_group, pairs$to_group))
    })

  split_key <- do.call(rbind, strsplit(df$measure, " -> ", fixed = TRUE))
  df$from_group <- split_key[, 1L]
  df$to_group   <- split_key[, 2L]

  .metric(df, level = "graph", what = sprintf("Mixing by %s", attribute),
          dn = dn, note = "edge counts between vertex groups per time bin")
}

# ===========================================================================
# dyn_snapshots() — the network as a sequence of tidy edge tables
# ===========================================================================

#' The network sliced into snapshots
#'
#' @description
#' The edges alive in each time bin, as one tidy table. Useful for exporting a
#' slice, for feeding a layout routine, or for checking by eye what the metric
#' verbs are seeing.
#'
#' @param dn A temporal network from [dynet()].
#' @param at Optional numeric time. When given, only the bin containing that
#'   time is returned.
#' @param sessions How to treat sessions, as in [dyn_centrality()].
#' @param sample `"window"` or `"instant"`, as in [dyn_centrality()].
#'
#' @return A `data.frame` with one row per active edge per bin: `session`
#'   (when present), `time`, `from`, `to`, `weight` and `n_spells`. A pair
#'   joined by more than one spell in the same bin is one edge, with
#'   `n_spells` recording how many spells were collapsed -- so the edge counts
#'   here agree with those from [dyn_metrics()].
#'
#' @examples
#' dn <- dynet(school_contacts)
#' dyn_snapshots(dn, at = 3)
#'
#' @export
dyn_snapshots <- function(dn, at = NULL,
                          sessions = c("bounded", "collapse", "separate"),
                          sample = c("window", "instant")) {
  sessions <- match.arg(sessions)
  .check_dynet(dn, sessions)
  sample <- match.arg(sample)

  parts <- .split_sessions(dn, sessions)
  frames <- Map(function(enc, label) {
    grid <- .grid_for(enc, dn)
    if (!is.null(at)) {
      k <- which(grid$lo <= at & grid$hi > at)
      if (length(k) == 0L) k <- nrow(grid)
      grid <- grid[k, , drop = FALSE]
    }
    do.call(rbind, lapply(seq_len(nrow(grid)), function(k) {
      act <- .active(enc, grid$lo[k], grid$hi[k],
                     last = grid$bin[k] == max(grid$bin), sample = sample)
      if (!any(act)) return(NULL)
      key <- paste(enc$from[act], enc$to[act], sep = "\r")
      by_pair <- split(seq_len(sum(act)), key)
      ends <- do.call(rbind, strsplit(names(by_pair), "\r", fixed = TRUE))
      data.frame(
        session = label, time = grid$time[k],
        from = enc$names[as.integer(ends[, 1L])],
        to   = enc$names[as.integer(ends[, 2L])],
        weight   = vapply(by_pair, function(i) sum(enc$weight[act][i]), numeric(1L)),
        n_spells = vapply(by_pair, length, integer(1L)),
        stringsAsFactors = FALSE)
    }))
  }, parts, names(parts))

  out <- do.call(rbind, frames)
  if (is.null(out)) {
    out <- data.frame(session = character(), time = numeric(),
                      from = character(), to = character(), weight = numeric(),
                      n_spells = integer(), stringsAsFactors = FALSE)
  }
  if (is.null(dn$meta$sessions)) out$session <- NULL
  rownames(out) <- NULL
  out
}
