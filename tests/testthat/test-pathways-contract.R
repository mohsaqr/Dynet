test_that("pathways ranks whole routes and never renormalises the share", {
  dn <- quiet_dynet(school_contacts)
  all_routes <- pathways(dn, from = "Ana")

  expect_s3_class(all_routes, "dynet_pathways")
  expect_identical(names(as.data.frame(all_routes)),
                   c("route", "endpoint", "count", "share", "n_hops",
                     "arrival_time"))
  # Already ordered, so a caller never sorts it.
  expect_identical(all_routes$count, sort(all_routes$count, decreasing = TRUE))
  expect_equal(sum(all_routes$share), 1)
  # A route's endpoint is the last vertex of its own sequence.
  last <- vapply(strsplit(all_routes$route, " -> ", fixed = TRUE),
                 function(s) s[[length(s)]], character(1L))
  expect_identical(last, all_routes$endpoint)
  # n_hops is one fewer than the vertices visited.
  expect_identical(
    all_routes$n_hops,
    vapply(strsplit(all_routes$route, " -> ", fixed = TRUE), length,
           integer(1L)) - 1L
  )

  # `top` keeps the head; it does NOT rescale share, or the number would be
  # meaningless -- it would always sum to one whatever was kept.
  three <- pathways(dn, from = "Ana", top = 3)
  expect_identical(nrow(three), 3L)
  expect_identical(three$share, utils::head(all_routes$share, 3L))
  expect_lt(sum(three$share), 1)
})

test_that("pooling adds a source column and covers every vertex", {
  dn <- quiet_dynet(school_contacts)
  pooled <- pathways(dn)
  expect_identical(names(as.data.frame(pooled))[[1L]], "from")
  # Each route begins at its own stated source.
  first <- vapply(strsplit(pooled$route, " -> ", fixed = TRUE),
                  function(s) s[[1L]], character(1L))
  expect_identical(first, pooled$from)

  # A single source is the same answer as that source's slice of the pool,
  # up to the share, which is over a different total in each case.
  one <- pathways(dn, from = "Ana")
  from_pool <- pooled[pooled$from == "Ana", , drop = FALSE]
  expect_setequal(from_pool$route, one$route)
  expect_identical(sum(from_pool$count), sum(one$count))
})

test_that("routes sharing a vertex sequence are merged, not listed twice", {
  dn <- quiet_dynet(school_contacts)
  found <- pathways(dn, from = "Ana")
  expect_false(anyDuplicated(found$route) > 0L)

  # The merge is only lossless because arrival times AGREE within a repeated
  # sequence: paths() is foremost, so a later realisation of the same sequence
  # is never optimal and never counted. If that ever stops holding, reporting
  # one arrival time for the group silently hides a spread, so assert it.
  tree <- as.data.frame(path_trajectories(paths(dn, from = "Ana")))
  body <- tree[tree$node != "(start)", , drop = FALSE]
  parent_of <- stats::setNames(body$parent, body$node)
  vertex_of <- stats::setNames(body$vertex, body$node)
  leaves <- body[!body$node %in% body$parent, , drop = FALSE]
  sequence_of <- vapply(leaves$node, function(id) {
    steps <- character(0)
    while (!is.na(id) && nzchar(id) && id != "(start)") {
      steps <- c(vertex_of[[id]], steps); id <- parent_of[[id]]
    }
    paste(steps, collapse = " -> ")
  }, character(1L))
  spans <- vapply(split(leaves$time, sequence_of), function(times) {
    diff(range(times))
  }, numeric(1L))
  expect_true(all(spans <= sqrt(.Machine$double.eps)))
})

test_that("pathways summarises, plots and refuses bad input by class", {
  dn <- quiet_dynet(school_contacts)
  found <- pathways(dn, from = "Ana")

  digest <- summary(found)
  expect_identical(sum(digest$count), sum(found$count))
  expect_identical(sum(digest$routes), nrow(found))
  expect_setequal(digest$endpoint, unique(found$endpoint))
  expect_identical(digest$count, sort(digest$count, decreasing = TRUE))

  expect_s3_class(plot(found), "ggplot")

  expect_error(pathways(dn, from = "Nobody"), class = "dynet_unknown_node")
  expect_error(pathways(dn, top = 0), class = "dynet_bad_input")
  expect_error(pathways(dn, min_hops = -1), class = "dynet_bad_input")
  expect_error(pathways(dn, from = "Ana", min_hops = 99),
               class = "dynet_empty_result")
  expect_error(plot(found, top = 0), class = "dynet_bad_input")
  expect_error(plot(found, labels = NA), class = "dynet_bad_input")
})

test_that("the step table times every hop and matches the routes it describes", {
  dn <- quiet_dynet(school_contacts)
  found <- pathways(dn, from = "Ana")
  steps <- as.data.frame(found, what = "steps")

  expect_identical(names(steps), c("route", "step", "vertex", "time"))
  # Exactly the routes that were returned, no more and no fewer.
  expect_setequal(unique(steps$route), found$route)
  # A route's steps reconstruct its own name, in order.
  rebuilt <- vapply(split(steps, steps$route), function(part) {
    part <- part[order(part$step), , drop = FALSE]
    paste(part$vertex, collapse = " -> ")
  }, character(1L))
  expect_identical(unname(rebuilt[found$route]), found$route)

  # Time is what makes the drawing time-respecting: a route never travels
  # backwards, and its last step is the arrival time the route table reports.
  lapply(split(steps, steps$route), function(part) {
    part <- part[order(part$step), , drop = FALSE]
    expect_false(is.unsorted(part$time))
  })
  arrivals <- vapply(split(steps$time, steps$route), max, numeric(1L))
  expect_equal(unname(arrivals[found$route]), found$arrival_time)
  # One row per hop, plus the source itself.
  counted <- vapply(split(steps$step, steps$route), length, integer(1L))
  expect_identical(unname(counted[found$route]), found$n_hops + 1L)

  expect_error(as.data.frame(found, what = "nope"))
})
