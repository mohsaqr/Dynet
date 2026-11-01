# Contracts pinned by the 2026-11-01 audit of the editing verbs. Each block
# asserts one condition class and one invariant.

# Structural validity of an edited network: the integer `edges` table is the
# aggregate of `spells`, every endpoint is a vertex, labels follow names,
# vertex activity names known vertices and never overlaps within a vertex,
# and the cograph grouping matches the node table.
expect_valid_dynet <- function(x) {
  expect_s3_class(x, c("dynet", "netobject", "cograph_network"), exact = TRUE)
  expect_silent(Dynet:::.check_dynet(x))
  expect_true(all(c(x$spells$from, x$spells$to) %in% x$nodes$name))
  expect_identical(x$nodes$label, x$nodes$name)
  expect_identical(x$spells$.raw_spell, seq_len(nrow(x$spells)))
  pair <- if (x$directed) {
    paste(x$spells$from, x$spells$to)
  } else {
    paste(pmin(x$spells$from, x$spells$to), pmax(x$spells$from, x$spells$to))
  }
  from_spells <- tapply(x$spells$weight, pair, sum)
  network <- as.data.frame(x, what = "network")
  from_edges <- stats::setNames(network$weight,
                                paste(network$from, network$to))
  expect_equal(from_edges[sort(names(from_edges))],
               as.vector(from_spells[sort(names(from_spells))]),
               ignore_attr = TRUE)
  expect_setequal(names(from_edges), names(from_spells))
  vs <- as.data.frame(x, what = "vertex_spells")
  expect_true(all(vs$node %in% x$nodes$name))
  if (nrow(vs) > 1L) {
    key <- paste(vs$node, vs$session)
    overlapping <- vapply(split(seq_len(nrow(vs)), key), function(rows) {
      starts <- vs$start[rows]
      ends <- vs$end[rows]
      ord <- order(starts)
      length(rows) > 1L &&
        any(utils::head(ends[ord], -1L) > utils::tail(starts[ord], -1L))
    }, logical(1L))
    expect_false(any(overlapping))
  }
  if ("groups" %in% names(x$nodes)) {
    expect_identical(x$node_groups$group, x$nodes$groups)
    expect_identical(x$node_groups$node, x$nodes$name)
  }
  invisible(x)
}

# Metadata comparison by name, ignoring the recorded call.
expect_same_meta <- function(a, b, ignore = "call") {
  keys <- setdiff(union(names(a$meta), names(b$meta)), ignore)
  differs <- keys[!vapply(keys, function(k) {
    isTRUE(all.equal(a$meta[[k]], b$meta[[k]]))
  }, logical(1L))]
  expect_identical(differs, character())
}

test_that("an all-FALSE vertex-spell mask is refused, not read as 'all'", {
  dn <- quiet_dynet(chain_edges())
  declared <- set_vertex_spells(dn, data.frame(
    node = c("A", "B"), start = 0, end = 3
  ))
  # `x[-integer(0), ]` is empty, so this used to clear every declaration.
  expect_error(remove_vertex_spells(declared, spells = c(FALSE, FALSE)),
               class = "dynet_vertex_spell_not_found")
  expect_error(update_vertex_spells(declared, spells = c(FALSE, FALSE),
                                    data = data.frame(end = 9)),
               class = "dynet_vertex_spell_not_found")
  # Invariant: removing one component and adding it back round-trips.
  trimmed <- remove_vertex_spells(declared, spells = 1)
  expect_valid_dynet(trimmed)
  expect_identical(nrow(as.data.frame(trimmed, what = "vertex_spells")), 1L)
  restored <- add_vertex_spells(trimmed, data.frame(node = "A", start = 0,
                                                    end = 3))
  expect_equal(as.data.frame(restored, what = "vertex_spells"),
               as.data.frame(declared, what = "vertex_spells"))
})

test_that("update_ties on an empty selection raises a classed condition", {
  dn <- quiet_dynet(chain_edges())
  expect_error(update_ties(dn, ties = start > 100,
                           data = data.frame(kind = "x")),
               class = "dynet_tie_not_found")
  # Invariant: an update and its inverse round-trip the spell table.
  heavier <- update_ties(dn, ties = from == "B", data = data.frame(weight = 5))
  expect_valid_dynet(heavier)
  back <- update_ties(heavier, ties = from == "B",
                      data = data.frame(weight = 1))
  expect_equal(as.data.frame(back), as.data.frame(dn))
  expect_equal(back$edges, dn$edges)
})

