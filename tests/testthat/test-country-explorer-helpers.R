testthat::test_that("Explorer filters a selected country and preserves the reset state", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "AAA", "BBB", "CCC"),
      country_name = c("Alpha", "Alpha", "Beta", "Gamma"),
      year = c(2023L, 2024L, 2024L, 2024L),
      score = c(60, 70, 80, 85),
      pillar_1_score = c(61, 71, 81, 86),
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB", "CCC"),
      country_name = c("Alpha", "Beta", "Gamma"),
      year = c(2024L, 2024L, 2024L),
      region = c("Region A", "Region B", "Region A"),
      income_group = c("HIC", "MIC", "HIC"),
      stringsAsFactors = FALSE
    ),
    indicators = data.frame(),
    operation_status = list()
  )

  filtered <- spi_explorer_filter(snapshot, year = 2024L, country_search = c("BBB", "beta"))
  testthat::expect_equal(filtered$data$country_code, "BBB")

  accented <- spi_explorer_filter(snapshot, year = 2024L, country_search = "curazao")
  testthat::expect_equal(accented$data$country_code, character(0))

  fuzzy <- data.frame(
    country_code = c("CUW", "USA"),
    country_name = c("Curaçao", "United States"),
    year = c(2024L, 2024L),
    score = c(50, 60),
    stringsAsFactors = FALSE
  )
  result_fuzzy <- spi_explorer_filter(
    list(
      index = fuzzy,
      metadata = data.frame(
        country_code = c("CUW", "USA"),
        country_name = c("Curaçao", "United States"),
        year = c(2024L, 2024L),
        region = c("Americas", "Americas"),
        income_group = c("HIC", "HIC"),
        stringsAsFactors = FALSE
      ),
      indicators = data.frame(),
      operation_status = list()
    ),
    year = 2024L,
    country_search = "curazao"
  )
  testthat::expect_equal(result_fuzzy$data$country_code, "CUW")

  result <- spi_explorer_filter(snapshot, year = 2024L, region = "Region A")
  testthat::expect_equal(sort(result$data$country_code), c("AAA", "CCC"))
})

testthat::test_that("Explorer filters and resets from an all-years snapshot", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "AAA", "BBB"),
      country_name = c("Alpha", "Alpha", "Beta"),
      year = c(2023L, 2024L, 2024L), score = c(60, 70, 80),
      pillar_1_score = c(61, 71, 81), stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("Region A", "Region B"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    ),
    indicators = data.frame(),
    operation_status = list()
  )

  result <- spi_explorer_filter(
    snapshot, year = 2024L, region = "Region A", country_search = "alp"
  )

  testthat::expect_equal(result$data$country_code, "AAA")
  testthat::expect_equal(result$available_years, c(2023L, 2024L))

  reset <- spi_explorer_filter(snapshot)
  testthat::expect_equal(reset$selected_year, 2024L)
  testthat::expect_equal(nrow(reset$data), 2L)
})

testthat::test_that("Explorer views retain overall SPI and missing values", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), score = c(70, 80),
      pillar_1_score = c(NA, 81), dimension_1_1_score = c(72, 82),
      stringsAsFactors = FALSE
    ),
    indicators = data.frame(
      indicator_id = c("SPI.D1.1.TEST", "SPI.D1.1.TEST"),
      indicator_label = c("SPI.D1.1.TEST", "SPI.D1.1.TEST"),
      pillar_id = c("D1", "D1"), pillar_label = c("D1", "D1"),
      dimension_id = c("D1.1", "D1.1"), dimension_label = c("D1.1", "D1.1"),
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), score = c(71, NA), raw_value = c(7, 8),
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("Region A", "Region B"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    ),
    operation_status = list()
  )

  pillars <- spi_explorer_view(snapshot, view = "pillars", year = 2024L)
  indicators <- spi_explorer_view(
    snapshot, view = "indicators", indicator_id = "SPI.D1.1.TEST", year = 2024L
  )

  testthat::expect_true(all(c("overall_spi", "metric_score") %in% names(pillars$data)))
  testthat::expect_true(is.na(pillars$data$metric_score[pillars$data$country_code == "AAA"]))
  testthat::expect_equal(indicators$data$overall_spi, c(70, 80))
  testthat::expect_equal(indicators$data$metric_score, c(71, NA_real_))
})

testthat::test_that("Explorer dimensions widen to one row per country-year", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "AAA", "AAA"),
      country_name = c("Alpha", "Alpha", "Alpha"),
      year = c(2021L, 2023L, 2024L),
      score = c(40, 60, 70),
      pillar_1_score = c(41.1111, 65.1111, 72.1111),
      dimension_1_1_score = c(61.1111, 71.1111, 81.1111),
      dimension_1_2_score = c(62.2222, 72.2222, 82.2222),
      stringsAsFactors = FALSE
    ),
    indicators = data.frame(),
    metadata = data.frame(
      country_code = "AAA",
      country_name = "Alpha",
      year = 2024L,
      region = "Region A",
      income_group = "HIC",
      stringsAsFactors = FALSE
    ),
    operation_status = list()
  )

  pillars <- spi_explorer_view(snapshot, view = "pillars", year = 2024L)
  wide <- spi_explorer_widen_metrics(pillars$data)

  testthat::expect_equal(nrow(wide), 1L)
  testthat::expect_equal(wide$change_previous, 10)
  testthat::expect_equal(wide$change_first, 30)
  testthat::expect_equal(wide[["Pillar 1"]], 72.1111)
})

testthat::test_that("Explorer indicators support all and multiple selections", {
  source(testthat::test_path("..", "..", "R", "country_explorer_data.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), score = c(70, 80), stringsAsFactors = FALSE
    ),
    indicators = data.frame(
      indicator_id = c("I1", "I1", "I2", "I2"),
      indicator_label = c("Indicator one", "Indicator one", "Indicator two", "Indicator two"),
      country_code = c("AAA", "BBB", "AAA", "BBB"),
      country_name = c("Alpha", "Beta", "Alpha", "Beta"),
      year = rep(2024L, 4), score = c(0.7, 0.8, 0.4, 0.5),
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("R1", "R2"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    ),
    operation_status = list()
  )

  all_rows <- spi_explorer_view(
    snapshot, view = "indicators", indicator_id = "__all__", year = 2024L
  )$data
  selected_rows <- spi_explorer_view(
    snapshot, view = "indicators", indicator_id = c("I1", "I2"),
    year = 2024L
  )$data

  testthat::expect_equal(length(unique(all_rows$metric_id)), 2L)
  testthat::expect_equal(length(unique(selected_rows$metric_id)), 2L)
  wide <- spi_explorer_widen_metrics(selected_rows)
  testthat::expect_true(all(c("Indicator one", "Indicator two") %in% names(wide)))
})

testthat::test_that("Explorer summary reports mean median and standard deviation", {
  source(testthat::test_path("..", "..", "R", "country_explorer_helpers.R"), local = TRUE)

  result <- spi_explorer_summary(data.frame(metric_score = c(60, 70, 80)))

  testthat::expect_equal(result$average, 70)
  testthat::expect_equal(result$median, 70)
  testthat::expect_equal(result$standard_deviation, 10)
})
