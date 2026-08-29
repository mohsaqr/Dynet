contact_net <- function(from, to, time, end = 10) {
  dynet(data.frame(from = from, to = to, time = time),
        format = "contact", directed = TRUE,
        observation_start = 0, observation_end = end)
}

# One direct hop and one three-hop journey both arrive at D at t = 4.
two_lengths <- function() {
  contact_net(c("A", "A", "B", "C"), c("D", "B", "C", "D"), c(4, 1, 2, 4))
}

# A->B(0)->C(1)->B(2)->D(3) revisits B and arrives with A->B(0)->D(3).
with_cycle <- function() {
  contact_net(c("A", "B", "C", "B"), c("B", "C", "B", "D"), c(0, 1, 2, 3))
}

# Independent oracle written from the contract, not from the search: every
# vertex-simple sequence of contacts with nondecreasing times, starting at
# `from` no earlier than `start` and completing no later than `end`, is a
# journey. The foremost family to z is the journeys arriving at min arrival.
enumerate_journeys <- function(contacts, from, start = 0, end = Inf) {
  journeys <- list()
  extend <- function(vertices, time, atoms) {
    journeys[[length(journeys) + 1L]] <<- list(vertices = vertices,
                                               arrival = time, atoms = atoms)
    tail <- vertices[[length(vertices)]]
    usable <- which(contacts$from == tail & contacts$time >= time &
                      contacts$time <= end &
                      !(contacts$to %in% vertices))
    for (row in usable) {
      extend(c(vertices, contacts$to[[row]]), contacts$time[[row]],
             c(atoms, row))
    }
  }
  extend(from, start, integer(0))
  journeys
}

foremost_oracle <- function(contacts, from, start = 0, end = Inf) {
  journeys <- enumerate_journeys(contacts, from, start, end)
  ends <- vapply(journeys, function(j) j$vertices[[length(j$vertices)]],
                 character(1L))
  arrivals <- vapply(journeys, function(j) j$arrival, numeric(1L))
  hops <- vapply(journeys, function(j) length(j$atoms), integer(1L))
  do.call(rbind, lapply(sort(unique(ends)), function(z) {
    at <- ends == z
    best <- min(arrivals[at])
    fam <- at & arrivals == best
    fam_hops <- unique(hops[fam])
    data.frame(node = z, arrival_time = best,
               n_hops = if (length(fam_hops) == 1L) fam_hops else NA_integer_,
               n_paths = sum(fam), stringsAsFactors = FALSE)
  }))
}

test_that("foremost keeps every earliest-arrival journey, the default only the shortest", {
  dn <- two_lengths()
  pure <- subset(as.data.frame(paths(dn, from = "A", criterion = "foremost")),
                 node == "D")
  default <- subset(as.data.frame(paths(dn, from = "A")), node == "D")
  expect_identical(pure$arrival_time, 4)
  expect_identical(pure$n_paths, 2)
  expect_identical(pure$n_hops, NA_integer_)
  expect_identical(default$n_paths, 1)
  expect_identical(default$n_hops, 1L)
  steps <- as.data.frame(paths(dn, from = "A", criterion = "foremost"),
                         what = "steps")
  expect_identical(sort(unique(subset(steps, endpoint == "D")$path_id)),
                   c(1, 2))
  expect_identical(attr(paths(dn, from = "A", criterion = "foremost"),
                        "optimality"), "minimum")
})

test_that("a journey that revisits a vertex is not a foremost path", {
  # The hop-widened state key the specification proposed would count the
  # cyclic journey too; the vertex-set key must not.
  dn <- with_cycle()
  out <- subset(as.data.frame(paths(dn, from = "A", criterion = "foremost")),
                node == "D")
  expect_identical(out$arrival_time, 3)
  expect_identical(out$n_paths, 1)
  expect_identical(out$n_hops, 2L)
})

test_that("foremost families match an exhaustive enumeration", {
  set.seed(20260829)
  for (rep in seq_len(12)) {
    n_contacts <- 9L
    nodes <- c("A", "B", "C", "D", "E", "F")
    contacts <- data.frame(
      from = sample(nodes, n_contacts, replace = TRUE),
      to = sample(nodes, n_contacts, replace = TRUE),
      time = sample(0:6, n_contacts, replace = TRUE),
      stringsAsFactors = FALSE
    )
    contacts <- subset(contacts, from != to)
    contacts <- unique(contacts)
    if (!nrow(contacts)) next
    dn <- dynet(contacts, format = "contact", directed = TRUE,
                observation_start = 0, observation_end = 10)
    # The constructor keeps only vertices with contacts.
    present <- as.data.frame(dn, what = "nodes")$name
    for (src in present) {
      got <- subset(as.data.frame(paths(dn, from = src, criterion = "foremost")),
                    reachable)
      want <- foremost_oracle(contacts, src, start = 0, end = 10)
      got <- got[order(got$node), c("node", "arrival_time", "n_hops", "n_paths")]
      rownames(got) <- NULL
      expect_equal(got, want, info = paste("rep", rep, "from", src))
    }
  }
})

