# motifs() counts the Paranjape (2017) 40-class three-node temporal motif
# census in raphtory 0.17.0's class ordering. The ordering is copied from
# raphtory deliberately: it is what makes the taxonomy falsifiable.
#
# The class table in R/motif-table.R was DERIVED from raphtory by brute force,
# not transcribed -- every canonical three-edge sequence on at most three nodes
# was classified by raphtory and its answer recorded.

raphtory_cases <- function() {
  source(test_path("fixtures", "raphtory-motifs.R"), local = TRUE)$value
}

directed <- function(d) quiet_dynet(d, format = "contact", directed = TRUE)

# ---------------------------------------------------------------- error paths

test_that("motifs refuses an undirected network", {
  dn <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "C"), time = c(1, 2)),
    format = "contact", directed = FALSE
  )
  expect_error(motifs(dn, delta = 2), class = "dynet_needs_directed")
})

test_that("delta is required and must be a sane number", {
  dn <- directed(data.frame(from = "A", to = "B", time = 1))
  expect_error(motifs(dn), class = "dynet_bad_input")
  expect_error(motifs(dn, delta = -1), class = "dynet_bad_input")
  expect_error(motifs(dn, delta = c(1, 2)), class = "dynet_bad_input")
  expect_error(motifs(dn, delta = Inf), class = "dynet_bad_input")
})

test_that("motifs refuses separate without sessions", {
  dn <- directed(data.frame(from = "A", to = "B", time = 1))
  expect_error(motifs(dn, delta = 1, sessions = "separate"),
               class = "dynet_no_sessions")
})

# ---------------------------------------------------------------- calibration

test_that("every raphtory reference census is reproduced exactly", {
  for (name in names(raphtory_cases())) {
    case <- raphtory_cases()[[name]]
    out <- as.data.frame(motifs(directed(case$edges), delta = case$delta))
    expect_identical(as.integer(out$motif[out$count > 0]),
                     as.integer(case$nonzero), info = name)
    expect_equal(sum(out$count), length(case$nonzero), info = name)
  }
})

test_that("delta spans first to last, not consecutive gaps", {
  # The boundary case: the same three events are a motif at delta = 2 and not
  # at delta = 1, because 3 - 1 = 2.
  edges <- data.frame(from = c("A", "B", "A"), to = c("B", "C", "C"),
                      time = c(1, 2, 3))
  expect_equal(sum(as.data.frame(motifs(directed(edges), delta = 2))$count), 1)
  expect_equal(sum(as.data.frame(motifs(directed(edges), delta = 1))$count), 0)
})

# ----------------------------------------------------------------- invariants

test_that("the census always has all 40 classes", {
  dn <- directed(data.frame(from = "A", to = "B", time = 1))
  expect_identical(nrow(as.data.frame(motifs(dn, delta = 1))), 40L)
  local_census <- as.data.frame(motifs(dn, delta = 1, output = "local"))
  expect_identical(nrow(local_census), 40L * nrow(dn$nodes))
  # An empty census is all zeros, not missing rows.
  expect_true(all(as.data.frame(motifs(dn, delta = 1))$count == 0))
})

test_that("local and global reconcile per family", {
  # Raphtory's counting rule, verified against it directly: stars and two-node
  # motifs reconcile 1:1, triangles 3:1 because all three vertices count the
  # instance. This is the invariant a wrong implementation breaks.
  dn <- quiet_dynet(school_contacts, format = "contact")
  global_census <- as.data.frame(motifs(dn, delta = 2))
  local_census <- as.data.frame(motifs(dn, delta = 2, output = "local"))
  by_family <- function(d, families) sum(d$count[d$family %in% families])
  stars <- c("star_pre", "star_mid", "star_post")

  expect_equal(by_family(local_census, stars),
               by_family(global_census, stars))
  expect_equal(by_family(local_census, "two_node"),
               by_family(global_census, "two_node"))
  expect_equal(by_family(local_census, "triangle"),
               3 * by_family(global_census, "triangle"))
})

