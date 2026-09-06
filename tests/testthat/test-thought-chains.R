# ===========================================================================
# thought_chains: the anonymised Trees of Thought reply table
# ===========================================================================

test_that("thought_chains has the documented shape and nothing identifying", {
  x <- thought_chains
  expect_named(x, c("from", "to", "time", "participant", "discussion", "group", "course"))
  expect_s3_class(x$time, "POSIXct")
  expect_setequal(unique(c(x$from, x$to)),
                  c("Approving", "Arguing", "Coordinating", "Drafting", "Inquiring",
                    "Objecting", "Resourcing", "Socialising", "Tutoring"))
  expect_true(all(grepl("^P[0-9]{3}$", x$participant)))
  expect_true(all(grepl("^[A-E]$", x$course)))
  expect_true(all(grepl("^[A-E]_[0-9]{2}$", x$group)))
  expect_true(is.integer(x$discussion) && min(x$discussion) == 1L)
  expect_false(anyNA(x))
})

test_that("the two sparse weekdays are absent and the other five present", {
  days <- weekdays(thought_chains$time)
  expect_false(any(days %in% c("Thursday", "Friday")))
  expect_setequal(unique(days), c("Saturday", "Sunday", "Monday", "Tuesday", "Wednesday"))
})

test_that("every remaining participant authored at least twenty reply links", {
  # The bottom 20% of authors were trimmed on distinct messages; nobody left
  # is a near-silent account.
  expect_gte(min(table(thought_chains$participant)), 20L)
})

test_that("thought_chains builds as a contact log and as a threaded log", {
  contact <- quiet_dynet(thought_chains, time = "time")
  expect_identical(contact$meta$format, "contact")
  expect_equal(nrow(as.data.frame(contact, what = "nodes")), 9L)
  threaded <- quiet_dynet(thought_chains, thread = "discussion")
  expect_identical(threaded$meta$format, "threaded")
  # Self-links (a code answering itself) are dropped unless loops = TRUE.
  expect_equal(nrow(as.data.frame(threaded)), sum(thought_chains$from != thought_chains$to))
  with_loops <- quiet_dynet(thought_chains, time = "time", loops = TRUE)
  expect_equal(nrow(as.data.frame(with_loops)), nrow(thought_chains))
  # `course` is picked up as the session column by the alias table.
  expect_identical(contact$meta$sessions, c("A", "B", "C", "D", "E"))
  # A tie in a threaded network lasts until the discussion's last post.
  sp <- as.data.frame(threaded)
  expect_true(all(sp$end >= sp$start))
})

test_that("asking for a column the table does not have is a classed error", {
  expect_error(dynet(thought_chains, thread = "conversation"),
               class = "dynet_missing_column")
})
