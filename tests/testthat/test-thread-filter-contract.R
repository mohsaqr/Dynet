# `min_thread_posts` and the order of the threaded filters: self-replies are
# removed before a thread's lifetime is computed, and a thread with too few
# surviving posts is dropped whole.

thread_log <- data.frame(
  from   = c("A", "B", "A", "C", "D"),
  to     = c("B", "A", "A", "D", "D"),
  time   = c(0, 1, 5, 2, 7),
  thread = c("t1", "t1", "t1", "t2", "t2")
)

test_that("min_thread_posts is validated and needs a threaded log", {
  expect_error(dynet(thread_log, thread = "thread", min_thread_posts = 0),
               class = "dynet_bad_input")
  expect_error(dynet(thread_log, thread = "thread", min_thread_posts = 1.5),
               class = "dynet_bad_input")
  expect_error(dynet(thread_log, time = "time", min_thread_posts = 2),
               class = "dynet_needs_thread")
})

test_that("a dropped self-reply does not extend its thread", {
  # t1 holds A->B at 0, B->A at 1 and the self-reply A->A at 5. With loops
  # dropped the thread ends at 1, not 5.
  dn <- quiet_dynet(thread_log, thread = "thread")
  spells <- as.data.frame(dn)
  t1 <- subset(spells, thread == "t1")
  expect_equal(max(t1$end), 1)
  # Kept loops restore the longer lifetime.
  kept <- quiet_dynet(thread_log, thread = "thread", loops = TRUE)
  kept_spells <- as.data.frame(kept)
  kept_t1 <- subset(kept_spells, thread == "t1")
  expect_equal(max(kept_t1$end), 5)
})

test_that("min_thread_posts drops thin threads whole and reports it", {
  # t2 has one non-loop post (C->D) after its self-reply is dropped, so it
  # falls below a minimum of two.
  expect_message(
    dn <- dynet(thread_log, thread = "thread", min_thread_posts = 2),
    "Dropped 1 thread"
  )
  spells <- as.data.frame(dn)
  expect_identical(unique(spells$thread), "t1")
  # Invariant: every surviving thread holds at least the minimum.
  expect_true(all(table(spells$thread) >= 2))
  # No thin thread ever survives, whatever the minimum.
  dn3 <- quiet_dynet(thread_log, thread = "thread", loops = TRUE,
                     min_thread_posts = 3)
  expect_true(all(table(as.data.frame(dn3)$thread) >= 3))
  expect_error(dynet(thread_log, thread = "thread", min_thread_posts = 4),
               class = "dynet_empty_network")
})
