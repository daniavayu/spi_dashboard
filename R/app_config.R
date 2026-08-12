app_sys <- function() {
  installed_path <- system.file("app", package = "spiDashboard")
  if (nzchar(installed_path)) {
    return(installed_path)
  }
  file.path(app_root(), "inst", "app")
}

get_golem_config <- function(value = NULL, use_parent = TRUE) {
  config_path <- file.path(dirname(app_sys()), "golem-config.yml")
  if (!file.exists(config_path) && use_parent) {
    config_path <- file.path(app_root(), "inst", "golem-config.yml")
  }
  if (!file.exists(config_path)) {
    return(NULL)
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("The yaml package is required to read golem-config.yml")
  }
  config <- yaml::read_yaml(config_path)
  if (is.list(config$default)) {
    config <- config$default
  }
  if (is.null(value)) {
    return(config)
  }
  config[[value]]
}

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
