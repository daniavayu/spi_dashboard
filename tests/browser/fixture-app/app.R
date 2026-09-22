project_root <- normalizePath(file.path("..", "..", ".."))
pkgload::load_all(project_root, quiet = TRUE)

# Three countries x three years. AAA/BBB 2023-2024 scores are kept identical
# to the original minimal fixture so that country-profile-smoke.R's
# assertions (AAA selected by default, AAA 2024 score "70.0") keep passing.
fixture_countries <- data.frame(
  country_code = c("AAA", "BBB", "CCC"),
  country_name = c("Alpha", "Beta", "Gamma"),
  region = c("Test Region A", "Test Region A", "Test Region B"),
  income_group = c("High income", "Upper middle income", "Lower middle income"),
  stringsAsFactors = FALSE
)

fixture_years <- c(2022L, 2023L, 2024L)

fixture_scores <- list(
  AAA = c(`2022` = 50, `2023` = 60, `2024` = 70),
  BBB = c(`2022` = 65, `2023` = 75, `2024` = 80),
  CCC = c(`2022` = 55, `2023` = 63, `2024` = 72)
)

fixture_index <- do.call(rbind, lapply(fixture_countries$country_code, function(code) {
  scores <- fixture_scores[[code]]
  name <- fixture_countries$country_name[fixture_countries$country_code == code]
  data.frame(
    country_code = code,
    country_name = name,
    year = fixture_years,
    score = as.numeric(scores),
    pillar_1_score = as.numeric(scores) + 1,
    pillar_2_score = as.numeric(scores) - 2,
    pillar_3_score = as.numeric(scores) + 3,
    pillar_4_score = as.numeric(scores) - 4,
    pillar_5_score = as.numeric(scores) + 5,
    dimension_1_1_score = as.numeric(scores) + 2,
    stringsAsFactors = FALSE
  )
}))
rownames(fixture_index) <- NULL

fixture_metadata <- do.call(rbind, lapply(seq_len(nrow(fixture_countries)), function(i) {
  data.frame(
    country_code = fixture_countries$country_code[i],
    country_name = fixture_countries$country_name[i],
    year = fixture_years,
    region = fixture_countries$region[i],
    income_group = fixture_countries$income_group[i],
    stringsAsFactors = FALSE
  )
}))
rownames(fixture_metadata) <- NULL

fixture_snapshot <- list(
  provider = "fixture",
  years = fixture_years,
  index = fixture_index,
  indicators = data.frame(),
  metadata = fixture_metadata,
  aggregates = data.frame(),
  operation_status = list()
)

shiny::shinyApp(
  ui = spiDashboard:::app_ui(),
  server = function(input, output, session) {
    spiDashboard:::app_server(
      input, output, session,
      snapshot_loader = function() fixture_snapshot
    )
  }
)
