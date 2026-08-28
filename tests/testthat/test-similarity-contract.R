test_that("similarity is symmetric with a defined diagonal", {
  skip_if_not_installed("cograph")
  dn <- dynet(school_contacts)
  s <- as.data.frame(similarity(dn))
  # Only the off-diagonal forms mirrored pairs; the diagonal is a single cell.
  off <- s[s$time != s$other, , drop = FALSE]
  key <- paste(pmin(off$time, off$other), pmax(off$time, off$other))
  halves <- split(off$value, key)
  expect_true(all(vapply(halves, \(v) isTRUE(all.equal(v[[1L]], v[[2L]])),
                         logical(1L))))
  expect_true(all(s$value[s$time == s$other] == 1))
  expect_true(all(s$value >= 0 & s$value <= 1))
})

test_that("hamming is a distance, so its diagonal is zero", {
  skip_if_not_installed("cograph")
  dn <- dynet(school_contacts)
  h <- as.data.frame(similarity(dn, method = "hamming"))
  expect_true(all(h$value[h$time == h$other] == 0))
  expect_true(all(h$value >= 0))
})

test_that("every coefficient runs and the table is complete", {
  skip_if_not_installed("cograph")
  dn <- dynet(school_contacts)
  bins <- length(unique(as.data.frame(snapshots(dn))$time))
  invisible(lapply(c("jaccard", "overlap", "hamming", "cosine", "pearson"),
    function(m) {
      s <- similarity(dn, method = m)
      expect_equal(nrow(s), bins^2)           # every ordered pair present
      expect_identical(unique(s$measure), m)
      expect_false(anyNA(s$value))
    }))
})

test_that("similarity refuses a single bin rather than returning a 1x1", {
  # One contact gives one bin, and a similarity matrix of itself says nothing.
  dn <- dynet(data.frame(from = "A", to = "B", time = 1), format = "contact")
  expect_error(similarity(dn), class = "dynet_empty_result")
})

test_that("similarity has the accessors every result class carries", {
  skip_if_not_installed("cograph")
  s <- similarity(dynet(school_contacts))
  expect_s3_class(s, "dynet_similarity")
  expect_s3_class(as.data.frame(s), "data.frame")
  expect_false(inherits(as.data.frame(s), "dynet_similarity"))
  expect_output(print(s), "similarity across")
  expect_s3_class(plot(s), "ggplot")
})

test_that("omega weights the interlayer coupling of the projection", {
  # The identity arcs carry a node from one slice to the next; their weight
  # is the interlayer coupling of the time-expanded network.
  dn <- dynet(school_contacts)
  arc <- function(w) {
    e <- as.data.frame(projection(dn, omega = w), what = "edges")
    unique(e$weight[e$edge_type == "identity_arc"])
  }
  expect_identical(arc(1), 1)
  expect_identical(arc(0), 0)
  expect_identical(arc(2.5), 2.5)
  # Coupling must not disturb the within-slice edges.
  within <- function(w) {
    e <- as.data.frame(projection(dn, omega = w), what = "edges")
    sum(e$edge_type == "within_slice")
  }
  expect_identical(within(0), within(3))
  expect_error(projection(dn, omega = -1), class = "dynet_bad_input")
})
