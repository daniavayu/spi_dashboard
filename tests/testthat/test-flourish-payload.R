testthat::test_that("Flourish payload is fixed to 2024 and uses required bindings", {
  root <- normalizePath(testthat::test_path("..", ".."))
  source(file.path(root, "R", "flourish_payload.R"), local = TRUE)
  index <- data.frame(
    country_code = c("AAA", "BBB", "CCC"),
    country_name = c("Alpha", "Beta", "Gamma"),
    year = c(2024, 2024, 2023),
    score = c(80, NA, 70)
  )

  result <- prepare_flourish_regions(index)

  testthat::expect_named(result, c("Economy", "SPI.INDEX"))
  testthat::expect_equal(result$Economy, "AAA")
  testthat::expect_equal(result$SPI.INDEX, 80)
})
