testthat::test_that("Profile radar prepares country and regional pillar series", {
  source(testthat::test_path("..", "..", "R", "country_profile_visualizations.R"),
    local = TRUE
  )

  index <- data.frame(
    country_code = c("AAA", "BBB"),
    country_name = c("Alpha", "Beta"), year = c(2024L, 2024L),
    pillar_1_score = c(70, 80), pillar_2_score = c(60, 70),
    pillar_3_score = c(50, 60), pillar_4_score = c(40, 50),
    pillar_5_score = c(30, 40), stringsAsFactors = FALSE
  )
  metadata <- data.frame(
    country_code = c("AAA", "BBB"), country_name = c("Alpha", "Beta"),
    year = c(2024L, 2024L), region = c("Region A", "Region A"),
    stringsAsFactors = FALSE
  )

  result <- spi_profile_radar_data(index, metadata, "AAA", 2024L)

  testthat::expect_equal(nrow(result), 10L)
  testthat::expect_setequal(result$series, c("country", "region"))
  testthat::expect_equal(
    result$value[result$series == "region"], c(75, 65, 55, 45, 35)
  )
  testthat::expect_s3_class(spi_profile_pillar_radar(result, "AAA", 2024L),
    "ggplot"
  )
})