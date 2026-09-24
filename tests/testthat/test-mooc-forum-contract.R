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

  expect_identical(names(mooc_people), c("name", "experience", "expert_level"))
  expect_identical(nrow(mooc_people), 445L)
  expect_type(mooc_people$name, "character")
  expect_type(mooc_people$experience, "integer")
  expect_setequal(unique(mooc_people$experience), c(1L, 2L, 3L))
  # The label is a pure recode of the code, so the two columns agree row by row.
  expect_identical(mooc_people$expert_level,
                   c("Expert", "Student", "Teacher")[mooc_people$experience])

  # The data contract the vignette depends on: every poster is a known
  # participant, so `dynet(nodes = )` never invents an unnamed vertex.
  posters <- unique(c(mooc_posts$sender, mooc_posts$receiver))
  expect_true(all(posters %in% mooc_people$name))
})

test_that("min_thread_posts reproduces the chapter's counts in one call", {
  dn_full <- quiet_dynet(mooc_posts, from = "sender", to = "receiver",
                         time = "timestamp", thread = "discussion",
                         nodes = mooc_people, time_unit = "days",
                         min_thread_posts = 2)
  spells <- as.data.frame(dn_full)
  expect_identical(nrow(spells), 2406L)
  expect_identical(length(unique(spells$thread)), 299L)
  vertices <- as.data.frame(dn_full, what = "nodes")
  expect_identical(nrow(vertices), 441L)

  dn <- induce_subgraph(dn_full, degree > 20)
  active <- as.data.frame(dn, what = "nodes")
  expect_identical(nrow(active), 45L)
  expect_true("444" %in% active$name)

  # 428, not the chapter's 433: the five extra ties are pairs the chapter
  # admits before dropping single-post discussions, which networkDynamic then
  # leaves active for all time.
  scalars <- metrics(dn, measure = c("edges", "density"), window = "all")
  measured <- as.data.frame(scalars)
  expect_equal(measured$value[measured$measure == "edges"], 428)
  expect_equal(measured$value[measured$measure == "density"], 0.2161616,
               tolerance = 1e-6)
})

test_that("the shipped mixing attribute covers every active vertex", {
  dn_full <- quiet_dynet(mooc_posts, from = "sender", to = "receiver",
                         time = "timestamp", thread = "discussion",
                         nodes = mooc_people, time_unit = "days",
                         min_thread_posts = 2)
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
