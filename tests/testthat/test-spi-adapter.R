testthat::test_that("index normalization uses stable names and excludes missing scores", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("AAA", "BBB", "CCC"),
    date = c(2024, 2024, 2023),
    country = c("Alpha", "Beta", "Gamma"),
    `SPI.INDEX` = c(80, NA, 70),
    check.names = FALSE
  )

  result <- spi_normalize_index(raw, year = 2024)

  testthat::expect_named(
    result,
    c("country_code", "country_name", "year", "score")
  )
  testthat::expect_equal(result$country_code, "AAA")
  testthat::expect_equal(result$score, 80)
})

testthat::test_that("indicator normalization preserves partial rows", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("AAA", "AAA"),
    date = c(2024, 2024),
    country = c("Alpha", "Alpha"),
    `SPI.D1.1.TEST` = c(70, NA),
    `RAW.D1.1.TEST` = c(7, 8),
    check.names = FALSE
  )

  result <- spi_normalize_indicators(raw)

  testthat::expect_true(all(c("indicator_id", "score", "raw_value") %in% names(result)))
  testthat::expect_equal(nrow(result), 2)
  testthat::expect_equal(result$score[[2]], NA_real_)
  testthat::expect_equal(result$raw_value[[2]], 8)
})

testthat::test_that("aggregate normalization retains official source rows", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("AFE", "HIC", "AAA"),
    date = c(2024, 2024, 2024),
    country = c("Africa Eastern and Southern", "High income", "Alpha"),
    source_id = c("SPI.INDEX", "SPI.INDEX", "SPI.INDEX"),
    value = c(55, 75, 80),
    check.names = FALSE
  )

  result <- spi_normalize_aggregates(raw, year = 2024)

  testthat::expect_equal(result$group_code, c("AFE", "HIC"))
  testthat::expect_equal(result$score, c(55, 75))
})

testthat::test_that("aggregate data is normalized to the application schema", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "spi_adapter.R"), envir = env)

  raw <- data.frame(
    iso3c = "WLD",
    date = 2024,
    country = "World",
    source_id = "SPI.INDEX",
    value = 65,
    stringsAsFactors = FALSE
  )
  result <- env$spi_normalize_aggregates(raw)

  testthat::expect_named(
    result,
    c("group_code", "group_name", "year", "source_id", "score")
  )
  testthat::expect_equal(result$score, 65)
})

testthat::test_that("available years require a valid overall SPI score", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  index <- data.frame(
    year = c(2004L, 2016L, 2024L),
    score = c(NA_real_, 60, 75)
  )

  testthat::expect_equal(
    spi_available_years(index),
    c(2016L, 2024L)
  )
})
