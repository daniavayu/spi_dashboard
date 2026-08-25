spi_profile_statuses <- c(
  "pending", "ok", "partial", "empty", "unavailable", "error"
)

#' Resolve human-readable dimension names for the Country Profile
#'
#' Looks up each `dimension_id` (e.g. `"1.5"`) in the metadata hierarchy
#' lookup and returns its descriptive name (e.g.
#' `"Data use by international organisations"`). Falls back to the
#' generic `fallback_label` (e.g. `"Dimension 1.5"`) when the lookup is
#' unavailable or has no match, so the UI never shows a blank label.
#'
#' @param dimension_ids Character vector of dimension IDs to resolve.
#' @param fallback_labels Character vector of fallback labels, recycled
#'   alongside `dimension_ids`.
#' @param dimension_labels A lookup `data.frame` with `dimension_id` and
#'   `dimension_label` columns, as produced by
#'   `spi_normalize_dimension_labels()`.
#' @return A character vector the same length as `dimension_ids`.
#' @keywords internal
spi_profile_dimension_names <- function(
  dimension_ids,
  fallback_labels,
  dimension_labels
) {
  if (!is.data.frame(dimension_labels) || nrow(dimension_labels) == 0L ||
    !all(c("dimension_id", "dimension_label") %in% names(dimension_labels))
  ) {
    return(fallback_labels)
  }
  requested <- sub("^D", "", as.character(dimension_ids), ignore.case = TRUE)
  requested <- sub("^SPI\\.DIM", "", requested, ignore.case = TRUE)
  requested <- sub("\\.INDEX$", "", requested, ignore.case = TRUE)
  lookup_ids <- sub("^D", "", as.character(dimension_labels$dimension_id),
    ignore.case = TRUE)
  lookup_ids <- sub("^SPI\\.DIM", "", lookup_ids, ignore.case = TRUE)
  lookup_ids <- sub("\\.INDEX$", "", lookup_ids, ignore.case = TRUE)
  matched <- dimension_labels$dimension_label[
    match(requested, lookup_ids)
  ]
  ifelse(is.na(matched) | !nzchar(matched), fallback_labels, matched)
}

spi_profile_find_column <- function(data, aliases, required = TRUE) {
  found <- aliases[aliases %in% names(data)]
  if (length(found) > 0L) {
    return(found[[1L]])
  }
  if (isTRUE(required)) {
    stop(
      "Profile data is missing one of: ",
      paste(aliases, collapse = ", "),
      call. = FALSE
    )
  }
  NULL
}

spi_profile_empty_overall <- function() {
  data.frame(
    country_code = character(), country_name = character(),
    year = integer(), score = numeric(),
    stringsAsFactors = FALSE
  )
}

spi_profile_keys <- function(data) {
  if (!is.data.frame(data) || nrow(data) == 0L ||
    !all(c("country_code", "year") %in% names(data))) {
    return(character())
  }
  paste(as.character(data$country_code), as.integer(data$year), sep = "|")
}

spi_profile_section_result <- function(
  data,
  status = NULL,
  message = NULL,
  coverage = NULL,
  source = NULL,
  requested_keys = NULL
) {
  if (!is.data.frame(data)) {
    data <- data.frame(stringsAsFactors = FALSE)
  }
  if (!is.null(status) && !status %in% spi_profile_statuses) {
    stop("Unknown Profile section status: ", status, call. = FALSE)
  }

  available_keys <- unique(spi_profile_keys(data))
  requested_key_values <- unique(spi_profile_keys(requested_keys))
  missing_keys <- setdiff(requested_key_values, available_keys)
  if (is.null(status)) {
    status <- if (length(available_keys) == 0L) {
      "empty"
    } else if (length(missing_keys) > 0L) {
      "partial"
    } else {
      "ok"
    }
  }
  if (is.null(coverage)) {
    coverage <- list(
      requested = length(requested_key_values),
      available = length(available_keys),
      missing = length(missing_keys)
    )
  }
  if (is.null(message)) {
    message <- switch(
      status,
      pending = "Loading Profile data.",
      ok = NULL,
      partial = "Some requested Profile data is unavailable.",
      empty = "No matching Profile data was returned.",
      unavailable = "This Profile section is unavailable.",
      error = "Profile data could not be loaded.",
      NULL
    )
  }
  list(
    data = data,
    status = status,
    message = message,
    coverage = coverage,
    source = source
  )
}

