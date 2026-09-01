testthat::test_that("comparison prepared data preserves missing pillar cells", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  index <- data.frame(
    country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
    year = c(2024L, 2024L), score = c(80, 70),
    pillar_1_score = c(81, NA_real_), pillar_2_score = c(75, 72),
    pillar_3_score = c(70, 68), pillar_4_score = c(77, 69),
    pillar_5_score = c(82, 71)
  )

  result <- env$spi_compare_pillars(index, c("AAA", "BBB"), 2024L)

  testthat::expect_equal(nrow(result$data), 10L)
  testthat::expect_true(is.na(result$data$score[result$data$country_code == "BBB" & result$data$pillar_id == "1"]))
  testthat::expect_equal(result$status, "partial")
})

testthat::test_that("comparison trends use all available years and selected metric", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  index <- data.frame(
    country_code = c("AAA", "AAA", "BBB"), country_name = c("Alpha", "Alpha", "Beta"),
    year = c(2020L, 2024L, 2022L), score = c(50, 60, 55),
    pillar_3_score = c(40, 45, 42)
  )
  result <- env$spi_compare_trends(index, c("AAA", "BBB"), "pillar_3")

  testthat::expect_equal(result$data$year, c(2020L, 2022L, 2024L, 2020L, 2022L, 2024L))
  testthat::expect_equal(result$data$score, c(40, NA_real_, 45, NA_real_, 42, NA_real_))
  testthat::expect_equal(result$status, "partial")
})

testthat::test_that("comparison duplicate conflicts become missing and partial", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  data <- data.frame(
    country_code = c("AAA", "AAA"), country_name = c("Alpha", "Alpha"),
    year = c(2024L, 2024L), pillar_id = c("1", "1"),
    dimension_id = c("1.1", "1.1"), score = c(70, 80)
  )
  result <- env$spi_compare_collapse_duplicates(data)

  testthat::expect_true(is.na(result$data$score))
  testthat::expect_equal(result$status, "partial")
  testthat::expect_equal(result$coverage$conflicts, 1L)
})
