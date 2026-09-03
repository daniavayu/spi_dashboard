spi_explorer_normalize_text <- function(value) {
  value <- as.character(value)
  value <- trimws(value)
  value <- iconv(value, to = "ASCII//TRANSLIT", sub = "")
  value <- tolower(value)
  value <- gsub("[[:space:]]+", " ", value)
  value <- gsub("[-_]+", " ", value)
  value
}

spi_explorer_country_match <- function(search_terms, country_names, country_codes) {
  if (length(search_terms) == 0L) return(rep(FALSE, length(country_names)))
  normalized_names <- spi_explorer_normalize_text(country_names)
  normalized_codes <- spi_explorer_normalize_text(country_codes)
  matches <- rep(FALSE, length(country_names))
  for (term in search_terms) {
    term <- spi_explorer_normalize_text(term)
    if (!nzchar(term)) next

    exact <- which(normalized_codes == term | normalized_names == term)
    if (length(exact) > 0L) {
      matches[exact] <- TRUE
      next
    }

    substring <- which(grepl(term, normalized_names, fixed = TRUE) |
      grepl(term, normalized_codes, fixed = TRUE))
    if (length(substring) > 0L) {
      matches[substring] <- TRUE
      next
    }

    fuzzy <- unique(c(
      agrep(term, normalized_names, max.distance = 0.12, ignore.case = TRUE),
      agrep(term, normalized_codes, max.distance = 0.12, ignore.case = TRUE)
    ))
    if (length(fuzzy) > 0L) {
      matches[fuzzy] <- TRUE
    }
  }
  matches
}

spi_explorer_filter <- function(
  snapshot,
  year = NULL,
  region = NULL,
  income_group = NULL,
  country_search = NULL,
  selected_countries = NULL
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
  year_data <- base$data[base$data$year == selected_year, , drop = FALSE]
  result <- year_data
  search_countries <- character()
  if (!is.null(country_search) && length(country_search) > 0L) {
    search_countries <- as.character(country_search)
    search_countries <- search_countries[
      !is.na(search_countries) & nzchar(search_countries) &
        search_countries != "__all__"
    ]
  }
  if (length(search_countries) > 0L) {
    country_codes <- as.character(result$country_code)
    country_names <- as.character(result$country_name)
    matched <- spi_explorer_country_match(search_countries, country_names, country_codes)
    result <- result[matched, , drop = FALSE]
  } else {
    if (!is.null(region) && nzchar(region)) {
      result <- result[
        !is.na(result$region) & result$region == region, , drop = FALSE
      ]
    }
    if (!is.null(income_group) && nzchar(income_group)) {
      result <- result[
        !is.na(result$income_group) & result$income_group == income_group,
        , drop = FALSE
      ]
    }
  }
  selected_for_compare <- as.character(selected_countries)
  selected_for_compare <- selected_for_compare[
    !is.na(selected_for_compare) & nzchar(selected_for_compare) &
      selected_for_compare != "__all__"
  ]
  if (length(selected_for_compare) > 0L && length(search_countries) == 0L) {
    selected_rows <- year_data[
      as.character(year_data$country_code) %in% selected_for_compare,
      , drop = FALSE
    ]
    result <- unique(rbind(result, selected_rows))
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
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

spi_explorer_lookup_labels <- function(ids, fallback, lookup, id_col, label_col) {
  if (!is.data.frame(lookup) || nrow(lookup) == 0L ||
    !all(c(id_col, label_col) %in% names(lookup))) {
    return(fallback)
  }
  requested <- as.character(ids)
  lookup_ids <- as.character(lookup[[id_col]])
  if (id_col %in% c("pillar", "pillar_id")) {
    requested <- sub("^P", "", requested, ignore.case = TRUE)
    requested <- sub("^SPI\\.INDEX\\.PIL", "", requested,
      ignore.case = TRUE)
    lookup_ids <- sub("^P", "", lookup_ids, ignore.case = TRUE)
    lookup_ids <- sub("^SPI\\.INDEX\\.PIL", "", lookup_ids,
      ignore.case = TRUE)
  }
  if (id_col %in% c("dimension", "dimension_id")) {
    requested <- sub("^D", "", requested, ignore.case = TRUE)
    requested <- sub("^SPI\\.DIM", "", requested, ignore.case = TRUE)
    requested <- sub("\\.INDEX$", "", requested, ignore.case = TRUE)
    lookup_ids <- sub("^D", "", lookup_ids, ignore.case = TRUE)
    lookup_ids <- sub("^SPI\\.DIM", "", lookup_ids, ignore.case = TRUE)
    lookup_ids <- sub("\\.INDEX$", "", lookup_ids, ignore.case = TRUE)
  }
  labels <- as.character(lookup[[label_col]])[match(requested, lookup_ids)]
  ifelse(is.na(labels) | !nzchar(labels), fallback, labels)
}

spi_explorer_attach_overall_changes <- function(snapshot, data) {
  if (!is.data.frame(data) || nrow(data) == 0L) return(data)
  index <- snapshot$index
  if (!is.data.frame(index) || nrow(index) == 0L) return(data)
  
  if (requireNamespace("spiR", quietly = TRUE) &&
      exists("spi_change", asNamespace("spiR"), inherits = FALSE)) {
    changes <- spiR::spi_change(
      index,
      value_col = "score",
      group_cols = "country_code",
      year_col = "year"
    )
    change_key <- paste(changes$country_code, changes$year, sep = "_")
    data_key <- paste(data$country_code, data$year, sep = "_")
    data$change_previous <- changes$change_previous[match(data_key, change_key)]
    data$change_first <- changes$change_first[match(data_key, change_key)]
    return(data)
  }
  
  index_year <- suppressWarnings(as.integer(index$year))
  data$change_previous <- NA_real_
  data$change_first <- NA_real_
  for (row_number in seq_len(nrow(data))) {
    country_rows <- which(as.character(index$country_code) ==
      as.character(data$country_code[[row_number]]) &
      !is.na(index_year))
    if (length(country_rows) == 0L) next
    country_years <- index_year[country_rows]
    country_scores <- suppressWarnings(as.numeric(index$score[country_rows]))
    current_year <- data$year[[row_number]]
    current_rows <- which(country_years == current_year)
    if (length(current_rows) == 0L) next
    current_score <- country_scores[current_rows[[1L]]]
    valid_rows <- which(!is.na(country_scores))
    if (length(valid_rows) == 0L) next
    first_row <- valid_rows[which.min(country_years[valid_rows])]
    previous_rows <- valid_rows[country_years[valid_rows] < current_year]
    if (length(previous_rows) > 0L && !is.na(current_score)) {
      previous_row <- previous_rows[which.max(country_years[previous_rows])]
      if (!is.na(country_scores[previous_row])) {
        data$change_previous[[row_number]] <-
          current_score - country_scores[previous_row]
      }
    }
    if (!is.na(current_score) && !is.na(country_scores[first_row])) {
      data$change_first[[row_number]] <-
        current_score - country_scores[first_row]
    }
  }
  data
}

spi_explorer_widen_metrics <- function(data) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    return(data)
  }
  if (!all(c("metric_label", "metric_score") %in% names(data))) {
    return(data)
  }

  identity_columns <- intersect(c(
    "country_code", "country_name", "year", "region", "income_group",
    "overall_spi", "change_previous", "change_first"
  ), names(data))
  row_key <- paste(data$country_code, data$year, sep = "_")
  wide_data <- data[!duplicated(row_key), identity_columns, drop = FALSE]
  wide_key <- paste(wide_data$country_code, wide_data$year, sep = "_")

  for (metric_label in unique(data$metric_label)) {
    metric_rows <- data[data$metric_label == metric_label, , drop = FALSE]
    metric_key <- paste(metric_rows$country_code, metric_rows$year, sep = "_")
    wide_data[[metric_label]] <- metric_rows$metric_score[match(wide_key, metric_key)]
  }

  rownames(wide_data) <- NULL
  return(wide_data)
}

