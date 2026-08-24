# Launch the ShinyApp (Do not remove this comment)
# To deploy, run: rsconnect::deployApp()
# Or use the blue button on top of this file

spiR_root <- Sys.getenv(
  "SPI_R_ROOT",
  unset = file.path(getwd(), "..", "spiR")
)
pkgload::load_all(
  normalizePath(spiR_root, winslash = "/", mustWork = TRUE),
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE
)

pkgload::load_all(
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE
)
options("golem.app.prod" = TRUE)
spiDashboard::run_app() # add parameters here (if any)

# options(rsconnect.packrat = TRUE)
# rsconnect::deployApp()

