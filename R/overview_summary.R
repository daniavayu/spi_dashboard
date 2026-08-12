overview_score_distribution <- function(snapshot, year) {
  data <- overview_index_for_year(snapshot, year)
  if (nrow(data) == 0L) {
    return(data.frame(score = numeric(), stringsAsFactors = FALSE))
  }
  data.frame(score = data$score, stringsAsFactors = FALSE)
}

overview_group_summary <- function(snapshot, year) {
  data <- overview_aggregate_for_year(snapshot, year)
  data[data$source_id == "SPI.INDEX", c("group_code", "group_name", "score"), drop = FALSE]
}

overview_region_summary <- function(snapshot, year) {
  data <- overview_group_summary(snapshot, year)
  region_codes <- c(
    "EAP", "ECA", "LAC", "MNA", "NAC", "SAS", "SSF"
  )
  data <- data[data$group_code %in% region_codes, , drop = FALSE]
  region_labels <- c(
    EAP = "East Asia & Pacific",
    ECA = "Europe & Central Asia",
    LAC = "Latin America & Caribbean",
    MNA = "Middle East & North Africa",
    NAC = "North America",
    SAS = "South Asia",
    SSF = "Sub-Saharan Africa"
  )
  data$group_name <- unname(region_labels[data$group_code])
  data
}

overview_income_group_summary <- function(snapshot, year) {
  data <- snapshot$income_data
  if (is.null(data) || !nrow(data)) {
    return(data.frame(
      group_code = character(), group_name = character(), score = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  data <- data[data$year == as.integer(year), , drop = FALSE]
  if (!nrow(data)) {
    return(data.frame(
      group_code = character(), group_name = character(), score = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  result <- stats::aggregate(
    score ~ income_group,
    data = data,
    FUN = mean,
    na.rm = TRUE
  )
  names(result) <- c("income_group", "score")
  result$group_code <- overview_income_group_code(result$income_group)
  result$group_name <- overview_income_group_label(result$group_code)
  result <- result[order(overview_income_group_order(result$group_code)), ,
    drop = FALSE]
  result[, c("group_code", "group_name", "score"), drop = FALSE]
}

overview_income_group_code <- function(value) {
  normalized <- tolower(trimws(as.character(value)))
  code <- c(
    "high income" = "HIC",
    "upper-middle income" = "UMC",
    "upper middle income" = "UMC",
    "lower-middle income" = "LMC",
    "lower middle income" = "LMC",
    "low income" = "LIC",
    "not classified" = "NOC"
  )
  result <- unname(code[normalized])
  result[is.na(result)] <- toupper(trimws(as.character(value)))[is.na(result)]
  result
}

overview_income_group_label <- function(value) {
  labels <- c(
    HIC = "High income",
    UMC = "Upper-middle income",
    LMC = "Lower-middle income",
    LIC = "Low income",
    NOC = "Not classified"
  )
  result <- unname(labels[toupper(trimws(as.character(value)))])
  result[is.na(result)] <- as.character(value)[is.na(result)]
  result
}

overview_income_group_order <- function(value) {
  match(
    toupper(trimws(as.character(value))),
    c("HIC", "UMC", "LMC", "LIC", "NOC"),
    nomatch = 99L
  )
}

overview_income_group_variation <- function(snapshot, year) {
  data <- snapshot$income_data
  empty <- data.frame(
    group_code = character(), group_name = character(),
    q25 = numeric(), q75 = numeric(), stringsAsFactors = FALSE
  )
  if (is.null(data) || !nrow(data)) {
    return(empty)
  }

  data <- data[
    data$year == as.integer(year) &
      !is.na(data$score) & !is.na(data$income_group) &
      nzchar(data$income_group),
    ,
    drop = FALSE
  ]
  if (!nrow(data)) {
    return(empty)
  }

  groups <- split(data, data$income_group)
  result <- do.call(rbind, lapply(names(groups), function(group_code) {
    group_data <- groups[[group_code]]
    group_code <- overview_income_group_code(group_code)
    data.frame(
      group_code = group_code,
      group_name = overview_income_group_label(group_code),
      q25 = as.numeric(stats::quantile(group_data$score, 0.25,
        na.rm = TRUE, names = FALSE)),
      q75 = as.numeric(stats::quantile(group_data$score, 0.75,
        na.rm = TRUE, names = FALSE)),
      stringsAsFactors = FALSE
    )
  }))
  rownames(result) <- NULL
  result <- result[order(overview_income_group_order(result$group_code)), ,
    drop = FALSE]
  result
}

overview_median_improvement <- function(
  snapshot,
  start_year = 2016L,
  end_year = NULL
) {
  data <- snapshot$index
  if (is.null(data) || !nrow(data)) {
    return(NA_real_)
  }
  if (is.null(end_year)) {
    end_year <- max(data$year[!is.na(data$score)], na.rm = TRUE)
  }
  data <- data[
    data$year %in% c(as.integer(start_year), as.integer(end_year)) &
      !is.na(data$score) & nzchar(data$country_code),
    c("country_code", "year", "score"),
    drop = FALSE
  ]
  if (!nrow(data)) {
    return(NA_real_)
  }

  baseline <- data[data$year == as.integer(start_year), , drop = FALSE]
  latest <- data[data$year == as.integer(end_year), , drop = FALSE]
  matched <- merge(
    baseline,
    latest,
    by = "country_code",
    suffixes = c("_start", "_end")
  )
  if (!nrow(matched)) {
    return(NA_real_)
  }
  stats::median(matched$score_end - matched$score_start, na.rm = TRUE)
}
