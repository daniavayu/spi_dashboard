testthat::test_that("app server accepts a fixture snapshot loader", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("spi_adapter.R", "spi_provider.R", "overview_data.R",
    "mod_overview.R", "country_explorer_data.R",
    "country_explorer_helpers.R", "country_profile_data.R",
    "country_profile_helpers.R", "country_profile_visualizations.R",
    "country_compare_helpers.R", "country_compare_data.R",
    "mod_country_explorer.R", "mod_country_compare.R",
    "mod_country_profile.R",
    "app_server.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  snapshot <- list(
    provider = "fixture",
    years = c(2023L, 2024L),
    index = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), score = c(70, 80),
      pillar_1_score = c(71, 81), stringsAsFactors = FALSE
    ),
    indicators = data.frame(),
    metadata = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L), region = c("Region A", "Region B"),
      income_group = c("HIC", "MIC"), stringsAsFactors = FALSE
    ),
    aggregates = data.frame(), operation_status = list()
  )

  fixture_server <- function(input, output, session) {
    env$app_server(
      input, output, session,
      snapshot_loader = function() snapshot
    )
  }

  shiny::testServer(
    fixture_server,
    {
      testthat::expect_equal(output$kpi_years, "2024")
      session$setInputs(main_nav = "Country Profile")
      testthat::expect_true(isTRUE(session$input$main_nav == "Country Profile"))
    }
  )
})