test_that("a tie condition that is NA for a spell does not select it", {
  dn <- quiet_dynet(chain_edges())
  marked <- update_ties(dn, ties = 1, data = data.frame(kind = "long"))
  # `kind` is NA on three spells; subset() semantics drop them.
  kept <- induce_subgraph(marked, ties = kind == "long")
  dropped <- remove_ties(marked, ties = kind == "long")
  relabelled <- update_ties(marked, ties = kind == "long",
                            data = data.frame(flag = TRUE))
  expect_valid_dynet(kept)
  expect_valid_dynet(dropped)
  # Invariant: the kept and the removed spells partition the table.
  expect_identical(nrow(as.data.frame(kept)) + nrow(as.data.frame(dropped)),
                   nrow(as.data.frame(marked)))
  expect_identical(sum(as.data.frame(relabelled)$flag, na.rm = TRUE), 1L)
  expect_error(remove_ties(marked, ties = missing_column == 1),
               class = "dynet_bad_selection")
})

test_that("every edgeless outcome is dynet_empty_network under dynet_bad_input", {
  dn <- quiet_dynet(chain_edges())
  conditions <- list(
    tryCatch(remove_ties(dn, ties = rep(TRUE, 4L)), error = identity),
    tryCatch(induce_subgraph(dn, ties = rep(FALSE, 4L)), error = identity),
    tryCatch(remove_nodes(dn, c("A", "B", "C", "D", "E"), cascade = TRUE),
             error = identity)
  )
  classes <- vapply(conditions, function(e) {
    inherits(e, "dynet_empty_network") && inherits(e, "dynet_bad_input")
  }, logical(1L))
  expect_true(all(classes))
  expect_error(remove_ties(dn, ties = rep(TRUE, 4L)),
               class = "dynet_empty_network")
})

test_that("a factor attribute value is written as its label", {
  dn <- quiet_dynet(chain_edges())
  roled <- update_nodes(dn, data.frame(name = "A", role = "x"))
  expect_error(update_nodes(roled, data.frame(name = "Q", role = "y")),
               class = "dynet_unknown_node")
  # Assigning a factor into a character column used to write its code, "1".
  updated <- update_nodes(roled, data.frame(name = c("B", "C"),
                                            role = factor(c("zz", "yy"))))
  expect_valid_dynet(updated)
  roles <- as.data.frame(updated, what = "nodes")
  expect_identical(roles$role, c("x", "zz", "yy", NA, NA))
  # Invariant: character and factor input give the same network.
  as_text <- update_nodes(roled, data.frame(name = c("B", "C"),
                                            role = c("zz", "yy")))
  expect_identical(as.data.frame(as_text, what = "nodes"), roles)
})

test_that("updating the attribute a grouping came from moves the grouping", {
  rooms <- data.frame(name = c("A", "B", "C", "D", "E"),
                      room = c("x", "x", "y", "y", "z"))
  dn <- quiet_dynet(chain_edges(), nodes = rooms, groups = "room")
  moved <- update_nodes(dn, data.frame(name = "A", room = "q"))
  expect_valid_dynet(moved)
  nodes <- as.data.frame(moved, what = "nodes")
  # Invariant: the grouping equals its source attribute after the edit.
  expect_identical(nodes$groups, nodes$room)
  expect_identical(moved$node_groups$group, c("q", "x", "y", "y", "z"))
  expect_error(add_nodes(dn, "F"), class = "dynet_missing_group")
})

test_that("an attribute-only update keeps the source format", {
  contacts <- quiet_dynet(data.frame(from = c("A", "B"), to = c("B", "C"),
                                     time = c(1, 2)))
  expect_identical(contacts$meta$format, "contact")
  relabelled <- update_ties(contacts, ties = 1, data = data.frame(kind = "k"))
  expect_identical(relabelled$meta$format, "contact")
  retimed <- update_ties(contacts, ties = 1, data = data.frame(end = 1.5))
  expect_identical(retimed$meta$format, "interval")
  expect_valid_dynet(retimed)
  expect_error(update_ties(contacts, ties = 1,
                           data = data.frame(duration = 3)),
               class = "dynet_reserved_column")
})

test_that("add_ties refuses derived columns and round-trips with remove_ties", {
  dn <- quiet_dynet(chain_edges())
  expect_error(add_ties(dn, data.frame(from = "A", to = "C", start = 1,
                                       end = 2, duration = 99)),
               class = "dynet_reserved_column")
  added <- add_ties(dn, data.frame(from = "A", to = "C", start = 1.5,
                                   end = 2.5))
  expect_valid_dynet(added)
  back <- remove_ties(added, from = "A", to = "C")
  expect_equal(as.data.frame(back), as.data.frame(dn))
  expect_equal(back$edges, dn$edges)
  expect_same_meta(back, dn, ignore = c("call", "sessions"))
})

