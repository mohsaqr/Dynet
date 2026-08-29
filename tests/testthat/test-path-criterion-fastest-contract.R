contact_net <- function(from, to, time, end = 10, ...) {
  dynet(data.frame(from = from, to = to, time = time),
        format = "contact", directed = TRUE,
        observation_start = 0, observation_end = end, ...)
}

# A->F->G->D arrives 3 (leaves 1), A->B->D arrives 5 (leaves 0),
# A->C->D arrives 7 (leaves 6): the fastest is A->C->D, duration 1.
three_journeys <- function(shift = 0, scale = 1) {
  dynet(data.frame(from = c("A", "B", "A", "C", "A", "F", "G"),
                   to   = c("B", "D", "C", "D", "F", "G", "D"),
                   time = c(0, 5, 6, 7, 1, 2, 3) * scale + shift),
        format = "contact", directed = TRUE,
        nodes = data.frame(name = c("A", "B", "C", "D", "F", "G")),
        observation_start = shift, observation_end = 10 * scale + shift)
}

# Independent oracle from the contract: every vertex-simple contact sequence
# with nondecreasing times is a journey; its duration is last time minus
# first time (zero for the empty journey). Contact departures are always
# attained. Ties go to the earliest departure, then the fewest hops.
enumerate_journeys <- function(contacts, from, start = 0, end = Inf) {
  journeys <- list()
  extend <- function(vertices, times, atoms) {
    journeys[[length(journeys) + 1L]] <<- list(vertices = vertices,
                                               times = times, atoms = atoms)
    tail <- vertices[[length(vertices)]]
    ready <- if (length(times)) times[[length(times)]] else start
    usable <- which(contacts$from == tail & contacts$time >= ready &
                      contacts$time <= end & !(contacts$to %in% vertices))
    for (row in usable) {
      extend(c(vertices, contacts$to[[row]]), c(times, contacts$time[[row]]),
             c(atoms, row))
    }
  }
  extend(from, numeric(0), integer(0))
  journeys
}

fastest_oracle <- function(contacts, from, start = 0, end = Inf) {
  journeys <- enumerate_journeys(contacts, from, start, end)
  ends <- vapply(journeys, function(j) j$vertices[[length(j$vertices)]],
                 character(1L))
  departure <- vapply(journeys, function(j) {
    if (length(j$times)) j$times[[1L]] else start
  }, numeric(1L))
  arrival <- vapply(journeys, function(j) {
    if (length(j$times)) j$times[[length(j$times)]] else start
  }, numeric(1L))
  hops <- vapply(journeys, function(j) length(j$atoms), integer(1L))
  do.call(rbind, lapply(sort(unique(ends)), function(z) {
    at <- ends == z
    duration <- arrival - departure
    best <- min(duration[at])
    fam <- at & duration == best
    dep <- min(departure[fam])
    fam <- fam & departure == dep
    data.frame(node = z, departure_time = dep,
               arrival_time = arrival[fam][[1L]], duration = best,
               n_hops = min(hops[fam]),
               n_paths = sum(fam & hops == min(hops[fam])),
               stringsAsFactors = FALSE)
  }))
}

test_that("a negative traversal time is rejected", {
  dn <- three_journeys()
  expect_error(paths(dn, from = "A", criterion = "fastest",
                     traversal_time = -1),
               class = "dynet_bad_input")
})

test_that("fastest has no backward form", {
  dn <- three_journeys()
  expect_error(paths(dn, from = "A", direction = "backward",
                     criterion = "fastest"),
               class = "dynet_bad_input")
})

test_that("the fixture selects the fastest journey", {
  out <- as.data.frame(paths(three_journeys(), from = "A",
                             criterion = "fastest"))
  expect_named(out, c("node", "reachable", "arrival_time", "departure_time",
                      "duration", "attained", "latency", "n_hops",
                      "n_paths"))
  d <- subset(out, node == "D")
  expect_identical(d$duration, 1)
  expect_identical(d$departure_time, 6)
  expect_identical(d$arrival_time, 7)
  expect_true(d$attained)
  expect_identical(d$n_hops, 2L)
  expect_identical(d$n_paths, 1)
  a <- subset(out, node == "A")
  expect_identical(a$duration, 0)
  expect_identical(a$departure_time, 0)
  expect_identical(a$n_hops, 0L)
  expect_identical(attr(paths(three_journeys(), from = "A",
                              criterion = "fastest"), "optimality"),
                   "minimum")
})

