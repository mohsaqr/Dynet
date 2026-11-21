# Reference computations shared by the equivalence tests. Nothing here calls Dynet: each function is one side
# of a comparison (a bridge to an established package, or the definition written out in base R), and the
# package is the other side.

#' A spell table as a networkDynamic object
#'
#' The bridge to tsna, networkDynamic and sna. Vertices are numbered in sorted name order and named in
#' `vertex.names`. networkDynamic merges overlapping spells of one pair, as its own documentation states.
#'
#' @param edges A data frame with `from`, `to`, `start`, `end`.
#' @param directed Whether a tie has a sender and a receiver.
#' @param vertices The vertex names; by default every name in `edges`, sorted.
#' @param observed `c(start, end)` to declare as `net.obs.period`; `NULL` declares none.
#' @return A networkDynamic object.
ref_network_dynamic <- function(edges, directed = TRUE, vertices = sort(unique(c(edges$from, edges$to))),
                                observed = NULL) {
  stopifnot("`edges` needs from, to, start, end" = all(c("from", "to", "start", "end") %in% names(edges)),
            "every endpoint must be in `vertices`" = all(c(edges$from, edges$to) %in% vertices))
  base <- network::network.initialize(length(vertices), directed = directed, loops = any(edges$from == edges$to))
  network::set.vertex.attribute(base, "vertex.names", vertices)
  spells <- data.frame(onset = edges$start, terminus = edges$end, tail = match(edges$from, vertices),
                       head = match(edges$to, vertices))
  period <- if (!is.null(observed)) {
    list(observations = list(observed), mode = "continuous", time.increment = NA, time.unit = "step")
  }
  suppressMessages(networkDynamic::networkDynamic(base.net = base, edge.spells = spells, net.obs.period = period,
                                                  verbose = FALSE))
}

#' Spells clipped to a window
#'
#' @param edges A data frame with `start` and `end`.
#' @param lo,hi The window `[lo, hi]`.
#' @return The rows that overlap the window for a positive length, with `start` and `end` cut to it.
ref_clip <- function(edges, lo, hi) {
  cut <- transform(edges, start = pmax(start, lo), end = pmin(end, hi))
  subset(cut, end > start)
}

#' The length of the union of intervals
#'
#' Sort by onset; a new run opens wherever an onset lies beyond every terminus seen so far.
#'
#' @param start,end Numeric vectors of one length.
#' @return One number.
ref_union_length <- function(start, end) {
  by_onset <- order(start)
  start <- start[by_onset]
  reach <- cummax(end[by_onset])
  opens <- c(TRUE, start[-1L] > utils::head(reach, -1L))
  sum(tapply(reach, cumsum(opens), max) - start[opens])
}

#' The binary snapshot of a window as an igraph graph
#'
#' A window `[lo, hi)` holds a spell `[start, end)` when the two overlap for a positive length; the window's
#' snapshot is the set of pairs with at least one such spell, one arc per ordered pair.
#'
#' @param edges A spell table.
#' @param lo,hi The window.
#' @param vertices Every vertex, in the order of the result.
#' @param directed Whether arcs have a direction.
#' @return An igraph graph.
ref_snapshot <- function(edges, lo, hi, vertices = sort(unique(c(edges$from, edges$to))), directed = TRUE) {
  active <- subset(edges, start < hi & end > lo, select = c(from, to))
  igraph::simplify(igraph::graph_from_data_frame(active, directed = directed, vertices = vertices))
}

#' The binary snapshot of a window as an adjacency matrix
#'
#' @inheritParams ref_snapshot
#' @return A 0/1 matrix with the vertex names as dimnames.
ref_adjacency <- function(edges, lo, hi, vertices = sort(unique(c(edges$from, edges$to))), directed = TRUE) {
  active <- subset(edges, start < hi & end > lo & from != to)
  adjacency <- matrix(0, length(vertices), length(vertices), dimnames = list(vertices, vertices))
  adjacency[cbind(match(active$from, vertices), match(active$to, vertices))] <- 1
  if (!directed) adjacency <- pmax(adjacency, t(adjacency))
  adjacency
}

#' Per-vertex values over several windows as one long table
#'
#' @param per_window A list, one element per window onset, of named lists of named numeric vectors
#'   (`measure -> node -> value`).
#' @param onsets The window onsets, one per element.
#' @return A data frame `time`, `node`, `measure`, `value`.
ref_node_table <- function(per_window, onsets) {
  rows <- Map(\(values, onset) {
    do.call(rbind, Map(\(scores, measure) {
      data.frame(time = onset, node = names(scores), measure = measure, value = unname(as.numeric(scores)))
    }, values, names(values)))
  }, per_window, onsets)
  do.call(rbind, rows)
}

#' Earliest arrival from one vertex, the recurrence written out
#'
#' An interval spell `[start, end)` can be entered at any instant from its onset up to but excluding its
#' terminus; waiting is free and a hop takes no time. The arrival time at every vertex is relaxed until
#' nothing improves.
#'
#' @param edges A spell table of interval spells.
#' @param source The vertex the search starts from.
#' @param origin The time it is present from.
#' @param vertices Every vertex.
#' @return A named numeric vector of arrival times, `Inf` where a vertex is not reached.
ref_earliest_arrival <- function(edges, source, origin, vertices = sort(unique(c(edges$from, edges$to)))) {
  arrival <- stats::setNames(rep(Inf, length(vertices)), vertices)
  arrival[[source]] <- origin
  relax <- function(arrival) {
    here <- arrival[edges$from]
    enterable <- here < edges$end
    entered <- pmax(here, edges$start)[enterable]
    best <- tapply(entered, edges$to[enterable], min)
    updated <- arrival
    updated[names(best)] <- pmin(arrival[names(best)], best)
    if (identical(updated, arrival)) arrival else relax(updated)
  }
  relax(arrival)
}

