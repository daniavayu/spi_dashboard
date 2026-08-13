testthat::test_that("Explorer base joins metadata by country and year", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "AAA", "BBB"),
      country_name = c("Alpha", "Alpha", "Beta"),
      year = c(2023L, 2024L, 2024L),
      score = c(60, 70, 80),
      pillar_1_score = c(61, 71, 81),
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("Region A", "Region B"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    )
  )

  result <- spi_explorer_base(snapshot)

  testthat::expect_equal(nrow(result$data), 3L)
  testthat::expect_equal(result$data$region[result$data$country_code == "AAA" &
    result$data$year == 2023L], NA_character_)
  testthat::expect_equal(result$status$metadata, "ok")
})

testthat::test_that("metadata duplicate conflicts are explicit and deterministic", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)

  metadata <- data.frame(
    country_code = c("AAA", "AAA", "AAA"),
    country_name = c("Alpha", "Alpha", "Alpha"),
    year = c(2024L, 2024L, 2024L),
    region = c("Region A", "Region A", "Region B"),
    income_group = c("HIC", "HIC", "HIC"),
    stringsAsFactors = FALSE
  )

  result <- spi_explorer_metadata_deduplicate(metadata)

  testthat::expect_equal(nrow(result$data), 1L)
  testthat::expect_true(is.na(result$data$region))
  testthat::expect_equal(result$status$conflict_count, 1L)
})

testthat::test_that("identical metadata duplicates keep the stable first row", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)

  metadata <- data.frame(
    country_code = c("AAA", "AAA"), country_name = c("Alpha", "Alpha"),
    year = c(2024L, 2024L), region = c("Region A", "Region A"),
    income_group = c("HIC", "HIC"), stringsAsFactors = FALSE
  )

  result <- spi_explorer_metadata_deduplicate(metadata)

  testthat::expect_equal(nrow(result$data), 1L)
  testthat::expect_equal(result$data$region, "Region A")
  testthat::expect_equal(result$status$conflict_count, 0L)
})
