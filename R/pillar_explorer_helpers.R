pillar_explorer_empty_coverage <- function() {
  list(
    requested = 5L,
    available = 0L,
    missing = 5L,
    renormalized = FALSE
  )
}

pillar_explorer_invalid_result <- function(message, official_score = NA_real_) {
  list(
    status = "invalid_weights",
    message = message,
    official_score = official_score,
    custom_score = NA_real_,
    difference = NA_real_,
    available_pillars = integer(),
    effective_weights = rep(0, 5L),
    coverage = pillar_explorer_empty_coverage()
  )
}

pillar_explorer_validate_weights <- function(weights) {
  invalid <- function(message) {
    list(valid = FALSE, weights = integer(), message = message)
  }
  if (!is.numeric(weights) || length(weights) != 5L) {
    return(invalid("Provide exactly five numeric weights."))
  }
  if (anyNA(weights) || any(!is.finite(weights))) {
    return(invalid("Weights must be finite and non-missing."))
  }
  if (any(weights < 0 | weights > 100) || any(weights != floor(weights))) {
    return(invalid("Weights must be integer percentages from 0 to 100."))
  }
  weights <- as.integer(weights)
  if (sum(weights) != 100L) {
    return(invalid("Weights must sum exactly to 100."))
  }
  list(valid = TRUE, weights = weights, message = NULL)
}

pillar_explorer_calculate <- function(scores, weights, official_score = NA_real_) {
  validation <- pillar_explorer_validate_weights(weights)
  if (!isTRUE(validation$valid)) {
    return(pillar_explorer_invalid_result(
      validation$message,
      official_score = if (length(official_score)) {
        suppressWarnings(as.numeric(official_score[[1L]]))
      } else {
        NA_real_
      }
    ))
  }

  scores <- if (length(scores) == 5L) {
    suppressWarnings(as.numeric(scores))
  } else {
    rep(NA_real_, 5L)
  }
  available <- !is.na(scores) & is.finite(scores)
  available_count <- sum(available)
  effective_total <- sum(validation$weights[available])
  coverage <- list(
    requested = 5L,
    available = as.integer(available_count),
    missing = as.integer(5L - available_count),
    renormalized = available_count < 5L && effective_total > 0
  )
  official <- if (length(official_score) &&
    is.finite(suppressWarnings(as.numeric(official_score[[1L]])))) {
    suppressWarnings(as.numeric(official_score[[1L]]))
  } else {
    NA_real_
  }
  effective_weights <- rep(0, 5L)

  if (!available_count || effective_total <= 0) {
    return(list(
      status = "unavailable",
      message = if (!available_count) {
        "No valid pillar scores are available for this country-year."
      } else {
        "Available pillar scores have zero effective weight."
      },
      official_score = official,
      custom_score = NA_real_,
      difference = NA_real_,
      available_pillars = which(available),
      effective_weights = effective_weights,
      coverage = coverage
    ))
  }

  effective_weights[available] <-
    validation$weights[available] / effective_total
  custom_score <- sum(scores[available] * effective_weights[available])
  difference <- if (is.na(official)) NA_real_ else custom_score - official
  list(
    status = "ok",
    message = if (coverage$renormalized) {
      "Missing pillar scores were excluded and available weights were renormalized."
    } else {
      NULL
    },
    official_score = official,
    custom_score = custom_score,
    difference = difference,
    available_pillars = which(available),
    effective_weights = effective_weights,
    coverage = coverage
  )
}

pillar_explorer_pillar_metrics <- function(
  scores,
  previous_scores = numeric(),
  effective_weights = numeric()
) {
  scores <- if (length(scores) == 5L) {
    suppressWarnings(as.numeric(scores))
  } else {
    rep(NA_real_, 5L)
  }
  previous_scores <- if (length(previous_scores) == 5L) {
    suppressWarnings(as.numeric(previous_scores))
  } else {
    rep(NA_real_, 5L)
  }
  effective_weights <- if (length(effective_weights) == 5L) {
    suppressWarnings(as.numeric(effective_weights))
  } else {
    rep(0, 5L)
  }

  list(
    change = ifelse(
      is.finite(scores) & is.finite(previous_scores),
      scores - previous_scores,
      NA_real_
    ),
    contribution = ifelse(
      is.finite(scores) & is.finite(effective_weights),
      scores * effective_weights,
      NA_real_
    )
  )
}

pillar_explorer_analysis_data <- function(index, year) {
  columns <- pillar_explorer_expected_columns()
  if (!is.data.frame(index) || !all(columns %in% names(index)) ||
    !all(c("country_code", "year") %in% names(index)) || is.na(year)) {
    return(data.frame())
  }
  country_name <- if ("country_name" %in% names(index)) {
    as.character(index$country_name)
  } else {
    as.character(index$country_code)
  }
  data <- index[
    suppressWarnings(as.integer(index$year)) == as.integer(year),
    c("country_code", columns),
    drop = FALSE
  ]
  data$country_name <- ifelse(
    is.na(country_name[match(data$country_code, index$country_code)]) |
      !nzchar(country_name[match(data$country_code, index$country_code)]),
    as.character(data$country_code),
    country_name[match(data$country_code, index$country_code)]
  )
  data$country_name <- ifelse(
    is.na(data$country_name) | !nzchar(as.character(data$country_name)),
    as.character(data$country_code),
    as.character(data$country_name)
  )
  data[!duplicated(data$country_code), , drop = FALSE]
}

pillar_explorer_correlation <- function(index, year) {
  data <- pillar_explorer_analysis_data(index, year)
  columns <- pillar_explorer_expected_columns()
  if (nrow(data) < 2L) return(matrix(NA_real_, 5L, 5L,
    dimnames = list(columns, columns)))
  stats::cor(
    data[columns], use = "pairwise.complete.obs", method = "pearson"
  )
}

pillar_explorer_scatter_data <- function(index, year, x_column, y_column) {
  data <- pillar_explorer_analysis_data(index, year)
  columns <- pillar_explorer_expected_columns()
  if (!x_column %in% columns || !y_column %in% columns || !nrow(data)) {
    return(data.frame(country_name = character(), x = numeric(), y = numeric()))
  }
  result <- data.frame(
    country_name = data$country_name,
    x = suppressWarnings(as.numeric(data[[x_column]])),
    y = suppressWarnings(as.numeric(data[[y_column]])),
    stringsAsFactors = FALSE
  )
  result[is.finite(result$x) & is.finite(result$y), , drop = FALSE]
}

pillar_explorer_correlation_summary <- function(correlation, labels) {
  if (!is.matrix(correlation) || !any(is.finite(correlation))) return("")
  diagonal <- diag(correlation)
  correlation[seq_along(diagonal), seq_along(diagonal)] <- NA_real_
  pairs <- which(is.finite(correlation), arr.ind = TRUE)
  pairs <- pairs[pairs[, 1L] < pairs[, 2L], , drop = FALSE]
  if (!nrow(pairs)) return("")
  values <- correlation[pairs]
  strongest <- pairs[which.max(values), , drop = FALSE]
  weakest <- pairs[which.min(values), , drop = FALSE]
  sprintf(
    "Strongest correlation: %s <-> %s (%.2f). Weakest: %s <-> %s (%.2f).",
    labels[[strongest[1L]]], labels[[strongest[2L]]],
    correlation[strongest], labels[[weakest[1L]]], labels[[weakest[2L]]],
    correlation[weakest]
  )
}