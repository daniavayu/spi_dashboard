FLOURISH_VISUALISATION_ID <- "26427135"
FLOURISH_MAP_YEAR <- 2024L

prepare_flourish_regions <- function(index_data, year = FLOURISH_MAP_YEAR) {
  if (!all(c("country_code", "year", "score") %in% names(index_data))) {
    names(index_data)[names(index_data) == "iso3c"] <- "country_code"
    names(index_data)[names(index_data) == "date"] <- "year"
    names(index_data)[names(index_data) == "SPI.INDEX"] <- "score"
  }
  required <- c("country_code", "year", "score")
  missing <- setdiff(required, names(index_data))
  if (length(missing) > 0L) {
    stop("Normalized index is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!identical(as.integer(year), FLOURISH_MAP_YEAR)) {
    stop("The Milestone 1 Flourish map is fixed to 2024.", call. = FALSE)
  }

  result <- data.frame(
    Economy = as.character(index_data$country_code),
    SPI.INDEX = suppressWarnings(as.numeric(index_data$score)),
    stringsAsFactors = FALSE
  )
  result <- result[
    result$Economy != "" & !is.na(result$Economy) &
      !is.na(result$SPI.INDEX) & index_data$year == FLOURISH_MAP_YEAR,
    ,
    drop = FALSE
  ]
  result <- result[!duplicated(result$Economy), , drop = FALSE]
  rownames(result) <- NULL
  result
}
