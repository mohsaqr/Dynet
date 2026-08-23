# Generates the three bundled example datasets. Run once; the .rda files are
# the record. Deterministic under the seeds below.
set.seed(2024)

# ---------------------------------------------------------------------------
# school_contacts: an interval log. 14 students in three friendship clusters,
# meeting over three weeks, with activity rising then falling.
# ---------------------------------------------------------------------------
students <- c("Ana", "Ben", "Cara", "Dan", "Eve", "Finn", "Gita",
              "Hugo", "Iris", "Jonas", "Kira", "Leo", "Mira", "Nils")
cluster <- rep(1:3, length.out = length(students))
names(cluster) <- students

n_ev <- 240
day <- sort(round(c(
  runif(n_ev * 0.25, 0, 7), runif(n_ev * 0.5, 6, 15),
  runif(n_ev * 0.25, 13, 21)), 2))[seq_len(n_ev)]

pick_pair <- function(i) {
  a <- sample(students, 1L)
  same <- students[cluster == cluster[[a]] & students != a]
  other <- setdiff(students, c(a, same))
  b <- if (runif(1) < 0.7) sample(same, 1L) else sample(other, 1L)
  c(a, b)
}
pairs <- vapply(seq_len(n_ev), pick_pair, character(2L))

school_contacts <- data.frame(
  from     = pairs[1L, ],
  to       = pairs[2L, ],
  start    = day,
  end      = round(day + rgamma(n_ev, shape = 2, scale = 0.25), 2),
  stringsAsFactors = FALSE
)
school_contacts <- school_contacts[school_contacts$from != school_contacts$to, ]
rownames(school_contacts) <- NULL

# ---------------------------------------------------------------------------
# forum_posts: a threaded log with real timestamps, plus a vertex table.
# ---------------------------------------------------------------------------
set.seed(17)
people <- c(paste0("student_", sprintf("%02d", 1:16)),
            "teacher_A", "teacher_B", "teacher_C", "facilitator")
forum_people <- data.frame(
  name = people,
  role = c(rep("Student", 16), rep("Teacher", 3), "Facilitator"),
  achievement = c(sample(c("High", "Middle", "Low"), 16, TRUE,
                         prob = c(0.3, 0.45, 0.25)), rep(NA, 4)),
  stringsAsFactors = FALSE
)

n_threads <- 62
origin <- as.POSIXct("2024-09-02 08:00:00", tz = "UTC")
thread_rows <- lapply(seq_len(n_threads), function(k) {
  opener <- sample(people, 1L, prob = c(rep(3, 16), 1, 1, 1, 2))
  n_reply <- 1L + rpois(1L, 3.2)
  t0 <- origin + runif(1L, 0, 52) * 86400
  gaps <- cumsum(c(0, rgamma(n_reply, shape = 1.4, scale = 0.55)))
  posters <- c(opener, sample(people, n_reply, TRUE,
                              prob = c(rep(3, 16), 1, 1, 1, 2)))
  targets <- c(posters[1L], vapply(seq_len(n_reply), function(i)
    sample(posters[seq_len(i)], 1L), character(1L)))
  data.frame(
    sender    = posters,
    receiver  = targets,
    timestamp = t0 + gaps * 86400,
    thread    = sprintf("thread_%02d", k),
    stringsAsFactors = FALSE
  )
})
forum_posts <- do.call(rbind, thread_rows)
forum_posts <- forum_posts[forum_posts$sender != forum_posts$receiver, ]
forum_posts <- forum_posts[order(forum_posts$timestamp), ]
rownames(forum_posts) <- NULL

# ---------------------------------------------------------------------------
# seminar_attendance: a two-mode co-presence log.
# ---------------------------------------------------------------------------
set.seed(99)
enrolled <- paste0("s", sprintf("%02d", 1:24))
seminars <- sprintf("week_%02d", 1:12)
attend <- lapply(seq_along(seminars), function(k) {
  present <- sample(enrolled, sample(6:11, 1L))
  data.frame(student = present, seminar = seminars[k],
             date = as.Date("2024-09-03") + (k - 1L) * 7L,
             stringsAsFactors = FALSE)
})
seminar_attendance <- do.call(rbind, attend)
rownames(seminar_attendance) <- NULL

usethis_free_save <- function(obj, name) {
  assign(name, obj)
  save(list = name, file = file.path("data", paste0(name, ".rda")),
       compress = "xz", version = 3)
}
usethis_free_save(school_contacts, "school_contacts")
usethis_free_save(forum_posts, "forum_posts")
usethis_free_save(forum_people, "forum_people")
usethis_free_save(seminar_attendance, "seminar_attendance")

cat(sprintf("school_contacts    %d rows, %d vertices\n", nrow(school_contacts),
            length(unique(c(school_contacts$from, school_contacts$to)))))
cat(sprintf("forum_posts        %d rows, %d threads, %d people\n",
            nrow(forum_posts), length(unique(forum_posts$thread)),
            length(unique(c(forum_posts$sender, forum_posts$receiver)))))
cat(sprintf("seminar_attendance %d rows, %d students, %d seminars\n",
            nrow(seminar_attendance), length(unique(seminar_attendance$student)),
            length(unique(seminar_attendance$seminar))))