test_that("add_ties equals building the network from the bound log", {
  edges <- random_edges(seed = 3)
  base <- edges[seq_len(40L), ]
  extra <- edges[seq.int(41L, nrow(edges)), ]
  results <- lapply(c(TRUE, FALSE), function(directed) {
    grown <- add_ties(quiet_dynet(base, directed = directed), extra)
    built <- quiet_dynet(rbind(base, extra), directed = directed)
    expect_valid_dynet(grown)
    expect_equal(as.data.frame(grown), as.data.frame(built))
    expect_equal(grown$edges, built$edges)
    expect_same_meta(grown, built, ignore = c("call", "sessions"))
    TRUE
  })
  expect_true(all(unlist(results)))
  expect_error(add_ties(quiet_dynet(base), data.frame(
    from = "v1", to = "nobody", start = 1, end = 2
  )), class = "dynet_unknown_node")
})

test_that("add_nodes and remove_nodes accept factors and round-trip", {
  dn <- quiet_dynet(chain_edges())
  by_factor <- add_nodes(dn, factor(c("Y", "Z")))
  by_text <- add_nodes(dn, c("Y", "Z"))
  expect_identical(as.data.frame(by_factor, what = "nodes"),
                   as.data.frame(by_text, what = "nodes"))
  expect_valid_dynet(by_factor)
  removed <- remove_nodes(by_factor, factor(c("Y", "Z")))
  expect_equal(as.data.frame(removed, what = "nodes"),
               as.data.frame(dn, what = "nodes"))
  expect_equal(removed$edges, dn$edges)
  expect_error(add_nodes(dn, factor("A")), class = "dynet_duplicate_node")
  expect_error(remove_nodes(dn, factor("Q")), class = "dynet_unknown_node")
})

test_that("remove_arcs is not shadowed by a tie attribute named `ties`", {
  edges <- chain_edges()
  edges$ties <- c(TRUE, FALSE, FALSE, FALSE)
  directed <- quiet_dynet(edges, directed = TRUE)
  # The wrapper used to hand `ties` on for a second substitute(), where the
  # spell column of the same name was found first.
  by_arc <- remove_arcs(directed, from = "B")
  by_tie <- remove_ties(directed, from = "B")
  expect_valid_dynet(by_arc)
  expect_equal(as.data.frame(by_arc), as.data.frame(by_tie))
  expect_identical(nrow(as.data.frame(by_arc)), 3L)
  expect_error(remove_arcs(quiet_dynet(edges, directed = FALSE), ties = 1),
               class = "dynet_needs_directed")
})

test_that("remove_ties names an unknown endpoint or session precisely", {
  dn <- quiet_dynet(chain_edges())
  expect_error(remove_ties(dn, from = "Q"), class = "dynet_unknown_node")
  expect_error(remove_ties(dn, session = "s9"),
               class = "dynet_unknown_session")
  sessioned <- set_tie_sessions(dn, breaks = 3)
  expect_error(remove_ties(sessioned, session = "s9"),
               class = "dynet_unknown_session")
  # A known name that simply matches nothing is still "not found".
  expect_error(remove_ties(dn, from = "E"), class = "dynet_tie_not_found")
  # Invariant: removing a session leaves exactly the other session's spells.
  late <- remove_ties(sessioned, session = "session_1")
  expect_valid_dynet(late)
  expect_identical(unique(as.data.frame(late)$session), "session_2")
})

test_that("add_vertex_spells puts calendar times on the network clock", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    start = as.Date(c("2024-01-01", "2024-01-10")),
                    end = as.Date(c("2024-01-02", "2024-01-12")))
  dn <- quiet_dynet(log)
  first <- data.frame(node = "A", start = as.Date("2024-01-01"),
                      end = as.Date("2024-01-05"))
  second <- data.frame(node = "B", start = as.Date("2024-01-03"),
                       end = as.Date("2024-01-06"))
  declared <- set_vertex_spells(dn, first)
  extended <- add_vertex_spells(declared, second)
  expect_valid_dynet(extended)
  # A Date bound onto the stored offsets used to read as days since 1970.
  spells <- as.data.frame(extended, what = "vertex_spells")
  expect_equal(spells$start, c(0, 2))
  expect_equal(spells$end, c(4, 5))
  # Invariant: adding equals declaring both at once.
  at_once <- set_vertex_spells(dn, rbind(first, second))
  expect_equal(spells, as.data.frame(at_once, what = "vertex_spells"))
  expect_error(add_vertex_spells(declared, data.frame(
    node = "B", start = as.Date("2024-01-03"),
    end = as.Date("2024-01-06"), session = "s"
  )), class = "dynet_incompatible_vertex_spells")
})

