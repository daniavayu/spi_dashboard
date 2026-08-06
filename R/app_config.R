app_root <- function() {
  root <- Sys.getenv("SPI_DASHBOARD_ROOT", unset = getwd())
  normalizePath(root, winslash = "/", mustWork = FALSE)
}

app_source_local_provider <- function(root = app_root()) {
  files <- c(
    "functions/spi-filters.R",
    "functions/spi-github.R",
    "functions/spi-download.R",
    "functions/spi-data.R",
    "functions/spi-wrappers.R"
  )
  missing <- files[!file.exists(file.path(root, files))]
  if (length(missing) > 0L) {
    stop("Local SPI provider files are missing: ", paste(missing, collapse = ", "))
  }
  for (file in files) {
    sys.source(file.path(root, file), envir = .GlobalEnv)
  }
  invisible(TRUE)
}
