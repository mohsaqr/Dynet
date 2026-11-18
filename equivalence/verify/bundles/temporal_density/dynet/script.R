library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
whole <- metrics(network, measure = "temporal_density", window = "all")
whole
tiled <- metrics(network, measure = "temporal_density", step = 7, window = 7)
tiled
result <- rbind(
  transform(as.data.frame(whole), quantity = "temporal_density whole period", kind = measure),
  transform(as.data.frame(tiled), quantity = sprintf("temporal_density t=%g", time), kind = measure))
