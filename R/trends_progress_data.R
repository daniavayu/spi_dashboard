trends_empty_result <- function(status = "empty") {
  list(data = data.frame(stringsAsFactors = FALSE), status = status)
}

trends_deduplicate <- function(data) {
  if (!is.data.frame(data) || !nrow(data)) return(data)
  required <- c("country_code", "year")
  if (!all(required %in% names(data))) return(data)
  data$.row_order <- seq_len(nrow(data))
  score_columns <- grep("score$", names(data), value = TRUE)
  completeness <- if (length(score_columns)) {
    rowSums(!is.na(data[score_columns]))
  } else {
    rep(0L, nrow(data))
  }
  data <- data[order(data$country_code, data$year, -completeness, data$.row_order), , drop = FALSE]
  data <- data[!duplicated(data[c("country_code", "year")]), , drop = FALSE]
  data$.row_order <- NULL
  rownames(data) <- NULL
  data
}

trends_metric_catalog <- function(index) {
  if (!is.data.frame(index)) return(data.frame(id = character(), label = character(), column = character(), stringsAsFactors = FALSE))
  pillar_columns <- grep("^pillar_[0-9]+_score$", names(index), value = TRUE)
  data.frame(
    id = c("overall", sub("_score$", "", pillar_columns)),
    label = c("Overall SPI", paste("Pillar", sub("^pillar_", "", sub("_score$", "", pillar_columns)))),
    column = c("score", pillar_columns),
    stringsAsFactors = FALSE
  )
}

trends_available_years <- function(snapshot) {
  index <- snapshot$index
  if (!is.data.frame(index) || !nrow(index) || !"year" %in% names(index)) return(integer())
  years <- suppressWarnings(as.integer(index$year))
  sort(unique(years[!is.na(years) & !is.na(index$score)]))
}

trends_group_catalog <- function(snapshot) {
  aggregates <- snapshot$aggregates
  result <- data.frame(code = character(), name = character(), source_id = character(), source = character(), stringsAsFactors = FALSE)
  if (is.data.frame(aggregates) && nrow(aggregates)) {
    valid <- !is.na(aggregates$group_code) & nzchar(aggregates$group_code) &
      !is.na(aggregates$score) & !is.na(aggregates$year)
    if (any(valid)) {
      result <- data.frame(
        code = as.character(aggregates$group_code[valid]),
        name = as.character(aggregates$group_name[valid]),
        source_id = as.character(aggregates$source_id[valid]),
        source = "official_aggregate",
        stringsAsFactors = FALSE
      )
    }
  }
  metadata <- snapshot$metadata
  if (is.data.frame(metadata) && nrow(metadata)) {
    for (field in c("region", "income_group", "lending_type", "admin_region")) {
      if (field %in% names(metadata)) {
        values <- unique(as.character(metadata[[field]]))
        values <- values[!is.na(values) & nzchar(values)]
        if (length(values)) {
          metadata_rows <- data.frame(
            code = values, name = values, source_id = field,
            source = "metadata", stringsAsFactors = FALSE
          )
          result <- rbind(result, metadata_rows)
        }
      }
    }
  }
  if (!nrow(result)) return(result)

  result$code_key <- trimws(tolower(as.character(result$code)))
  result <- result[!duplicated(result$code_key), , drop = FALSE]
  result$code_key <- NULL
  rownames(result) <- NULL
  result
}

trends_period_changes <- function(index, metric_column, start_year, end_year) {
  empty <- data.frame(country_code = character(), country_name = character(), start_value = numeric(), end_value = numeric(), change = numeric(), stringsAsFactors = FALSE)
  if (!is.data.frame(index) || !metric_column %in% names(index)) return(empty)
  data <- trends_deduplicate(index)
  data <- data[data$year %in% c(start_year, end_year), , drop = FALSE]
  if (!nrow(data)) return(empty)
  start <- data[data$year == start_year, c("country_code", "country_name", metric_column), drop = FALSE]
  end <- data[data$year == end_year, c("country_code", "country_name", metric_column), drop = FALSE]
  names(start)[3] <- "start_value"
  names(end)[3] <- "end_value"
  result <- merge(start, end, by = "country_code", suffixes = c("_start", "_end"))
  result$country_name <- ifelse(!is.na(result$country_name_end), result$country_name_end, result$country_name_start)
  result$change <- result$end_value - result$start_value
  result <- result[!is.na(result$start_value) & !is.na(result$end_value), c("country_code", "country_name", "start_value", "end_value", "change"), drop = FALSE]
  result[order(-result$change, result$country_code), , drop = FALSE]
}

