# The bundled chapter-17 forum data, and the pipeline
# `vignette("ch17-temporal-networks")` runs on it. These pin the shape the
# documentation promises and the numbers the vignette prints, so a rebuild of
# `data-raw/mooc_forum.R` that changes either fails here rather than in a
# reader's hands.

test_that("the bundled MOOC data has the documented shape", {
  expect_s3_class(mooc_posts, "data.frame")
  expect_identical(names(mooc_posts),
                   c("sender", "receiver", "timestamp", "discussion"))
  expect_identical(nrow(mooc_posts), 2529L)
  expect_type(mooc_posts$sender, "character")
  expect_type(mooc_posts$receiver, "character")
  expect_s3_class(mooc_posts$timestamp, "POSIXct")
  expect_identical(attr(mooc_posts$timestamp, "tzone"), "UTC")
  expect_false(anyNA(mooc_posts$timestamp))
  expect_identical(length(unique(mooc_posts$discussion)), 338L)

  expect_identical(names(mooc_people), c("name", "experience"))
  expect_identical(nrow(mooc_people), 445L)
  expect_type(mooc_people$name, "character")
  expect_type(mooc_people$experience, "integer")
  expect_setequal(unique(mooc_people$experience), c(1L, 2L, 3L))

  # The data contract the vignette depends on: every poster is a known
  # participant, so `dynet(nodes = )` never invents an unnamed vertex.
  posters <- unique(c(mooc_posts$sender, mooc_posts$receiver))
  expect_true(all(posters %in% mooc_people$name))
})

test_that("the chapter pipeline reproduces its published counts", {
  replies <- subset(mooc_posts, sender != receiver)
  busy <- names(which(table(replies$discussion) > 1))
  exchanges <- subset(replies, discussion %in% busy)
  expect_identical(nrow(exchanges), 2406L)
  expect_identical(length(unique(exchanges$discussion)), 299L)

  people <- transform(
    mooc_people,
    expert_level = as.character(factor(experience, levels = c(1L, 2L, 3L),
                                       labels = c("Expert", "Student", "Teacher")))
  )
  dn_full <- quiet_dynet(exchanges, from = "sender", to = "receiver",
                         time = "timestamp", thread = "discussion",
                         nodes = people, time_unit = "days",
                         directed = TRUE, loops = FALSE)
  dn <- induce_subgraph(dn_full, degree > 20)

  vertices <- as.data.frame(dn, what = "nodes")
  expect_identical(nrow(vertices), 45L)
  expect_true("444" %in% vertices$name)

  # 428, not the chapter's 433: the five extra ties are pairs the chapter
  # admits before dropping single-post discussions, which networkDynamic then
  # leaves active for all time. Documented in the vignette's "what differs".
  scalars <- metrics(dn, measure = c("edges", "density"), window = "all")
  measured <- as.data.frame(scalars)
  expect_equal(measured$value[measured$measure == "edges"], 428)
  expect_equal(measured$value[measured$measure == "density"], 0.2161616,
               tolerance = 1e-6)
})

test_that("the mixing attribute the chapter uses covers every active vertex", {
  people <- transform(
    mooc_people,
    expert_level = as.character(factor(experience, levels = c(1L, 2L, 3L),
                                       labels = c("Expert", "Student", "Teacher")))
  )
  replies <- subset(mooc_posts, sender != receiver)
  busy <- names(which(table(replies$discussion) > 1))
  exchanges <- subset(replies, discussion %in% busy)
  dn_full <- quiet_dynet(exchanges, from = "sender", to = "receiver",
                         time = "timestamp", thread = "discussion",
                         nodes = people, time_unit = "days",
                         directed = TRUE, loops = FALSE)
  dn <- induce_subgraph(dn_full, degree > 20)

  vertices <- as.data.frame(dn, what = "nodes")
  expect_false(anyNA(vertices$expert_level))

  # The invariant: three levels give nine ordered pairs, and every tie the
  # network holds is counted in exactly one of them.
  mix <- mixing(dn, attribute = "expert_level", window = "all")
  pairs <- as.data.frame(mix)
  expect_identical(nrow(pairs), 9L)
  edges <- metrics(dn, measure = "edges", window = "all")
  edge_total <- as.data.frame(edges)
  expect_equal(sum(pairs$value), edge_total$value)
})
