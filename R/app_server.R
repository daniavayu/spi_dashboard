app_server <- function(input, output, session, snapshot_loader = NULL) {
  compare_countries <- shiny::reactiveVal(character())
  overview_loader <- if (is.null(snapshot_loader)) {
    function() spi_provider_snapshot(
      load_details = FALSE,
      load_metadata = TRUE,
      load_aggregates = TRUE
    )
  } else {
    snapshot_loader
  }
  explorer_loader <- if (is.null(snapshot_loader)) {
    function() spi_provider_snapshot(
      load_details = FALSE,
      load_metadata = TRUE,
      load_aggregates = FALSE
    )
  } else {
    snapshot_loader
  }
  overview <- overview_server(
    "overview",
    snapshot_loader = overview_loader
  )
  explorer <- country_explorer_server(
    "country_explorer",
    snapshot_loader = explorer_loader,
    active = function() identical(input$main_nav, "Country Explorer"),
    on_compare = function(countries) {
      compare_countries(countries)
      shiny::updateTabsetPanel(
        session, "main_nav", selected = "Compare Countries"
      )
    }
  )
  country_compare_server(
    "country_compare",
    snapshot_loader = explorer_loader,
    selected_countries = compare_countries,
    selected_year = explorer$selected_year
  )
  profile_loader <- if (is.null(snapshot_loader)) {
    function() spi_profile_sections_from_snapshot(spi_provider_snapshot(
      load_details = TRUE,
      load_metadata = TRUE,
      load_aggregates = TRUE
    ))
  } else {
    function() spi_profile_sections_from_snapshot(snapshot_loader())
  }
  country_profile_server(
    "country_profile",
    profile_loader = profile_loader,
    active = function() identical(input$main_nav, "Country Profile")
  )

  output$overview_flourish_map <- shiny::renderUI({
    regions <- prepare_flourish_regions(overview$snapshot()$index)
    flourish_live_map_ui(regions)
  })

  output$overview_distribution <- shiny::renderPlot({
    data <- overview_score_distribution(overview$snapshot(), overview$selected_year())
    if (nrow(data) == 0L) {
      plot.new()
      text(0.5, 0.5, "No index data for the latest available year")
      return(invisible(NULL))
    }
    hist(data$score, breaks = seq(0, 100, by = 10), col = "#0b9ed0",
      border = "white", main = "", xlab = "SPI score", ylab = "Countries")
  })

  output$overview_regions <- shiny::renderPlot({
    spi_plot_regions(
      overview$snapshot(),
      overview$selected_year()
    )
  })

  output$overview_groups <- shiny::renderPlot({
    data <- overview_income_group_summary(
      overview$snapshot(),
      overview$selected_year()
    )
    spi_plot_horizontal_bars(
      data,
      bar_colors = c(
        HIC = "#0b9ed0",
        UMC = "#0b9ed0",
        LMC = "#f39a38",
        LIC = "#ee513d"
      )
    )
  })

  output$overview_income_variation <- shiny::renderText({
    data <- overview_income_group_variation(
      overview$snapshot(),
      overview$selected_year()
    )
    if (!nrow(data)) {
      return("No within-group variation available")
    }
    paste(
      paste0(
        data$group_name, ": ", round(data$q25), "-", round(data$q75)
      ),
      collapse = " | "
    )
  })

  output$overview_region_history <- shiny::renderPlot({
    spi_plot_region_history()
  })

  output$kpi_countries <- shiny::renderText({
    nrow(overview_index_for_year(overview$snapshot(), overview$selected_year()))
  })
  output$kpi_years <- shiny::renderText(
    max(overview_years(overview$snapshot()))
  )
  output$kpi_year_count <- shiny::renderText({
    overview_year_count(overview$snapshot())
  })
  output$kpi_year_range <- shiny::renderText({
    overview_year_range(overview$snapshot())
  })
  output$kpi_average <- shiny::renderText({
    data <- overview_index_for_year(overview$snapshot(), overview$selected_year())
    if (!nrow(data)) return("-")
    sprintf("%.1f", mean(data$score, na.rm = TRUE))
  })
  output$kpi_improvement <- shiny::renderText({
    improvement <- overview_median_improvement(overview$snapshot())
    if (is.na(improvement)) return("-")
    sprintf("%+.1f", improvement)
  })
  output$kpi_change <- shiny::renderText("+")
  output$footer_provider <- shiny::renderText(overview$snapshot()$provider)
}
