pillar_explorer_expected_pillar_ids <- function() {
  as.character(seq_len(5L))
}

pillar_explorer_expected_columns <- function() {
  paste0(
    "pillar_", pillar_explorer_expected_pillar_ids(), "_score"
  )
}

pillar_explorer_default_labels <- function() {
  paste("Pillar", pillar_explorer_expected_pillar_ids())
}

pillar_explorer_schema <- function(index, pillar_labels = NULL) {
  expected_columns <- pillar_explorer_expected_columns()
  structural_columns <- if (is.data.frame(index)) {
    grep("^pillar_[0-9]+_score$", names(index), value = TRUE)
  } else {
    character()
  }
  valid_schema <- is.data.frame(index) &&
    setequal(structural_columns, expected_columns)

  if (!valid_schema) {
    return(list(
      status = "unavailable",
      message = "Pillar schema requires exactly five structural pillars.",
      columns = expected_columns,
      pillar_ids = pillar_explorer_expected_pillar_ids(),
      labels = pillar_explorer_default_labels()
    ))
  }

  labels <- pillar_explorer_default_labels()
  if (is.data.frame(pillar_labels) &&
    all(c("pillar_id", "pillar_label") %in% names(pillar_labels))) {
    ids <- sub("^D", "", as.character(pillar_labels$pillar_id))
    values <- as.character(pillar_labels$pillar_label)
    valid <- !is.na(ids) & nzchar(ids) & !is.na(values) & nzchar(values)
    matches <- match(
      pillar_explorer_expected_pillar_ids(), ids[valid]
    )
    has_label <- !is.na(matches)
    labels[has_label] <- values[valid][matches[has_label]]
  }

  list(
    status = "ok",
    message = NULL,
    columns = expected_columns,
    pillar_ids = pillar_explorer_expected_pillar_ids(),
    labels = labels
  )
}

pillar_explorer_country_year_choices <- function(index) {
  empty <- data.frame(
    country_code = character(), country_name = character(),
    year = integer(), score = numeric(), stringsAsFactors = FALSE
  )
  schema <- pillar_explorer_schema(index)
  if (!identical(schema$status, "ok") ||
    !all(c("country_code", "year") %in% names(index))) {
    return(empty)
  }

  scores <- lapply(index[schema$columns], function(values) {
    values <- suppressWarnings(as.numeric(values))
    !is.na(values) & is.finite(values)
  })
  valid_pillar <- rowSums(as.data.frame(scores)) > 0L
  country_code <- trimws(as.character(index$country_code))
  year <- suppressWarnings(as.integer(index$year))
  valid_identity <- !is.na(year) & nzchar(country_code)
  country_name <- if ("country_name" %in% names(index)) {
    as.character(index$country_name)
  } else {
    country_code
  }
  result <- data.frame(
    country_code = country_code,
    country_name = country_name,
    year = year,
    score = if ("score" %in% names(index)) {
      suppressWarnings(as.numeric(index$score))
    } else {
      rep(NA_real_, nrow(index))
    },
    .row_order = seq_len(nrow(index)),
    stringsAsFactors = FALSE
  )
  result <- result[valid_pillar & valid_identity, , drop = FALSE]
  result <- result[order(result$country_code, result$year, result$.row_order), ,
    drop = FALSE]
  result <- result[!duplicated(result[c("country_code", "year")]), ,
    drop = FALSE]
  result$.row_order <- NULL
  rownames(result) <- NULL
  result
}

pillar_explorer_country_choices <- function(index) {
  rows <- pillar_explorer_country_year_choices(index)
  if (!nrow(rows)) {
    return(data.frame(
      country_code = character(), country_name = character(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- rows[order(rows$country_name, rows$country_code), , drop = FALSE]
  rows[!duplicated(rows$country_code), c("country_code", "country_name"),
    drop = FALSE]
}

pillar_explorer_year_choices <- function(index, country_code = NULL) {
  rows <- pillar_explorer_country_year_choices(index)
  if (!is.null(country_code)) {
    rows <- rows[rows$country_code == as.character(country_code), , drop = FALSE]
  }
  sort(unique(rows$year))
}