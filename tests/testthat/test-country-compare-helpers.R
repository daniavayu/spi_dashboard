testthat::test_that("comparison selection canonicalizes and validates ISO3 codes", {
  source(testthat::test_path("..", "..", "R", "country_compare_helpers.R"), local = TRUE)
  catalog <- data.frame(country_code = c("AAA", "BBB", "CCC"))

  result <- spi_compare_canonicalize_selection(
    c(" aaa ", "BBB", "AAA"),
    catalog
  )

  testthat::expect_true(result$ok)
  testthat::expect_equal(result$countries, c("AAA", "BBB"))

  invalid <- spi_compare_canonicalize_selection(c("AAA", "ZZZ"), catalog)
  testthat::expect_false(invalid$ok)
  testthat::expect_match(invalid$error, "ZZZ")
})

testthat::test_that("comparison selection enforces the two to three country limit", {
  source(testthat::test_path("..", "..", "R", "country_compare_helpers.R"), local = TRUE)
  catalog <- c("AAA", "BBB", "CCC", "DDD")

  testthat::expect_false(
    spi_compare_canonicalize_selection(character(), catalog)$ok
  )
  testthat::expect_false(
    spi_compare_canonicalize_selection("AAA", catalog)$ok
  )
  testthat::expect_false(
    spi_compare_canonicalize_selection(c("AAA", "BBB", "CCC", "DDD"), catalog)$ok
  )
})

testthat::test_that("comparison global year uses the selected-country union", {
  source(testthat::test_path("..", "..", "R", "country_compare_helpers.R"), local = TRUE)
  index <- data.frame(
    country_code = c("AAA", "AAA", "BBB"),
    year = c(2020L, 2024L, 2022L),
    score = c(50, 60, NA_real_)
  )

  testthat::expect_equal(
    spi_compare_global_year(index, c("AAA", "BBB")),
    2024L
  )
})

testthat::test_that("comparison metric helper accepts overall and verified pillars", {
  source(testthat::test_path("..", "..", "R", "country_compare_helpers.R"), local = TRUE)

  testthat::expect_equal(spi_compare_metrics(), c("overall", "pillar_1", "pillar_2", "pillar_3", "pillar_4", "pillar_5"))
  testthat::expect_equal(spi_compare_metric_column("overall"), "score")
  testthat::expect_equal(spi_compare_metric_column("pillar_3"), "pillar_3_score")
  testthat::expect_error(spi_compare_metric_column("dimension_1_1"), "Unsupported")
})
