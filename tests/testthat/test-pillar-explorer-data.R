testthat::test_that("pillar schema accepts exactly five structural pillars", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)

  index <- data.frame(
    country_code = "AAA",
    country_name = "Alpha",
    year = 2024L,
    score = NA_real_,
    pillar_1_score = 70,
    pillar_2_score = NA_real_,
    pillar_3_score = 80,
    pillar_4_score = 90,
    pillar_5_score = 60,
    stringsAsFactors = FALSE
  )
  labels <- data.frame(
    pillar_id = as.character(1:5),
    pillar_label = paste("Label", 1:5),
    stringsAsFactors = FALSE
  )

  result <- env$pillar_explorer_schema(index, labels)

  testthat::expect_equal(result$status, "ok")
  testthat::expect_equal(
    result$columns,
    paste0("pillar_", 1:5, "_score")
  )
  testthat::expect_equal(result$labels, paste("Label", 1:5))
})

testthat::test_that("pillar schema rejects incomplete or extra structural pillars", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)

  incomplete <- data.frame(
    country_code = "AAA", year = 2024L,
    pillar_1_score = 70, pillar_2_score = 80,
    stringsAsFactors = FALSE
  )
  extra <- data.frame(
    country_code = "AAA", year = 2024L,
    pillar_1_score = 70, pillar_2_score = 80, pillar_3_score = 80,
    pillar_4_score = 90, pillar_5_score = 60, pillar_6_score = 50,
    stringsAsFactors = FALSE
  )

  incomplete_result <- env$pillar_explorer_schema(incomplete)
  extra_result <- env$pillar_explorer_schema(extra)

  testthat::expect_equal(incomplete_result$status, "unavailable")
  testthat::expect_equal(extra_result$status, "unavailable")
  testthat::expect_match(incomplete_result$message, "five")
  testthat::expect_match(extra_result$message, "five")
})

testthat::test_that("pillar schema preserves valid row-level missingness", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)

  index <- data.frame(
    country_code = "AAA", year = 2024L,
    pillar_1_score = 70, pillar_2_score = NA_real_,
    pillar_3_score = 80, pillar_4_score = NA_real_,
    pillar_5_score = 60, stringsAsFactors = FALSE
  )

  result <- env$pillar_explorer_schema(index)

  testthat::expect_equal(result$status, "ok")
  testthat::expect_true(is.na(index$pillar_2_score))
  testthat::expect_true(is.na(index$pillar_4_score))
})

testthat::test_that("country-year choices require at least one pillar score", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)

  index <- data.frame(
    country_code = c("BBB", "AAA", "AAA", "CCC"),
    country_name = c("Beta", "Alpha", "Alpha", "Gamma"),
    year = c(2024L, 2024L, 2023L, 2024L),
    score = c(70, NA, 60, 80),
    pillar_1_score = c(70, 80, NA, NA),
    pillar_2_score = c(70, NA, NA, NA),
    pillar_3_score = c(70, NA, 65, NA),
    pillar_4_score = c(70, NA, NA, NA),
    pillar_5_score = c(70, NA, NA, NA),
    stringsAsFactors = FALSE
  )

  result <- env$pillar_explorer_country_year_choices(index)

  testthat::expect_equal(result$country_code, c("AAA", "AAA", "BBB"))
  testthat::expect_equal(result$year, c(2023L, 2024L, 2024L))
  testthat::expect_true(is.na(result$score[[2L]]))
  testthat::expect_false("CCC" %in% result$country_code)
})

testthat::test_that("country choices include official-score-missing rows", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)

  index <- data.frame(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year = c(2024L, 2024L),
    score = c(NA_real_, 80),
    pillar_1_score = c(70, 80),
    pillar_2_score = c(NA, 80),
    pillar_3_score = c(NA, 80),
    pillar_4_score = c(NA, 80),
    pillar_5_score = c(NA, 80),
    stringsAsFactors = FALSE
  )

  result <- env$pillar_explorer_country_year_choices(index)

  testthat::expect_equal(result$country_code, c("AAA", "BBB"))
  testthat::expect_true(is.na(result$score[[1L]]))
})
