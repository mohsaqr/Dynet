#' @keywords internal
"_PACKAGE"

#' @importFrom grDevices adjustcolor
#' @importFrom graphics par
#' @importFrom stats ave median reorder sd setNames
#' @importFrom utils globalVariables head modifyList tail
NULL

# ggplot2 aesthetics are non-standard evaluation; declare the column names
# used inside aes() so R CMD check does not flag them as globals.
utils::globalVariables(c(
  ".grp", ".row", "arrival_time", "arrival_time_prev", "count", "depth", "vertex_fill",
  "depth_prev", "edge", "end_draw", "endpoint", "ev", "family", "freq",
  "from", "group", "id", "label", "label_y", "lt", "measure", "node", "note",
  "other", "pair", "part", "position", "session", "shift", "size", "start", "ties",
  "time", "tip", "to", "value", "vertex", "weight", "x", "xend", "y",
  "yend", "yf"
))
