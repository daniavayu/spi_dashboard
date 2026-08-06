overview_index_for_year <- function(snapshot, year) {
  data <- snapshot$index
  data <- data[data$year == as.integer(year) & !is.na(data$score), , drop = FALSE]
  data <- data[!duplicated(data$country_code), , drop = FALSE]
  rownames(data) <- NULL
  data
}

overview_aggregate_for_year <- function(snapshot, year) {
  data <- snapshot$aggregates
  data <- data[
    data$year == as.integer(year) &
      data$source_id == "SPI.INDEX" &
      !is.na(data$score),
    ,
    drop = FALSE
  ]
  rownames(data) <- NULL
  data
}

overview_years <- function(snapshot) {
  years <- snapshot$years
  if (is.null(years)) {
    years <- sort(unique(snapshot$index$year))
  }
  as.integer(years[!is.na(years)])
}
