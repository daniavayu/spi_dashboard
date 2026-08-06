testthat::test_that("application foundation sources in a clean session", {
  root <- testthat::test_path("..", "..")
  env <- new.env(parent = baseenv())
  sys.source(file.path(root, "R", "app_config.R"), envir = env)
  sys.source(file.path(root, "R", "spi_adapter.R"), envir = env)
  sys.source(file.path(root, "R", "spi_provider.R"), envir = env)
  sys.source(file.path(root, "R", "overview_data.R"), envir = env)
  sys.source(file.path(root, "R", "mod_overview.R"), envir = env)
  sys.source(file.path(root, "R", "app_ui.R"), envir = env)
  sys.source(file.path(root, "R", "app_server.R"), envir = env)
  sys.source(file.path(root, "R", "run_app.R"), envir = env)

  testthat::expect_true(is.function(env$run_app))
  testthat::expect_true(is.function(env$app_ui))
  testthat::expect_true(is.function(env$app_server))
})

testthat::test_that("spiR is preferred when available", {
  root <- testthat::test_path("..", "..")
  env <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "app_config.R"), envir = env)
  sys.source(file.path(root, "R", "spi_adapter.R"), envir = env)

  testthat::expect_true(env$spi_provider_available("spiR"))
  testthat::expect_equal(env$spi_select_provider(), "spiR")
})