#' Skip, recorded, when the reference Python cannot import a module
#'
#' The skip goes through `skip_without_reference()` with the module's name, so that Prova lists it with the
#' reference that is missing. The interpreter is the helper's verify_python() (VERIFY_PYTHON, RETICULATE_PYTHON,
#' ~/equiv-py, then `python3` on the PATH), so a re-run in Prova finds the virtualenv on a machine set up like ci.
#'
#' @param module The Python module, e.g. `"networkx"`.
#' @param reference The reference's name in `verify.json`.
#' @return `TRUE`, invisibly, when the module imports.
ref_skip_without_python <- function(module, reference = module) {
  python <- verify_python()
  found <- nzchar(python) &&
    identical(system2(python, c("-c", shQuote(sprintf("import %s", module))), stdout = FALSE, stderr = FALSE), 0L)
  if (!found) skip_without_reference(reference)
  invisible(TRUE)
}

#' Run a Python script and read the JSON it writes
#'
#' @param code Lines of Python; the script reads its input JSON from `sys.argv[1]` and writes its result to
#'   `sys.argv[2]`.
#' @param input Anything `jsonlite::write_json()` can write.
#' @return The parsed result.
ref_python <- function(code, input) {
  script <- tempfile(fileext = ".py")
  given <- tempfile(fileext = ".json")
  result <- tempfile(fileext = ".json")
  on.exit(unlink(c(script, given, result)), add = TRUE)
  writeLines(code, script)
  jsonlite::write_json(input, given, auto_unbox = TRUE, digits = NA)
  status <- system2(verify_python(), c("-I", script, given, result))
  stopifnot("the Python script must succeed" = identical(status, 0L))
  jsonlite::fromJSON(result, simplifyVector = TRUE)
}

#' The version of a Python module
#'
#' @param module The module.
#' @return A string.
ref_python_version <- function(module) {
  system2(verify_python(), c("-c", shQuote(sprintf("import %s; print(%s.__version__)", module, module))), stdout = TRUE)
}

#' A seeded random spell table
#'
#' @param seed The seed; the caller's random stream is restored afterwards.
#' @param vertices The number of vertices.
#' @param spells The number of spells drawn (self-loops are dropped).
#' @param span The time span.
#' @return A data frame `from`, `to`, `start`, `end`, times on a 0.01 grid.
ref_random_spells <- function(seed, vertices = 8L, spells = 40L, span = 30) {
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else assign(".Random.seed", old, envir = globalenv()),
          add = TRUE)
  set.seed(seed)
  start <- round(stats::runif(spells, 0, span), 2)
  drawn <- data.frame(from = paste0("v", sample(vertices, spells, TRUE)),
                      to = paste0("v", sample(vertices, spells, TRUE)),
                      start = start, end = start + round(stats::runif(spells, 0.5, span / 3), 2))
  subset(drawn, from != to)
}

#' Every vertex-simple journey from `vertex`, entered as early as possible: one row per journey, named by its route
enumerate_journeys <- function(edges, vertex, time, visited, hops, route = vertex) {
  leaving <- which(edges$from == vertex & edges$end > time & !(edges$to %in% visited))
  found <- lapply(leaving, \(spell) {
    entered <- max(time, edges$start[[spell]])
    onward <- paste(route, edges$to[[spell]], sep = " -> ")
    rbind(data.frame(node = edges$to[[spell]], arrival_time = entered, n_hops = hops + 1, route = onward),
          enumerate_journeys(edges, edges$to[[spell]], entered, c(visited, edges$to[[spell]]), hops + 1, onward))
  })
  do.call(rbind, c(list(data.frame(node = character(), arrival_time = numeric(), n_hops = numeric(),
                                   route = character())), found))
}

#' The foremost journey to every reached vertex, the fewest hops among the foremost
#'
#' @param edges A spell table.
#' @param source The source vertex; the search starts at the first onset.
#' @return A data frame `node`, `arrival_time`, `n_hops`.
foremost_by_enumeration <- function(edges, source) {
  origin <- min(edges$start)
  journeys <- rbind(data.frame(node = source, arrival_time = origin, n_hops = 0, route = source),
                    enumerate_journeys(edges, source, origin, source, 0))
  earliest <- stats::aggregate(arrival_time ~ node, journeys, min)
  foremost <- merge(journeys, earliest)
  stats::aggregate(n_hops ~ node + arrival_time, foremost, min)
}

#' The optimal journeys themselves: the foremost, then shortest, journeys to every reached vertex but the source
optimal_journeys <- function(edges, source) {
  origin <- min(edges$start)
  journeys <- enumerate_journeys(edges, source, origin, source, 0)
  merge(journeys, foremost_by_enumeration(edges, source), by = c("node", "arrival_time", "n_hops"))
}
