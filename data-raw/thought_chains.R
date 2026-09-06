# ===========================================================================
# thought_chains — an anonymised, day-trimmed version of the Trees of Thought
# reply network
# ===========================================================================
# The Trees of Thought study coded asynchronous discussion messages and linked
# the code of each message to the code of the message it replies to. This
# builds a shippable version of that reply table, per the maintainer's
# specification (2026-09-06):
#
#   1. drop the two sparse weekdays (Friday and Thursday: 141 of 24,592 rows);
#   2. trim the bottom 20% of authors by their number of distinct messages in
#      the reply table; rows they authored go, replies to them by others stay
#      (the study's teacher accounts are authors like any other and are kept
#      or trimmed by the same rule);
#   3. strip every identity: student ids, message ids, descriptions; courses
#      become A..E, groups `A_01`, discussions are renumbered, and the author
#      becomes an anonymous `participant` label assigned after trimming;
#   4. shift every timestamp back by one fixed random number of whole weeks,
#      so the calendar is hidden while weekdays are kept;
#   5. rename the codes, merging Evaluation and Acceptance into Approving.
#
# No row is resampled or synthesised: each row is one real reply link with
# its real weekday and time of day. Not run at build time; requires the
# study's private data directory.

data_dir <- file.path(
  "/Users/mohammedsaqr/Library/CloudStorage",
  "GoogleDrive-saqr@saqr.me/Other computers/My MacBook Pro (2)",
  "My_Data/Zips/Trees_of_thought 2"
)

edges <- read.csv(file.path(data_dir, "complicated_nw2.csv"), check.names = FALSE)
n_source <- nrow(edges)

# --- 1. sparse weekdays -----------------------------------------------------
edges$stamp <- as.POSIXct(edges$timestamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
stopifnot("every timestamp must parse" = !anyNA(edges$stamp))
weekday <- weekdays(edges$stamp)
sparse_days <- c("Friday", "Thursday")
edges <- edges[!weekday %in% sparse_days, , drop = FALSE]

# --- 2. bottom 20% of participants ------------------------------------------
# Activity is counted inside the reply table itself: distinct messages per
# author. (The message file `Longed.csv` keys authors differently for some
# courses and covers only 198 of the 300 authors here.)
author <- as.character(edges$Source_student)
per_author <- tapply(edges$messageID, author, function(id) length(unique(id)))
cut_off <- stats::quantile(per_author, 0.20)
trimmed <- names(per_author)[per_author <= cut_off]
n_authors <- length(per_author)
edges <- edges[!author %in% trimmed, , drop = FALSE]

# --- 5. code names (done before identities so the merge is visible) ---------
code_map <- c(
  Acceptance = "Approving", Evaluation = "Approving",
  Argument = "Arguing", Composing = "Drafting", Disagreement = "Objecting",
  Group_regulation = "Coordinating", Question = "Inquiring",
  Sharing = "Resourcing", Socioemotional = "Socialising",
  T.Regulation = "Tutoring"
)
stopifnot("every source code is mapped" = all(edges$Source %in% names(code_map)),
          "every target code is mapped" = all(edges$Target %in% names(code_map)))

# --- 3. identities ------------------------------------------------------------
set.seed(20260906)
course_of <- sub("_.*", "", edges$course_group)
group_of <- sub(".*_", "", edges$course_group)
course_levels <- sort(unique(course_of))
course_code <- stats::setNames(LETTERS[seq_along(course_levels)], course_levels)
group_code <- vapply(seq_len(nrow(edges)), function(i) {
  groups <- sort(unique(group_of[course_of == course_of[i]]))
  sprintf("%s_%02d", course_code[[course_of[i]]], match(group_of[i], groups))
}, character(1L))
discussion_id <- match(edges$discussion, sort(unique(edges$discussion)))
authors <- sort(unique(as.character(edges$Source_student)))
participant <- sprintf("P%03d", match(as.character(edges$Source_student), sample(authors)))

# --- 4. calendar shift: whole weeks, so weekdays survive ---------------------
shift_weeks <- sample(100:300, 1L)
stamp <- edges$stamp - shift_weeks * 7 * 86400

thought_chains <- data.frame(
  from = unname(code_map[edges$Source]),
  to = unname(code_map[edges$Target]),
  time = stamp,
  participant = participant,
  discussion = discussion_id,
  group = group_code,
  course = unname(course_code[course_of]),
  stringsAsFactors = FALSE
)
thought_chains <- thought_chains[order(thought_chains$time, thought_chains$discussion,
                                       thought_chains$from, thought_chains$to), ]
rownames(thought_chains) <- NULL

stopifnot(
  "sparse weekdays are gone" = !any(weekdays(thought_chains$time) %in% sparse_days),
  "the other five weekdays remain" = length(unique(weekdays(thought_chains$time))) == 5L,
  "the bottom-20% authors are gone" = length(authors) <= ceiling(0.8 * n_authors) + 1L,
  "nine codes" = length(unique(c(thought_chains$from, thought_chains$to))) == 9L,
  "Approving merges two codes" = sum(thought_chains$from == "Approving") ==
    sum(edges$Source %in% c("Acceptance", "Evaluation")),
  "no identity survives" = !any(grepl("^[0-9]+$", thought_chains$participant)),
  "one label per author" = length(unique(thought_chains$participant)) == length(authors)
)
usethis::use_data(thought_chains, overwrite = TRUE)
