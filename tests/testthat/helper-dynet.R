# Small fixtures used across test files.

chain_edges <- function() {
  data.frame(from = c("A", "B", "C", "D"), to = c("B", "C", "D", "E"),
             start = c(1, 2, 3, 4), end = c(2, 3, 4, 5),
             stringsAsFactors = FALSE)
}

triangle_edges <- function() {
  data.frame(from = c("A", "B", "C"), to = c("B", "C", "A"),
             start = c(1, 2, 3), end = c(4, 5, 6), stringsAsFactors = FALSE)
}

random_edges <- function(n_v = 12L, n_e = 60L, span = 20, seed = 1L) {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()), add = TRUE)
  set.seed(seed)
  s <- round(stats::runif(n_e, 0, span), 2)
  e <- data.frame(
    from  = paste0("v", sample(n_v, n_e, TRUE)),
    to    = paste0("v", sample(n_v, n_e, TRUE)),
    start = s,
    end   = s + round(stats::runif(n_e, 0.5, span / 4), 2),
    stringsAsFactors = FALSE
  )
  e[e$from != e$to, , drop = FALSE]
}

quiet_dynet <- function(...) suppressMessages(dynet(...))

# The retired `dyn_centrality()` still routes `scope = "temporal"` reach and
# its old argument checks; tests of those contracts silence only its classed
# deprecation warning, so any other warning still reaches the test.
legacy_centrality <- function(...) {
  withCallingHandlers(
    dyn_centrality(...),
    dynet_deprecated = function(w) invokeRestart("muffleWarning")
  )
}
