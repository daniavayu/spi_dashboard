country_compare_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(class = "spi-compare-header",
      shiny::h1(class = "spi-title", "Compare Countries"),
      shiny::p(class = "spi-intro", "Compare two or three countries across pillars and available years."),
      shiny::actionButton(ns("compare_clear"), "Clear selection")
    ),
    shiny::div(class = "spi-explorer-controls spi-compare-controls",
      shiny::selectizeInput(ns("compare_country"), "Countries", choices = NULL, multiple = TRUE),
      shiny::uiOutput(ns("compare_year_control"))
    ),
    shiny::div(class = "spi-explorer-summary",
      shiny::span("Selected: "), shiny::textOutput(ns("compare_selected"), inline = TRUE),
      shiny::span("Year: "), shiny::textOutput(ns("compare_year"), inline = TRUE),
      shiny::span(class = "spi-explorer-status", shiny::textOutput(ns("compare_status"), inline = TRUE))
    ),
    shiny::div(class = "spi-profile-hero-grid",
      shiny::div(class = "spi-card spi-panel", shiny::h3("Pillar comparison"), shiny::plotOutput(ns("compare_pillars"), height = "350px")),
      shiny::div(class = "spi-card spi-panel", shiny::h3("Trend"), shiny::plotOutput(ns("compare_plot"), height = "350px"))
    ),
    shiny::div(class = "spi-card spi-panel spi-compare-dimensions",
      shiny::h3("Largest dimension gaps"),
      shiny::uiOutput(ns("compare_dimensions"))
    )
  )
}

country_compare_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = TRUE),
  selected_countries = NULL,
  selected_year = NULL,
  handoff = NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactive(snapshot_loader())
    countries <- shiny::reactiveVal(character())
    year <- shiny::reactiveVal(NULL)
    handoff_consumed <- FALSE

    catalog <- shiny::reactive({
      data <- snapshot()$index
      if (!is.data.frame(data) || !"country_code" %in% names(data)) character() else unique(as.character(data$country_code))
    })

    shiny::observeEvent(catalog(), {
      shiny::updateSelectizeInput(
        session, "compare_country", choices = catalog(), server = TRUE
      )
    })

    shiny::observeEvent(input$compare_country, {
      values <- unique(toupper(trimws(as.character(input$compare_country))))
      values <- values[nzchar(values) & !is.na(values)]
      valid <- values %in% catalog()
      if (length(values) <= 3L && all(valid)) {
        countries(values)
      } else if (length(values) > 3L) {
        countries(values[seq_len(3L)])
        shiny::freezeReactiveValue(input, "compare_country")
        shiny::updateSelectizeInput(
          session, "compare_country", selected = values[seq_len(3L)]
        )
      } else {
        countries(character())
      }
    }, ignoreInit = TRUE)

    shiny::observe({
      incoming <- if (is.null(handoff)) NULL else handoff()
      if (!handoff_consumed && !is.null(incoming)) {
        result <- spi_compare_canonicalize_selection(incoming, catalog())
        if (result$ok) countries(result$countries)
        handoff_consumed <<- TRUE
      }
    })

    shiny::observeEvent(input$compare_clear, {
      countries(character())
      shiny::freezeReactiveValue(input, "compare_country")
      shiny::updateSelectizeInput(session, "compare_country", selected = character())
    })

    shiny::observe({
      available <- spi_compare_global_year(snapshot()$index, countries())
      if (is.null(year()) || is.na(year()) || (!is.na(available) && year() > available)) {
        if (!is.na(available)) year(available)
      }
    })

    output$compare_selected <- shiny::renderText({
      value <- countries()
      if (length(value) == 0L) "None selected" else paste(value, collapse = ", ")
    })
    output$compare_year <- shiny::renderText(as.character(year()))
    output$compare_status <- shiny::renderText({
      if (length(countries()) < 2L) "Select two or three countries." else ""
    })
    output$compare_year_control <- shiny::renderUI({
      selected_year <- year()
      if (is.null(selected_year) || is.na(selected_year)) {
        return(shiny::helpText("Select countries to choose a comparison year."))
      }
      shiny::numericInput(
        session$ns("compare_year_input"), "Year", value = selected_year,
        min = 1900, max = 2100, step = 1
      )
    })
    shiny::observeEvent(input$compare_year_input, {
      year(suppressWarnings(as.integer(input$compare_year_input)))
    }, ignoreInit = TRUE)

    pillar_data <- shiny::reactive(spi_compare_pillars(snapshot()$index, countries(), year()))
    trend_data <- shiny::reactive(spi_compare_trends(snapshot()$index, countries(), "overall"))
    dimension_data <- shiny::reactive(spi_compare_dimension_gaps(
      snapshot()$index, countries(), year(), snapshot()$dimension_labels
    ))

    output$compare_pillars <- shiny::renderPlot({
      data <- pillar_data()$data
      if (nrow(data) == 0L) return(plot.new())
      ggplot2::ggplot(data, ggplot2::aes(x = pillar_id, y = score, fill = country_code)) +
        ggplot2::geom_col(position = "dodge", na.rm = FALSE) + ggplot2::scale_y_continuous(limits = c(0, 100)) + ggplot2::theme_minimal()
    })
    output$compare_plot <- shiny::renderPlot({
      data <- trend_data()$data
      if (nrow(data) == 0L) return(plot.new())
      ggplot2::ggplot(data, ggplot2::aes(x = year, y = score, color = country_code, group = country_code)) +
        ggplot2::geom_line(na.rm = FALSE) + ggplot2::geom_point(na.rm = TRUE) + ggplot2::scale_y_continuous(limits = c(0, 100)) + ggplot2::theme_minimal()
    })
    output$compare_dimensions <- shiny::renderUI({
      if (nrow(dimension_data()) == 0L) {
        return(shiny::div("No dimension comparison is available for the selected countries and year."))
      }
      DT::DTOutput(session$ns("compare_dimensions_table"))
    })
    output$compare_dimensions_table <- DT::renderDT({
      data <- dimension_data()
      country_columns <- countries()
      DT::datatable(
        data,
        rownames = FALSE,
        colnames = c("Pillar", "Dimension", country_columns, "Gap"),
        class = "compact stripe hover",
        options = list(
          pageLength = 12, dom = "t", ordering = FALSE, scrollX = TRUE
        )
      ) |>
        DT::formatRound(columns = c(country_columns, "gap"), digits = 1) |>
        DT::formatStyle(
          columns = country_columns,
          backgroundColor = DT::styleInterval(
            c(40, 70), c("#fde2e1", "#fff3cd", "#dff3e4")
          ),
          color = DT::styleInterval(
            c(40, 70), c("#a12828", "#795900", "#176b42")
          ),
          fontWeight = "700",
          textAlign = "center"
        ) |>
        DT::formatStyle(
          columns = "gap",
          backgroundColor = DT::styleInterval(
            c(5, 15, 30), c("#e9f8f2", "#fff3cd", "#fde2e1", "#f8c9c5")
          ),
          color = DT::styleInterval(
            c(5, 15, 30), c("#176b42", "#795900", "#a12828", "#8d2020")
          ),
          fontWeight = "700",
          textAlign = "center"
        )
    })

    list(selected_countries = countries, selected_year = year)
  })
}
