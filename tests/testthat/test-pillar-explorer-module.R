testthat::test_that("pillar explorer UI exposes weighting controls and outputs", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "mod_pillar_explorer.R"), envir = env)

  html <- as.character(env$pillar_explorer_ui("pillar"))

  testthat::expect_match(html, "Explore by Pillar")
  testthat::expect_match(html, "pillar-country")
  testthat::expect_match(html, "pillar-year")
  testthat::expect_match(html, "pillar-pillar_1_weight")
  testthat::expect_match(html, "pillar-pillar_5_weight")
  testthat::expect_match(html, "pillar-reset")
  testthat::expect_match(html, "pillar-pillar_1_change")
  testthat::expect_match(html, "pillar-pillar_5_contribution")
  testthat::expect_match(html, "pillar-correlation_plot")
  testthat::expect_match(html, "pillar-scatter_x")
  testthat::expect_match(html, "pillar-scatter_y")
  testthat::expect_match(html, "pillar-official_score")
  testthat::expect_match(html, "pillar-custom_score")
  testthat::expect_match(html, "pillar-difference")
})

testthat::test_that("pillar explorer loads lazily and calculates defaults", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "mod_pillar_explorer.R"), envir = env)

  snapshot <- list(
    index = data.frame(
      country_code = "AAA", country_name = "Alpha", year = 2024L,
      score = 75, pillar_1_score = 60, pillar_2_score = 70,
      pillar_3_score = 80, pillar_4_score = 90, pillar_5_score = 100,
      stringsAsFactors = FALSE
    ),
    pillar_labels = data.frame(
      pillar_id = as.character(1:5),
      pillar_label = paste("Label", 1:5),
      stringsAsFactors = FALSE
    )
  )
  active <- shiny::reactiveVal(FALSE)
  calls <- 0L

  shiny::testServer(
    env$pillar_explorer_server,
    args = list(
      snapshot_loader = function() {
        calls <<- calls + 1L
        snapshot
      },
      active = active
    ),
    {
      session$flushReact()
      testthat::expect_equal(calls, 0L)
      active(TRUE)
      session$flushReact()
      testthat::expect_equal(calls, 1L)
      testthat::expect_equal(output$total, "100%")
      testthat::expect_equal(output$custom_score, "80.00")
      testthat::expect_equal(output$official_score, "75.00")
      testthat::expect_equal(output$difference, "5.00")
    }
  )
})

testthat::test_that("invalid weight totals suppress the custom result", {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "pillar_explorer_data.R"), envir = env)
  sys.source(file.path(root, "R", "pillar_explorer_helpers.R"), envir = env)
  sys.source(file.path(root, "R", "mod_pillar_explorer.R"), envir = env)

  snapshot <- list(
    index = data.frame(
      country_code = "AAA", country_name = "Alpha", year = 2024L,
      score = 75, pillar_1_score = 60, pillar_2_score = 70,
      pillar_3_score = 80, pillar_4_score = 90, pillar_5_score = 100,
      stringsAsFactors = FALSE
    )
  )

  shiny::testServer(
    env$pillar_explorer_server,
    args = list(snapshot_loader = function() snapshot),
    {
      session$flushReact()
      session$setInputs(
        pillar_1_weight = 21L,
        pillar_2_weight = 20L,
        pillar_3_weight = 20L,
        pillar_4_weight = 20L,
        pillar_5_weight = 20L
      )
      session$flushReact()
      testthat::expect_equal(output$custom_score, "-")
      testthat::expect_match(output$status, "sum exactly to 100")
    }
  )
})
