spi_profile_select_year <- function(
  data,
  country_code,
  year = NULL,
  metric = "score"
) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    return(list(data = data.frame(), available_years = integer(),
      selected_year = NA_integer_))
  }
  selected_data <- data[
    as.character(data$country_code) == as.character(country_code),
    , drop = FALSE
  ]
  metric_values <- suppressWarnings(as.numeric(selected_data[[metric]]))
  available_years <- sort(unique(
    as.integer(selected_data$year)[!is.na(selected_data$year) &
      !is.na(metric_values)]
  ))
  selected_year <- if (length(available_years) == 0L) {
    NA_integer_
  } else if (!is.null(year) && as.integer(year) %in% available_years) {
    as.integer(year)
  } else {
    max(available_years)
  }
  result <- selected_data[selected_data$year == selected_year, , drop = FALSE]
  rownames(result) <- NULL
  list(
    data = result,
    available_years = available_years,
    selected_year = selected_year
  )
}

spi_profile_format_value <- function(value, digits = 1L) {
  if (length(value) == 0L || is.na(value[[1L]])) {
    return("-")
  }
  format(round(as.numeric(value[[1L]]), digits), nsmall = digits,
    trim = TRUE)
}

spi_profile_prepare_trend <- function(data, country_code) {
  selected <- data[
    as.character(data$country_code) == as.character(country_code),
    , drop = FALSE
  ]
  selected$year <- suppressWarnings(as.integer(selected$year))
  selected$score <- suppressWarnings(as.numeric(selected$score))
  selected <- selected[order(selected$year), , drop = FALSE]
  if (requireNamespace("spiR", quietly = TRUE) &&
      exists("spi_change", asNamespace("spiR"), inherits = FALSE)) {
    selected <- spiR::spi_change(
      selected,
      value_col = "score",
      group_cols = "country_code",
      year_col = "year"
    )
    valid <- which(!is.na(selected$year) & !is.na(selected$score))
    if (length(valid) > 0L) {
      selected$change_first[[valid[[1L]]]] <- NA_real_
    }
  } else {
    selected$change_previous <- NA_real_
    selected$change_first <- NA_real_
    valid <- which(!is.na(selected$year) & !is.na(selected$score))
    if (length(valid) > 0L) {
      first_score <- selected$score[valid[[1L]]]
      for (position in seq_along(valid)) {
        row_number <- valid[[position]]
        if (position > 1L) {
          previous_row <- valid[[position - 1L]]
          selected$change_previous[[row_number]] <-
            selected$score[[row_number]] - selected$score[[previous_row]]
          selected$change_first[[row_number]] <-
            selected$score[[row_number]] - first_score
        }
      }
    }
  }
  rownames(selected) <- NULL
  selected[selected$year %in% selected$year[valid], , drop = FALSE]
}

spi_profile_prepare_dimension_extremes <- function(
  data,
  year,
  coverage_threshold = 0.5,
  limit = 3L
) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    empty <- data[FALSE, , drop = FALSE]
    return(list(highest = empty, lowest = empty))
  }
  selected <- data[data$year == as.integer(year), , drop = FALSE]
  if (!"coverage" %in% names(selected)) {
    selected$coverage <- 1
  }
  selected$score <- suppressWarnings(as.numeric(selected$score))
  selected <- selected[
    !is.na(selected$score) & selected$coverage >= coverage_threshold,
    , drop = FALSE
  ]
  high_order <- selected[order(-selected$score, selected$dimension_id), ,
    drop = FALSE
  ]
  low_order <- selected[order(selected$score, selected$dimension_id), ,
    drop = FALSE
  ]
  low_count <- min(as.integer(limit), floor(nrow(selected) / 2L))
  high_count <- min(as.integer(limit), nrow(selected) - low_count)
  highest <- head(high_order, high_count)
  lowest <- head(low_order, low_count)
  rownames(highest) <- NULL
  rownames(lowest) <- NULL
  list(highest = highest, lowest = lowest)
}

spi_profile_prepare_benchmarks <- function(
  data,
  year,
  source_id = "SPI.INDEX"
) {
  empty <- if (is.data.frame(data)) data[FALSE, , drop = FALSE] else data.frame()
  if (!is.data.frame(data) || nrow(data) == 0L) {
    return(list(
      data = empty, status = "empty", message = "No benchmark data.",
      coverage = list(requested = 0L, available = 0L, missing = 0L),
      source = "spiR"
    ))
  }
  required <- c("group_code", "group_name", "year", "source_id", "score")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0L) {
    return(list(
      data = empty, status = "error",
      message = paste("Benchmark data is missing:", paste(missing, collapse = ", ")),
      coverage = list(requested = 0L, available = 0L, missing = 0L),
      source = "spiR"
    ))
  }
  result <- data[
    data$year == as.integer(year) & data$source_id %in% source_id &
      data$group_code %in% c("AFE", "AFW", "ARB", "CEB", "CSS", "EAP",
        "EAR", "EAS", "ECA", "ECS", "EMU", "EUU", "FCS", "HIC", "HPC",
        "IBD", "IBT", "IDA", "IDB", "IDX", "LAC", "LCN", "LDC", "LIC",
        "LMC", "LMY", "LTE", "MEA", "MIC", "MNA", "NAC", "OED", "OSS",
        "PRE", "PSS", "PST", "SAS", "SSA", "SSF", "SST", "TEA", "TEC",
        "TLA", "TMN", "TSA", "TSS", "UMC", "WLD"),
    , drop = FALSE
  ]
  result <- result[!duplicated(result$group_code), , drop = FALSE]
  status <- if (nrow(result) == 0L) "empty" else "ok"
  rownames(result) <- NULL
  list(
    data = result,
    status = status,
    message = if (status == "empty") "No official overall benchmarks." else NULL,
    coverage = list(requested = 1L, available = nrow(result), missing = 0L),
    source = "spiR"
  )
}
