# ===========================================================================
# synthdata — a synthetic stand-in for the Trees of Thought code network
# ===========================================================================
# The Trees of Thought study coded asynchronous discussion messages into ten
# interaction codes and studied how one code follows another over time. Its
# network is code-to-code: a tie runs from the code of a message to the code of
# the message it replies to, so a vertex is a CATEGORY, never a person. The
# study's own saved network is not redistributable, so this builds a synthetic
# stand-in that supports the same analysis without being the same data.
#
# Construction, per the maintainer's specification:
#   1. draw a random 70% subset of the study's edge spells as the pool;
#   2. resample that pool WITH REPLACEMENT to 90% of the original spell count.
#
# The result therefore omits roughly a third of the real spells, repeats
# others, and is smaller than the original, so no row of it can be read as a
# claim about the study. Vertices keep their code labels: they name interaction
# categories rather than individuals, they carry no personal data, and
# replacing them would make the reproduction uninterpretable.
#
# Not run at build time. Requires the study's private data directory.

library(Dynet)

data_dir <- file.path(
  "/Users/mohammedsaqr/Library/CloudStorage",
  "GoogleDrive-saqr@saqr.me/Other computers/My MacBook Pro (2)",
  "My_Data/Zips/Trees_of_thought 2"
)

source_network <- as_dynet(readRDS(file.path(
  data_dir, "Out", "Dynamic_network_Weightedloops.RDS"
)))
spells <- as.data.frame(source_network)

set.seed(2026)
n_spells <- nrow(spells)
pool <- sample(seq_len(n_spells), size = floor(0.70 * n_spells))
drawn <- sample(pool, size = floor(0.90 * n_spells), replace = TRUE)

synthdata <- data.frame(
  from   = spells$from[drawn],
  to     = spells$to[drawn],
  start  = spells$start[drawn],
  end    = spells$end[drawn],
  weight = spells$weight[drawn],
  stringsAsFactors = FALSE
)
synthdata <- synthdata[order(synthdata$start, synthdata$from, synthdata$to), ]
rownames(synthdata) <- NULL

stopifnot(
  "synthdata must be 90% of the source" =
    nrow(synthdata) == floor(0.90 * n_spells),
  "synthdata must omit part of the source" =
    length(unique(drawn)) < n_spells,
  "resampling must repeat at least one spell" =
    anyDuplicated(drawn) > 0
)

usethis::use_data(synthdata, overwrite = TRUE)
