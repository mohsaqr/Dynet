library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
network
overview <- summary(network)
overview
counts <- subset(overview, property %in% c("vertices", "edge spells", "distinct pairs",
                                            "observed from", "observed to", "span", "time bins"))
ties <- as.data.frame(durations(network, measure = c("events", "total", "union", "mean")))
head(ties)
result <- rbind(
  subset(transform(counts, quantity = property, kind = "network", value = as.numeric(value)),
         select = c(quantity, kind, value)),
  subset(transform(ties, quantity = sprintf("%s: %s -> %s", measure, from, to), kind = measure),
         select = c(quantity, kind, value)))