trends_pillar_stability <- function(index, metric_column, start_year, end_year) {
  if (!is.data.frame(index) || !metric_column %in% names(index)) return(list(value = NA_real_, countries = 0L, changes = 0L, status = "unavailable"))
  data <- trends_deduplicate(index)
  data <- data[data$year >= start_year & data$year <= end_year, c("country_code", "year", metric_column), drop = FALSE]
  changes <- numeric()
  countries <- character()
  for (code in unique(data$country_code)) {
    rows <- data[data$country_code == code & !is.na(data[[metric_column]]), , drop = FALSE]
    rows <- rows[order(rows$year), , drop = FALSE]
    if (nrow(rows) >= 2L) {
      delta <- diff(rows[[metric_column]])
      changes <- c(changes, delta)
      countries <- c(countries, rep(code, length(delta)))
    }
  }
  if (length(changes) < 2L) return(list(value = NA_real_, countries = length(unique(countries)), changes = length(changes), status = "insufficient_data"))
  list(value = stats::sd(changes), countries = length(unique(countries)), changes = length(changes), status = "ok")
}

trends_pillar_stability_summary <- function(index, metrics, start_year, end_year) {
  metrics <- metrics[metrics$column != "score", , drop = FALSE]
  if (!nrow(metrics)) return(data.frame())
  result <- do.call(rbind, lapply(seq_len(nrow(metrics)), function(row) {
    value <- trends_pillar_stability(index, metrics$column[[row]], start_year, end_year)
    data.frame(
      label = metrics$label[[row]], column = metrics$column[[row]],
      value = value$value, changes = value$changes,
      countries = value$countries, status = value$status,
      stringsAsFactors = FALSE
    )
  }))
  result[order(result$value, na.last = TRUE), , drop = FALSE]
}

trends_pillar_associations <- function(index, columns) {
  pairs <- utils::combn(columns, 2L, simplify = FALSE)
  if (!length(pairs)) return(data.frame(pillar_1 = character(), pillar_2 = character(), correlation = numeric(), observations = integer(), status = character(), stringsAsFactors = FALSE))
  do.call(rbind, lapply(pairs, function(pair) {
    valid <- complete.cases(index[, pair, drop = FALSE])
    values <- index[valid, pair, drop = FALSE]
    enough <- nrow(values) >= 3L && stats::sd(values[[1L]]) > 0 && stats::sd(values[[2L]]) > 0
    data.frame(pillar_1 = pair[[1L]], pillar_2 = pair[[2L]], correlation = if (enough) stats::cor(values[[1L]], values[[2L]], method = "pearson") else NA_real_, observations = nrow(values), status = if (enough) "ok" else "insufficient_data", stringsAsFactors = FALSE)
  }))
}

trends_annual_summary <- function(index, metric_column) {
  if (!is.data.frame(index) || !metric_column %in% names(index)) return(data.frame())
  data <- trends_deduplicate(index)
  years <- sort(unique(data$year[!is.na(data$year)]))
  do.call(rbind, lapply(years, function(year) {
    values <- data[data$year == year, metric_column]
    valid <- !is.na(values)
    data.frame(year = year, median = if (any(valid)) stats::median(values[valid]) else NA_real_, iqr = if (sum(valid) > 1L) stats::IQR(values[valid]) else NA_real_, contributors = sum(valid), countries = nrow(data[data$year == year, , drop = FALSE]), stringsAsFactors = FALSE)
  }))
}

trends_group_annual_summary <- function(snapshot, metric_column, group_code) {
  if (identical(group_code, "global")) return(trends_annual_summary(snapshot$index, metric_column))
  aggregates <- snapshot$aggregates
  if (is.data.frame(aggregates) && nrow(aggregates)) {
    source_id <- if (identical(metric_column, "score")) {
      "SPI.INDEX"
    } else {
      sub("^pillar_([0-9]+)_score$", "SPI.INDEX.PIL\\1", metric_column)
    }
    rows <- aggregates[
      aggregates$group_code == group_code &
        aggregates$source_id == source_id &
        !is.na(aggregates$score) & !is.na(aggregates$year),
      ,
      drop = FALSE
    ]
    rows <- rows[!duplicated(rows$year), , drop = FALSE]
    if (nrow(rows)) {
      return(data.frame(
        year = rows$year, median = rows$score, iqr = NA_real_,
        contributors = NA_integer_, countries = NA_integer_,
        stringsAsFactors = FALSE
      ))
    }
  }
  metadata <- snapshot$metadata
  if (!is.data.frame(metadata) || !nrow(metadata)) return(data.frame())
  field <- if (group_code %in% metadata$region) "region" else if (group_code %in% metadata$income_group) "income_group" else if ("lending_type" %in% names(metadata) && group_code %in% metadata$lending_type) "lending_type" else if ("admin_region" %in% names(metadata) && group_code %in% metadata$admin_region) "admin_region" else NULL
  if (is.null(field)) return(data.frame())
  index <- trends_deduplicate(snapshot$index)
  joined <- merge(index, metadata[c("country_code", field)], by = "country_code")
  joined <- joined[joined[[field]] == group_code, , drop = FALSE]
  trends_annual_summary(joined, metric_column)
}
