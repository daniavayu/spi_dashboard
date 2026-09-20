data_downloads_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h1(class = "spi-title", "Data & Downloads"),
    shiny::p(class = "spi-intro", "Download the normalized data used by the dashboard."),
    shiny::div(class = "spi-explorer-controls",
      shiny::selectInput(ns("dataset"), "Dataset", choices = c(
        "Country index" = "index",
        "Metadata" = "metadata",
        "Aggregates" = "aggregates",
        "Indicators" = "indicators"
      )),
      shiny::downloadButton(ns("download"), "Download CSV")
    ),
    shiny::div(class = "spi-card spi-panel",
      shiny::textOutput(ns("status"))
    )
  )
}

data_downloads_server <- function(
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
    dataset <- shiny::reactive({
      value <- snapshot()
      name <- as.character(input$dataset)
      if (is.null(value) || !name %in% names(value) ||
        !is.data.frame(value[[name]])) return(data.frame())
      value[[name]]
    })
    output$status <- shiny::renderText({
      if (is.null(snapshot())) return("Loading downloadable data...")
      paste(nrow(dataset()), "rows available")
    })
    output$download <- shiny::downloadHandler(
      filename = function() paste0("spi_", input$dataset, ".csv"),
      content = function(file) utils::write.csv(dataset(), file, row.names = FALSE, na = "")
    )
  })
}