test_that("update_vertex_spells converts calendar times and factor labels", {
  log <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    start = as.Date(c("2024-01-01", "2024-01-10")),
                    end = as.Date(c("2024-01-02", "2024-01-12")))
  dn <- quiet_dynet(log)
  declared <- set_vertex_spells(dn, data.frame(
    node = "A", start = as.Date("2024-01-01"), end = as.Date("2024-01-05")
  ))
  moved <- update_vertex_spells(declared, spells = 1, data = data.frame(
    node = factor("B"), end = as.Date("2024-01-08")
  ))
  expect_valid_dynet(moved)
  # Invariant: the update equals declaring the edited spell directly.
  direct <- set_vertex_spells(dn, data.frame(
    node = "B", start = as.Date("2024-01-01"), end = as.Date("2024-01-08")
  ))
  expect_equal(as.data.frame(moved, what = "vertex_spells"),
               as.data.frame(direct, what = "vertex_spells"))
  numeric_clock <- set_vertex_spells(quiet_dynet(chain_edges()),
                                     data.frame(node = "A", start = 0, end = 3))
  expect_error(update_vertex_spells(numeric_clock, spells = 1,
                                    data = data.frame(end = Sys.Date())),
               class = "dynet_bad_input")
})

test_that("set_observations equals the matching dynet() declaration", {
  scalar <- set_observations(quiet_dynet(chain_edges()), start = 0, end = 3.5)
  built_scalar <- quiet_dynet(chain_edges(), observation_start = 0,
                              observation_end = 3.5)
  expect_same_meta(scalar, built_scalar)
  expect_equal(as.data.frame(metrics(scalar, step = 1)),
               as.data.frame(metrics(built_scalar, step = 1)))
  windows <- data.frame(start = c(0, 3), end = c(2, 5))
  spelled <- set_observations(quiet_dynet(chain_edges()), data = windows)
  built_spelled <- quiet_dynet(chain_edges(), observation_spells = windows)
  expect_same_meta(spelled, built_spelled)
  expect_equal(as.data.frame(metrics(spelled, step = 1)),
               as.data.frame(metrics(built_spelled, step = 1)))
  # Replacing component support with scalar bounds leaves no component table.
  replaced <- set_observations(spelled, start = 0, end = 3.5)
  expect_same_meta(replaced, built_scalar)
  expect_error(set_observations(spelled, start = 5, end = 2),
               class = "dynet_bad_input")
})

test_that("observation edits clip measurement but never rewrite spells", {
  dn <- quiet_dynet(chain_edges())
  narrowed <- set_observations(dn, start = 0, end = 3.5)
  expect_equal(as.data.frame(narrowed), as.data.frame(dn))
  observed <- as.data.frame(durations(narrowed, measure = "total"))
  full <- as.data.frame(durations(dn, measure = "total"))
  expect_lt(sum(observed$value), sum(full$value))
  restored <- clear_observations(narrowed)
  expect_same_meta(restored, dn)
  expect_equal(as.data.frame(durations(restored, measure = "total")), full)
  expect_error(set_observations(dn), class = "dynet_bad_input")
})

test_that("set_tie_sessions breaks use the time tolerance and calendar times", {
  starts <- c(0.29, 0.7 - 0.4, 0.1 + 0.2)
  dn <- quiet_dynet(data.frame(from = c("A", "B", "C"), to = c("B", "C", "D"),
                               start = starts, end = 1))
  cut <- set_tie_sessions(dn, breaks = 0.3)
  sessions <- as.data.frame(cut)$session
  # 0.7 - 0.4 is 0.29999999999999993: at the break, so in the later session.
  expect_identical(sessions, c("session_1", "session_2", "session_2"))
  # Invariant: every spell has exactly one session, ordered with its start.
  expect_false(anyNA(sessions))
  expect_identical(nrow(as.data.frame(cut)), nrow(as.data.frame(dn)))
  expect_error(set_tie_sessions(dn, breaks = c(0.5, 0.2)),
               class = "dynet_bad_input")

  log <- data.frame(from = c("A", "B"), to = c("B", "C"),
                    start = as.Date(c("2024-01-01", "2024-01-10")),
                    end = as.Date(c("2024-01-02", "2024-01-12")))
  dated <- quiet_dynet(log)
  by_date <- set_tie_sessions(dated, breaks = as.Date("2024-01-05"))
  by_number <- set_tie_sessions(dated, breaks = 4)
  expect_identical(as.data.frame(by_date)$session,
                   as.data.frame(by_number)$session)
  expect_identical(as.data.frame(by_date)$session, c("session_1", "session_2"))
})

