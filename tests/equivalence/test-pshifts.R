# pshifts(): Gibson's (2003) participation shifts, the transitions between consecutive turns of a conversation.
# For dyadic turns A -> B followed by C -> D, the class is read off who speaks and to whom: AB-BA (the target
# answers the speaker), AB-BY (the target turns to a third), AB-AY (the speaker turns to a third), AB-XA and
# AB-XB (a third addresses the speaker or the target), AB-XY (a third addresses a fourth); a repeated A -> B is no
# shift. The reference classifies a random sequence of dyadic turns at distinct times from that definition.

classify_turns <- function(turns) {
  previous <- utils::head(turns, -1L)
  following <- utils::tail(turns, -1L)
  a <- previous$from
  b <- previous$to
  c <- following$from
  d <- following$to
  shift <- ifelse(c == b & d == a, "AB-BA",
           ifelse(c == b, "AB-BY",
           ifelse(c == a & d == b, NA_character_,
           ifelse(c == a, "AB-AY",
           ifelse(d == a, "AB-XA",
           ifelse(d == b, "AB-XB", "AB-XY"))))))
  table(factor(stats::na.omit(shift), c("AB-BA", "AB-B0", "AB-BY", "A0-X0", "A0-XA", "A0-XY", "AB-X0", "AB-XA",
                                       "AB-XB", "AB-XY", "A0-AY", "AB-A0", "AB-AY")))
}

random_turns <- function(seed, n_turns) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  people <- LETTERS[seq_len(6L)]
  speakers <- sample(people, n_turns, TRUE)
  targets <- vapply(speakers, \(speaker) sample(setdiff(people, speaker), 1L), character(1))
  data.frame(from = speakers, to = unname(targets), start = seq_len(n_turns), end = seq_len(n_turns))
}

by_definition <- "independent: Gibson (2003) classes of consecutive dyadic turns, base R"

test_that("the counts of each participation shift equal the classes of consecutive turns", {
  invisible(lapply(c(3L, 4L, 5L), \(seed) {
    turns <- random_turns(seed, 60L)
    counts <- classify_turns(turns)
    theirs <- data.frame(shift = names(counts), value = as.numeric(counts))
    ours <- as.data.frame(pshifts(dynet(turns, directed = TRUE)))
    expect_reference(ours, theirs, reference = by_definition, covers = c("pshifts()", "as.data.frame.dynet_pshifts()"),
                     quantity = sprintf("60 turns, seed %d", seed), tolerance = 0, key = "shift")
  }))
})

test_that("summary() of the shifts totals each family", {
  turns <- random_turns(3L, 60L)
  counts <- classify_turns(turns)
  family <- c(`AB-BA` = "turn_receiving", `AB-B0` = "turn_receiving", `AB-BY` = "turn_receiving",
              `A0-X0` = "turn_claiming", `A0-XA` = "turn_claiming", `A0-XY` = "turn_claiming",
              `AB-X0` = "turn_usurping", `AB-XA` = "turn_usurping", `AB-XB` = "turn_usurping",
              `AB-XY` = "turn_usurping", `A0-AY` = "turn_continuing", `AB-A0` = "turn_continuing",
              `AB-AY` = "turn_continuing")
  totals <- tapply(as.numeric(counts), family[names(counts)], sum)
  ours <- as.data.frame(summary(pshifts(dynet(turns, directed = TRUE))))
  expect_reference(ours, data.frame(family = names(totals), count = as.numeric(totals)), reference = by_definition,
                   covers = "summary.dynet_pshifts()", quantity = "per family", tolerance = 0, key = "family")
})

test_that("AB-BA counted whenever the target speaks next, whoever is addressed, differs (negative control)", {
  turns <- random_turns(3L, 60L)
  counts <- classify_turns(turns)
  ours <- subset(as.data.frame(pshifts(dynet(turns, directed = TRUE))), shift == "AB-BA")
  expect_differs(ours, data.frame(shift = "AB-BA", value = as.numeric(counts[["AB-BA"]] + counts[["AB-BY"]])),
                 reference = by_definition, covers = "pshifts()", quantity = "AB-BA, the target's every reply",
                 tolerance = 0.5, key = "shift")
})

test_that("the counts of each participation shift equal relevent::accum.ps()", {
  skip_without_reference("relevent")
  rows <- lapply(c(3L, 4L, 5L, 6L), \(seed) {
    turns <- random_turns(seed, 80L)
    people <- sort(unique(c(turns$from, turns$to)))
    # accum.ps() takes an event list (time, sender, receiver) and returns the cumulative counts after each event;
    # its last row is the whole sequence.
    accumulated <- relevent::accum.ps(cbind(turns$start, match(turns$from, people), match(turns$to, people)))
    totals <- accumulated[nrow(accumulated), ]
    list(ours = cbind(seed = seed, as.data.frame(pshifts(dynet(turns, directed = TRUE)))),
         theirs = data.frame(seed = seed, shift = colnames(accumulated), value = as.numeric(totals)))
  })
  expect_reference(do.call(rbind, lapply(rows, `[[`, "ours")), do.call(rbind, lapply(rows, `[[`, "theirs")),
                   reference = "relevent", covers = c("pshifts()", "as.data.frame.dynet_pshifts()"),
                   quantity = "80 turns", tolerance = 0, key = c("seed", "shift"))
  family <- c(`AB-BA` = "turn_receiving", `AB-B0` = "turn_receiving", `AB-BY` = "turn_receiving",
              `A0-X0` = "turn_claiming", `A0-XA` = "turn_claiming", `A0-XY` = "turn_claiming",
              `AB-X0` = "turn_usurping", `AB-XA` = "turn_usurping", `AB-XB` = "turn_usurping",
              `AB-XY` = "turn_usurping", `A0-AY` = "turn_continuing", `AB-A0` = "turn_continuing",
              `AB-AY` = "turn_continuing")
  summed <- lapply(rows, \(side) {
    totals <- tapply(side$theirs$value, family[side$theirs$shift], sum)
    list(ours = cbind(seed = side$ours$seed[[1L]],
                      as.data.frame(summary(pshifts(dynet(random_turns(side$ours$seed[[1L]], 80L), directed = TRUE))))),
         theirs = data.frame(seed = side$theirs$seed[[1L]], family = names(totals), count = as.numeric(totals)))
  })
  expect_reference(do.call(rbind, lapply(summed, `[[`, "ours")), do.call(rbind, lapply(summed, `[[`, "theirs")),
                   reference = "relevent", covers = "summary.dynet_pshifts()",
                   quantity = "80 turns, per family", tolerance = 0, key = c("seed", "family"))
})