test_that("an infimum at an excluded terminus has no minimising journey", {
  # A->B is active on [0, 10) and B->C fires at exactly 10: departing at d
  # gives duration 10 - d, the infimum 0 is approached but never reached.
  spells <- data.frame(from = c("A", "B"), to = c("B", "C"),
                       start = c(0, 10), end = c(10, 10))
  dn <- dynet(spells, directed = TRUE, observation_start = 0,
              observation_end = 10)
  out <- paths(dn, from = "A", criterion = "fastest")
  c_row <- subset(as.data.frame(out), node == "C")
  expect_true(c_row$reachable)
  expect_identical(c_row$duration, 0)
  expect_false(c_row$attained)
  expect_identical(c_row$departure_time, 10)
  expect_identical(c_row$arrival_time, 10)
  expect_identical(c_row$n_paths, 0)
  expect_identical(c_row$n_hops, NA_integer_)
  expect_false("C" %in% as.data.frame(out, what = "steps")$endpoint)
  # B itself is entered on the open interval: duration 0 is attained.
  b_row <- subset(as.data.frame(out), node == "B")
  expect_true(b_row$attained)
  expect_identical(b_row$duration, 0)
})

test_that("the fastest departure can be a downstream endpoint", {
  # s->y is active throughout [0, 10] and y->z fires at 5: the fastest
  # journey leaves s at 5, an endpoint of an atom that does not touch s.
  spells <- data.frame(from = c("s", "y"), to = c("y", "z"),
                       start = c(0, 5), end = c(10, 5))
  dn <- dynet(spells, directed = TRUE, observation_start = 0,
              observation_end = 10)
  z <- subset(as.data.frame(paths(dn, from = "s", criterion = "fastest")),
              node == "z")
  expect_identical(z$departure_time, 5)
  expect_identical(z$duration, 0)
  expect_true(z$attained)
})

test_that("fastest journeys match an exhaustive enumeration", {
  set.seed(20260830)
  checked <- 0L
  for (rep in seq_len(12)) {
    nodes <- c("A", "B", "C", "D", "E", "F")
    contacts <- unique(subset(data.frame(
      from = sample(nodes, 10, replace = TRUE),
      to = sample(nodes, 10, replace = TRUE),
      time = sample(0:8, 10, replace = TRUE),
      stringsAsFactors = FALSE
    ), from != to))
    if (!nrow(contacts)) next
    dn <- dynet(contacts, format = "contact", directed = TRUE,
                observation_start = 0, observation_end = 10)
    present <- as.data.frame(dn, what = "nodes")$name
    for (src in present) {
      got <- subset(as.data.frame(paths(dn, from = src, criterion = "fastest")),
                    reachable)
      expect_true(all(got$attained), info = paste("rep", rep, src))
      want <- fastest_oracle(contacts, src, start = 0, end = 10)
      got <- got[order(got$node), c("node", "departure_time", "arrival_time",
                                    "duration", "n_hops", "n_paths")]
      rownames(got) <- NULL
      expect_equal(got, want, info = paste("rep", rep, "from", src))
      checked <- checked + nrow(want)
    }
  }
  expect_gt(checked, 30L)
})

