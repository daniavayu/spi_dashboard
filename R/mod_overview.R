overview_ui <- function(id) {
  shiny::tagList()
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

    selected_year <- shiny::reactive({
      available <- years()
      if (length(available) == 0L) return(NA_integer_)
      max(available)
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
