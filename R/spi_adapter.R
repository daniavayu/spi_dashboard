spi_find_column <- function(data, aliases, required = TRUE) {
  found <- aliases[aliases %in% names(data)]
  if (length(found) > 0L) {
    return(found[[1L]])
  }
  if (required) {
    stop(
      "SPI data is missing one of: ",
      paste(aliases, collapse = ", "),
      call. = FALSE
    )
  }
  NULL
}

spi_empty_index <- function() {
  data.frame(
    country_code = character(), country_name = character(),
    year = integer(), score = numeric(),
    stringsAsFactors = FALSE
  )
}

spi_empty_indicators <- function() {
  data.frame(
    indicator_id = character(), indicator_label = character(),
    pillar_id = character(), pillar_label = character(),
    dimension_id = character(), dimension_label = character(),
    country_code = character(), country_name = character(),
    year = integer(), score = numeric(), raw_value = numeric(),
    stringsAsFactors = FALSE
  )
}

spi_empty_metadata <- function() {
  data.frame(
    country_code = character(), country_name = character(),
    year = integer(), region = character(), income_group = character(),
    stringsAsFactors = FALSE
  )
}

spi_empty_aggregates <- function() {
  data.frame(
    group_code = character(), group_name = character(), year = integer(),
    source_id = character(), score = numeric(),
    stringsAsFactors = FALSE
  )
}

spi_as_year <- function(value) {
  suppressWarnings(as.integer(as.character(value)))
}

spi_normalize_index <- function(data, year = NULL) {
  country_code_col <- spi_find_column(data, c("iso3c", "country_code", "Economy"))
  country_name_col <- spi_find_column(
    data,
    c("country", "country_name", "Economy_name"),
    required = FALSE
  )
  year_col <- spi_find_column(data, c("date", "year", "Year"))
  score_col <- spi_find_column(data, c("SPI.INDEX", "spi_index", "score"))

  result <- data.frame(
    country_code = as.character(data[[country_code_col]]),
    country_name = if (is.null(country_name_col)) {
      as.character(data[[country_code_col]])
    } else {
      as.character(data[[country_name_col]])
    },
    year = spi_as_year(data[[year_col]]),
    score = suppressWarnings(as.numeric(data[[score_col]])),
    stringsAsFactors = FALSE
  )

  pillar_cols <- grep("^SPI\\.INDEX\\.PIL[0-9]+$", names(data), value = TRUE)
  for (column in pillar_cols) {
    pillar_id <- sub("^SPI\\.INDEX\\.PIL", "", column)
    result[[paste0("pillar_", pillar_id, "_score")]] <-
      suppressWarnings(as.numeric(data[[column]]))
  }

  dimension_cols <- grep(
    "^SPI\\.DIM[0-9]+\\.[0-9]+\\.INDEX$",
    names(data),
    value = TRUE
  )
  for (column in dimension_cols) {
    dimension_id <- sub("^SPI\\.DIM", "", column)
    dimension_id <- sub("\\.INDEX$", "", dimension_id)
    result[[paste0("dimension_", gsub("\\.", "_", dimension_id), "_score")]] <-
      suppressWarnings(as.numeric(data[[column]]))
  }

  if (!is.null(year)) {
    result <- result[result$year %in% spi_as_year(year), , drop = FALSE]
  }
  result <- result[!is.na(result$score) & nzchar(result$country_code), , drop = FALSE]
  rownames(result) <- NULL
  result
}

