testthat::test_that("overview summaries use normalized index and official aggregates", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("overview_data.R", "overview_summary.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }
  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024, 2024), score = c(80, 60)
    ),
    aggregates = data.frame(
      group_code = c("EAP", "HIC", "LIC"),
      group_name = c(
        "East Asia & Pacific", "High income", "Low income"
      ),
      year = c(2024, 2024, 2024),
      source_id = c("SPI.INDEX", "SPI.INDEX", "SPI.INDEX"),
      score = c(55, 75, 35)
    ),
    income_data = data.frame(
      country_code = c("AAA", "BBB", "CCC"),
      country_name = c("Alpha", "Beta", "Gamma"),
      year = c(2024, 2024, 2024),
      income_group = c("HIC", "LIC", "HIC"),
      score = c(80, 60, 70)
    )
  )

  testthat::expect_equal(env$overview_score_distribution(snapshot, 2024)$score, c(80, 60))
  testthat::expect_equal(
    env$overview_region_summary(snapshot, 2024)$group_code,
    "EAP"
  )
  testthat::expect_equal(
    env$overview_income_group_summary(snapshot, 2024)$group_code,
    c("HIC", "LIC")
  )
  testthat::expect_equal(
    env$overview_income_group_summary(snapshot, 2024)$group_name,
    c("High income", "Low income")
  )
  testthat::expect_equal(
    env$overview_income_group_summary(snapshot, 2024)$score,
    c(75, 60)
  )
  empty_summary <- env$overview_income_group_summary(snapshot, 2030)
  testthat::expect_equal(nrow(empty_summary), 0L)
})

testthat::test_that("overview calculates income variation with IQR", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "overview_summary.R"), envir = env)
  snapshot <- list(
    income_data = data.frame(
      country_code = c("A", "B", "C", "D"),
      income_group = c("HIC", "HIC", "LIC", "LIC"),
      year = rep(2024L, 4),
      score = c(60, 80, 20, 40)
    )
  )

  result <- env$overview_income_group_variation(snapshot, 2024)

  testthat::expect_equal(result$group_code, c("HIC", "LIC"))
  testthat::expect_equal(
    result$group_name,
    c("High income", "Low income")
  )
  testthat::expect_equal(result$q25, c(65, 25))
  testthat::expect_equal(result$q75, c(75, 35))
})

testthat::test_that("overview calculates median country improvement", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "overview_summary.R"), envir = env)
  snapshot <- list(
    index = data.frame(
      country_code = c("A", "B", "C", "A", "B", "D"),
      year = c(2016L, 2016L, 2016L, 2024L, 2024L, 2024L),
      score = c(50, 70, 30, 60, 80, 90)
    )
  )

  result <- env$overview_median_improvement(snapshot)

  testthat::expect_equal(result, 10)
})
