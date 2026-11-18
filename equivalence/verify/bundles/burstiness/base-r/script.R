contacts <- utils::read.delim("../data/school_contacts.tsv")
incident <- data.frame(node = c(contacts$from, contacts$to), time = c(contacts$start, contacts$start))
rhythm <- function(times) {
  gap <- diff(sort(times))
  mu <- mean(gap)
  sigma <- sqrt(mean((gap - mu)^2))
  c(events = length(times), mean_gap = mu, burstiness = (sigma - mu) / (sigma + mu),
    memory = stats::cor(head(gap, -1), tail(gap, -1)))
}
per_node <- vapply(split(incident$time, incident$node), rhythm, numeric(4))
t(per_node)
result <- data.frame(quantity = sprintf("%s: %s", rownames(per_node)[row(per_node)], colnames(per_node)[col(per_node)]),
                     kind = rownames(per_node)[row(per_node)], value = as.numeric(per_node))
