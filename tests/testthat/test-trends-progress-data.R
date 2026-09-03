testthat::test_that("Trends deduplicates repeated group labels across official and metadata sources", {
  source(testthat::test_path("..", "..", "R", "trends_progress_data.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(),
    metadata = data.frame(
      country_code = c("AAA", "BBB", "CCC"),
      region = c("North", "North", "South"),
      income_group = c("Upper middle income", "Upper middle income", "Low income"),
      stringsAsFactors = FALSE
    ),
    aggregates = data.frame(
      group_code = c("Upper middle income", "Low income"),
      group_name = c("Upper middle income", "Low income"),
      year = c(2023L, 2023L),
      source_id = c("SPI.INDEX", "SPI.INDEX"),
      score = c(66, 42),
      stringsAsFactors = FALSE
    )
  )

  groups <- trends_group_catalog(snapshot)
  testthat::expect_equal(anyDuplicated(groups$code), 0L)
  testthat::expect_true(all(c("Upper middle income", "Low income") %in% groups$code))
})

testthat::test_that("Trends exposes metrics, years, groups, and period changes", {
  source(testthat::test_path("..", "..", "R", "trends_progress_data.R"), local = TRUE)

  index <- data.frame(
    country_code = c("AAA", "AAA", "BBB", "BBB", "CCC", "CCC"),
    country_name = c("Alpha", "Alpha", "Beta", "Beta", "Gamma", "Gamma"),
    year = c(2022L, 2023L, 2022L, 2023L, 2022L, 2023L),
    score = c(60, 65, 70, 68, 80, 85),
    pillar_1_score = c(61, 66, 71, 69, 81, 86),
    stringsAsFactors = FALSE
  )
  metadata <- data.frame(
    country_code = c("AAA", "BBB", "CCC"),
    country_name = c("Alpha", "Beta", "Gamma"),
    year = c(2023L, 2023L, 2023L),
    region = c("North", "North", "South"),
    region_code = c("NOR", "NOR", "SOU"),
    income_group = c("HIC", "MIC", "LIC"),
    stringsAsFactors = FALSE
  )
  aggregates <- data.frame(
    group_code = c("NOR", "SOU", "CUSTOM"),
    group_name = c("North", "South", "Official custom aggregate"),
    year = c(2022L, 2022L, 2022L),
    source_id = c("region", "region", "new_source"),
    score = c(65, 80, 74),
    stringsAsFactors = FALSE
  )
  snapshot <- list(index = index, metadata = metadata, aggregates = aggregates)

  testthat::expect_setequal(trends_metric_catalog(index)$id, c("overall", "pillar_1"))
  testthat::expect_equal(trends_available_years(snapshot), c(2022L, 2023L))
  groups <- trends_group_catalog(snapshot)
  testthat::expect_true(all(c("NOR", "SOU", "CUSTOM") %in% groups$code))

  changes <- trends_period_changes(index, "score", 2022L, 2023L)
  testthat::expect_equal(changes$change, c(5, 5, -2))
  stability <- trends_pillar_stability_summary(index, trends_metric_catalog(index), 2022L, 2023L)
  testthat::expect_equal(stability$label, "Pillar 1")
  testthat::expect_false(is.na(stability$value))
})

testthat::test_that("official group trends select the requested aggregate metric", {
  source(testthat::test_path("..", "..", "R", "trends_progress_data.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(),
    metadata = data.frame(),
    aggregates = data.frame(
      group_code = rep("AFE", 6L),
      group_name = rep("Africa Eastern and Southern", 6L),
      year = rep(c(2016L, 2017L), 3L),
      source_id = rep(c("SPI.INDEX", "SPI.INDEX.PIL1", "SPI.D1.1.SCORE"), each = 2L),
      score = c(55, 57, 60, 62, 10, 20),
      stringsAsFactors = FALSE
    )
  )

  overall <- trends_group_annual_summary(snapshot, "score", "AFE")
  pillar <- trends_group_annual_summary(snapshot, "pillar_1_score", "AFE")

  testthat::expect_equal(overall$median, c(55, 57))
  testthat::expect_equal(pillar$median, c(60, 62))
})

testthat::test_that("Trends enforces minimum observations and preserves NA", {
  source(testthat::test_path("..", "..", "R", "trends_progress_data.R"), local = TRUE)

  index <- data.frame(
    country_code = c("AAA", "AAA", "BBB"),
    year = c(2022L, 2023L, 2023L),
    score = c(NA_real_, 65, 70),
    pillar_1_score = c(1, 2, 3),
    pillar_2_score = c(2, 3, NA_real_),
    stringsAsFactors = FALSE
  )
  association <- trends_pillar_associations(index, c("pillar_1_score", "pillar_2_score"))
  testthat::expect_true(is.na(association$correlation[[1L]]))
  testthat::expect_equal(association$status[[1L]], "insufficient_data")
  stability <- trends_pillar_stability(index, "pillar_1_score", 2022L, 2023L)
  testthat::expect_equal(stability$status, "insufficient_data")
})
