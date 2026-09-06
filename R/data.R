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

#' Synthetic code-transition network (Trees of Thought stand-in)
#'
#' A synthetic temporal network of how one interaction code follows another in
#' asynchronous discussion. Vertices are the ten codes a message can carry, so
#' a vertex is a **category, never a person**, and a tie runs from the code of
#' a message to the code of the message it replies to.
#'
#' This is a stand-in for the network analysed in the *Trees of Thought* study,
#' whose own data is not redistributable. It was built by drawing a random 70%
#' subset of that study's edge spells and resampling that subset with
#' replacement to 90% of the original spell count, so it omits about a third of
#' the real spells and repeats others. **No row of it should be read as a
#' finding about the study**, and figures computed from it will not match the
#' published ones. It exists so the analysis can be run and taught end to end.
#'
#' Spells are weighted by how many message pairs they represent, overlap in
#' time, and include self-loops, because a code following itself is a real and
#' common transition. Build with `loops = TRUE` to keep them, and name
#' `weight = "weight"` or the spell counts are silently replaced by ones.
#'
#' @format A `data.frame` with 101 rows and 5 columns:
#' \describe{
#'   \item{from}{Character. Code of the replying message.}
#'   \item{to}{Character. Code of the message replied to.}
#'   \item{start}{Numeric. When the spell opens.}
#'   \item{end}{Numeric. When it closes.}
#'   \item{weight}{Integer. Message pairs the spell represents.}
#' }
#'
#' @source Synthesised from the *Trees of Thought* code-transition network by
#'   the resampling described above; see `data-raw/synthdata.R`.
#'
#' @examples
#' dynet(synthdata, directed = TRUE, loops = TRUE, weight = "weight")
"synthdata"

#' Trees of Thought reply links, anonymised
#'
#' @description
#' Each row is one link from the code of a discussion message to the code of
#' the message it replies to, from the *Trees of Thought* study of coded
#' asynchronous discussions. It is the study's own reply table with every
#' identity removed and its shape trimmed, not a resampled or synthesised set:
#' each row is a real link with its real weekday and time of day.
#'
#' Applied to the study table, in order: the two sparse weekdays (Thursday and
#' Friday, under one percent of links) were dropped; the bottom 20 percent of
#' authors by number of distinct messages were removed together with the
#' links they authored (replies to them by others remain); author, message
#' and description columns were dropped, courses became `A` to `E`, groups
#' `A_01` and so on, discussions were renumbered and authors relabelled
#' `P001` onward in random order; every timestamp was shifted back by one
#' fixed random number of whole weeks, so the calendar is hidden and the
#' weekday kept; and the codes were renamed, with the study's *Evaluation*
#' and *Acceptance* merged into *Approving*.
#'
#' A reply carrying two codes that both map to one label yields two identical
#' rows; the study counted such repeats as weight, and they are kept as rows.
#' A code answering itself is a self-link (9,452 rows); [dynet()] drops these
#' unless `loops = TRUE`. The `course` column is recognised as the session
#' column, so the five courses become sessions unless `session = ` says
#' otherwise.
#'
#' @format A `data.frame` with 23,017 rows and 7 columns:
#' \describe{
#'   \item{from}{Code of the replying message, one of `Approving`, `Arguing`,
#'     `Coordinating`, `Drafting`, `Inquiring`, `Objecting`, `Resourcing`,
#'     `Socialising`, `Tutoring`.}
#'   \item{to}{Code of the message replied to, same set.}
#'   \item{time}{`POSIXct` (UTC) time of the replying message, shifted by
#'     whole weeks.}
#'   \item{participant}{Anonymous author label, `P001` to `P240`.}
#'   \item{discussion}{Integer discussion (thread) id, 1 to 1169.}
#'   \item{group}{Course group, `A_01` style; 29 groups.}
#'   \item{course}{Course, `A` to `E`.}
#' }
#' @source Derived from the *Trees of Thought* study reply table by the
#'   procedure in `data-raw/thought_chains.R`, which needs the study's private
#'   files and is not run at build time.
#' @examples
#' dynet(thought_chains, time = "time", loops = TRUE)
#' dynet(thought_chains, thread = "discussion")
"thought_chains"
