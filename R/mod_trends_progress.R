trends_progress_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(class = "spi-trends-page",
    shiny::h1(class = "spi-title", "Trends & Progress"),
    shiny::p(class = "spi-intro", "Explore SPI movement, coverage, and pillar consistency over time."),
    shiny::div(class = "spi-explorer-controls",
      shiny::selectInput(ns("start_year"), "Start year", choices = NULL),
      shiny::selectInput(ns("end_year"), "End year", choices = NULL),
      shiny::selectInput(ns("metric"), "Metric", choices = NULL),
      shiny::selectInput(ns("group"), "Official grouping", choices = c("Global" = "global")),
      shiny::div(class = "spi-trends-status", shiny::textOutput(ns("status"), inline = TRUE))
    ),
    shiny::div(class = "spi-main-grid",
      shiny::div(class = "spi-card spi-panel", shiny::h3("Global trend"), shiny::p("Median, interquartile range, and valid contributors by year."), shiny::plotOutput(ns("global_trend"), height = "280px")),
      shiny::div(class = "spi-card spi-panel", shiny::h3("Selected group"), shiny::p("Official aggregate or metadata-based descriptive series."), shiny::plotOutput(ns("group_trend"), height = "280px")),
      shiny::div(class = "spi-card spi-panel", shiny::h3("Pillar stability"), shiny::p("Standard deviation of year-to-year changes. Shorter bars mean more stable pillars."), shiny::plotOutput(ns("stability_plot"), height = "190px"), shiny::textOutput(ns("stability")), shiny::textOutput(ns("coverage")))
    ),
    shiny::div(class = "spi-card spi-panel", shiny::h3("Period change by country"), shiny::p("Descriptive changes, sortable by the table headers; not a statistical ranking."), shiny::div(class = "spi-explorer-table", DT::DTOutput(ns("changes")))),
    shiny::div(class = "spi-card spi-panel", shiny::h3("Pillar associations"), shiny::p("Pearson correlations use complete country-year pairs and are descriptive only."), shiny::div(class = "spi-explorer-table", DT::DTOutput(ns("associations"))))
  )
}

trends_progress_server <- function(id, snapshot_loader) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactive(snapshot_loader())
    years <- shiny::reactive(trends_available_years(snapshot()))
    metrics <- shiny::reactive(trends_metric_catalog(snapshot()$index))
    groups <- shiny::reactive(trends_group_catalog(snapshot()))

    shiny::observeEvent(years(), {
      values <- years()
      shiny::updateSelectInput(session, "start_year", choices = values, selected = min(values))
      shiny::updateSelectInput(session, "end_year", choices = values, selected = max(values))
    }, once = TRUE)
    shiny::observeEvent(metrics(), {
      values <- metrics()
      shiny::updateSelectInput(session, "metric", choices = stats::setNames(values$column, values$label), selected = "score")
    }, once = TRUE)
    shiny::observeEvent(groups(), {
      values <- groups()
      choices <- c("Global" = "global")
      if (nrow(values)) choices <- c(choices, stats::setNames(values$code, paste0(values$name, " (", values$source, ")")))
      shiny::updateSelectInput(session, "group", choices = choices)
    }, once = TRUE)

    period <- shiny::reactive({
      values <- years()
      if (!length(values)) return(c(NA_integer_, NA_integer_))
      start <- suppressWarnings(as.integer(input$start_year %||% min(values)))
      end <- suppressWarnings(as.integer(input$end_year %||% max(values)))
      sort(c(start, end))
    })
    metric_column <- shiny::reactive(input$metric %||% "score")

    output$status <- shiny::renderText({
      if (!length(years())) return("Unavailable: no valid index years")
      paste("Showing", period()[[1L]], "to", period()[[2L]])
    })
    output$global_trend <- shiny::renderPlot({
      data <- trends_annual_summary(snapshot()$index, metric_column())
      data <- data[data$year >= period()[[1L]] & data$year <= period()[[2L]], , drop = FALSE]
      if (!nrow(data)) return(plot.new())
      graphics::plot(data$year, data$median, type = "o", pch = 16, col = "#0b9ed0", xlab = "Year", ylab = "Median score")
      graphics::arrows(data$year, data$median - data$iqr / 2, data$year, data$median + data$iqr / 2, code = 3, angle = 90, length = .05, col = "#8aa7b8")
    })
    output$group_trend <- shiny::renderPlot({
      data <- trends_group_annual_summary(snapshot(), metric_column(), input$group %||% "global")
      data <- data[data$year >= period()[[1L]] & data$year <= period()[[2L]], , drop = FALSE]
      if (!nrow(data)) return(plot.new())
      graphics::plot(data$year, data$median, type = "o", pch = 16, col = "#27a36a", xlab = "Year", ylab = "Median score")
    })
    output$changes <- DT::renderDT({
      data <- trends_period_changes(snapshot()$index, metric_column(), period()[[1L]], period()[[2L]])
      DT::datatable(
        data,
        rownames = FALSE,
        colnames = c("Country code", "Country", "Start value", "End value", "Change"),
        class = "compact stripe hover",
        options = list(pageLength = 10, dom = "tip", ordering = TRUE, scrollX = TRUE)
      ) |>
        DT::formatRound(columns = c("start_value", "end_value", "change"), digits = 1)
    })
    output$stability <- shiny::renderText({
      data <- trends_pillar_stability_summary(snapshot()$index, metrics(), period()[[1L]], period()[[2L]])
      if (!nrow(data)) return("No pillar stability data available")
      available <- !is.na(data$value)
      if (!any(available)) return("Stability requires at least two valid year-to-year changes")
      sprintf("Based on %d valid pillar series; each requires at least two changes", sum(available))
    })
    output$stability_plot <- shiny::renderPlot({
      data <- trends_pillar_stability_summary(snapshot()$index, metrics(), period()[[1L]], period()[[2L]])
      data <- data[!is.na(data$value), , drop = FALSE]
      if (!nrow(data)) {
        plot.new()
        text(.5, .5, "Insufficient data")
        return(invisible(NULL))
      }
      graphics::barplot(
        rev(data$value), names.arg = rev(data$label), horiz = TRUE,
        las = 1, col = "#0b9ed0", border = NA,
        xlab = "Standard deviation of annual change",
        main = "Lower = more stable"
      )
    })
    output$coverage <- shiny::renderText({
      sprintf("Period endpoints: %d to %d", period()[[1L]], period()[[2L]])
    })
    output$associations <- DT::renderDT({
      columns <- metrics()$column[metrics()$column != "score"]
      DT::datatable(
        trends_pillar_associations(snapshot()$index, columns),
        rownames = FALSE,
        colnames = c("Pillar 1", "Pillar 2", "Pearson correlation", "Observations", "Status"),
        class = "compact stripe hover",
        options = list(pageLength = 10, dom = "tip", ordering = TRUE, scrollX = TRUE)
      ) |>
        DT::formatRound(columns = "correlation", digits = 2)
    })
  })
}

`%||%` <- function(value, fallback) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) fallback else value[[1L]]
}
