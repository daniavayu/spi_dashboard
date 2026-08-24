country_explorer_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(
      class = "spi-explorer-controls",
      shiny::selectInput(ns("explorer_year"), "Data year", choices = NULL),
      shiny::selectInput(ns("explorer_view"), "Score view", choices = c(
        "Pillars" = "pillars",
        "Dimensions" = "dimensions",
        "Indicators" = "indicators"
      )),
      shiny::selectInput(ns("explorer_region"), "Region", choices = ""),
      shiny::selectInput(ns("explorer_income"), "Income level", choices = ""),
      shiny::textInput(ns("explorer_country"), "Search country", value = "",
        placeholder = "Type country name..."),
      shiny::uiOutput(ns("explorer_indicator_ui")),
      shiny::actionButton(ns("explorer_compare"), "Compare Selected"),
      shiny::actionButton(ns("explorer_reset"), "Reset")
    ),
    shiny::div(
      class = "spi-explorer-summary",
      shiny::span("Average: ", shiny::textOutput(ns("explorer_average"), inline = TRUE)),
      shiny::span("Median: ", shiny::textOutput(ns("explorer_median"), inline = TRUE)),
      shiny::span("SD: ", shiny::textOutput(ns("explorer_sd"), inline = TRUE)),
      shiny::span("Year: ", shiny::textOutput(ns("explorer_selected_year"), inline = TRUE)),
      shiny::span(class = "spi-explorer-status", shiny::textOutput(
        ns("explorer_status"), inline = TRUE
      ))
    ),
    shiny::div(class = "spi-explorer-table", DT::DTOutput(ns("explorer_table")))
  )
}

