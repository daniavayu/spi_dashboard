testthat::test_that("provider snapshot loads all years and records operation status", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) data.frame(
      iso3c = c("AAA", "AAA"),
      country = c("Alpha", "Alpha"),
      date = c(2023, 2024),
      SPI.INDEX = c(60, 70),
      check.names = FALSE
    ),
    indicators = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.D1.1.TEST = 70, RAW.D1.1.TEST = 7,
      check.names = FALSE
    ),
    metadata = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      region = "Region A", income_level = "HIC"
    ),
    aggregates = function(year = NULL) data.frame(
      iso3c = "WLD", country = "World", date = 2024,
      source_id = "SPI.INDEX", value = 65
    ),
    hierarchy = function() list(
      dimensions = data.frame(
        pillar = "1", dimension = "1.1", dimension_name = "First dimension",
        stringsAsFactors = FALSE
      )
    )
  )

  snapshot <- spi_provider_snapshot(
    preferred = "stub",
    provider_functions = provider_functions
  )

  testthat::expect_equal(snapshot$years, c(2023L, 2024L))
  testthat::expect_equal(nrow(snapshot$index), 2L)
  testthat::expect_true(all(c("index", "metadata", "indicators", "aggregates") %in%
    names(snapshot$operation_status)))
  testthat::expect_true(all(vapply(snapshot$operation_status, function(x) {
    isTRUE(x$ok) && identical(x$status, "ok")
  }, logical(1))))
  testthat::expect_equal(snapshot$dimension_labels$dimension_id, "1.1")
  testthat::expect_equal(snapshot$dimension_labels$dimension_label,
    "First dimension")
})

testthat::test_that("optional provider failures are controlled and overall data survives", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.INDEX = 70, check.names = FALSE
    ),
    indicators = function(year = NULL) stop("indicator service unavailable"),
    metadata = function(year = NULL) stop("metadata service unavailable"),
    aggregates = function(year = NULL) stop("aggregate service unavailable")
  )

  snapshot <- spi_provider_snapshot(
    preferred = "stub",
    provider_functions = provider_functions
  )

  testthat::expect_equal(nrow(snapshot$index), 1L)
  testthat::expect_false(snapshot$operation_status$metadata$ok)
  testthat::expect_equal(snapshot$operation_status$metadata$status, "error")
  testthat::expect_match(snapshot$operation_status$metadata$error, "unavailable")
  testthat::expect_equal(nrow(snapshot$metadata), 0L)
  testthat::expect_equal(nrow(snapshot$indicators), 0L)
  testthat::expect_equal(nrow(snapshot$aggregates), 0L)
})

testthat::test_that("mandatory index failure remains a controlled error", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) stop("index service unavailable"),
    indicators = function(year = NULL) data.frame(),
    metadata = function(year = NULL) data.frame(),
    aggregates = function(year = NULL) data.frame()
  )

  testthat::expect_error(
    spi_provider_snapshot(
      preferred = "stub",
      provider_functions = provider_functions
    ),
    "index service unavailable"
  )
})

testthat::test_that("malformed optional responses are marked as errors", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.INDEX = 70, check.names = FALSE
    ),
    indicators = function(year = NULL) data.frame(bad = 1),
    metadata = function(year = NULL) data.frame(bad = 1),
    aggregates = function(year = NULL) data.frame(bad = 1)
  )

  snapshot <- spi_provider_snapshot(
    preferred = "stub", provider_functions = provider_functions
  )

  testthat::expect_equal(snapshot$operation_status$metadata$status, "error")
  testthat::expect_equal(snapshot$operation_status$indicators$status, "error")
  testthat::expect_equal(snapshot$operation_status$aggregates$status, "error")
})

testthat::test_that("missing optional operations are unavailable without aborting", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.INDEX = 70, check.names = FALSE
    )
  )

  snapshot <- spi_provider_snapshot(
    preferred = "stub", provider_functions = provider_functions
  )

  testthat::expect_equal(nrow(snapshot$index), 1L)
  testthat::expect_equal(snapshot$operation_status$metadata$status, "unavailable")
  testthat::expect_equal(snapshot$operation_status$indicators$status, "unavailable")
  testthat::expect_equal(snapshot$operation_status$aggregates$status, "unavailable")
})

testthat::test_that("reconciled labels are applied to indicators data frame", {
  source(testthat::test_path("..", "..", "R", "spi_adapter.R"), local = TRUE)
  source(testthat::test_path("..", "..", "R", "spi_provider.R"), local = TRUE)

  provider_functions <- list(
    name = "stub",
    index = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.INDEX = 70, check.names = FALSE
    ),
    indicators = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      SPI.D3.2.HNGR = 80, SPI.D4.1.1.POPU = 90,
      check.names = FALSE
    ),
    metadata = function(year = NULL) data.frame(
      iso3c = "AAA", country = "Alpha", date = 2024,
      region = "Region A", income_level = "HIC"
    ),
    aggregates = function(year = NULL) data.frame(
      iso3c = "WLD", country = "World", date = 2024,
      source_id = "SPI.INDEX", value = 65
    ),
    hierarchy = function() list(
      pillars = data.frame(
        pillar = c("3", "4"),
        pillar_name = c("Pillar 3: Data Products", "Pillar 4: Data Sources"),
        stringsAsFactors = FALSE
      ),
      indicators = data.frame(
        indicator_id = c("SPI.D3.1.HNGR", "SPI.D4.1.POPU"),
        indicator_name = c(
          "Indicator 3.1.2: GOAL 2: Zero Hunger",
          "Indicator 4.1.1: Population census"
        ),
        stringsAsFactors = FALSE
      )
    )
  )

  snapshot <- spi_provider_snapshot(
    preferred = "stub", provider_functions = provider_functions
  )

  ind <- snapshot$indicators
  hngr <- ind[ind$indicator_id == "SPI.D3.2.HNGR", "indicator_label"]
  popu <- ind[ind$indicator_id == "SPI.D4.1.1.POPU", "indicator_label"]
  testthat::expect_equal(unique(hngr), "Indicator 3.1.2: GOAL 2: Zero Hunger")
  testthat::expect_equal(unique(popu), "Indicator 4.1.1: Population census")
  testthat::expect_equal(unique(ind$pillar_label[ind$pillar_id == "D3"]),
    "Data Products")
})