spi_explorer_view <- function(
  snapshot,
  view = c("pillars", "dimensions", "indicators"),
  year = NULL,
  region = NULL,
  income_group = NULL,
  country_search = NULL,
  indicator_id = NULL,
  selected_countries = NULL
) {
  view <- match.arg(view)
  filtered <- spi_explorer_filter(
    snapshot, year = year, region = region,
    income_group = income_group, country_search = country_search,
    selected_countries = selected_countries
  )
  base <- filtered$data
  if (view == "pillars") {
    columns <- grep("^pillar_[0-9]+_score$", names(base), value = TRUE)
    if (length(columns) > 0L) {
      data <- spi_explorer_metric_rows(base, columns, "pillar_", "Pillar")
    } else {
      data <- data.frame(
        country_code = base$country_code,
        country_name = base$country_name,
        year = base$year,
        region = base$region,
        income_group = base$income_group,
        overall_spi = base$overall_spi,
        metric_id = "overall",
        metric_label = "Overall SPI",
        metric_score = base$overall_spi,
        stringsAsFactors = FALSE
      )
    }
    data <- spi_explorer_attach_overall_changes(snapshot, data)
  } else if (view == "dimensions") {
    columns <- grep("^dimension_[0-9]+_[0-9]+_score$", names(base), value = TRUE)
    data <- spi_explorer_metric_rows(base, columns, "dimension_", "Dimension")
  } else {
    indicators <- snapshot$indicators
    if (!is.data.frame(indicators) || nrow(indicators) == 0L) {
      data <- spi_explorer_empty_table()[0, , drop = FALSE]
    } else {
      selected_indicators <- as.character(indicator_id)
      selected_indicators <- selected_indicators[
        !is.na(selected_indicators) & nzchar(selected_indicators) &
          selected_indicators != "__all__"
      ]
      if (length(selected_indicators) == 0L) {
        selected_indicators <- unique(indicators$indicator_id)
      }
      indicators <- indicators[
        indicators$indicator_id %in% selected_indicators, , drop = FALSE
      ]
      requested_year <- filtered$selected_year
      keep_rows <- logical(nrow(indicators))
      for (current_indicator in selected_indicators) {
        indicator_rows <- which(
          indicators$indicator_id == current_indicator
        )
        indicator_years <- indicators$year[indicator_rows]
        indicator_years <- indicator_years[!is.na(indicator_years)]
        target_year <- if (requested_year %in% indicator_years) {
          requested_year
        } else if (length(indicator_years) > 0L) {
          max(indicator_years)
        } else {
          requested_year
        }
        keep_rows[indicator_rows] <- indicators$year[indicator_rows] ==
          target_year
      }
      indicators <- indicators[keep_rows, , drop = FALSE]
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
        stringsAsFactors = FALSE
      )
    }
  }
  if (view == "pillars" && nrow(data) > 0L) {
    data$metric_label <- spi_explorer_lookup_labels(
      data$metric_id, data$metric_label, snapshot$pillar_labels,
      "pillar_id", "pillar_label"
    )
  }
  if (view == "dimensions" && nrow(data) > 0L) {
    data$metric_label <- spi_explorer_lookup_labels(
      data$metric_id, data$metric_label, snapshot$dimension_labels,
      "dimension_id", "dimension_label"
    )
  }
  if (view == "indicators" && nrow(data) > 0L) {
    data$metric_label <- spi_explorer_lookup_labels(
      data$metric_id, data$metric_label, snapshot$indicator_labels,
      "indicator_id", "indicator_label"
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
