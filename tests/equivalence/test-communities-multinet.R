# temporal_communities(): on networks with planted communities, the partition of the node-time states against
# multinet's generalized Louvain (glouvain_ml(), Mucha et al. 2010) run on the same windows as layers of a
# multilayer network. multinet couples a vertex with itself in every layer (categorical coupling) and Dynet only
# in neighbouring windows (ordinal), and either optimiser draws its own moves; so the comparison is made where the
# optimum does not depend on either: every window holds the same planted communities (three or four groups,
# each a near-clique, nothing between them; a few within-group ties missing at random). The partitions are
# compared without their labels, as whether every two states share a community. Several planted networks and
# Dynet seed sets.

planted <- function(seed, groups, size = 5L, windows = 4L, missing = 0.15) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  nodes <- sprintf("n%02d", seq_len(groups * size))
  group <- rep(seq_len(groups), each = size)
  pairs <- subset(expand.grid(from = nodes, to = nodes, stringsAsFactors = FALSE),
                  from < to & group[match(from, nodes)] == group[match(to, nodes)])
  edges <- do.call(rbind, lapply(seq_len(windows) - 1L, \(w) {
    kept <- pairs[stats::runif(nrow(pairs)) > missing, ]
    data.frame(from = kept$from, to = kept$to, start = 7 * w + 1, end = 7 * w + 2)
  }))
  list(edges = edges, nodes = nodes, onsets = 7 * (seq_len(windows) - 1L))
}

#' Whether every two node-time states share a community
co_membership <- function(time, node, community) {
  state <- paste(time, node)
  grid <- expand.grid(a = seq_along(state), b = seq_along(state))
  grid <- subset(grid, a < b)
  data.frame(state_a = state[grid$a], state_b = state[grid$b],
             together = as.numeric(community[grid$a] == community[grid$b]))
}

multinet_partition <- function(case) {
  layered <- multinet::ml_empty()
  layers <- sprintf("w%g", case$onsets)
  multinet::add_layers_ml(layered, layers, directed = FALSE)
  multinet::add_vertices_ml(layered, data.frame(actor = rep(case$nodes, length(layers)),
                                               layer = rep(layers, each = length(case$nodes))))
  window_of <- layers[floor(case$edges$start / 7) + 1L]
  multinet::add_edges_ml(layered, data.frame(actor1 = case$edges$from, layer1 = window_of, actor2 = case$edges$to,
                                            layer2 = window_of))
  found <- multinet::glouvain_ml(layered, gamma = 1, omega = 1)
  data.frame(time = case$onsets[match(found$layer, layers)], node = found$actor, community = found$cid)
}

test_that("the partition of planted communities equals multinet::glouvain_ml()'s", {
  skip_without_reference("multinet")
  cases <- list(list(name = "three groups, seed 1", seed = 1L, groups = 3L),
                list(name = "three groups, seed 2", seed = 2L, groups = 3L),
                list(name = "four groups, seed 3", seed = 3L, groups = 4L))
  rows <- lapply(cases, \(case) {
    drawn <- planted(case$seed, case$groups)
    theirs <- multinet_partition(drawn)
    found <- temporal_communities(dynet(drawn$edges, directed = FALSE, observation_start = 0,
                                       observation_end = 7 * length(drawn$onsets)), omega = 1, seeds = 1:3, step = 7, window = 7)
    ours <- as.data.frame(found)
    theirs <- theirs[match(paste(ours$time, ours$node), paste(theirs$time, theirs$node)), ]
    sizes <- \(community) sort(as.numeric(table(community)), decreasing = TRUE)
    list(ours = cbind(case = case$name, co_membership(ours$time, ours$node, ours$community)),
         theirs = cbind(case = case$name, co_membership(theirs$time, theirs$node, theirs$community)),
         ours_sizes = data.frame(case = case$name, rank = seq_along(sizes(ours$community)),
                                 n_states = sizes(ours$community)),
         theirs_sizes = data.frame(case = case$name, rank = seq_along(sizes(theirs$community)),
                                   n_states = sizes(theirs$community)),
         ours_summary = data.frame(case = case$name, rank = seq_len(nrow(summary(found))),
                                   n_states = sort(summary(found)$n_states, decreasing = TRUE)))
  })
  stack <- \(part) do.call(rbind, lapply(rows, `[[`, part))
  expect_reference(stack("ours"), stack("theirs"), reference = "multinet",
                   covers = c("temporal_communities()", "as.data.frame.dynet_communities()"),
                   quantity = "two states in one community, planted groups", tolerance = 0,
                   key = c("case", "state_a", "state_b"))
  expect_reference(stack("ours_summary"), stack("theirs_sizes"), reference = "multinet",
                   covers = "summary.dynet_communities()", quantity = "community sizes in states, largest first",
                   tolerance = 0, key = c("case", "rank"))
})
