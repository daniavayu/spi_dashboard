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
      group_code = "AFE", group_name = "Africa Eastern and Southern",
      year = 2024, source_id = "SPI.INDEX", score = 55
    )
  )

  testthat::expect_equal(env$overview_score_distribution(snapshot, 2024)$score, c(80, 60))
  testthat::expect_equal(env$overview_group_summary(snapshot, 2024)$score, 55)
})
