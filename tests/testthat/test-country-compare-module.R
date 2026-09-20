testthat::test_that("Compare Countries UI exposes the selection handoff", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)
  sys.source(file.path(root, "R", "mod_country_compare.R"), envir = env)

  ui <- env$country_compare_ui("compare")
  html <- as.character(ui)

  testthat::expect_match(html, "Compare Countries")
  testthat::expect_match(html, "compare-compare_plot")
  testthat::expect_match(html, "compare-compare_clear")
})

testthat::test_that("Compare Countries displays an empty handoff state", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)
  sys.source(file.path(root, "R", "mod_country_compare.R"), envir = env)

  snapshot <- list(index = data.frame())
  selected <- shiny::reactiveVal(character())
  year <- shiny::reactiveVal(2024L)

  shiny::testServer(
    env$country_compare_server,
    args = list(
      snapshot_loader = function() snapshot,
      selected_countries = selected,
      selected_year = year
    ),
    {
      testthat::expect_equal(output$compare_selected, "None selected")
    }
  )
})

testthat::test_that("Compare Countries retries a handoff after lazy snapshot loading", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "country_compare_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "country_compare_data.R"), envir = env)
  sys.source(file.path(root, "R", "spi_adapter.R"), envir = env)
  sys.source(file.path(root, "R", "mod_country_compare.R"), envir = env)

  snapshot <- list(
    index = data.frame(
      country_code = c("AAA", "BBB"),
      country_name = c("Alpha", "Beta"),
      year = c(2024L, 2024L),
      score = c(60, 70),
      stringsAsFactors = FALSE
    ),
    dimension_labels = env$spi_empty_dimension_labels(),
    operation_status = list()
  )
  active <- shiny::reactiveVal(FALSE)
  handoff <- shiny::reactiveVal(c("AAA", "BBB"))

  shiny::testServer(
    env$country_compare_server,
    args = list(
      snapshot_loader = function() snapshot,
      handoff = handoff,
      active = active
    ),
    {
      testthat::expect_equal(output$compare_selected, "None selected")
      active(TRUE)
      session$flushReact()
      testthat::expect_equal(output$compare_selected, "AAA, BBB")
    }
  )
})