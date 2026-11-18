library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
series <- centrality_series(network, measure = c("degree", "betweenness", "closeness", "coreness"),
                            mode = "all", step = 7, window = 7)
series
out_closeness <- centrality_series(network, measure = "closeness", mode = "out", step = 7, window = 7)
result <- rbind(
  transform(subset(as.data.frame(series), measure != "closeness"),
            quantity = sprintf("%s t=%g: %s", measure, time, node), kind = measure),
  transform(as.data.frame(out_closeness),
            quantity = sprintf("%s t=%g: %s", measure, time, node), kind = measure))
