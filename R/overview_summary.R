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
