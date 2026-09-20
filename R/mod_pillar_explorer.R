pillar_explorer_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h1(class = "spi-title", "Explore by Pillar"),
    shiny::p(class = "spi-intro", "Review pillar scores by country and year."),
    shiny::div(class = "spi-explorer-controls",
      shiny::selectInput(ns("year"), "Data year", choices = NULL),
      shiny::selectInput(ns("pillar"), "Pillar", choices = NULL)
    ),
    shiny::div(class = "spi-card spi-panel",
      DT::DTOutput(ns("table")),
      shiny::textOutput(ns("status"))
    )
  )
}

pillar_explorer_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = TRUE),
  active = function() TRUE
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactiveVal(NULL)
    shiny::observe({
      if (isTRUE(active()) && is.null(snapshot())) {
        snapshot(tryCatch(snapshot_loader(), error = function(error) NULL))
      }
    })
    index <- shiny::reactive({
      value <- snapshot()
      if (is.null(value) || !is.data.frame(value$index)) return(data.frame())
      value$index
    })
    pillar_columns <- shiny::reactive({
      grep("^pillar_[0-9]+_score$", names(index()), value = TRUE)
    })
    shiny::observeEvent(index(), {
      years <- sort(unique(as.integer(index()$year)))
      years <- years[!is.na(years)]
      columns <- pillar_columns()
      shiny::updateSelectInput(session, "year", choices = years,
        selected = if (length(years)) max(years) else character())
      shiny::updateSelectInput(session, "pillar", choices = columns,
        selected = if (length(columns)) columns[[1L]] else character())
    }, ignoreInit = FALSE)
    selected_year <- shiny::reactive({
      value <- suppressWarnings(as.integer(input$year))
      years <- sort(unique(as.integer(index()$year)))
      years <- years[!is.na(years)]
      if (!length(years)) return(NA_integer_)
      if (is.na(value) || !value %in% years) max(years) else value
    })
    output$table <- DT::renderDT({
      data <- index()
      column <- as.character(input$pillar)
      if (!nrow(data) || !nzchar(column) || !column %in% names(data)) {
        return(data.frame())
      }
      result <- data[data$year == selected_year(),
        c("country_code", "country_name", "year", column), drop = FALSE]
      names(result)[4L] <- "pillar_score"
      result[order(-result$pillar_score, result$country_name), , drop = FALSE]
    }, options = list(pageLength = 15, scrollX = TRUE))
    output$status <- shiny::renderText({
      if (is.null(snapshot())) "Loading pillar data..." else if (!nrow(index()))
        "No pillar data available" else ""
    })
  })
}