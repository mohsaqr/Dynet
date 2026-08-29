three_journeys <- function(shift = 0) {
  # A->F->G->D arrives 3 (3 hops), A->B->D arrives 5 (2 hops),
  # A->C->D arrives 7 (2 hops) and is the latest-departing journey (leaves 6).
  dynet(
    data.frame(from = c("A", "B", "A", "C", "A", "F", "G"),
               to   = c("B", "D", "C", "D", "F", "G", "D"),
               time = c(0, 5, 6, 7, 1, 2, 3) + shift),
    format = "contact", directed = TRUE,
    nodes = data.frame(name = c("A", "B", "C", "D", "F", "G")),
    observation_start = 0 + shift, observation_end = 10 + shift)
}

school <- function() dynet(school_contacts, format = "contact")
deadline_of <- function(dn) dn$meta$time_range[["end"]]

test_that("a latest-departure query without a deadline is refused", {
  dn <- dynet(data.frame(from = "A", to = "B", time = 1),
              format = "contact", directed = TRUE)
  expect_false(isTRUE(dn$meta$observation_explicit))
  expect_error(paths(dn, from = "A", criterion = "latest_departure"),
               class = "dynet_bad_input")
  expect_error(Dynet:::.latest_departure_search(
    dn, Dynet:::.encode(dn), 1L, 0, Inf, FALSE))
  out <- paths(dn, from = "A", criterion = "latest_departure", end = 5)
  expect_identical(attr(out, "deadline"), 5)
})

test_that("latest departure combined with a backward query is refused", {
  dn <- three_journeys()
  expect_error(paths(dn, from = "A", direction = "backward",
                     criterion = "latest_departure", end = 10),
               class = "dynet_bad_input")
})

test_that("the optimality of every criterion is recorded", {
  dn <- three_journeys()
  expect_identical(attr(paths(dn, from = "A"), "optimality"), "minimum")
  expect_identical(attr(paths(dn, from = "A", criterion = "min_hops"),
                        "optimality"), "minimum")
  expect_identical(attr(paths(dn, from = "A", criterion = "latest_departure"),
                        "optimality"), "maximum")
  expect_error(Dynet:::.criterion_optimality("cheapest"),
               class = "dynet_bad_input")
})

test_that("the fixture selects the latest-departing journey", {
  dn <- three_journeys()
  out <- as.data.frame(paths(dn, from = "A", criterion = "latest_departure"))
  expect_named(out, c("node", "reachable", "arrival_time", "departure_time",
                      "duration", "attained", "latency", "n_hops", "n_paths"))
  expect_equal(out$duration, out$arrival_time - out$departure_time)
  d <- subset(out, node == "D")
  expect_identical(d$departure_time, 6)
  expect_identical(d$arrival_time, 7)
  expect_identical(d$n_hops, 2L)
  expect_identical(d$n_paths, 1)
  expect_true(d$attained)
  # The empty journey departs at the deadline itself.
  a <- subset(out, node == "A")
  expect_identical(a$departure_time, 10)
  expect_identical(a$arrival_time, 10)
  expect_identical(a$n_hops, 0L)
  expect_identical(a$n_paths, 1)
})

test_that("the steps of every route start at the departure and end at the arrival", {
  dn <- three_journeys()
  out <- paths(dn, from = "A", criterion = "latest_departure")
  steps <- as.data.frame(out, what = "steps")
  first <- subset(steps, step == 0)
  last <- do.call(rbind, lapply(split(steps, steps$endpoint), function(block) {
    block[which.max(block$step), ]
  }))
  table <- as.data.frame(out)
  expect_identical(first$node, rep("A", nrow(first)))
  expect_equal(first$time, table$departure_time[match(first$endpoint, table$node)])
  expect_identical(last$node, last$endpoint)
  expect_equal(last$time, table$arrival_time[match(last$endpoint, table$node)])
})

test_that("source-pivoted and target-pivoted latest departures are the same numbers", {
  # The duality that defines the criterion: leaving `s`, the latest departure
  # into `z` equals the label a backward search rooted at `z` assigns to `s`.
  for (dn in list(three_journeys(), school())) {
    H <- deadline_of(dn)
    nodes <- as.data.frame(dn, what = "nodes")$name
    for (s in nodes) {
      fwd <- as.data.frame(paths(dn, from = s, criterion = "latest_departure",
                                 end = H))
      for (z in nodes) {
        bwd <- as.data.frame(paths(dn, from = z, direction = "backward",
                                   end = H))
        expect_identical(subset(fwd, node == z)$departure_time,
                         subset(bwd, node == s)$arrival_time,
                         info = paste(s, "->", z))
        expect_identical(subset(fwd, node == z)$attained,
                         subset(bwd, node == s)$attained,
                         info = paste(s, "->", z))
      }
    }
  }
})

test_that("latest departures agree with tsna's latest.depart oracle", {
  skip_if_not_installed("tsna")
  skip_if_not_installed("networkDynamic")
  dn <- three_journeys()
  nodes <- c("A", "B", "C", "D", "F", "G")
  el <- data.frame(from = c("A", "B", "A", "C", "A", "F", "G"),
                   to   = c("B", "D", "C", "D", "F", "G", "D"),
                   time = c(0, 5, 6, 7, 1, 2, 3))
  base <- network::network.initialize(length(nodes), directed = TRUE)
  network::network.vertex.names(base) <- nodes
  nd <- networkDynamic::networkDynamic(
    base.net = base,
    edge.spells = data.frame(onset = el$time, terminus = el$time,
                             tail = match(el$from, nodes),
                             head = match(el$to, nodes)),
    verbose = FALSE)
  # tsna reports `end - departure` per source, one target at a time.
  oracle <- vapply(nodes, function(z) {
    tp <- tsna::tPath(nd, v = match(z, nodes), direction = "bkwd",
                      type = "latest.depart", start = 0, end = 10)
    10 - tp$tdist[[match("A", nodes)]]
  }, numeric(1L))
  out <- as.data.frame(paths(dn, from = "A", criterion = "latest_departure"))
  expect_equal(out$departure_time[match(nodes, out$node)], unname(oracle))
})

