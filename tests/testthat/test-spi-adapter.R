testthat::test_that("index normalization uses stable names and preserves missing scores", {
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
  testthat::expect_equal(result$country_code, c("AAA", "BBB"))
  testthat::expect_equal(result$score, c(80, NA_real_))
})

testthat::test_that("country aliases use one canonical ISO3 code", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("CHI", "CHL", "AAA"),
    date = c(2024, 2024, 2024),
    country = c("Chile", "Chile", "Alpha"),
    `SPI.INDEX` = c(70, 71, 80),
    `SPI.INDEX.PIL1` = c(70, 71, 80),
    check.names = FALSE
  )

  result <- spi_normalize_index(raw, year = 2024)

  testthat::expect_equal(sum(result$country_code == "CHL"), 1L)
  testthat::expect_false("CHI" %in% result$country_code)
  testthat::expect_equal(result$score[result$country_code == "CHL"], 71)
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

testthat::test_that("dimension label normalization extracts a clean lookup", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  hierarchy <- list(
    dimensions = data.frame(
      pillar = c("1", "1"),
      dimension = c("1.1", "1.2"),
      dimension_name = c("Data use by national legislature", NA_character_),
      stringsAsFactors = FALSE
    )
  )

  result <- spi_normalize_dimension_labels(hierarchy)

  testthat::expect_equal(result$dimension_id, "1.1")
  testthat::expect_equal(result$dimension_label, "Data use by national legislature")
})

testthat::test_that("dimension label normalization tolerates missing or malformed hierarchies", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)

  testthat::expect_equal(nrow(spi_normalize_dimension_labels(NULL)), 0L)
  testthat::expect_equal(nrow(spi_normalize_dimension_labels(list())), 0L)
  testthat::expect_equal(
    nrow(spi_normalize_dimension_labels(list(dimensions = data.frame(bad = 1)))),
    0L
  )
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

testthat::test_that("index normalization retains direct pillar and dimension scores", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = "AAA",
    date = 2024,
    country = "Alpha",
    SPI.INDEX = 80,
    SPI.INDEX.PIL1 = 75,
    SPI.DIM1.1.INDEX = 72,
    check.names = FALSE
  )

  result <- spi_normalize_index(raw)

  testthat::expect_equal(result$score, 80)
  testthat::expect_equal(result$pillar_1_score, 75)
  testthat::expect_equal(result$dimension_1_1_score, 72)
})

testthat::test_that("indicator normalization exposes stable pillar and dimension fields", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = "AAA",
    date = 2024,
    country = "Alpha",
    SPI.D1.1.TEST = 70,
    RAW.D1.1.TEST = 7,
    check.names = FALSE
  )

  result <- spi_normalize_indicators(raw)

  testthat::expect_named(
    result,
    c(
      "indicator_id", "indicator_label", "pillar_id", "pillar_label",
      "dimension_id", "dimension_label", "country_code", "country_name",
      "year", "score", "raw_value"
    )
  )
  testthat::expect_equal(result$pillar_id, "D1")
  testthat::expect_equal(result$dimension_id, "D1.1")
})

testthat::test_that("indicator labels use provider indicator IDs", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  hierarchy <- list(
    indicators = data.frame(
      indicator = "3.2.1",
      indicator_id = "SPI.D3.2.HNGR",
      indicator_name = "Indicator 3.2.1: Hunger prevalence",
      stringsAsFactors = FALSE
    )
  )

  result <- spi_normalize_indicator_labels(hierarchy)

  testthat::expect_equal(result$indicator_id, "SPI.D3.2.HNGR")
  testthat::expect_equal(
    result$indicator_label,
    "Indicator 3.2.1: Hunger prevalence"
  )
})

testthat::test_that("reconciliation matches indicators by pillar and suffix", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  labels <- data.frame(
    indicator_id = c("SPI.D3.1.HNGR", "SPI.D3.1.HLTH", "SPI.D4.1.POPU"),
    indicator_label = c("GOAL 2: Zero Hunger", "GOAL 3: Health", "Population census"),
    stringsAsFactors = FALSE
  )
  data_ids <- c(
    "SPI.D3.1.HNGR", "SPI.D3.2.HNGR", "SPI.D3.3.HLTH",
    "SPI.D4.1.1.POPU", "SPI.D3.NA"
  )

  result <- spi_reconcile_indicator_labels(data_ids, labels)

  testthat::expect_equal(
    result$indicator_label[result$indicator_id == "SPI.D3.2.HNGR"],
    "GOAL 2: Zero Hunger"
  )
  testthat::expect_equal(
    result$indicator_label[result$indicator_id == "SPI.D3.3.HLTH"],
    "GOAL 3: Health"
  )
  testthat::expect_equal(
    result$indicator_label[result$indicator_id == "SPI.D4.1.1.POPU"],
    "Population census"
  )
  testthat::expect_false("SPI.D3.NA" %in% result$indicator_id)
})

testthat::test_that("indicator normalization scales across multiple indicator columns", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  raw <- data.frame(
    iso3c = c("AAA", "BBB"),
    date = c(2024, 2024),
    country = c("Alpha", "Beta"),
    SPI.D1.1.TEST = c(70, 80),
    RAW.D1.1.TEST = c(7, 8),
    SPI.D2.1.TEST = c(50, 60),
    check.names = FALSE
  )

  result <- spi_normalize_indicators(raw)

  testthat::expect_equal(nrow(result), 4L)
  testthat::expect_equal(length(unique(result$indicator_id)), 2L)
  testthat::expect_equal(
    result$score[result$indicator_id == "SPI.D2.1.TEST"],
    c(50, 60)
  )
})
