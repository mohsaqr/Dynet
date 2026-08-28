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
  ".grp", ".row", "arrival_time", "arrival_time_prev", "count", "depth",
  "depth_prev", "edge", "end_draw", "endpoint", "ev", "freq", "from", "group",
  "id", "label", "label_y", "measure", "node", "other", "pair", "position",
  "session", "size", "start", "ties", "time", "to", "value", "weight", "x",
  "xend",
  "y", "yend", "yf"
))
