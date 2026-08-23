test_that("the four construction formats are inferred from the arguments named", {
  interval <- quiet_dynet(chain_edges())
  expect_identical(interval$meta$format, "interval")

  contact <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                    time = c(1, 2)))
  expect_identical(contact$meta$format, "contact")

  threaded <- quiet_dynet(
    data.frame(from = c("A", "B"), to = c("B", "A"), time = c(1, 5),
               thread = c("t1", "t1")),
    thread = "thread")
  expect_identical(threaded$meta$format, "threaded")

  copres <- quiet_dynet(
    data.frame(actor = c("a", "b", "c"), group = c("g", "g", "g")),
    actor = "actor", group = "group")
  expect_identical(copres$meta$format, "copresence")
})

test_that("column aliases are matched case-insensitively", {
  aliased <- quiet_dynet(data.frame(Sender = "A", Receiver = "B",
                                    Onset = 1, Terminus = 3))
  expect_identical(as.data.frame(aliased)$from, "A")
  expect_identical(as.data.frame(aliased)$to, "B")
  expect_identical(as.data.frame(aliased)$start, 1)
})

test_that("a threaded post stays active until its thread falls silent", {
  posts <- data.frame(
    from   = c("A", "B", "C", "A"),
    to     = c("B", "A", "A", "C"),
    time   = c(1, 2, 7, 3),
    thread = c("t1", "t1", "t1", "t2"),
    stringsAsFactors = FALSE)
  dn <- quiet_dynet(posts, thread = "thread")
  e <- as.data.frame(dn)
  expect_true(all(e$end[e$thread == "t1"] == 7))
  expect_true(all(e$end[e$thread == "t2"] == 3))
})

test_that("co-presence connects every pair sharing a group and is undirected", {
  att <- data.frame(student = c("a", "b", "c", "a", "b"),
                    seminar = c("g1", "g1", "g1", "g2", "g2"),
                    stringsAsFactors = FALSE)
  dn <- quiet_dynet(att, actor = "student", group = "seminar")
  expect_false(dn$directed)
  expect_equal(nrow(as.data.frame(dn)), choose(3, 2) + choose(2, 2))
})

test_that("date-time columns are converted to elapsed time in a readable unit", {
  hours <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    time = as.POSIXct(c("2024-01-01 09:00", "2024-01-02 09:00"), tz = "UTC")))
  expect_identical(hours$meta$time_unit, "hours")
  expect_equal(as.data.frame(hours)$start, c(0, 24))

  strings <- quiet_dynet(data.frame(
    from = c("A", "B"), to = c("B", "C"),
    time = c("2024-01-01 09:00", "2024-03-01 09:00")))
  expect_identical(strings$meta$time_unit, "days")
})

test_that("self-loops are dropped by default and kept on request", {
  loops <- data.frame(from = c("A", "A"), to = c("A", "B"),
                      start = c(1, 2), end = c(2, 3))
  expect_message(dropped <- dynet(loops), "Dropped 1 self-loop")
  expect_equal(nrow(as.data.frame(dropped)), 1L)
  expect_message(kept <- dynet(loops, loops = TRUE), "Keeping 1 self-loop")
  expect_equal(nrow(as.data.frame(kept)), 2L)
})

test_that("vertices are addressed by name and never by index", {
  dn <- quiet_dynet(chain_edges())
  e <- as.data.frame(dn)
  expect_type(e$from, "character")
  expect_type(e$to, "character")
  expect_identical(as.data.frame(dn, what = "nodes")$name,
                   c("A", "B", "C", "D", "E"))
  expect_false("id" %in% names(as.data.frame(dn, what = "nodes")))
})

test_that("vertex attributes merge onto the vertex table", {
  dn <- quiet_dynet(chain_edges(),
                    nodes = data.frame(name = c("A", "B", "C", "D", "E"),
                                       role = c("x", "y", "x", "y", "x"),
                                       stringsAsFactors = FALSE))
  nodes <- as.data.frame(dn, what = "nodes")
  expect_identical(nodes$role[nodes$name == "B"], "y")
})

test_that("broken input raises a classed condition, not a bare stop", {
  expect_error(dynet(list(a = 1)), class = "dynet_bad_input")
  expect_error(dynet(data.frame(x = 1, y = 2)), class = "dynet_missing_column")
  expect_error(dynet(chain_edges(), from = "nope"), class = "dynet_missing_column")
  expect_error(
    dynet(data.frame(from = "A", to = "B", start = 5, end = 1)),
    class = "dynet_bad_input")
  expect_error(
    dynet(data.frame(from = "A", to = "B", time = c("not a date"))),
    class = "dynet_unparsed_time")
})
