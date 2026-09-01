spi_compare_canonicalize_selection <- function(countries, catalog) {
  values <- unique(toupper(trimws(as.character(countries))))
  values <- values[nzchar(values) & !is.na(values)]
  catalog_values <- if (is.data.frame(catalog)) {
    code_col <- intersect(c("country_code", "iso3c"), names(catalog))
    if (length(code_col) == 0L) character() else catalog[[code_col[[1L]]]]
  } else {
    catalog
  }
  catalog_values <- unique(toupper(trimws(as.character(catalog_values))))
  invalid <- setdiff(values, catalog_values)
  if (length(values) == 0L) {
    return(list(ok = FALSE, countries = character(), error = "Select at least two countries."))
  }
  if (length(invalid) > 0L) {
    return(list(
      ok = FALSE, countries = values,
      error = paste("Invalid country code(s):", paste(invalid, collapse = ", "))
    ))
  }
  if (length(values) < 2L || length(values) > 3L) {
    return(list(
      ok = FALSE, countries = values,
      error = "Select exactly two or three countries."
    ))
  }
  list(ok = TRUE, countries = values, error = NULL)
}

spi_compare_global_year <- function(index, countries) {
  if (!is.data.frame(index) || !all(c("country_code", "year") %in% names(index))) {
    return(NA_integer_)
  }
  selected <- toupper(trimws(as.character(countries)))
  years <- suppressWarnings(as.integer(index$year))
  codes <- toupper(trimws(as.character(index$country_code)))
  years <- years[codes %in% selected & !is.na(years)]
  if (length(years) == 0L) NA_integer_ else max(years)
}

spi_compare_metrics <- function() {
  c("overall", paste0("pillar_", 1:5))
}

spi_compare_metric_column <- function(metric) {
  metric <- as.character(metric)[[1L]]
  if (identical(metric, "overall")) return("score")
  if (grepl("^pillar_[1-5]$", metric)) {
    return(paste0(metric, "_score"))
  }
  stop("Unsupported comparison metric: ", metric, call. = FALSE)
}

spi_compare_filter_dimensions <- function(data, dimension_ids = NULL) {
  if (!is.data.frame(data) || is.null(dimension_ids) || length(dimension_ids) == 0L) {
    return(data)
  }
  data[as.character(data$dimension_id) %in% as.character(dimension_ids), , drop = FALSE]
}
