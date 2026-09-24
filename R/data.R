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
#' The fourteen students are `Ana`, `Ben`, `Cara`, `Dan`, `Eve`, `Finn`,
#' `Gita`, `Hugo`, `Iris`, `Jonas`, `Kira`, `Leo`, `Mira` and `Nils`; times
#' run from day 0 to day 21.52.
#'
#' @source Simulated, not observed. Generated deterministically under a fixed
#'   seed by `data-raw/make-data.R`.
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
#'   \item{timestamp}{`POSIXct` (UTC). When the post was made. Posts run from
#'     2024-09-02 to 2024-10-27, just under eight weeks.}
#'   \item{thread}{Character. The discussion thread it belongs to; 62 threads.}
#' }
#'
#' @source Simulated, not observed. Generated deterministically under a fixed
#'   seed by `data-raw/make-data.R`.
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
#'   \item{role}{Character. `"Student"` (16), `"Teacher"` (3) or
#'     `"Facilitator"` (1).}
#'   \item{achievement}{Character. `"High"`, `"Middle"` or `"Low"` for
#'     students; `NA` for the four staff.}
#' }
#'
#' @source Simulated, not observed. Generated deterministically under a fixed
#'   seed by `data-raw/make-data.R`.
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
#'   \item{student}{Character. Student identifier, `s01` to `s24`.}
#'   \item{seminar}{Character. Which weekly seminar, `week_01` to `week_12`.}
#'   \item{date}{`Date`. When the seminar was held, 2024-09-03 to 2024-11-19.}
#' }
#'
#' @source Simulated, not observed. Generated deterministically under a fixed
#'   seed by `data-raw/make-data.R`.
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
#' common transition. Build with `loops = TRUE` to keep them; the `weight`
#' column is picked up as the tie weight.
#'
#' @format A `data.frame` with 101 rows and 5 columns:
#' \describe{
#'   \item{from}{Character. Code of the replying message.}
#'   \item{to}{Character. Code of the message replied to.}
#'   \item{start}{Numeric. When the spell opens, 0 to 2.10.}
#'   \item{end}{Numeric. When it closes, 0.03 to 5.80.}
#'   \item{weight}{Numeric, whole-valued. Message pairs the spell represents,
#'     1 to 5881.}
#' }
#' The ten codes are `Acceptance`, `Argument`, `Composing`, `Disagreement`,
#' `Evaluation`, `Group_regulation`, `Question`, `Sharing`, `Socioemotional`
#' and `T.Regulation`; 14 rows are self-loops.
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
#'   \item{from}{Character. Code of the replying message, one of the nine
#'     codes `Approving`, `Arguing`, `Coordinating`, `Drafting`, `Inquiring`,
#'     `Objecting`, `Resourcing`, `Socialising`, `Tutoring`.}
#'   \item{to}{Character. Code of the message replied to, same set.}
#'   \item{time}{`POSIXct` (UTC) time of the replying message, shifted by
#'     whole weeks; 2006-09-23 to 2011-11-02 after the shift.}
#'   \item{participant}{Character. Anonymous author label, `P001` to `P240`.}
#'   \item{discussion}{Integer discussion (thread) id, 1 to 1169, all present.}
#'   \item{group}{Character. Course group, `A_01` style; 29 groups.}
#'   \item{course}{Character. Course, `A` to `E`.}
#' }
#' @source Derived from the *Trees of Thought* study reply table by the
#'   procedure in `data-raw/thought_chains.R`, which needs the study's private
#'   files and is not run at build time.
#' @examples
#' dynet(thought_chains, time = "time", loops = TRUE)
#' dynet(thought_chains, thread = "discussion")
"thought_chains"

#' Posts in a MOOC discussion forum
#'
#' The discussion log of chapter 17 of *Learning Analytics Methods and
#' Tutorials* (Saqr, 2024), one row per post in the Digital Learning
#' Transition MOOC, April to June 2013. A post names the participant who
#' wrote it and the participant it answers, so a tie runs from sender to
#' receiver; `discussion` is the thread the post belongs to, which is what
#' makes the log threaded in the sense [dynet()] means by `thread =`.
#'
#' Only the four columns the chapter's analysis reads are kept; the category
#' hierarchy and comment identifiers of the published file are dropped.
#'
#' @format A data frame with 2529 rows and 4 columns:
#' \describe{
#'   \item{sender}{Character. The participant who wrote the post.}
#'   \item{receiver}{Character. The participant the post answers.}
#'   \item{timestamp}{POSIXct (UTC). When the post was made, from
#'     2013-04-04 16:32 to 2013-06-16 17:12.}
#'   \item{discussion}{Character. Thread title; 338 distinct threads.}
#' }
#' @source Saqr, M. (2024). Temporal network analysis: Introduction, methods
#'   and analysis with R. In M. Saqr & S. López-Pernas (Eds.), *Learning
#'   Analytics Methods and Tutorials*. Springer.
#'   \doi{10.1007/978-3-031-54464-4_17}. Data from
#'   <https://github.com/lamethods/data>, directory `6_snaMOOC`, prepared by
#'   `data-raw/mooc_forum.R`.
#' @seealso [mooc_people] for the participants, and
#'   `vignette("ch17-temporal-networks")` for the chapter's analysis.
#' @examples
#' # summary() measures every graph-level statistic on all 74 daily bins and
#' # takes about 28 seconds on this network; print() is immediate. The article
#' # `vignette("mooc-posts")` walks through the data with stated grids.
#' dn <- dynet(mooc_posts, from = "sender", to = "receiver",
#'             time = "timestamp", thread = "discussion")
#' dn
"mooc_posts"

#' Participants in a MOOC discussion forum
#'
#' The participant table accompanying [mooc_posts]: every person who appears
#' as a sender or a receiver there, with the self-reported experience level
#' as the chapter's integer code and as the label it recodes the code into
#' and uses as the mixing attribute.
#'
#' @format A data frame with 445 rows and 3 columns:
#' \describe{
#'   \item{name}{Character. Participant identifier, matching the `sender`
#'     and `receiver` columns of [mooc_posts].}
#'   \item{experience}{Integer. Self-reported experience level: `1` expert,
#'     `2` student, `3` teacher.}
#'   \item{expert_level}{Character. The same level as `Expert`, `Student`
#'     or `Teacher`.}
#' }
#' @source As [mooc_posts].
#' @seealso [mooc_posts]; `vignette("ch17-temporal-networks")`.
#' @examples
#' participants <- dynet(mooc_posts, from = "sender", to = "receiver",
#'                       time = "timestamp", thread = "discussion",
#'                       nodes = mooc_people)
#' as.data.frame(participants, what = "nodes")
"mooc_people"
