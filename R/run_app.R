#' Launch the SPI Shiny application.
#'
#' @param ... Arguments passed to shiny::shinyApp.
#' @return A shiny application object.
#' @export
run_app <- function(...) {
  golem::with_golem_options(
    shiny::shinyApp(
      ui = app_ui(),
      server = app_server,
      ...
    ),
    golem_opts = list()
  )
}