test_that("the census is non-decreasing in delta", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  totals <- vapply(c(0, 0.5, 1, 2, 4), function(d) {
    sum(as.data.frame(motifs(dn, delta = d))$count)
  }, numeric(1L))
  expect_false(is.unsorted(totals))
})

test_that("renaming vertices leaves the global census identical", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  before <- as.data.frame(motifs(dn, delta = 2))
  renamed <- rename_nodes(dn, stats::setNames(paste0("z_", dn$nodes$name),
                                              dn$nodes$name))
  after <- as.data.frame(motifs(renamed, delta = 2))
  expect_identical(before$count, after$count)
})

test_that("the census is invariant to translating and rescaling time", {
  edges <- data.frame(from = c("A", "B", "A", "A"), to = c("B", "C", "C", "B"),
                      time = c(1, 2, 3, 4))
  base <- as.data.frame(motifs(directed(edges), delta = 10))

  shifted <- edges; shifted$time <- shifted$time + 1000
  expect_identical(as.data.frame(motifs(directed(shifted), delta = 10))$count,
                   base$count)

  scaled <- edges; scaled$time <- scaled$time * 7
  expect_identical(as.data.frame(motifs(directed(scaled), delta = 70))$count,
                   base$count)
})

test_that("row order does not change the census", {
  # The tie rule exists so that simultaneous events cannot be decided by the
  # order rows happened to arrive in.
  set.seed(7L)
  edges <- data.frame(
    from = c("A", "B", "A", "C", "A", "B"),
    to   = c("B", "C", "C", "A", "B", "A"),
    time = c(1, 1, 2, 2, 3, 3)
  )
  base <- as.data.frame(motifs(directed(edges), delta = 5))
  shuffled <- edges[sample(nrow(edges)), , drop = FALSE]
  expect_identical(as.data.frame(motifs(directed(shuffled), delta = 5))$count,
                   base$count)
})

test_that("two events are a P-shift but never a motif", {
  # Confirms the two censuses have different arity and neither is secretly the
  # other.
  edges <- data.frame(from = c("A", "B"), to = c("B", "C"), time = c(1, 2))
  dn <- directed(edges)
  expect_equal(sum(as.data.frame(motifs(dn, delta = 10))$count), 0)
  shifts <- as.data.frame(pshifts(dn))
  expect_gt(sum(shifts$value), 0)
})

test_that("loops are excluded from the census", {
  with_loop <- quiet_dynet(
    data.frame(from = c("A", "A", "A", "A"), to = c("A", "B", "C", "A"),
               time = c(1, 2, 3, 4)),
    format = "contact", directed = TRUE, loops = TRUE
  )
  without <- quiet_dynet(
    data.frame(from = c("A", "A"), to = c("B", "C"), time = c(2, 3)),
    format = "contact", directed = TRUE
  )
  expect_identical(as.data.frame(motifs(with_loop, delta = 10))$count,
                   as.data.frame(motifs(without, delta = 10))$count)
})

# ------------------------------------------------------------------ structure

test_that("the result carries its definitional attributes", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  out <- motifs(dn, delta = 2)
  expect_s3_class(out, "dynet_motifs")
  expect_identical(attr(out, "delta"), 2)
  expect_identical(attr(out, "motif_family"), "paranjape_2017_3_3")
  expect_identical(attr(out, "motif_order"), "raphtory_0.17")
  expect_identical(attr(out, "overlapping_instances"), "counted")
  expect_identical(names(as.data.frame(out)),
                   c("motif", "family", "pattern", "count"))
})

test_that("the four methods exist and behave", {
  dn <- quiet_dynet(school_contacts, format = "contact")
  out <- motifs(dn, delta = 2)
  expect_output(print(out), "Temporal motifs")
  families <- summary(out)
  expect_true(all(c("family", "count", "share", "top_motif") %in%
                    names(families)))
  expect_equal(sum(families$share), 1, tolerance = sqrt(.Machine$double.eps))
  expect_s3_class(as.data.frame(out), "data.frame")
  expect_error(summary(out, by = "node"), class = "dynet_bad_input")
})
