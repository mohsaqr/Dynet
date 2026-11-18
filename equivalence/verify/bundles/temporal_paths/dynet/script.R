library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
journeys <- paths(network, from = "Ana")
journeys
reach <- reachability(network, direction = "both", start = 18, measure = "reach_count")
reach
closeness <- path_centrality(network, measure = "closeness", start = 18)
closeness
arrivals <- as.data.frame(journeys)
result <- rbind(
  subset(transform(arrivals, quantity = sprintf("arrival_time from Ana: %s", node), kind = "arrival_time",
                   value = arrival_time), select = c(quantity, kind, value)),
  subset(transform(arrivals, quantity = sprintf("latency from Ana: %s", node), kind = "latency",
                   value = latency), select = c(quantity, kind, value)),
  subset(transform(as.data.frame(reach), quantity = sprintf("%s from t=18: %s", measure, node), kind = measure),
         select = c(quantity, kind, value)),
  subset(transform(as.data.frame(closeness), quantity = sprintf("temporal closeness from t=18: %s", node),
                   kind = "temporal_closeness"), select = c(quantity, kind, value)))