spi_profile_prepare_overall <- function(
  data,
  country_code = NULL,
  requested_keys = NULL,
  source = "spiR"
) {
  result <- tryCatch({
    if (!is.data.frame(data) || nrow(data) == 0L) {
      return(spi_profile_section_result(
        spi_profile_empty_overall(),
        source = source,
        requested_keys = requested_keys
      ))
    }
    code_col <- spi_profile_find_column(data, c("iso3c", "country_code"))
    name_col <- spi_profile_find_column(
      data, c("country", "country_name"), required = FALSE
    )
    year_col <- spi_profile_find_column(data, c("date", "year", "Year"))
    score_col <- spi_profile_find_column(
      data, c("SPI.INDEX", "spi_index", "score")
    )
    country_values <- as.character(data[[code_col]])
    if (!is.null(country_code)) {
      data <- data[country_values %in% as.character(country_code), ,
        drop = FALSE
      ]
    }
    normalized <- data.frame(
      country_code = as.character(data[[code_col]]),
      country_name = if (is.null(name_col)) {
        as.character(data[[code_col]])
      } else {
        as.character(data[[name_col]])
      },
      year = suppressWarnings(as.integer(as.character(data[[year_col]]))),
      score = suppressWarnings(as.numeric(data[[score_col]])),
      stringsAsFactors = FALSE
    )
      raw_pillar_columns <- grep("^SPI\\.INDEX\\.PIL[0-9]+$", names(data),
        value = TRUE
      )
      normalized_pillar_columns <- grep("^pillar_[0-9]+_score$", names(data),
        value = TRUE
      )
      for (column in raw_pillar_columns) {
      pillar_id <- sub("^SPI\\.INDEX\\.PIL", "", column)
      normalized[[paste0("pillar_", pillar_id, "_score")]] <-
        suppressWarnings(as.numeric(data[[column]]))
    }
      for (column in normalized_pillar_columns) {
        normalized[[column]] <- suppressWarnings(as.numeric(data[[column]]))
      }
      raw_dimension_columns <- grep(
        "^SPI\\.DIM[0-9]+\\.[0-9]+\\.INDEX$", names(data), value = TRUE
      )
      normalized_dimension_columns <- grep(
        "^dimension_[0-9]+_[0-9]+_score$", names(data), value = TRUE
      )
      for (column in raw_dimension_columns) {
        dimension_id <- sub("^SPI\\.DIM", "", column)
        dimension_id <- sub("\\.INDEX$", "", dimension_id)
        normalized[[paste0(
          "dimension_", gsub("\\.", "_", dimension_id), "_score"
        )]] <- suppressWarnings(as.numeric(data[[column]]))
      }
      for (column in normalized_dimension_columns) {
        normalized[[column]] <- suppressWarnings(as.numeric(data[[column]]))
      }
    key <- spi_profile_keys(normalized)
    normalized <- normalized[!duplicated(key), , drop = FALSE]
    rownames(normalized) <- NULL
    spi_profile_section_result(
      normalized,
      source = source,
      requested_keys = requested_keys
    )
  }, error = function(error) {
    spi_profile_section_result(
      spi_profile_empty_overall(),
      status = "error",
      message = conditionMessage(error),
      source = source,
      requested_keys = requested_keys
    )
  })
  result
}

