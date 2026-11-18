library(Dynet)
contacts <- utils::read.delim("../data/school_contacts.tsv")
network <- dynet(contacts)
flat <- collapse_network(network, weight = "spell_count")
flat
result <- subset(transform(as.data.frame(flat), pair = paste(from, "->", to)),
                 select = c(pair, spell_count, total_duration, union_duration, first, last))
