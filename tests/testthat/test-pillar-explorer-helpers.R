testthat::test_that("equal weights calculate an exploratory score and difference", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  result <- env$pillar_explorer_calculate(
    scores = c(60, 70, 80, 90, 100),
    weights = rep(20L, 5L),
    official_score = 75
  )

  testthat::expect_equal(result$status, "ok")
  testthat::expect_equal(result$custom_score, 80)
  testthat::expect_equal(result$difference, 5)
  testthat::expect_equal(result$coverage$available, 5L)
  testthat::expect_false(result$coverage$renormalized)
})

testthat::test_that("weights reject invalid totals and values", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  invalid <- list(
    c(20L, 20L, 20L, 20L, 19L),
    c(20L, 20L, 20L, 20L, 21L),
    c(20.5, 20, 20, 20, 19.5),
    c(-1L, 26L, 25L, 25L, 25L),
    c(NA_integer_, 25L, 25L, 25L, 25L),
    c(Inf, 0, 0, 0, 0),
    c(20L, 20L, 20L, 20L),
    c("20", "20", "20", "20", "20")
  )

  for (weights in invalid) {
    result <- env$pillar_explorer_calculate(
      scores = rep(50, 5), weights = weights, official_score = 50
    )
    testthat::expect_equal(result$status, "invalid_weights")
    testthat::expect_true(is.na(result$custom_score))
  }
})

testthat::test_that("missing pillars renormalize available weights", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  result <- env$pillar_explorer_calculate(
    scores = c(60, NA, 80, NA, 100),
    weights = rep(20L, 5L),
    official_score = 80
  )

  testthat::expect_equal(result$status, "ok")
  testthat::expect_equal(result$custom_score, 80)
  testthat::expect_equal(result$difference, 0)
  testthat::expect_equal(result$coverage$available, 3L)
  testthat::expect_equal(result$coverage$missing, 2L)
  testthat::expect_true(result$coverage$renormalized)
  testthat::expect_equal(sum(result$effective_weights), 1)
})

testthat::test_that("zero effective weight and no scores are unavailable", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  zero_effective <- env$pillar_explorer_calculate(
    scores = c(NA, 50, NA, NA, NA),
    weights = c(100L, 0L, 0L, 0L, 0L),
    official_score = 50
  )
  no_scores <- env$pillar_explorer_calculate(
    scores = rep(NA_real_, 5),
    weights = rep(20L, 5L),
    official_score = 50
  )

  testthat::expect_equal(zero_effective$status, "unavailable")
  testthat::expect_equal(no_scores$status, "unavailable")
  testthat::expect_true(is.na(zero_effective$custom_score))
  testthat::expect_true(is.na(no_scores$custom_score))
})

testthat::test_that("missing official score remains unavailable", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  result <- env$pillar_explorer_calculate(
    scores = c(60, 70, 80, 90, 100),
    weights = rep(20L, 5L),
    official_score = NA_real_
  )

  testthat::expect_equal(result$status, "ok")
  testthat::expect_equal(result$custom_score, 80)
  testthat::expect_true(is.na(result$official_score))
  testthat::expect_true(is.na(result$difference))
})

testthat::test_that("pillar metrics expose change and weighted contribution", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  result <- env$pillar_explorer_pillar_metrics(
    scores = c(60, 70, 80, 90, 100),
    previous_scores = c(55, 72, 80, NA, 95),
    effective_weights = rep(0.2, 5)
  )

  testthat::expect_equal(result$change[1:3], c(5, -2, 0))
  testthat::expect_true(is.na(result$change[[4L]]))
  testthat::expect_equal(result$contribution[1:3], c(12, 14, 16))
  testthat::expect_equal(result$contribution[[5L]], 20)
})

testthat::test_that("pillar analysis supports correlations and cross-pillar data", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)

  index <- data.frame(
    country_code = c("AAA", "BBB", "CCC"),
    year = c(2024L, 2024L, 2024L),
    pillar_1_score = c(10, 20, 30), pillar_2_score = c(20, 30, 40),
    pillar_3_score = c(30, 20, 10), pillar_4_score = c(40, 50, 60),
    pillar_5_score = c(50, 60, 70), stringsAsFactors = FALSE
  )

  correlation <- env$pillar_explorer_correlation(index, 2024L)
  scatter <- env$pillar_explorer_scatter_data(
    index, 2024L, "pillar_1_score", "pillar_3_score"
  )

  testthat::expect_equal(dim(correlation), c(5L, 5L))
  testthat::expect_equal(correlation[1L, 2L], 1)
  testthat::expect_equal(nrow(scatter), 3L)
  testthat::expect_equal(scatter$x, c(10, 20, 30))
  testthat::expect_equal(scatter$y, c(30, 20, 10))
})