test_that("fastest is the minimiser: no other criterion is faster", {
  dn <- dynet(school_contacts, format = "contact")
  H <- dn$meta$time_range[["end"]]
  for (src in c("Ana", "Jonas", "Kira")) {
    fast <- as.data.frame(paths(dn, from = src, criterion = "fastest", end = H))
    late <- as.data.frame(paths(dn, from = src, criterion = "latest_departure",
                                end = H))
    both <- fast$reachable & late$reachable & !is.na(late$duration)
    expect_true(all(fast$duration[both] <= late$duration[both] +
                      sqrt(.Machine$double.eps)), info = src)
    # At zero traversal time a route's step-1 time is its first-hop entry;
    # the default's journey duration bounds the fastest from above.
    for (cr in c("foremost_then_shortest", "min_hops")) {
      other <- paths(dn, from = src, criterion = cr, end = H)
      steps <- as.data.frame(other, what = "steps")
      first_hop <- aggregate(time ~ endpoint, data = subset(steps, step == 1),
                             FUN = max)
      table <- as.data.frame(other)
      other_duration <- table$arrival_time[match(first_hop$endpoint,
                                                 table$node)] -
        first_hop$time
      bound <- fast$duration[match(first_hop$endpoint, fast$node)]
      expect_true(all(bound <= other_duration + sqrt(.Machine$double.eps)),
                  info = paste(src, cr))
    }
    base <- as.data.frame(paths(dn, from = src, end = H))
    expect_true(all(fast$arrival_time[fast$reachable] >=
                      base$arrival_time[base$reachable]), info = src)
    expect_identical(fast$reachable, base$reachable, info = src)
  }
})

test_that("translating time leaves duration alone and scaling scales it", {
  base <- as.data.frame(paths(three_journeys(), from = "A",
                              criterion = "fastest"))
  shifted <- as.data.frame(paths(three_journeys(shift = 1000), from = "A",
                                 criterion = "fastest"))
  scaled <- as.data.frame(paths(three_journeys(scale = 3), from = "A",
                                criterion = "fastest"))
  expect_equal(shifted$duration, base$duration)
  expect_equal(shifted$departure_time, base$departure_time + 1000)
  expect_equal(scaled$duration, base$duration * 3)
  expect_identical(scaled$n_hops, base$n_hops)
  expect_identical(scaled$n_paths, base$n_paths)
})

test_that("a positive traversal time is charged per hop", {
  dn <- three_journeys()
  out <- as.data.frame(paths(dn, from = "A", criterion = "fastest",
                             traversal_time = 0.5))
  d <- subset(out, node == "D")
  # A->C at 6 completes 6.5, C->D at 7 completes 7.5: duration 1.5.
  expect_identical(d$duration, 1.5)
  expect_identical(d$departure_time, 6)
  expect_identical(d$arrival_time, 7.5)
  expect_true(all(out$duration[out$reachable & out$n_hops > 0] >= 0.5))
})

test_that("bounded sessions keep the fastest journey inside one session", {
  contacts <- data.frame(from = c("A", "B", "A", "C"), to = c("B", "D", "C", "D"),
                         time = c(0, 5, 3, 4),
                         session = c("s1", "s2", "s2", "s2"))
  dn <- dynet(contacts, format = "contact", directed = TRUE,
              session = "session", observation_start = 0,
              observation_end = 10)
  d <- subset(as.data.frame(paths(dn, from = "A", criterion = "fastest")),
              node == "D")
  # A->B (s1) then B->D (s2) would take 5; A->C->D inside s2 takes 1.
  expect_identical(d$duration, 1)
  expect_identical(d$path_session, "s2")
  collapsed <- subset(as.data.frame(paths(dn, from = "A", criterion = "fastest",
                                          sessions = "collapse")), node == "D")
  expect_identical(collapsed$duration, 1)
})

test_that("closeness under fastest uses durations; betweenness is refused", {
  dn <- three_journeys()
  fast <- as.data.frame(dyn_centrality(dn, measure = "closeness",
                                       scope = "temporal",
                                       criterion = "fastest"))
  table <- as.data.frame(paths(dn, from = "A", criterion = "fastest"))
  others <- subset(table, node != "A" & reachable)
  expect_equal(subset(fast, node == "A")$value, 1 / mean(others$duration))
  expect_error(dyn_centrality(dn, measure = "betweenness", scope = "temporal",
                              criterion = "fastest"),
               class = "dynet_bad_input")
  expect_error(edge_centrality(dn, criterion = "fastest"),
               class = "dynet_bad_input")
})

test_that("print, summary and steps run on a fastest result", {
  out <- paths(three_journeys(), from = "A", criterion = "fastest")
  expect_output(print(out), "duration")
  expect_s3_class(summary(out), "data.frame")
  steps <- as.data.frame(out, what = "steps")
  first <- subset(steps, step == 0)
  table <- as.data.frame(out)
  expect_equal(first$time, table$departure_time[match(first$endpoint, table$node)])
})
