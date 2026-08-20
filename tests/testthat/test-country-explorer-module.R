testthat::test_that("Country Explorer module keeps its own year and view state", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("spi_adapter.R", "country_explorer_data.R",
    "country_explorer_helpers.R", "mod_country_explorer.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  snapshot <- list(
    provider = "fixture",
    index = data.frame(
      country_code = c("AAA", "AAA", "BBB", "BBB"),
      country_name = c("Alpha", "Alpha", "Beta", "Beta"),
      year = c(2023L, 2024L, 2023L, 2024L),
      score = c(60, 70, 75, 80),
      pillar_1_score = c(61, 71, 76, 81),
      stringsAsFactors = FALSE
    ),
    indicators = data.frame(
      indicator_id = c("SPI.D1.1.TEST", "SPI.D1.1.TEST"),
      indicator_label = c("SPI.D1.1.TEST", "SPI.D1.1.TEST"),
      pillar_id = c("D1", "D1"), pillar_label = c("D1", "D1"),
      dimension_id = c("D1.1", "D1.1"), dimension_label = c("D1.1", "D1.1"),
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), score = c(71, 81), raw_value = c(7, 8),
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("Region A", "Region B"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    ),
    operation_status = list()
  )

  shiny::testServer(
    env$country_explorer_server,
    args = list(snapshot_loader = function() snapshot),
    {
      testthat::expect_equal(output$explorer_selected_year, "2024")
      testthat::expect_equal(output$explorer_average, "76.00")
      session$setInputs(explorer_year = "2023")
      testthat::expect_equal(output$explorer_selected_year, "2023")
      session$setInputs(explorer_view = "indicators")
      testthat::expect_equal(output$explorer_selected_year, "2023")
    }
  )
})

testthat::test_that("Country Explorer renders an unavailable state without optional data", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("spi_adapter.R", "country_explorer_data.R",
    "country_explorer_helpers.R", "mod_country_explorer.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  snapshot <- list(
    provider = "fixture",
    index = data.frame(
      country_code = "AAA", country_name = "Alpha", year = 2024L,
      score = 70, stringsAsFactors = FALSE
    ),
    indicators = data.frame(), metadata = data.frame(),
    operation_status = list(indicators = list(status = "unavailable"))
  )

  shiny::testServer(
    env$country_explorer_server,
    args = list(snapshot_loader = function() snapshot),
    {
      testthat::expect_equal(output$explorer_selected_year, "2024")
      testthat::expect_equal(output$explorer_status,
        "No data available for the selected filters")
    }
  )
})

testthat::test_that("inactive Country Explorer does not load its provider", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("spi_adapter.R", "country_explorer_data.R",
    "country_explorer_helpers.R", "mod_country_explorer.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  calls <- 0L
  snapshot <- list(
    provider = "fixture",
    index = data.frame(
      country_code = "AAA", country_name = "Alpha", year = 2024L,
      score = 70, stringsAsFactors = FALSE
    ),
    indicators = data.frame(), metadata = data.frame(),
    operation_status = list()
  )

  shiny::testServer(
    env$country_explorer_server,
    args = list(
      snapshot_loader = function() {
        calls <<- calls + 1L
        snapshot
      },
      active = function() FALSE
    ),
    {
      testthat::expect_equal(calls, 0L)
    }
  )
})
