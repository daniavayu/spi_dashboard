app_server <- function(input, output, session) {
  overview <- overview_server("overview")

  output$overview_flourish_map <- shiny::renderUI({
    regions <- prepare_flourish_regions(overview$snapshot()$index)
    flourish_live_map_ui(regions)
  })

  output$overview_distribution <- shiny::renderPlot({
    data <- overview_score_distribution(overview$snapshot(), overview$selected_year())
    if (nrow(data) == 0L) {
      plot.new()
      text(0.5, 0.5, "No index data for the selected year")
      return(invisible(NULL))
    }
    hist(data$score, breaks = seq(0, 100, by = 10), col = "#0b9ed0",
      border = "white", main = "", xlab = "SPI score", ylab = "Countries")
  })

  output$overview_regions <- shiny::renderPlot({
    spi_plot_regions(overview$snapshot(), overview$selected_year())
  })

  output$overview_groups <- shiny::renderPlot({
    data <- overview_group_summary(overview$snapshot(), overview$selected_year())
    if (nrow(data) == 0L) {
      plot.new()
      text(0.5, 0.5, "No aggregate data for the selected year")
      return(invisible(NULL))
    }
    barplot(data$score, names.arg = data$group_name, las = 2L,
      col = c("#0b9ed0", "#0b9ed0", "#f39a38", "#ee513d"), border = NA,
      ylim = c(0, 100), main = "", ylab = "SPI score")
  })

  output$kpi_countries <- shiny::renderText({
    nrow(overview_index_for_year(overview$snapshot(), overview$selected_year()))
  })
  output$kpi_years <- shiny::renderText(length(overview_years(overview$snapshot())))
  output$kpi_average <- shiny::renderText({
    data <- overview_index_for_year(overview$snapshot(), overview$selected_year())
    if (!nrow(data)) return("-")
    sprintf("%.1f", mean(data$score, na.rm = TRUE))
  })
  output$kpi_change <- shiny::renderText("+")
  output$footer_provider <- shiny::renderText(overview$snapshot()$provider)
}