test_that("tie sessions on Unix-scale times respect the tolerance", {
  edges <- chain_edges()
  edges$start <- edges$start + 1.7e9
  edges$end <- edges$end + 1.7e9
  dn <- quiet_dynet(edges)
  break_at <- 1.7e9 + 3 - 1e-7
  cut <- set_tie_sessions(dn, breaks = break_at)
  expect_identical(as.data.frame(cut)$session,
                   c("session_1", "session_1", "session_2", "session_2"))
  expect_valid_dynet(cut)
  expect_error(set_tie_sessions(dn, breaks = c(1.7e9 + 3, NA)),
               class = "dynet_bad_input")
})

test_that("rename_nodes and rename_sessions are bijections", {
  rooms <- data.frame(name = c("A", "B", "C", "D", "E"),
                      room = c("x", "x", "y", "y", "z"))
  dn <- quiet_dynet(chain_edges(), nodes = rooms, groups = "room")
  declared <- set_vertex_spells(dn, data.frame(node = c("A", "E"),
                                               start = 0, end = 3))
  swapped <- rename_nodes(declared, c(A = "E", E = "A"))
  expect_valid_dynet(swapped)
  swapped_nodes <- as.data.frame(swapped, what = "nodes")
  renamed_a <- subset(swapped_nodes, name == "E")
  expect_identical(renamed_a$room, "x")
  back <- rename_nodes(swapped, c(A = "E", E = "A"))
  expect_equal(as.data.frame(back), as.data.frame(declared))
  expect_equal(as.data.frame(back, what = "nodes"),
               as.data.frame(declared, what = "nodes"))
  expect_equal(as.data.frame(back, what = "vertex_spells"),
               as.data.frame(declared, what = "vertex_spells"))
  expect_equal(back$node_groups, declared$node_groups)
  expect_equal(back$edges, declared$edges)
  expect_error(rename_nodes(dn, c(A = "B")), class = "dynet_duplicate_node")

  sessioned <- set_tie_sessions(quiet_dynet(chain_edges()), breaks = 3)
  renamed <- rename_sessions(sessioned, c(session_1 = "early"))
  expect_identical(renamed$meta$sessions, c("early", "session_2"))
  restored <- rename_sessions(renamed, c(early = "session_1"))
  expect_equal(as.data.frame(restored), as.data.frame(sessioned))
  expect_error(rename_sessions(sessioned, c(nope = "x")),
               class = "dynet_unknown_session")
})

test_that("a chain of edits leaves a valid network at every step", {
  dn <- quiet_dynet(random_edges(seed = 7))
  steps <- list(
    function(x) add_nodes(x, data.frame(name = "new", role = "r")),
    function(x) add_ties(x, data.frame(from = "new", to = "v1", start = 3,
                                       end = 4, kind = "k")),
    function(x) update_ties(x, ties = from == "new",
                            data = data.frame(weight = 2)),
    function(x) set_tie_sessions(x, breaks = 10),
    function(x) rename_sessions(x, c(session_1 = "first")),
    function(x) rename_nodes(x, c(new = "fresh")),
    function(x) set_vertex_spells(x, "ties"),
    function(x) update_nodes(x, data.frame(name = "fresh", role = "s")),
    function(x) set_observations(x, start = 1, end = 15),
    function(x) induce_subgraph(x, ties = start > 2),
    function(x) clear_observations(x)
  )
  final <- Reduce(function(x, step) expect_valid_dynet(step(x)), steps, dn)
  final_nodes <- as.data.frame(final, what = "nodes")
  expect_true("fresh" %in% final_nodes$name)
  final_spells <- as.data.frame(final)
  fresh_spells <- subset(final_spells, from == "fresh")
  expect_identical(fresh_spells$kind, "k")
  expect_error(induce_subgraph(final, ties = start > 1e6),
               class = "dynet_empty_network")
})