test_that("arrival is identical under foremost and the default; families are supersets", {
  set.seed(1)
  nets <- list(two_lengths(), with_cycle(),
               random_dynet(8, 30, seed = 2, model = "poisson"))
  for (dn in nets) {
    nodes <- as.data.frame(dn, what = "nodes")$name
    for (src in nodes) {
      a <- as.data.frame(paths(dn, from = src))
      b <- as.data.frame(paths(dn, from = src, criterion = "foremost"))
      expect_identical(a$node, b$node)
      expect_identical(a$reachable, b$reachable, info = src)
      expect_identical(a$arrival_time, b$arrival_time, info = src)
      expect_true(all(b$n_paths >= a$n_paths), info = src)
      known <- !is.na(b$n_hops)
      expect_identical(b$n_hops[known], a$n_hops[known], info = src)
    }
  }
})

test_that("row order and vertex labels do not change the family", {
  dn <- two_lengths()
  base <- as.data.frame(paths(dn, from = "A", criterion = "foremost"))
  contacts <- data.frame(from = c("A", "A", "B", "C"), to = c("D", "B", "C", "D"),
                         time = c(4, 1, 2, 4))
  shuffled <- contacts[c(3, 1, 4, 2), ]
  dn2 <- dynet(shuffled, format = "contact", directed = TRUE,
               observation_start = 0, observation_end = 10)
  again <- as.data.frame(paths(dn2, from = "A", criterion = "foremost"))
  expect_equal(again[order(again$node), ], base[order(base$node), ],
               ignore_attr = TRUE)
  relabel <- c(A = "w", B = "x", C = "y", D = "z")
  renamed <- within(contacts, {from <- relabel[from]; to <- relabel[to]})
  dn3 <- dynet(renamed, format = "contact", directed = TRUE,
               observation_start = 0, observation_end = 10)
  other <- as.data.frame(paths(dn3, from = "w", criterion = "foremost"))
  expect_identical(other$n_paths[match(relabel, other$node)],
                   base$n_paths[match(names(relabel), base$node)])
})

test_that("bounded sessions pool every session attaining the optimum", {
  contacts <- data.frame(from = c("A", "A", "B"), to = c("D", "B", "D"),
                         time = c(3, 1, 3), session = c("s1", "s2", "s2"))
  dn <- dynet(contacts, format = "contact", directed = TRUE,
              session = "session", observation_start = 0,
              observation_end = 10)
  pure <- subset(as.data.frame(paths(dn, from = "A", criterion = "foremost")),
                 node == "D")
  default <- subset(as.data.frame(paths(dn, from = "A")), node == "D")
  expect_identical(pure$n_paths, 2)
  expect_identical(pure$n_best_sessions, 2L)
  expect_identical(pure$n_hops, NA_integer_)
  expect_identical(default$n_paths, 1)
  expect_identical(default$path_session, "s1")
})

test_that("an exhausted state budget is a classed error, never a wrong count", {
  few <- two_lengths()
  expect_error(paths(few, from = "A", criterion = "foremost", max_states = 3),
               class = "dynet_path_family_too_large")
  expect_error(paths(few, from = "A", max_states = 500),
               class = "dynet_bad_input")
  expect_error(paths(few, from = "A", criterion = "foremost", max_states = 0))
  # A budget the family fits in is not an error.
  expect_s3_class(paths(few, from = "A", criterion = "foremost", max_states = 50),
                  "dynet_paths")
  # Real data: dead prefixes are pruned, so the family is small and exact.
  dn <- dynet(school_contacts, format = "contact")
  out <- as.data.frame(paths(dn, from = "Ana", criterion = "foremost"))
  base <- as.data.frame(paths(dn, from = "Ana"))
  expect_identical(out$arrival_time, base$arrival_time)
  expect_true(all(out$n_paths >= base$n_paths))
  expect_true(any(out$n_paths > base$n_paths))
})

test_that("betweenness under foremost is refused, closeness is not", {
  dn <- two_lengths()
  expect_error(dyn_centrality(dn, measure = "betweenness", scope = "temporal",
                              criterion = "foremost"),
               class = "dynet_intractable_criterion")
  expect_error(edge_centrality(dn, criterion = "foremost"),
               class = "dynet_intractable_criterion")
  pure <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                       scope = "temporal", criterion = "foremost"))
  default <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                          scope = "temporal"))
  expect_identical(pure$value, default$value)
})
