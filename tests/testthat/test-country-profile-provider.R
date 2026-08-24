testthat::test_that("development spiR exports the Profile provider contract", {
  testthat::skip_if_not_installed("devtools")
  project_root <- normalizePath(testthat::test_path("..", ".."))
  spir_path <- Sys.getenv(
    "SPIR_PATH",
    unset = file.path(project_root, "..", "spiR")
  )
  if (!dir.exists(spir_path)) {
    testthat::skip("The configured development spiR checkout is unavailable.")
  }

  devtools::load_all(spir_path, quiet = TRUE)
  namespace <- asNamespace("spiR")
  operations <- c(
    "spi_versions", "spi_get", "spi_data", "spi_index", "spi_indicator",
    "country_info", "metadata", "metadata_pillars", "metadata_dimensions",
    "spi_aggregates"
  )

  testthat::expect_true(all(
    vapply(operations, exists, logical(1), envir = namespace, inherits = FALSE)
  ))
  testthat::expect_true(all(operations %in% getNamespaceExports("spiR")))
  testthat::expect_true(all(vapply(
    operations,
    function(operation) is.function(get(operation, envir = namespace)),
    logical(1)
  )))
  testthat::expect_true("indicator" %in% names(formals(spiR::spi_indicator)))
  testthat::expect_true("version" %in% names(formals(spiR::spi_index)))
  testthat::expect_true("country" %in% names(formals(spiR::spi_data)))

  versions <- spiR::spi_versions()
  testthat::expect_true(is.character(versions) || is.data.frame(versions))
})
