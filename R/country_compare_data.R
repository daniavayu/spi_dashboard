spi_compare_dimensions <- function(index, dimension_labels = NULL) {
  required <- c("country_code", "country_name", "year")
  if (!is.data.frame(index) || !all(required %in% names(index))) {
    return(data.frame(
      country_code = character(), country_name = character(),
      year = integer(), pillar_id = character(), dimension_id = character(),
      dimension_label = character(), score = numeric(), stringsAsFactors = FALSE
    ))
  }

  dimension_cols <- grep(
    "^dimension_[0-9]+_[0-9]+_score$",
    names(index),
    value = TRUE
  )
  if (length(dimension_cols) == 0L || nrow(index) == 0L) {
    return(data.frame(
      country_code = character(), country_name = character(),
      year = integer(), pillar_id = character(), dimension_id = character(),
      dimension_label = character(), score = numeric(), stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(dimension_cols, function(column) {
    dimension_id <- sub("^dimension_", "", column)
    dimension_id <- sub("_score$", "", dimension_id)
    dimension_id <- sub("_", ".", dimension_id, fixed = TRUE)
    pillar_id <- sub("\\..*", "", dimension_id)
    data.frame(
      country_code = as.character(index$country_code),
      country_name = as.character(index$country_name),
      year = as.integer(index$year),
      pillar_id = pillar_id,
      dimension_id = dimension_id,
      score = suppressWarnings(as.numeric(index[[column]])),
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  labels <- rep(NA_character_, nrow(result))
  if (is.data.frame(dimension_labels) &&
    all(c("dimension_id", "dimension_label") %in% names(dimension_labels))) {
    labels <- as.character(dimension_labels$dimension_label)[
      match(result$dimension_id, as.character(dimension_labels$dimension_id))
    ]
  }
  labels[is.na(labels) | !nzchar(labels)] <- result$dimension_id[
    is.na(labels) | !nzchar(labels)
  ]
  result$dimension_label <- labels
  result <- result[c(
    "country_code", "country_name", "year", "pillar_id", "dimension_id",
    "dimension_label", "score"
  )]
  rownames(result) <- NULL
  result
}

spi_compare_dimension_gaps <- function(index, countries, year, dimension_labels = NULL) {
  empty <- data.frame(
    pillar = character(), dimension = character(), gap = numeric(),
    stringsAsFactors = FALSE
  )
  if (length(countries) < 2L || is.null(year) || length(year) == 0L || is.na(year)) {
    return(empty)
  }

  data <- spi_compare_dimensions(index, dimension_labels)
  data <- data[as.character(data$country_code) %in% countries &
    as.integer(data$year) == as.integer(year), , drop = FALSE]
  if (nrow(data) == 0L) return(empty)

  groups <- split(data, interaction(data$pillar_id, data$dimension_id, drop = TRUE))
  rows <- lapply(groups, function(group) {
    scores <- stats::setNames(as.numeric(group$score), as.character(group$country_code))
    scores <- scores[countries]
    gap <- if (all(is.na(scores))) NA_real_ else diff(range(scores, na.rm = TRUE))
    row <- data.frame(
      pillar = paste("Pillar", group$pillar_id[[1L]]),
      dimension = group$dimension_label[[1L]],
      gap = gap,
      stringsAsFactors = FALSE
    )
    for (country in countries) row[[country]] <- unname(scores[[country]])
    row
  })
  result <- do.call(rbind, rows)
  result <- result[order(-ifelse(is.na(result$gap), -Inf, result$gap)), , drop = FALSE]
  result[c("pillar", "dimension", countries, "gap")]
}

spi_compare_region_benchmark <- function(
  index, metadata, aggregates, countries, year
) {
  empty <- data.frame(
    country_code = character(), country_name = character(),
    region = character(), type = character(), score = numeric(),
    stringsAsFactors = FALSE
  )
  if (length(countries) == 0L || is.null(year) || is.na(year) ||
    !is.data.frame(index) || !is.data.frame(metadata) ||
    !is.data.frame(aggregates)) {
    return(empty)
  }

  selected <- index[
    as.character(index$country_code) %in% countries &
      as.integer(index$year) == as.integer(year), , drop = FALSE
  ]
  metadata <- metadata[
    as.character(metadata$country_code) %in% countries &
      as.integer(metadata$year) == as.integer(year), , drop = FALSE
  ]
  regional <- aggregates[
    as.integer(aggregates$year) == as.integer(year) &
      as.character(aggregates$source_id) == "SPI.INDEX" &
      !is.na(aggregates$score), , drop = FALSE
  ]
  if (nrow(selected) == 0L || nrow(metadata) == 0L ||
    nrow(regional) == 0L) {
    return(empty)
  }

  rows <- lapply(countries, function(country) {
    country_row <- selected[
      as.character(selected$country_code) == country, , drop = FALSE
    ]
    metadata_row <- metadata[
      as.character(metadata$country_code) == country, , drop = FALSE
    ]
    if (nrow(country_row) == 0L || nrow(metadata_row) == 0L) return(NULL)
    region <- as.character(metadata_row$region[[1L]])
    region_row <- regional[
      as.character(regional$group_name) == region, , drop = FALSE
    ]
    data.frame(
      country_code = c(country, paste0(country, "_region")),
      country_name = c(
        as.character(country_row$country_name[[1L]]), region
      ),
      region = c(region, region),
      type = c("Country", "Region"),
      score = c(
        as.numeric(country_row$score[[1L]]),
        if (nrow(region_row)) as.numeric(region_row$score[[1L]]) else NA_real_
      ),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(result) || nrow(result) == 0L) return(empty)
  rownames(result) <- NULL
  result
}

spi_compare_section_result <- function(data, status, coverage, source = "normalized") {
  list(
    data = data,
    status = status,
    message = switch(
      status,
      partial = "Some comparison data is unavailable or incomplete.",
      empty = "No comparison data is available.",
      unavailable = "This comparison section is unavailable.",
      error = "Comparison data could not be prepared.",
      NULL
    ),
    coverage = coverage,
    source = source
  )
}

spi_compare_collapse_duplicates <- function(data) {
  if (!is.data.frame(data) || nrow(data) == 0L) {
    return(spi_compare_section_result(data, "empty", list(conflicts = 0L)))
  }
  keys <- c("country_code", "year", "pillar_id", "dimension_id")
  keys <- keys[keys %in% names(data)]
  groups <- split(seq_len(nrow(data)), do.call(paste, c(data[keys], sep = "|")))
  conflicts <- 0L
  rows <- lapply(groups, function(indices) {
    row <- data[indices[[1L]], , drop = FALSE]
    values <- suppressWarnings(as.numeric(data$score[indices]))
    distinct <- unique(values[!is.na(values)])
    if (length(distinct) > 1L) {
      row$score <- NA_real_
      conflicts <<- conflicts + 1L
    } else if (length(distinct) == 1L) {
      row$score <- distinct[[1L]]
    } else {
      row$score <- NA_real_
    }
    row
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  spi_compare_section_result(result, if (conflicts > 0L) "partial" else "ok",
    list(conflicts = conflicts))
}

spi_compare_pillars <- function(index, countries, year) {
  if (!is.data.frame(index) || !all(c("country_code", "country_name", "year") %in% names(index)) ||
    length(countries) == 0L || is.null(year) || length(year) == 0L || is.na(year)) {
    return(spi_compare_section_result(data.frame(), "empty", list(requested = 0L, available = 0L)))
  }
  columns <- paste0("pillar_", 1:5, "_score")
  selected <- index[as.character(index$country_code) %in% countries, , drop = FALSE]
  selected <- selected[as.integer(selected$year) == as.integer(year), , drop = FALSE]
  rows <- vector("list", length(countries) * 5L)
  position <- 0L
  for (country in countries) {
    source_row <- selected[as.character(selected$country_code) == country, , drop = FALSE]
    for (pillar in 1:5) {
      position <- position + 1L
      column <- columns[[pillar]]
      rows[[position]] <- data.frame(
        country_code = country,
        country_name = if (nrow(source_row)) as.character(source_row$country_name[[1L]]) else country,
        year = as.integer(year),
        pillar_id = as.character(pillar),
        score = if (nrow(source_row) && column %in% names(source_row)) as.numeric(source_row[[column]][[1L]]) else NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  result <- do.call(rbind, rows)
  status <- if (all(!is.na(result$score))) "ok" else "partial"
  spi_compare_section_result(result, status,
    list(requested = nrow(result), available = sum(!is.na(result$score))))
}

spi_compare_trends <- function(index, countries, metric = "overall") {
  column <- spi_compare_metric_column(metric)
  if (!is.data.frame(index) || !all(c("country_code", "country_name", "year") %in% names(index)) ||
    length(countries) == 0L) {
    return(spi_compare_section_result(data.frame(), "empty", list(requested = 0L)))
  }
  selected <- index[as.character(index$country_code) %in% countries, , drop = FALSE]
  years <- sort(unique(suppressWarnings(as.integer(selected$year))))
  years <- years[!is.na(years)]
  if (length(years) == 0L) {
    return(spi_compare_section_result(data.frame(), "empty", list(requested = 0L)))
  }
  rows <- lapply(countries, function(country) {
    lapply(years, function(year) {
      source_row <- selected[
        as.character(selected$country_code) == country &
          as.integer(selected$year) == year, , drop = FALSE
      ]
      data.frame(
        country_code = country,
        country_name = if (nrow(source_row)) as.character(source_row$country_name[[1L]]) else country,
        year = year,
        score = if (nrow(source_row) && column %in% names(source_row)) as.numeric(source_row[[column]][[1L]]) else NA_real_,
        metric = metric,
        stringsAsFactors = FALSE
      )
    })
  })
  result <- do.call(rbind, unlist(rows, recursive = FALSE))
  result <- do.call(rbind, lapply(split(result, result$country_code), function(country_data) {
    valid_rows <- which(!is.na(country_data$score))
    if (!length(valid_rows)) return(country_data[0, , drop = FALSE])
    country_data[seq.int(valid_rows[[1L]], nrow(country_data)), , drop = FALSE]
  }))
  rownames(result) <- NULL
  status <- if (all(!is.na(result$score))) "ok" else "partial"
  spi_compare_section_result(result, status,
    list(requested = nrow(result), available = sum(!is.na(result$score))))
}