country_explorer_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = TRUE),
  active = function() TRUE,
  on_compare = function(countries) invisible(NULL)
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactiveVal(NULL)
  selected_countries <- shiny::reactiveVal(character())
    selected_country_input <- session$ns("explorer_selected_country")
    shiny::observeEvent(active(), {
      if (isTRUE(active()) && is.null(snapshot())) {
        snapshot(tryCatch(
          snapshot_loader(),
          error = function(error) {
            list(
              provider = "unavailable",
              years = integer(),
              index = spi_empty_index(),
              indicators = spi_empty_indicators(),
              metadata = spi_empty_metadata(),
              aggregates = spi_empty_aggregates(),
              operation_status = list(
                index = list(
                  ok = FALSE,
                  status = "error",
                  error = conditionMessage(error)
                )
              )
            )
          }
        ))
      }
    }, ignoreInit = FALSE)
    snapshot_value <- shiny::reactive({
      value <- snapshot()
      if (is.null(value)) {
        list(
          provider = "pending",
          years = integer(),
          index = spi_empty_index(),
          indicators = spi_empty_indicators(),
          metadata = spi_empty_metadata(),
          aggregates = spi_empty_aggregates(),
          operation_status = list()
        )
      } else {
        value
      }
    })
    available_years <- shiny::reactive({
      index <- snapshot_value()$index
      if (!is.data.frame(index) || !"year" %in% names(index)) {
        return(integer())
      }
      spi_available_years(index)
    })
    indicator_choices <- shiny::reactive({
      indicators <- snapshot_value()$indicators
      if (!is.data.frame(indicators) || nrow(indicators) == 0L) {
        return(character())
      }
      unique_rows <- indicators[!duplicated(indicators$indicator_id),
        c("indicator_id", "indicator_label"), drop = FALSE]
      stats::setNames(unique_rows$indicator_id, unique_rows$indicator_label)
    })

    shiny::observeEvent(snapshot(), {
      years <- available_years()
      shiny::updateSelectInput(
        session, "explorer_year", choices = years,
        selected = if (length(years) > 0L) max(years) else character()
      )
      base <- spi_explorer_base(snapshot_value())$data
      regions <- sort(unique(base$region[!is.na(base$region) & nzchar(base$region)]))
      incomes <- sort(unique(base$income_group[
        !is.na(base$income_group) & nzchar(base$income_group)
      ]))
      shiny::updateSelectInput(
        session, "explorer_region",
        choices = c("All regions" = "", stats::setNames(regions, regions))
      )
      shiny::updateSelectInput(
        session, "explorer_income",
        choices = c("All income levels" = "", stats::setNames(incomes, incomes))
      )
    })

    output$explorer_indicator_ui <- shiny::renderUI({
      if (!identical(input$explorer_view, "indicators")) {
        return(NULL)
      }
      choices <- indicator_choices()
      shiny::selectInput(
        session$ns("explorer_indicator"),
        "Indicator",
        choices = choices,
        selected = if (length(choices) > 0L) choices[[1L]] else character()
      )
    })

    shiny::observeEvent(input$explorer_reset, {
      selected_countries(character())
      years <- available_years()
      shiny::updateSelectInput(
        session, "explorer_year",
        selected = if (length(years) > 0L) max(years) else character()
      )
      shiny::updateSelectInput(session, "explorer_view", selected = "pillars")
      shiny::updateSelectInput(session, "explorer_region", selected = "")
      shiny::updateSelectInput(session, "explorer_income", selected = "")
      shiny::updateSelectInput(session, "explorer_indicator", selected = "")
      shiny::updateTextInput(session, "explorer_country", value = "")
    })

    selected_year <- shiny::reactive({
      years <- available_years()
      requested <- suppressWarnings(as.integer(input$explorer_year))
      if (length(years) == 0L) return(NA_integer_)
      if (length(requested) != 1L || is.na(requested) ||
        !requested %in% years) {
        max(years)
      } else {
        requested
      }
    })
    view_data <- shiny::reactive({
      selected_view <- if (is.null(input$explorer_view)) {
        "pillars"
      } else {
        input$explorer_view
      }
      spi_explorer_view(
        snapshot_value(),
        view = selected_view,
        year = selected_year(),
        region = input$explorer_region,
        income_group = input$explorer_income,
        country_search = input$explorer_country,
        indicator_id = input$explorer_indicator
      )
    })
    summary <- shiny::reactive(spi_explorer_summary(view_data()$data))

    output$explorer_selected_year <- shiny::renderText({
      as.character(selected_year())
    })
    output$explorer_average <- shiny::renderText({
      value <- summary()$average
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$explorer_median <- shiny::renderText({
      value <- summary()$median
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$explorer_sd <- shiny::renderText({
      value <- summary()$standard_deviation
      if (is.na(value)) "-" else sprintf("%.2f", value)
    })
    output$explorer_status <- shiny::renderText({
      data <- view_data()$data
      operation <- snapshot_value()$operation_status$index
      if (!is.null(operation) && identical(operation$status, "error")) {
        return(paste("Data could not be loaded:", operation$error))
      }
      if (nrow(data) == 0L) "No data available for the selected filters" else ""
    })
    output$explorer_table <- DT::renderDT({
      data <- view_data()$data
      selected_view <- if (is.null(input$explorer_view)) {
        "pillars"
      } else {
        input$explorer_view
      }
      if (nrow(data) == 0L) {
        data <- spi_explorer_empty_table()[0, , drop = FALSE]
      }
      if (nrow(data) > 0L && selected_view %in% c("pillars", "dimensions") &&
        all(c("metric_label", "metric_score") %in% names(data))) {
        data <- spi_explorer_widen_metrics(data)
      }
      data$Select <- paste0(
        '<input type="checkbox" class="spi-country-select" ',
        'data-country-code="', data$country_code, '" ',
        "onchange=\"Shiny.setInputValue('", selected_country_input,
        "', this.dataset.countryCode + '|' + ",
        "(this.checked ? '1' : '0'), {priority: 'event'})\" ",
        'aria-label="Select country" />'
      )
      data <- data[, c("Select", setdiff(names(data), "Select")), drop = FALSE]
      display_names <- c(
        country_code = "Code",
        country_name = "Country",
        year = "Year",
        region = "Region",
        income_group = "Income",
        overall_spi = "Overall score",
        metric_id = "Metric",
        metric_label = "Indicator",
        metric_score = "Score",
        change_previous = "Change vs previous data year",
        change_first = "Change vs first data year"
      )
      names(data) <- ifelse(
        names(data) %in% names(display_names),
        unname(display_names[names(data)]),
        names(data)
      )
      score_columns <- intersect(
        c("Overall score", "Score", "Pillar 1 score", "Pillar 2 score",
          "Pillar 3 score", "Pillar 4 score"),
        names(data)
      )
      table <- DT::datatable(
        data,
        rownames = FALSE,
        selection = list(mode = "multiple", target = "row"),
        escape = FALSE,
        filter = "none",
        class = "stripe hover compact",
        options = list(
          dom = "ltip",
          pageLength = 10,
          scrollX = TRUE,
          select = list(style = "multi", selector = "td:first-child"),
          columnDefs = list(list(
            targets = "_all",
            render = DT::JS(
              "function(data, type) {",
              "if (type === 'display' && (data === null || data === '')) return '-';",
              "return data;",
              "}"
            )
          ), list(targets = 0, orderable = FALSE))
        )
      )
      numeric_columns <- names(data)[vapply(data, is.numeric, logical(1L))]
      numeric_columns <- setdiff(numeric_columns, "Year")
      if (length(numeric_columns) > 0L) {
        table <- DT::formatRound(table, columns = numeric_columns, digits = 2)
      }
      if (length(score_columns) > 0L) {
        table <- DT::formatStyle(
          table, columns = score_columns,
          backgroundColor = DT::styleInterval(
            c(40, 60, 80),
            c("#fde8e8", "#fff4d8", "#e5f6ed", "#d5f2e5")
          ),
          color = DT::styleInterval(
            c(40, 60, 80),
            c("#c43d34", "#b56b13", "#087b4d", "#087b4d")
          ),
          fontWeight = "600"
        )
      }
      table
    }, server = FALSE)

    shiny::observeEvent(input$explorer_selected_country, {
      if (is.null(input$explorer_selected_country)) return()
      change <- strsplit(as.character(input$explorer_selected_country),
        "|", fixed = TRUE)[[1L]]
      if (length(change) != 2L || !nzchar(change[[1L]])) return()
      selected <- selected_countries()
      if (identical(change[[2L]], "1")) {
        selected <- unique(c(selected, change[[1L]]))
      } else {
        selected <- setdiff(selected, change[[1L]])
      }
      selected_countries(selected)
    })

    shiny::observe({
      shiny::updateActionButton(
        session,
        "explorer_compare",
        disabled = length(selected_countries()) < 2L
      )
    })

    shiny::observeEvent(input$explorer_compare, {
      data <- view_data()$data
      selected <- selected_countries()
      if (length(selected) < 2L || !"country_code" %in% names(data)) return()
      on_compare(selected)
    })

    list(
      snapshot = snapshot_value,
      selected_year = selected_year,
      view_data = view_data,
      summary = summary,
      selected_rows = shiny::reactive(selected_countries())
    )
  })
}
