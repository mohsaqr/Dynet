contacts <- utils::read.delim("../data/school_contacts.tsv")
union_length <- function(start, end) {
  by_onset <- order(start)
  start <- start[by_onset]
  reach <- cummax(end[by_onset])
  opens <- c(TRUE, start[-1] > head(reach, -1))
  sum(tapply(reach, cumsum(opens), max) - start[opens])
}
people <- unique(c(contacts$from, contacts$to))
pair_slots <- length(people) * (length(people) - 1)
# Occupied ordered-pair time inside [lo, hi] over all ordered-pair time there.
density <- function(lo, hi) {
  inside <- contacts[contacts$start < hi & contacts$end > lo, ]
  inside$start <- pmax(inside$start, lo)
  inside$end <- pmin(inside$end, hi)
  occupied <- vapply(split(inside, paste(inside$from, inside$to)),
                     function(spells) union_length(spells$start, spells$end), numeric(1))
  sum(occupied) / (pair_slots * (hi - lo))
}
observed_to <- max(contacts$end)
onsets <- c(0, 7, 14, 21)
result <- data.frame(
  quantity = c("temporal_density whole period", sprintf("temporal_density t=%g", onsets)),
  kind = "temporal_density",
  value = c(density(min(contacts$start), observed_to),
            vapply(onsets, function(lo) density(lo, min(lo + 7, observed_to)), numeric(1))))
print(result, digits = 15)
