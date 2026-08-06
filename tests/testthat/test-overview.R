testthat::test_that("overview keeps only valid countries for the selected year", {
  source(normalizePath(testthat::test_path("..", "..", "R", "overview_data.R")), local = TRUE)
  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "BBB", "AAA"),
      country_name = c("Alpha", "Beta", "Alpha"),
      year = c(2024, 2024, 2023),
      score = c(80, NA, 75)
    )
  )

  result <- overview_index_for_year(snapshot, 2024)

  testthat::expect_equal(result$country_code, "AAA")
  testthat::expect_equal(result$score, 80)
})

testthat::test_that("overview preserves limited aggregate observations", {
  source(normalizePath(testthat::test_path("..", "..", "R", "overview_data.R")), local = TRUE)
  snapshot <- list(
    aggregates = data.frame(
      group_code = c("AFE", "HIC"),
      group_name = c("Africa Eastern and Southern", "High income"),
      year = c(2024, 2023),
      source_id = c("SPI.INDEX", "SPI.INDEX"),
      score = c(55, 75)
    )
  )

  result <- overview_aggregate_for_year(snapshot, 2024)

  testthat::expect_equal(nrow(result), 1)
  testthat::expect_equal(result$group_code, "AFE")
})
