library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
rhythm <- burstiness(network, measure = c("events", "mean_gap", "burstiness", "memory"))
rhythm
summary(gaps(network))
result <- transform(as.data.frame(rhythm), quantity = sprintf("%s: %s", measure, node), kind = measure)
