# Shared fixtures for the Stage 4 community tests.

# A temporal stochastic block model with a constant planted partition.
planted_sbm <- function(n = 20L, bins = 8L, blocks = 2L, p_in = 0.6,
                        p_out = 0.05, split_at = NULL, seed = 1L) {
  set.seed(seed)
  block <- rep(seq_len(blocks), length.out = n)
  pairs <- t(utils::combn(n, 2L))
  nm <- sprintf("v%02d", seq_len(n))
  rows <- do.call(rbind, lapply(seq_len(bins), function(bin) {
    membership <- if (!is.null(split_at) && bin >= split_at) {
      # One block splits in two from this bin on.
      ifelse(block == 1L & seq_len(n) > n / 4, blocks + 1L, block)
    } else block
    same <- membership[pairs[, 1L]] == membership[pairs[, 2L]]
    keep <- stats::runif(nrow(pairs)) < ifelse(same, p_in, p_out)
    data.frame(from = nm[pairs[keep, 1L]], to = nm[pairs[keep, 2L]],
               time = bin - 1L, stringsAsFactors = FALSE)
  }))
  list(
    dn = dynet(rows, format = "contact", directed = FALSE,
               nodes = data.frame(name = nm), observation_start = 0,
               observation_end = bins),
    block = stats::setNames(block, nm), nodes = nm, bins = bins
  )
}

# A network whose structure changes once, at a known bin.
planted_regime <- function(bins = 8L) {
  nm <- sprintf("v%02d", 1:10)
  early <- t(utils::combn(1:5, 2L))
  late <- t(utils::combn(6:10, 2L))
  rows <- rbind(
    do.call(rbind, lapply(seq_len(bins) - 1L, function(t)
      data.frame(from = nm[early[, 1L]], to = nm[early[, 2L]], time = t))),
    do.call(rbind, lapply(seq_len(bins) + bins - 1L, function(t)
      data.frame(from = nm[late[, 1L]], to = nm[late[, 2L]], time = t))))
  dynet(rows, format = "contact", directed = FALSE,
        nodes = data.frame(name = nm), observation_start = 0,
        observation_end = 2 * bins)
}

# A membership frame built by hand, already matched.
hand_partition <- function(labels, times = seq_len(ncol(labels)) - 1,
                           nodes = rownames(labels), attributes = NULL) {
  x <- data.frame(
    time = rep(times, each = nrow(labels)),
    node = rep(nodes, ncol(labels)),
    community = as.vector(labels),
    active = TRUE, stringsAsFactors = FALSE)
  attr(x, "matched") <- TRUE
  attr(x, "time_unit") <- "step"
  attr(x, "source") <- list(
    meta = list(time_unit = "step", interval = 1, format = "contact"),
    nodes = if (is.null(attributes)) data.frame(name = nodes) else
      data.frame(name = nodes, attributes, stringsAsFactors = FALSE),
    directed = FALSE)
  structure(x, class = c("dynet_communities", "data.frame"))
}
