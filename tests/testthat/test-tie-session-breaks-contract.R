# `set_tie_sessions(breaks = )` cuts sessions on the time axis so that no
# caller has to derive a session column by hand.

test_that("breaks are validated and exclusive with session", {
  dn <- quiet_dynet(school_contacts)
  expect_error(set_tie_sessions(dn, session = "x", breaks = 7),
               class = "dynet_bad_input")
  expect_error(set_tie_sessions(dn, breaks = c(14, 7)),
               class = "dynet_bad_input")
  expect_error(set_tie_sessions(dn, breaks = c(7, Inf)),
               class = "dynet_bad_input")
  expect_error(set_tie_sessions(dn, breaks = 7, labels = "one"),
               class = "dynet_bad_input")
  expect_error(set_tie_sessions(dn, breaks = 7, labels = c("a", "a")),
               class = "dynet_bad_input")
})

test_that("a spell's session is the interval its start falls in", {
  dn <- quiet_dynet(school_contacts)
  weeks <- set_tie_sessions(dn, breaks = c(7, 14),
                            labels = c("week_1", "week_2", "week_3"))
  spells <- as.data.frame(weeks)
  expected <- c("week_1", "week_2", "week_3")[findInterval(spells$start, c(7, 14)) + 1L]
  expect_identical(spells$session, expected)
  # Invariant: k breaks give k + 1 sessions, every one nonempty here, and the
  # default labels count them in order.
  expect_identical(sort(unique(spells$session)), c("week_1", "week_2", "week_3"))
  numbered <- set_tie_sessions(dn, breaks = c(7, 14))
  expect_identical(sort(unique(as.data.frame(numbered)$session)),
                   c("session_1", "session_2", "session_3"))
  # Equivalence with the hand-derived column the vignette used to build.
  by_column <- quiet_dynet(transform(school_contacts,
                                     week = paste0("week_", floor(start / 7) + 1)),
                           session = "week")
  expect_identical(as.data.frame(weeks)$session, as.data.frame(by_column)$session)
})
