contacts <- utils::read.delim("../data/school_contacts.tsv")
people <- sort(unique(c(contacts$from, contacts$to)))
# Earliest arrival at every vertex from `source`, present from `origin` on.
earliest <- function(source, origin) {
  arrival <- setNames(rep(Inf, length(people)), people)
  arrival[source] <- origin
  repeat {
    enterable <- arrival[contacts$from] < contacts$end
    entered <- pmax(arrival[contacts$from], contacts$start)[enterable]
    best <- tapply(entered, contacts$to[enterable], min)
    improved <- pmin(arrival[names(best)], best)
    if (identical(unname(improved), unname(arrival[names(best)]))) break
    arrival[names(best)] <- improved
  }
  arrival
}
from_ana <- earliest("Ana", min(contacts$start))
from_ana
late <- vapply(people, earliest, numeric(length(people)), origin = 18)
dimnames(late) <- list(to = people, from = people)
reached <- is.finite(late) & row(late) != col(late)
latency <- ifelse(reached, late - 18, 0)
result <- rbind(
  data.frame(quantity = sprintf("arrival_time from Ana: %s", people), kind = "arrival_time", value = unname(from_ana)),
  data.frame(quantity = sprintf("latency from Ana: %s", people), kind = "latency",
             value = unname(from_ana) - min(contacts$start)),
  data.frame(quantity = sprintf("forward_reach_count from t=18: %s", people), kind = "forward_reach_count",
             value = colSums(reached)),
  data.frame(quantity = sprintf("backward_reach_count from t=18: %s", people), kind = "backward_reach_count",
             value = rowSums(reached)),
  data.frame(quantity = sprintf("temporal closeness from t=18: %s", people), kind = "temporal_closeness",
             value = ifelse(colSums(reached) > 0, colSums(reached) / colSums(latency), 0)))
result