spi_normalize_income_data <- function(index_data, metadata_data, year = NULL) {
  index_code_col <- spi_find_column(index_data, c("iso3c", "country_code"))
  index_name_col <- spi_find_column(
    index_data,
    c("country", "country_name"),
    required = FALSE
  )
  index_year_col <- spi_find_column(index_data, c("date", "year", "Year"))
  score_col <- spi_find_column(index_data, c("SPI.INDEX", "spi_index", "score"))
  metadata_code_col <- spi_find_column(
    metadata_data,
    c("iso3c", "country_code")
  )
  metadata_year_col <- spi_find_column(
    metadata_data,
    c("date", "year", "Year")
  )
  income_col <- spi_find_column(
    metadata_data,
    c("income_level", "income_group", "income_level_name"),
    required = FALSE
  )

  if (is.null(income_col)) {
    return(data.frame(
      country_code = character(), country_name = character(),
      year = integer(), income_group = character(), score = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  result <- data.frame(
    country_code = as.character(index_data[[index_code_col]]),
    country_name = if (is.null(index_name_col)) {
      as.character(index_data[[index_code_col]])
    } else {
      as.character(index_data[[index_name_col]])
    },
    year = spi_as_year(index_data[[index_year_col]]),
    income_group = NA_character_,
    score = suppressWarnings(as.numeric(index_data[[score_col]])),
    stringsAsFactors = FALSE
  )

  metadata_key <- paste(
    as.character(metadata_data[[metadata_code_col]]),
    spi_as_year(metadata_data[[metadata_year_col]]),
    sep = "_"
  )
  index_key <- paste(result$country_code, result$year, sep = "_")
  result$income_group <- as.character(
    metadata_data[[income_col]][match(index_key, metadata_key)]
  )

  if (!is.null(year)) {
    result <- result[result$year %in% spi_as_year(year), , drop = FALSE]
  }
  result <- result[
    !is.na(result$score) & nzchar(result$country_code) &
      !is.na(result$income_group) & nzchar(result$income_group),
    ,
    drop = FALSE
  ]
  rownames(result) <- NULL
  result
}

spi_normalize_indicators <- function(data) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    return(spi_empty_indicators())
  }
  country_code_col <- spi_find_column(data, c("iso3c", "country_code"))
  country_name_col <- spi_find_column(
    data,
    c("country", "country_name"),
    required = FALSE
  )
  year_col <- spi_find_column(data, c("date", "year", "Year"))
  score_cols <- grep("^SPI\\.D[0-9]+\\.", names(data), value = TRUE)
  if (length(score_cols) == 0L) {
    return(spi_empty_indicators())
  }

  row_count <- nrow(data)
  indicator_count <- length(score_cols)
  indicator_parts <- strsplit(score_cols, "\\.", fixed = FALSE)
  pillar_ids <- vapply(indicator_parts, function(parts) {
    if (length(parts) >= 2L) parts[[2L]] else NA_character_
  }, character(1L))
  dimension_ids <- vapply(indicator_parts, function(parts) {
    if (length(parts) >= 3L) {
      paste(parts[[2L]], parts[[3L]], sep = ".")
    } else {
      NA_character_
    }
  }, character(1L))

  score_values <- unlist(lapply(score_cols, function(column) {
    suppressWarnings(as.numeric(data[[column]]))
  }), use.names = FALSE)
  raw_values <- unlist(lapply(score_cols, function(column) {
    raw_column <- sub("^SPI", "RAW", column)
    if (raw_column %in% names(data)) {
      suppressWarnings(as.numeric(data[[raw_column]]))
    } else {
      rep(NA_real_, row_count)
    }
  }), use.names = FALSE)

  result <- data.frame(
    indicator_id = rep(score_cols, each = row_count),
    indicator_label = rep(score_cols, each = row_count),
    pillar_id = rep(pillar_ids, each = row_count),
    pillar_label = rep(pillar_ids, each = row_count),
    dimension_id = rep(dimension_ids, each = row_count),
    dimension_label = rep(dimension_ids, each = row_count),
    country_code = rep(as.character(data[[country_code_col]]), times = indicator_count),
    country_name = rep(if (is.null(country_name_col)) {
      as.character(data[[country_code_col]])
    } else {
      as.character(data[[country_name_col]])
    }, times = indicator_count),
    year = rep(spi_as_year(data[[year_col]]), times = indicator_count),
    score = score_values,
    raw_value = raw_values,
    stringsAsFactors = FALSE
  )
  rownames(result) <- NULL
  return(result)
}

spi_normalize_metadata <- function(data) {
  aliases <- list(
    country_code = c("iso3c", "country_code"),
    country_name = c("country", "country_name"),
    region = c("region", "region_name"),
    income_group = c("income_level", "income_group"),
    year = c("date", "year", "Year")
  )
  spi_find_column(data, aliases$country_code)
  spi_find_column(data, aliases$year)
  result <- data.frame(row.names = seq_len(nrow(data)))
  for (name in names(aliases)) {
    column <- spi_find_column(data, aliases[[name]], required = FALSE)
    result[[name]] <- if (is.null(column)) {
      rep(NA_character_, nrow(data))
    } else if (name == "year") {
      spi_as_year(data[[column]])
    } else {
      as.character(data[[column]])
    }
  }
  result
}

spi_normalize_aggregates <- function(data, year = NULL) {
  code_col <- spi_find_column(data, c("iso3c", "country_code"))
  name_col <- spi_find_column(data, c("country", "country_name"))
  year_col <- spi_find_column(data, c("date", "year", "Year"))
  source_col <- spi_find_column(data, c("source_id", "indicator_id"))
  value_col <- spi_find_column(data, c("value", "score"))

  result <- data.frame(
    group_code = as.character(data[[code_col]]),
    group_name = as.character(data[[name_col]]),
    year = spi_as_year(data[[year_col]]),
    source_id = as.character(data[[source_col]]),
    score = suppressWarnings(as.numeric(data[[value_col]])),
    stringsAsFactors = FALSE
  )
  if (!is.null(year)) {
    result <- result[result$year %in% spi_as_year(year), , drop = FALSE]
  }
  aggregate_codes <- c(
    "AFE", "AFW", "ARB", "CEB", "CSS", "EAP", "EAR", "EAS", "ECA",
    "ECS", "EMU", "EUU", "FCS", "HIC", "HPC", "IBD", "IBT", "IDA",
    "IDB", "IDX", "LAC", "LCN", "LDC", "LIC", "LMC", "LMY", "LTE",
    "MEA", "MIC", "MNA", "NAC", "OED", "OSS", "PRE", "PSS", "PST",
    "SAS", "SSA", "SSF", "SST", "TEA", "TEC", "TLA", "TMN", "TSA",
    "TSS", "UMC", "WLD"
  )
  result <- result[result$group_code %in% aggregate_codes, , drop = FALSE]
  result <- result[!is.na(result$score), , drop = FALSE]
  rownames(result) <- NULL
  result
}

spi_available_years <- function(index_data) {
  year_col <- if ("year" %in% names(index_data)) "year" else "date"
  score_col <- if ("score" %in% names(index_data)) "score" else "SPI.INDEX"
  years <- spi_as_year(index_data[[year_col]])
  scores <- suppressWarnings(as.numeric(index_data[[score_col]]))
  sort(unique(years[!is.na(years) & !is.na(scores)]))
}

spi_provider_available <- function(provider = c("spiR", "local")) {
  provider <- match.arg(provider)
  if (provider == "spiR") {
    return(requireNamespace("spiR", quietly = TRUE))
  }
  all(file.exists(file.path(app_root(), c(
    "functions/spi-filters.R",
    "functions/spi-github.R",
    "functions/spi-download.R",
    "functions/spi-data.R",
    "functions/spi-wrappers.R"
  ))))
}

spi_select_provider <- function(preferred = "spiR") {
  if (identical(preferred, "spiR") && spi_provider_available("spiR")) {
    return("spiR")
  }
  if (spi_provider_available("local")) {
    return("local")
  }
  stop("Neither the spiR provider nor the local SPI fallback is available.", call. = FALSE)
}
