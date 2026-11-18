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
network <- c(vertices = length(unique(c(contacts$from, contacts$to))), `edge spells` = nrow(contacts),
             `distinct pairs` = length(unique(pair)), `observed from` = min(contacts$start),
             `observed to` = max(contacts$end), span = max(contacts$end) - min(contacts$start),
             `time bins` = ceiling(max(contacts$end) - min(contacts$start)))
network
ties <- list(events = tapply(contacts$duration, pair, length), total = tapply(contacts$duration, pair, sum),
             union = vapply(split(contacts, pair), function(spells) union_length(spells$start, spells$end), numeric(1)),
             mean = tapply(contacts$duration, pair, mean))
result <- rbind(
  data.frame(quantity = names(network), kind = "network", value = unname(network)),
  do.call(rbind, Map(function(value, measure) {
    data.frame(quantity = sprintf("%s: %s", measure, names(value)), kind = measure, value = as.numeric(value))
  }, ties, names(ties))))
head(result, 12)
