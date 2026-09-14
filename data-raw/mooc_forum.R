# mooc_posts / mooc_people -------------------------------------------------
#
# The discussion-forum data of chapter 17 of *Learning Analytics Methods and
# Tutorials* (Saqr, M., 2024, "Temporal network analysis: Introduction,
# methods and analysis with R"), so that `vignette("ch17-temporal-networks")`
# reproduces the chapter without reaching the network at render time.
#
# Source: https://github.com/lamethods/data, directory `6_snaMOOC`
#   DLT1 Edgelist.csv -- one row per forum post
#   DLT1 Nodes.csv    -- one row per participant
#
# Only the columns the chapter's analysis reads are kept. Everything else --
# the category hierarchy, comment identifiers, and the demographic columns the
# chapter does not touch -- is dropped, which is what takes 597 KB of CSV down
# to 24 KB of compressed .rda.
#
# Run from the package root:  Rscript data-raw/mooc_forum.R

base_url <- "https://raw.githubusercontent.com/lamethods/data/main/6_snaMOOC/"

read_source <- function(file) {
  destination <- tempfile(fileext = ".csv")
  utils::download.file(paste0(base_url, utils::URLencode(file)), destination,
                       quiet = TRUE)
  utils::read.csv(destination, stringsAsFactors = FALSE)
}

edges <- read_source("DLT1 Edgelist.csv")
nodes <- read_source("DLT1 Nodes.csv")

stopifnot(
  "the edge list lost a column the chapter reads" =
    all(c("Sender", "Receiver", "Timestamp", "Discussion.Title") %in% names(edges)),
  "the node table lost a column the chapter reads" =
    all(c("UID", "experience") %in% names(nodes))
)

# The timestamps are US month/day/two-digit-year with a 24-hour clock. Parsing
# here rather than in the vignette keeps the shipped object a real POSIXct, so
# `dynet()` reads it through its own time handling instead of a string.
posted <- as.POSIXct(edges$Timestamp, format = "%m/%d/%y %H:%M", tz = "UTC")
stopifnot("a timestamp failed to parse" = !anyNA(posted))

mooc_posts <- data.frame(
  sender = as.character(edges$Sender),
  receiver = as.character(edges$Receiver),
  timestamp = posted,
  discussion = edges$Discussion.Title,
  stringsAsFactors = FALSE
)

mooc_people <- data.frame(
  name = as.character(nodes$UID),
  experience = as.integer(nodes$experience),
  stringsAsFactors = FALSE
)

# Every participant named in the log must be in the node table, or `dynet()`
# would silently carry an unnamed vertex.
stopifnot(
  "a poster is missing from the node table" =
    all(c(mooc_posts$sender, mooc_posts$receiver) %in% mooc_people$name)
)

usethis::use_data(mooc_posts, overwrite = TRUE, compress = "xz")
usethis::use_data(mooc_people, overwrite = TRUE, compress = "xz")

cat(sprintf("mooc_posts:  %d posts, %d discussions, %s to %s\n",
            nrow(mooc_posts), length(unique(mooc_posts$discussion)),
            format(min(mooc_posts$timestamp)), format(max(mooc_posts$timestamp))))
cat(sprintf("mooc_people: %d participants, experience %s\n",
            nrow(mooc_people),
            paste(sort(unique(mooc_people$experience)), collapse = "/")))
