# ===========================================================================
# Bundled example data
# ===========================================================================

#' Student contacts recorded as intervals
#'
#' Face-to-face contacts among fourteen students over three weeks. Each row is
#' one contact with an explicit start and end, which makes this an interval
#' log: duration carries information, and two students who met once at length
#' are distinguishable from two who met briefly many times. The students fall
#' into three loosely-connected friendship clusters and overall activity rises
#' through the second week before falling away.
#'
#' @format A `data.frame` with 240 rows and 4 columns:
#' \describe{
#'   \item{from}{Character. The student initiating the contact.}
#'   \item{to}{Character. The other student.}
#'   \item{start}{Numeric. Day the contact began, counted from day zero.}
#'   \item{end}{Numeric. Day the contact ended.}
#' }
#'
#' @examples
#' dynet(school_contacts)
"school_contacts"

#' Discussion forum posts
#'
#' Posts in a course discussion forum over roughly eight weeks. Each row is one
#' post directed at an earlier poster in the same thread. Because a post has a
#' timestamp but no end, the duration of the tie has to be derived: [dynet()]
#' treats a post as active until the last post in its thread, so a message that
#' provoked a long argument stays live longer than one that fell flat.
#'
#' Pairs with [forum_people], which carries the roles used for mixing analysis.
#'
#' @format A `data.frame` with 241 rows and 4 columns:
#' \describe{
#'   \item{sender}{Character. Who wrote the post.}
#'   \item{receiver}{Character. Who the post replied to.}
#'   \item{timestamp}{`POSIXct`. When the post was made.}
#'   \item{thread}{Character. The discussion thread it belongs to.}
#' }
#'
#' @examples
#' dynet(forum_posts, thread = "thread", nodes = forum_people)
"forum_posts"

#' People in the discussion forum
#'
#' Vertex attributes for [forum_posts]. Passed to [dynet()] through its `nodes`
#' argument, these become available to [mixing()].
#'
#' @format A `data.frame` with 20 rows and 3 columns:
#' \describe{
#'   \item{name}{Character. Matches the sender and receiver names in
#'     [forum_posts].}
#'   \item{role}{Character. `"Student"`, `"Teacher"` or `"Facilitator"`.}
#'   \item{achievement}{Character. `"High"`, `"Middle"` or `"Low"` for
#'     students; `NA` for staff.}
#' }
#'
#' @examples
#' dn <- dynet(forum_posts, thread = "thread", nodes = forum_people)
#' mixing(dn, attribute = "role")
"forum_people"

#' Seminar attendance
#'
#' Which students attended which weekly seminar over one term. This is
#' two-mode data: students are not linked to each other directly, only to the
#' seminars they turned up to. [dynet()] projects it, connecting every pair of
#' students who shared a room in the week they shared it.
#'
#' @format A `data.frame` with 104 rows and 3 columns:
#' \describe{
#'   \item{student}{Character. Student identifier.}
#'   \item{seminar}{Character. Which weekly seminar.}
#'   \item{date}{`Date`. When the seminar was held.}
#' }
#'
#' @examples
#' dynet(seminar_attendance, actor = "student", group = "seminar")
"seminar_attendance"
