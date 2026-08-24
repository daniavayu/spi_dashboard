project_root <- normalizePath(file.path("..", "..", ".."))
pkgload::load_all(project_root, quiet = TRUE)

fixture_snapshot <- list(
  provider = "fixture",
  years = c(2023L, 2024L),
  index = data.frame(
    country_code = c("AAA", "AAA", "BBB", "BBB"),
    country_name = c("Alpha", "Alpha", "Beta", "Beta"),
    year = c(2023L, 2024L, 2023L, 2024L),
    score = c(60, 70, 75, 80),
    pillar_1_score = c(61, 71, 76, 81),
    dimension_1_1_score = c(62, 72, 77, 82),
    stringsAsFactors = FALSE
  ),
  indicators = data.frame(),
  metadata = data.frame(),
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
