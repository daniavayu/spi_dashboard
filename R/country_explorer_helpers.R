spi_explorer_filter <- function(
  snapshot,
  year = NULL,
  region = NULL,
  income_group = NULL,
  country_search = NULL
) {
  base <- spi_explorer_base(snapshot)
  available_years <- sort(unique(base$data$year[!is.na(base$data$year)]))
  available_years <- available_years[!is.na(available_years)]
  selected_year <- if (length(available_years) == 0L) {
    NA_integer_
  } else if (is.null(year) || !year %in% available_years) {
    max(available_years)
  } else {
    as.integer(year)
  }
  result <- base$data[base$data$year == selected_year, , drop = FALSE]
  if (!is.null(region) && nzchar(region)) {
    result <- result[!is.na(result$region) & result$region == region, , drop = FALSE]
  }
  if (!is.null(income_group) && nzchar(income_group)) {
    result <- result[
      !is.na(result$income_group) & result$income_group == income_group,
      , drop = FALSE
    ]
  }
  if (!is.null(country_search) && nzchar(country_search)) {
    pattern <- tolower(country_search)
    matches <- grepl(pattern, tolower(result$country_name), fixed = TRUE)
    result <- result[!is.na(matches) & matches, , drop = FALSE]
  }
  rownames(result) <- NULL
  list(
    data = result,
    available_years = available_years,
    selected_year = selected_year,
    status = base$status
  )
}

spi_explorer_metric_rows <- function(base, metric_columns, prefix, label_prefix) {
  if (length(metric_columns) == 0L || nrow(base) == 0L) {
    return(spi_explorer_empty_table()[0, , drop = FALSE])
  }
  rows <- vector("list", length(metric_columns))
  for (position in seq_along(metric_columns)) {
    column <- metric_columns[[position]]
    metric_id <- sub(paste0("^", prefix), "", column)
    metric_id <- sub("_score$", "", metric_id)
    metric_id <- gsub("_", ".", metric_id, fixed = TRUE)
    rows[[position]] <- data.frame(
      country_code = base$country_code,
      country_name = base$country_name,
      year = base$year,
      region = base$region,
      income_group = base$income_group,
      overall_spi = base$overall_spi,
      metric_id = metric_id,
      metric_label = paste(label_prefix, metric_id),
      metric_score = suppressWarnings(as.numeric(base[[column]])),
      change = NA_real_,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

spi_explorer_view <- function(
  snapshot,
  view = c("pillars", "dimensions", "indicators"),
  year = NULL,
  region = NULL,
  income_group = NULL,
  country_search = NULL,
  indicator_id = NULL
) {
  view <- match.arg(view)
  filtered <- spi_explorer_filter(
    snapshot, year = year, region = region,
    income_group = income_group, country_search = country_search
  )
  base <- filtered$data
  if (view == "pillars") {
    columns <- grep("^pillar_[0-9]+_score$", names(base), value = TRUE)
    data <- spi_explorer_metric_rows(base, columns, "pillar_", "Pillar")
  } else if (view == "dimensions") {
    columns <- grep("^dimension_[0-9]+_[0-9]+_score$", names(base), value = TRUE)
    data <- spi_explorer_metric_rows(base, columns, "dimension_", "Dimension")
  } else {
    indicators <- snapshot$indicators
    if (!is.data.frame(indicators) || nrow(indicators) == 0L) {
      data <- spi_explorer_empty_table()[0, , drop = FALSE]
    } else {
      if (is.null(indicator_id) || !nzchar(indicator_id)) {
        indicator_id <- indicators$indicator_id[[1L]]
      }
      indicators <- indicators[indicators$indicator_id == indicator_id, , drop = FALSE]
      indicators <- indicators[indicators$year == filtered$selected_year, , drop = FALSE]
      match_row <- match(indicators$country_code, base$country_code)
      keep <- !is.na(match_row)
      indicators <- indicators[keep, , drop = FALSE]
      match_row <- match_row[keep]
      data <- data.frame(
        country_code = indicators$country_code,
        country_name = indicators$country_name,
        year = indicators$year,
        region = base$region[match_row],
        income_group = base$income_group[match_row],
        overall_spi = base$overall_spi[match_row],
        metric_id = indicators$indicator_id,
        metric_label = indicators$indicator_label,
        metric_score = indicators$score,
        change = NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  if (nrow(data) > 0L && nrow(snapshot$index) > 0L) {
    prior_year <- data$year - 1L
    prior_key <- paste(data$country_code, prior_year, sep = "_")
    index_key <- paste(snapshot$index$country_code, snapshot$index$year, sep = "_")
    prior_row <- match(prior_key, index_key)
    prior_score <- snapshot$index$score[prior_row]
    data$change <- ifelse(
      !is.na(data$metric_score) & !is.na(prior_score),
      data$metric_score - prior_score,
      NA_real_
    )
  }
  rownames(data) <- NULL
  list(
    data = data,
    available_years = filtered$available_years,
    selected_year = filtered$selected_year,
    status = filtered$status
  )
}

spi_explorer_summary <- function(data) {
  values <- suppressWarnings(as.numeric(data$metric_score))
  values <- values[!is.na(values)]
  if (length(values) == 0L) {
    return(list(average = NA_real_, median = NA_real_, standard_deviation = NA_real_))
  }
  list(
    average = mean(values),
    median = stats::median(values),
    standard_deviation = if (length(values) > 1L) stats::sd(values) else 0
  )
}
