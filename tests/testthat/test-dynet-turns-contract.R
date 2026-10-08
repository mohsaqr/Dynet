# dynet(format = "turns"): logs of actions with no recipient.

turns_log <- function() {
  data.frame(
    student = c("Ana", "Ben", "Ana", "Cy", "Dee", "Eli", "Eli"),
    team = c("t1", "t1", "t1", "t1", "t2", "t2", "t2"),
    minute = c(1, 2, 4, 5, 1, 3, 6),
    action = c("plan", "monitor", "discuss", "plan", "plan", "adapt", "plan")
  )
}

test_that("each action takes up the one before it in its group", {
  dn <- quiet_dynet(turns_log(), actor = "student", group = "team",
                    time = "minute", format = "turns")
  ties <- as.data.frame(dn)
  ties <- ties[order(ties$start, ties$from), ]
  # Eli following Eli is a self-loop and is dropped; the first action of each
  # team takes up nothing.
  expect_identical(paste(ties$from, ties$to),
                   c("Ana Ben", "Dee Eli", "Ben Ana", "Ana Cy"))
  expect_identical(ties$start, c(2, 3, 4, 5))
  expect_identical(ties$action, c("monitor", "adapt", "discuss", "plan"))
  expect_identical(ties$session, c("t1", "t2", "t1", "t1"))
})

test_that("row order does not change the turns network", {
  log <- turns_log()
  a <- as.data.frame(quiet_dynet(log, actor = "student", group = "team",
                                 time = "minute", format = "turns"))
  b <- as.data.frame(quiet_dynet(log[c(7, 3, 1, 6, 5, 2, 4), ],
                                 actor = "student", group = "team",
                                 time = "minute", format = "turns"))
  key <- function(x) x[order(x$start, x$from, x$to), ]
  expect_identical(key(a)[, c("from", "to", "start", "session", "action")],
                   key(b)[, c("from", "to", "start", "session", "action")],
                   ignore_attr = TRUE)
})

test_that("a column that looks like a session stays a tie attribute", {
  log <- turns_log()
  log$course <- "A"
  dn <- quiet_dynet(log, actor = "student", group = "team", time = "minute",
                    format = "turns")
  ties <- as.data.frame(dn)
  expect_setequal(unique(ties$session), c("t1", "t2"))
  expect_true("course" %in% names(ties))
})

test_that("turns raise classed conditions", {
  log <- turns_log()
  expect_error(dynet(log[, c("team", "minute")], format = "turns"),
               class = "dynet_missing_column")
  expect_error(dynet(log[c(1, 5), ], actor = "student", group = "team",
                     time = "minute", format = "turns"),
               class = "dynet_empty_network")
  log$student[2] <- NA
  expect_error(dynet(log, actor = "student", group = "team", time = "minute",
                     format = "turns"),
               class = "dynet_bad_input")
})
