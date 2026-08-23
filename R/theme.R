# ===========================================================================
# The "dynet" cograph theme
# ===========================================================================

#' Register Dynet's cograph theme
#'
#' cograph keeps a theme registry (`cograph::register_theme()`,
#' `cograph::get_theme()`, `cograph::list_themes()`) and `cograph::splot()`
#' takes a `theme` argument. Dynet registers `"dynet"` there on load, so it
#' appears in `cograph::list_themes()` alongside cograph's own and can be
#' asked for by name from any cograph call.
#'
#' The theme must be a `CographTheme` object rather than the plain list
#' `register_theme()` documents, because `splot()` reaches into it with
#' `th$get()`; a list is accepted by the registry and then fails at draw time.
#'
#' `splot()` reads six of the thirteen parameters a theme can hold --
#' `node_fill`, `background`, `label_color`, `edge_positive_color`,
#' `edge_negative_color` and `node_border_color`, the last of which a
#' `CographTheme` stores under the name `node_border` and so never matches.
#' Everything a theme cannot carry stays in [.splot_args()].
#'
#' @return `TRUE` if the theme was registered, `FALSE` otherwise, invisibly.
#' @keywords internal
.register_dynet_theme <- function() {
  if (!requireNamespace("cograph", quietly = TRUE)) return(invisible(FALSE))
  cograph::register_theme("dynet", cograph::CographTheme$new(
    name                = "dynet",
    background          = "white",
    node_fill           = "#56B4E9",
    node_border         = "white",
    node_border_width   = 1.2,
    edge_color          = "#4A4A4A",
    edge_positive_color = "#4A6FE3",
    edge_negative_color = "#D33F6A",
    edge_width          = 1,
    label_color         = "black",
    label_size          = 10,
    title_color         = "black",
    title_size          = 13,
    legend_background   = "white"
  ))
  invisible(TRUE)
}

# ===========================================================================
# The "temporal" cograph layout
# ===========================================================================

#' Position vertices by arrival time and path depth
#'
#' A layout for cograph's layout registry. Horizontal position is the real
#' arrival time of a vertex and vertical position is its depth in hops, so
#' the two axes can disagree: a vertex reached in one hop but late sits to
#' the right of one reached in four hops but early. A tree drawn by ordinary
#' graph-drawing rules hides exactly that.
#'
#' The network must carry `arrival_time` and `n_hops` vertex columns, which
#' [plot.dynet_paths()] writes when it builds the tree.
#'
#' @param network A `CographNetwork` carrying the two columns above.
#' @param ... Ignored; present because cograph passes layout parameters
#'   through.
#' @return A `data.frame` with `x` and `y`, one row per vertex.
#' @keywords internal
.layout_temporal <- function(network, ...) {
  nodes <- if (inherits(network, "CographNetwork")) network$get_nodes() else
    network$nodes
  need <- c("arrival_time", "n_hops")
  if (!all(need %in% names(nodes))) {
    stop(errorCondition(
      "The \"temporal\" layout needs `arrival_time` and `n_hops` vertex columns; it is meant for the result of dyn_paths().",
      class = "dynet_bad_input", call = NULL))
  }
  data.frame(
    x = .rescale(nodes$arrival_time),
    y = .rescale(-(nodes$n_hops + .jitter_within(nodes$n_hops)))
  )
}

#' Register Dynet's cograph layout
#'
#' cograph keeps a layout registry beside its theme registry
#' (`cograph::register_layout()`, `cograph::get_layout()`,
#' `cograph::list_layouts()`). Registering here means `"temporal"` is
#' resolvable by name from any cograph call and appears in
#' `cograph::list_layouts()`.
#'
#' @return `TRUE` if the layout was registered, `FALSE` otherwise, invisibly.
#' @keywords internal
.register_dynet_layout <- function() {
  if (!requireNamespace("cograph", quietly = TRUE)) return(invisible(FALSE))
  cograph::register_layout("temporal", .layout_temporal)
  invisible(TRUE)
}

.onLoad <- function(libname, pkgname) {
  .register_dynet_theme()
  .register_dynet_layout()
  invisible(NULL)
}
