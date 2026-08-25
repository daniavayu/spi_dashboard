spiR_path <- Sys.getenv(
  "SPIR_PATH",
  unset = file.path(getwd(), "..", "spiR")
)
if (dir.exists(spiR_path)) {
  devtools::load_all(spiR_path, quiet = TRUE)
}

pkgload::load_all(
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE
)
options(golem.app.prod = FALSE)
shiny::runApp(
  spiDashboard::run_app(),
  launch.browser = TRUE
)