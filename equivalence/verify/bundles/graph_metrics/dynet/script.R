library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
series <- metrics(network, measure = c("edges", "density", "reciprocity", "components", "components_strong",
                                       "isolates", "mutual", "asymmetric", "null", "mean_distance",
                                       "diameter", "triads"), step = 7, window = 7)
series
result <- transform(as.data.frame(series), quantity = sprintf("%s t=%g", measure, time), kind = measure)
