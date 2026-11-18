library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
series <- centrality_series(network, measure = "pagerank", damping = 0.85, step = 7, window = 7)
series
result <- transform(as.data.frame(series), quantity = sprintf("%s t=%g: %s", measure, time, node),
                    kind = measure)
