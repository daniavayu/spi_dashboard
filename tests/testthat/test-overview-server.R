testthat::test_that("overview server uses one shared selected year", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("overview_data.R", "mod_overview.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  snapshot <- list(
    provider = "fixture",
    years = c(2023L, 2024L),
    index = data.frame(
      country_code = c("AAA", "BBB"),
      country_name = c("Alpha", "Beta"),
      year = c(2024L, 2023L),
      score = c(80, 70)
    ),
    aggregates = data.frame(
      group_code = "AFE",
      group_name = "Africa Eastern and Southern",
      year = 2024L,
      source_id = "SPI.INDEX",
      score = 55
    )
  )

  shiny::testServer(
    env$overview_server,
    args = list(snapshot_loader = function() snapshot),
    {
      session$setInputs(year = 2024)
      testthat::expect_equal(output$provider, "Data provider: fixture")
      testthat::expect_equal(output$selected_year, "2024")
    }
  )
})
