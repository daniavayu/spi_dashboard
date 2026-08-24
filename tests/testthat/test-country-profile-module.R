testthat::test_that("Country Profile owns direct country and year state", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("country_profile_helpers.R", "country_profile_visualizations.R",
    "mod_country_profile.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  profile <- list(
    countries = data.frame(
      country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta")
    ),
    overall = list(
      data = data.frame(
        country_code = c("AAA", "AAA", "BBB"),
        country_name = c("Alpha", "Alpha", "Beta"),
        year = c(2023L, 2024L, 2024L), score = c(60, 70, 80)
      ), status = "ok", message = NULL, coverage = list(), source = "fixture"
    ),
    pillars = list(data = data.frame(), status = "empty"),
    dimensions = list(data = data.frame(), status = "empty"),
    indicators = list(data = data.frame(), status = "unavailable"),
    benchmarks = list(data = data.frame(), status = "unavailable")
  )

  shiny::testServer(
    env$country_profile_server,
    args = list(profile_loader = function() profile),
    {
      testthat::expect_equal(output$profile_selected_country, "AAA")
      testthat::expect_equal(output$profile_selected_year, "2024")
      testthat::expect_equal(output$profile_score, "70.0")
      session$setInputs(profile_country = "BBB")
      testthat::expect_equal(output$profile_selected_country, "BBB")
      testthat::expect_equal(output$profile_score, "80.0")
    }
  )
})

testthat::test_that("Country Profile keeps section failures independent", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  for (file in c("country_profile_helpers.R", "country_profile_visualizations.R",
    "mod_country_profile.R")) {
    sys.source(file.path(root, "R", file), envir = env)
  }

  profile <- list(
    countries = data.frame(country_code = "AAA", country_name = "Alpha"),
    overall = list(
      data = data.frame(country_code = "AAA", country_name = "Alpha",
        year = 2024L, score = 70), status = "ok"
    ),
    pillars = list(data = data.frame(), status = "error",
      message = "Pillars failed"),
    dimensions = list(data = data.frame(), status = "empty"),
    indicators = list(data = data.frame(), status = "unavailable"),
    benchmarks = list(data = data.frame(), status = "empty")
  )

  shiny::testServer(
    env$country_profile_server,
    args = list(profile_loader = function() profile),
    {
      testthat::expect_equal(output$profile_score, "70.0")
      testthat::expect_equal(output$profile_pillars_status, "Pillars failed")
      testthat::expect_equal(output$profile_indicators_status, "unavailable")
    }
  )
})
