country_compare_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(
      class = "spi-compare-header",
      shiny::h1(class = "spi-title", "Compare Countries"),
      shiny::p(class = "spi-intro", "Compare selected countries across available years."),
      shiny::actionButton(ns("compare_clear"), "Clear selection")
    ),
    shiny::div(class = "spi-compare-selection",
      shiny::strong("Selected countries: "),
      shiny::textOutput(ns("compare_selected"), inline = TRUE)
    ),
    shiny::div(class = "spi-card spi-panel",
      shiny::plotOutput(ns("compare_plot"), height = "480px")
    )
  )
}

country_compare_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = FALSE),
  selected_countries,
  selected_year
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactive(snapshot_loader())

    output$compare_selected <- shiny::renderText({
      countries <- selected_countries()
      if (length(countries) == 0L) "None selected" else paste(countries, collapse = ", ")
    })

    output$compare_plot <- shiny::renderPlot({
      countries <- selected_countries()
      data <- snapshot()$index
      if (length(countries) < 2L || !is.data.frame(data) || nrow(data) == 0L) {
        plot.new()
        text(0.5, 0.5, "Select at least two countries in Country Explorer")
        return(invisible(NULL))
      }
      data <- data[
        toupper(as.character(data$country_code)) %in% toupper(countries), ,
        drop = FALSE
      ]
      if (nrow(data) == 0L) {
        plot.new()
        text(0.5, 0.5, "No comparison data available")
        return(invisible(NULL))
      }
      data$country_label <- as.character(data$country_name)
      data$country_label[is.na(data$country_label) | !nzchar(data$country_label)] <-
        as.character(data$country_code[is.na(data$country_label) | !nzchar(data$country_label)])
      data$year <- as.integer(data$year)
      data$score <- as.numeric(data$score)
      data <- data[order(data$country_label, data$year), , drop = FALSE]
      ggplot2::ggplot(
        data,
        ggplot2::aes(x = year, y = score, color = country_label, group = country_label)
      ) +
        ggplot2::geom_line(linewidth = 1, na.rm = FALSE) +
        ggplot2::geom_point(size = 1.8, na.rm = TRUE) +
        ggplot2::scale_y_continuous(limits = c(0, 100)) +
        ggplot2::labs(
          title = "Overall SPI score over time",
          subtitle = paste("Explorer year:", selected_year()),
          x = NULL,
          y = "Score",
          color = NULL
        ) +
        ggplot2::theme_minimal(base_size = 12) +
        ggplot2::theme(legend.position = "bottom")
    })

    shiny::observeEvent(input$compare_clear, {
      selected_countries(character())
    })

    list(selected_countries = selected_countries)
  })
}