test_that("no other criterion departs later", {
  # Every criterion optimises over the same feasible set, so the departure of
  # any selected journey is bounded by the latest-departure supremum. At zero
  # traversal time a route's step-1 time is its first-hop entry.
  cases <- list(list(dn = three_journeys(), s = "A"),
                list(dn = school(), s = "Ana"))
  checked <- 0L
  for (case in cases) {
    dn <- case$dn
    H <- deadline_of(dn)
    for (s in case$s) {
      latest <- as.data.frame(paths(dn, from = s, criterion = "latest_departure",
                                    end = H))
      for (cr in c("foremost_then_shortest", "min_hops")) {
        steps <- as.data.frame(paths(dn, from = s, criterion = cr, end = H),
                               what = "steps")
        first_hop <- aggregate(time ~ endpoint, data = subset(steps, step == 1),
                               FUN = max)
        bound <- latest$departure_time[match(first_hop$endpoint, latest$node)]
        expect_true(all(first_hop$time <= bound), info = paste(s, cr))
        checked <- checked + nrow(first_hop)
      }
    }
  }
  expect_gt(checked, 10L)
})

test_that("reachability is identical to the default", {
  dn <- school()
  H <- deadline_of(dn)
  for (src in c("Ana", "Jonas", "Kira")) {
    a <- as.data.frame(paths(dn, from = src, end = H))
    b <- as.data.frame(paths(dn, from = src, criterion = "latest_departure",
                             end = H))
    expect_identical(a$reachable, b$reachable, info = src)
    expect_identical(a$node, b$node, info = src)
  }
})

test_that("lowering the deadline can only lower or preserve the departure", {
  dn <- three_journeys()
  late <- as.data.frame(paths(dn, from = "A", criterion = "latest_departure",
                              end = 10))
  early <- as.data.frame(paths(dn, from = "A", criterion = "latest_departure",
                               end = 6))
  both <- late$reachable & early$reachable
  expect_true(all(early$departure_time[both] <= late$departure_time[both]))
  # The literal: by t = 6 only A->F->G->D (leaving at 1) reaches D.
  expect_identical(subset(early, node == "D")$departure_time, 1)
  expect_identical(subset(early, node == "D")$arrival_time, 3)
})

test_that("translating time translates departures and arrivals", {
  base <- as.data.frame(paths(three_journeys(), from = "A",
                              criterion = "latest_departure"))
  shifted <- as.data.frame(paths(three_journeys(shift = 1000), from = "A",
                                 criterion = "latest_departure"))
  expect_equal(shifted$departure_time, base$departure_time + 1000)
  expect_equal(shifted$arrival_time, base$arrival_time + 1000)
  expect_identical(shifted$n_hops, base$n_hops)
  expect_identical(shifted$n_paths, base$n_paths)
  expect_identical(shifted$reachable, base$reachable)
})

test_that("an unattained supremum is reachable with no realising journey", {
  # A->B is open at 10 and B->C fires exactly at 10: the latest departure
  # into C is the supremum 10, which no journey attains.
  spells <- data.frame(from = c("A", "B"), to = c("B", "C"),
                       start = c(0, 10), end = c(10, 10))
  dn <- dynet(spells, directed = TRUE, observation_start = 0,
              observation_end = 10)
  out <- paths(dn, from = "A", criterion = "latest_departure")
  c_row <- subset(as.data.frame(out), node == "C")
  expect_true(c_row$reachable)
  expect_false(c_row$attained)
  expect_identical(c_row$departure_time, 10)
  # Journeys departing just before 10 arrive at 10: the limit is reported,
  # the family that would realise it is empty.
  expect_identical(c_row$arrival_time, 10)
  expect_identical(c_row$duration, 0)
  expect_identical(c_row$n_hops, NA_integer_)
  expect_identical(c_row$n_paths, 0)
  steps <- as.data.frame(out, what = "steps")
  expect_false("C" %in% steps$endpoint)
})

test_that("bounded sessions take the latest departure over the session-local ones", {
  contacts <- within(school_contacts, session <- ifelse(start < 5, "s1", "s2"))
  dn <- dynet(contacts, session = "session")
  H <- deadline_of(dn)
  bounded <- as.data.frame(paths(dn, from = "Ana", criterion = "latest_departure",
                                 end = H))
  separate <- as.data.frame(paths(dn, from = "Ana", criterion = "latest_departure",
                                  sessions = "separate", end = H))
  expect_true("path_session" %in% names(bounded))
  per_node <- aggregate(departure_time ~ node, data = separate, FUN = max,
                        na.action = stats::na.omit)
  expect_equal(bounded$departure_time[match(per_node$node, bounded$node)],
               per_node$departure_time)
  reached_somewhere <- unique(subset(separate, reachable)$node)
  expect_setequal(subset(bounded, reachable)$node, reached_somewhere)
})

test_that("print and summary run on a latest-departure result", {
  dn <- three_journeys()
  out <- paths(dn, from = "A", criterion = "latest_departure")
  expect_output(print(out), "Latest departures from")
  expect_output(print(out), "by t = 10")
  s <- summary(out)
  expect_s3_class(s, "data.frame")
  expect_identical(subset(s, property == "reachable")$value, "5")
})
