contacts <- utils::read.delim("../data/school_contacts.tsv")
union_length <- function(start, end) {
  by_onset <- order(start)
  start <- start[by_onset]
  reach <- cummax(end[by_onset])
  opens <- c(TRUE, start[-1] > head(reach, -1))
  sum(tapply(reach, cumsum(opens), max) - start[opens])
}
contacts$duration <- contacts$end - contacts$start
pair <- paste(contacts$from, "->", contacts$to)
result <- data.frame(
  pair = sort(unique(pair)),
  spell_count = as.numeric(tapply(contacts$duration, pair, length)),
  total_duration = as.numeric(tapply(contacts$duration, pair, sum)),
  union_duration = vapply(split(contacts, pair), function(spells) union_length(spells$start, spells$end), numeric(1)),
  first = as.numeric(tapply(contacts$start, pair, min)),
  last = as.numeric(tapply(contacts$end, pair, max)))
head(result)
