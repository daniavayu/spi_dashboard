testthat::test_that("comparison index preserves keyed rows with missing overall scores", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("AAA", "BBB"),
    date = c(2024, 2024),
    country = c("Alpha", "Beta"),
    `SPI.INDEX` = c(80, NA_real_),
    check.names = FALSE
  )

  result <- spi_normalize_index(raw, year = 2024)

  testthat::expect_equal(result$country_code, c("AAA", "BBB"))
  testthat::expect_equal(result$score, c(80, NA_real_))
})

testthat::test_that("comparison trends begin at each country's first valid score", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  index <- data.frame(
    country_code = c("ABW", "ABW", "ABW", "AAA", "AAA", "AAA"),
    country_name = c("Aruba", "Aruba", "Aruba", "Alpha", "Alpha", "Alpha"),
    year = c(2022L, 2023L, 2024L, 2022L, 2023L, 2024L),
    score = c(NA_real_, NA_real_, 40, 60, 61, 62),
    stringsAsFactors = FALSE
  )

  result <- env$spi_compare_trends(index, c("ABW", "AAA"))$data
  aruba <- result[result$country_code == "ABW", , drop = FALSE]

  testthat::expect_equal(aruba$year, 2024L)
  testthat::expect_equal(aruba$score, 40)
  testthat::expect_equal(result[result$country_code == "AAA", "year"], 2022:2024)
})

testthat::test_that("comparison dimensions are reshaped from normalized index columns", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "spi_adapter.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  raw <- data.frame(
    iso3c = "AAA",
    date = 2024,
    country = "Alpha",
    `SPI.INDEX` = 80,
    `SPI.DIM1.1.INDEX` = 72,
    `SPI.DIM2.3.INDEX` = NA_real_,
    check.names = FALSE
  )

  index <- env$spi_normalize_index(raw)
  result <- env$spi_compare_dimensions(index, data.frame(
    dimension_id = "1.1", dimension_label = "Dimension one"
  ))

  testthat::expect_named(
    result,
    c("country_code", "country_name", "year", "pillar_id",
      "dimension_id", "dimension_label", "score")
  )
  testthat::expect_equal(result$pillar_id, c("1", "2"))
  testthat::expect_equal(result$dimension_id, c("1.1", "2.3"))
  testthat::expect_equal(result$dimension_label, c("Dimension one", "2.3"))
  testthat::expect_equal(result$score, c(72, NA_real_))
})

testthat::test_that("dimension gaps rank differences and preserve missing scores", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)

  index <- data.frame(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"),
    year = c(2024, 2024),
    pillar_1_1_score = c(90, 80),
    dimension_1_1_score = c(90, 80),
    dimension_1_2_score = c(NA_real_, 50),
    stringsAsFactors = FALSE
  )

  result <- env$spi_compare_dimension_gaps(index, c("AAA", "BBB"), 2024)

  testthat::expect_equal(result$dimension, c("1.1", "1.2"))
  testthat::expect_equal(result$AAA, c(90, NA_real_))
  testthat::expect_equal(result$BBB, c(80, 50))
  testthat::expect_equal(result$gap, c(10, 0))
})
