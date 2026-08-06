overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(ns("year"), "Year", choices = NULL)
  )
}

overview_server <- function(
  id,
  snapshot_loader = function() spi_provider_snapshot(load_details = FALSE)
) {
  shiny::moduleServer(id, function(input, output, session) {
    snapshot <- shiny::reactive({
      snapshot_loader()
    })
    years <- shiny::reactive(overview_years(snapshot()))

    shiny::observe({
      available <- years()
      shiny::updateSelectInput(
        session,
        "year",
        choices = available,
        selected = if (length(available) > 0L) max(available) else character()
      )
    })

    selected_year <- shiny::reactive({
      value <- suppressWarnings(as.integer(input$year))
      if (is.na(value)) years()[[1L]] else value
    })

    output$provider <- shiny::renderText({
      paste("Data provider:", snapshot()$provider)
    })
    output$selected_year <- shiny::renderText({
      as.character(selected_year())
    })
    output$index_table <- shiny::renderTable({
      overview_index_for_year(snapshot(), selected_year())
    })
    output$aggregate_table <- shiny::renderTable({
      overview_aggregate_for_year(snapshot(), selected_year())
    })

    list(snapshot = snapshot, selected_year = selected_year)
  })
}