spi_profile_metric_rows <- function(data, columns, prefix, label_prefix) {
  if (!is.data.frame(data) || nrow(data) == 0L || length(columns) == 0L) {
    return(data.frame(
      metric_id = character(), metric_label = character(),
      country_code = character(), country_name = character(),
      year = integer(), score = numeric(), stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(columns, function(column) {
    metric_id <- sub(prefix, "", column)
    metric_id <- sub("_score$", "", metric_id)
    metric_id <- gsub("_", ".", metric_id, fixed = TRUE)
    score <- suppressWarnings(as.numeric(data[[column]]))
    if (identical(prefix, "dimension_") &&
      any(!is.na(score)) && max(abs(score), na.rm = TRUE) <= 1) {
      score <- score * 100
    }
    data.frame(
      metric_id = metric_id,
      metric_label = paste(label_prefix, metric_id),
      country_code = data$country_code,
      country_name = data$country_name,
      year = data$year,
      score = score,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

spi_profile_operation_result <- function(snapshot, name, data, source) {
  operation <- snapshot$operation_status[[name]]
  if (!is.null(operation) && identical(operation$status, "unavailable")) {
    return(spi_profile_section_result(
      data[FALSE, , drop = FALSE], status = "unavailable",
      message = operation$error, source = source
    ))
  }
  if (!is.null(operation) && identical(operation$status, "error")) {
    return(spi_profile_section_result(
      data[FALSE, , drop = FALSE], status = "error",
      message = operation$error, source = source
    ))
  }
  spi_profile_section_result(data, source = source)
}

spi_profile_lookup_labels <- function(
  ids, fallback_labels, lookup, id_col, label_col
) {
  if (!is.data.frame(lookup) || nrow(lookup) == 0L ||
    !all(c(id_col, label_col) %in% names(lookup))) {
    return(fallback_labels)
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
  labels <- as.character(lookup[[label_col]])[
    match(requested, lookup_ids)
  ]
  ifelse(is.na(labels) | !nzchar(labels), fallback_labels, labels)
}

spi_profile_sections_from_snapshot <- function(snapshot) {
  overall <- spi_profile_prepare_overall(snapshot$index)
  countries <- unique(overall$data[c("country_code", "country_name")])
  pillar_columns <- grep("^pillar_[0-9]+_score$", names(overall$data),
    value = TRUE
  )
  dimension_columns <- grep("^dimension_[0-9]+_[0-9]+_score$",
    names(overall$data), value = TRUE
  )
  pillars <- spi_profile_operation_result(
    snapshot,
    "index",
    spi_profile_metric_rows(overall$data, pillar_columns, "pillar_", "Pillar"),
    snapshot$provider
  )
  if (nrow(pillars$data) > 0L && is.data.frame(snapshot$pillar_labels)) {
    pillars$data$metric_label <- spi_profile_lookup_labels(
      pillars$data$metric_id, pillars$data$metric_label,
      snapshot$pillar_labels, "pillar_id", "pillar_label"
    )
  }
  dimension_data <- spi_profile_metric_rows(
    overall$data, dimension_columns, "dimension_", "Dimension"
  )
  if (nrow(dimension_data) > 0L) {
    dimension_data$dimension_id <- dimension_data$metric_id
    dimension_data$dimension_label <- spi_profile_dimension_names(
      dimension_data$metric_id, dimension_data$metric_label,
      snapshot$dimension_labels
    )
  }
  dimensions <- spi_profile_operation_result(
    snapshot, "index", dimension_data, snapshot$provider
  )
  indicators <- spi_profile_operation_result(
    snapshot, "indicators", snapshot$indicators, snapshot$provider
  )
  if (nrow(indicators$data) > 0L && is.data.frame(snapshot$indicator_labels)) {
    indicators$data$indicator_label <- spi_profile_lookup_labels(
      indicators$data$indicator_id, indicators$data$indicator_label,
      snapshot$indicator_labels, "indicator_id", "indicator_label"
    )
  }
  benchmarks <- spi_profile_operation_result(
    snapshot, "aggregates", snapshot$aggregates, snapshot$provider
  )
  radar <- spi_profile_section_result(
    data.frame(), status = "pending", source = snapshot$provider
  )
  trend <- spi_profile_section_result(
    overall$data, source = snapshot$provider
  )
  list(
    countries = countries,
    overall = overall,
    trend = trend,
    radar = radar,
    radar_index = overall$data,
    radar_metadata = snapshot$metadata,
    pillars = pillars,
    dimensions = dimensions,
    indicators = indicators,
    benchmarks = benchmarks
  )
}
