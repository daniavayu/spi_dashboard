testthat::test_that("Profile selects the latest valid metric year", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  data <- data.frame(
    country_code = c("AAA", "AAA", "AAA"),
    country_name = "Alpha",
    year = c(2021L, 2022L, 2023L),
    score = c(60, NA_real_, 75),
    stringsAsFactors = FALSE
  )

  result <- spi_profile_select_year(data, "AAA")

  testthat::expect_equal(result$selected_year, 2023L)
  testthat::expect_equal(result$data$year, 2023L)
  testthat::expect_equal(result$available_years, c(2021L, 2023L))
})

testthat::test_that("Profile renders missing values without converting them", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  testthat::expect_equal(spi_profile_format_value(75), "75.0")
  testthat::expect_equal(spi_profile_format_value(NA_real_), "-")
})

testthat::test_that("Profile trend computes changes using valid observations", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  data <- data.frame(
    country_code = c("AAA", "AAA", "AAA"),
    year = c(2021L, 2022L, 2023L), score = c(60, NA_real_, 75)
  )
  result <- spi_profile_prepare_trend(data, "AAA")

  testthat::expect_equal(result$change_previous, c(NA_real_, 15))
  testthat::expect_equal(result$change_first, c(NA_real_, 15))
})

testthat::test_that("Profile dimensions order deterministic highest and lowest", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  dimensions <- data.frame(
    dimension_id = c("D2.1", "D1.1", "D3.1", "D4.1"),
    dimension_label = c("Second", "First", "Third", "Fourth"),
    year = 2024L,
    score = c(80, 80, 40, 10),
    coverage = c(1, 1, 1, 0.25),
    stringsAsFactors = FALSE
  )
  result <- spi_profile_prepare_dimension_extremes(
    dimensions, year = 2024L, coverage_threshold = 0.5
  )

  testthat::expect_equal(result$highest$dimension_id, c("D1.1", "D2.1"))
  testthat::expect_equal(result$lowest$dimension_id, "D3.1")
})

testthat::test_that("Profile benchmarks keep only the official overall source", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  benchmarks <- data.frame(
    group_code = c("WLD", "HIC", "WLD"),
    group_name = c("World", "High income", "World"),
    year = 2024L,
    source_id = c("SPI.INDEX", "SPI.INDEX", "SPI.PIL1"),
    score = c(60, 70, 90),
    stringsAsFactors = FALSE
  )
  result <- spi_profile_prepare_benchmarks(benchmarks, year = 2024L)

  testthat::expect_equal(result$status, "ok")
  testthat::expect_equal(result$data$source_id, c("SPI.INDEX", "SPI.INDEX"))
})

testthat::test_that("Profile context compares country with region and income group", {
  source(testthat::test_path("..", "..", "R", "country_profile_helpers.R"),
    local = TRUE
  )

  overall <- data.frame(
    country_code = "AAA", country_name = "Alpha", year = 2024L, score = 82
  )
  metadata <- data.frame(
    country_code = "AAA", country_name = "Alpha", year = 2024L,
    region = "Test region", income_group = "UMC"
  )
  benchmarks <- data.frame(
    group_code = c("TST", "UMC"),
    group_name = c("Test region", "Upper middle income"),
    year = 2024L, source_id = "SPI.INDEX", score = c(75, 68)
  )

  result <- spi_profile_prepare_context(
    overall, metadata, benchmarks, "AAA", 2024L
  )

  testthat::expect_equal(result$comparison, c("Region", "Income group"))
  testthat::expect_equal(result$difference, c(7, 14))
})
