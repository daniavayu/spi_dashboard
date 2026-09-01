testthat::test_that("profile overall preserves country-year rows with missing scores", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  raw <- data.frame(
    iso3c = c("AAA", "AAA"),
    country = c("Alpha", "Alpha"),
    date = c(2023L, 2024L),
    `SPI.INDEX` = c(65, NA_real_),
    `SPI.INDEX.PIL1` = c(70, 72),
    check.names = FALSE
  )

  result <- spi_profile_prepare_overall(raw, country_code = "AAA")

  testthat::expect_named(
    result,
    c("data", "status", "message", "coverage", "source")
  )
  testthat::expect_equal(result$data$year, c(2023L, 2024L))
  testthat::expect_true(is.na(result$data$score[[2L]]))
  testthat::expect_equal(result$status, "ok")
})

testthat::test_that("profile overall deduplicates country-year rows deterministically", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  raw <- data.frame(
    iso3c = c("AAA", "AAA"),
    country = c("Alpha", "Alpha"),
    date = c(2024L, 2024L),
    `SPI.INDEX` = c(70, 71),
    check.names = FALSE
  )

  result <- spi_profile_prepare_overall(raw, country_code = "AAA")

  testthat::expect_equal(nrow(result$data), 1L)
  testthat::expect_equal(result$data$score, 70)
})

testthat::test_that("profile sections expose partial and unavailable states", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  partial <- spi_profile_section_result(
    data.frame(country_code = "AAA", year = 2024L, score = 70),
    requested_keys = data.frame(
      country_code = c("AAA", "AAA"), year = c(2023L, 2024L)
    ),
    source = "fixture"
  )
  unavailable <- spi_profile_section_result(
    data.frame(), status = "unavailable", message = "Not supported",
    source = "spiR"
  )

  testthat::expect_equal(partial$status, "partial")
  testthat::expect_equal(partial$coverage$available, 1L)
  testthat::expect_equal(unavailable$status, "unavailable")
  testthat::expect_equal(unavailable$message, "Not supported")
})

testthat::test_that("profile overall preserves normalized pillar columns", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  normalized <- spi_profile_prepare_overall(data.frame(
    country_code = "AAA", country_name = "Alpha", year = 2024L,
    score = 70, pillar_1_score = 71, pillar_2_score = 72,
    pillar_3_score = 73, pillar_4_score = 74, pillar_5_score = 75
  ))

  testthat::expect_equal(
    names(normalized$data)[grepl("^pillar_[0-9]+_score$", names(normalized$data))],
    paste0("pillar_", 1:5, "_score")
  )
})

testthat::test_that("profile overall extracts dimension score columns from raw SPI columns", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  raw <- data.frame(
    iso3c = "AAA", country = "Alpha", date = 2024L,
    `SPI.INDEX` = 70, `SPI.DIM1.5.INDEX` = 55,
    check.names = FALSE
  )

  normalized <- spi_profile_prepare_overall(raw)

  testthat::expect_true("dimension_1_5_score" %in% names(normalized$data))
  testthat::expect_equal(normalized$data$dimension_1_5_score, 55)
})

testthat::test_that("profile dimension scores preserve the source scale", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  dimensions <- data.frame(
    country_code = "AAA", country_name = "Alpha", year = 2024L,
    dimension_1_1_score = 0.7, stringsAsFactors = FALSE
  )

  result <- spi_profile_metric_rows(
    dimensions, "dimension_1_1_score", "dimension_", "Dimension"
  )

  testthat::expect_equal(result$score, 0.7)
})

testthat::test_that("profile dimension missing scores do not become negative", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"), local = TRUE)

  dimensions <- data.frame(
    country_code = "AAA", country_name = "Alpha", year = 2024L,
    dimension_1_1_score = -0.99, stringsAsFactors = FALSE
  )

  result <- spi_profile_metric_rows(
    dimensions, "dimension_1_1_score", "dimension_", "Dimension"
  )

  testthat::expect_true(is.na(result$score))
})

testthat::test_that("dimension names resolve via the metadata lookup with a safe fallback", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  lookup <- data.frame(
    dimension_id = "1.5",
    dimension_label = "Data use by international organisations",
    stringsAsFactors = FALSE
  )

  resolved <- spi_profile_dimension_names(
    c("1.5", "2.1"), c("Dimension 1.5", "Dimension 2.1"), lookup
  )

  testthat::expect_equal(resolved, c(
    "Data use by international organisations", "Dimension 2.1"
  ))
  testthat::expect_equal(
    spi_profile_dimension_names("1.5", "Dimension 1.5", data.frame()),
    "Dimension 1.5"
  )
})

testthat::test_that("sections from snapshot label dimensions with their metadata name", {
  source(testthat::test_path("..", "..", "R", "country_profile_data.R"),
    local = TRUE
  )

  snapshot <- list(
    provider = "fixture",
    index = data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024L,
      `SPI.INDEX` = 70, `SPI.DIM1.5.INDEX` = 55,
      check.names = FALSE
    ),
    indicators = data.frame(),
    aggregates = data.frame(),
    dimension_labels = data.frame(
      dimension_id = "1.5",
      dimension_label = "Data use by international organisations",
      stringsAsFactors = FALSE
    ),
    operation_status = list()
  )

  sections <- spi_profile_sections_from_snapshot(snapshot)

  testthat::expect_equal(
    sections$dimensions$data$dimension_label,
    "Data use by international organisations"
  )
})

