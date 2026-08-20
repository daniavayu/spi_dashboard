spi_explorer_empty_table <- function() {
  data.frame(
    country_code = character(), country_name = character(),
    year = integer(), region = character(), income_group = character(),
    overall_spi = numeric(), metric_id = character(),
    metric_label = character(), metric_score = numeric(),
    change_previous = numeric(), change_first = numeric(),
    stringsAsFactors = FALSE
  )
}

spi_explorer_metadata_deduplicate <- function(metadata) {
  required <- c(
    "country_code", "country_name", "year", "region", "income_group"
  )
  if (!is.data.frame(metadata) || nrow(metadata) == 0L) {
    return(list(
      data = data.frame(
        country_code = character(), country_name = character(),
        year = integer(), region = character(), income_group = character(),
        stringsAsFactors = FALSE
      ),
      status = list(status = "unavailable", conflict_count = 0L)
    ))
  }
  for (column in setdiff(required, names(metadata))) {
    metadata[[column]] <- if (column == "year") {
      integer(nrow(metadata))
    } else {
      rep(NA_character_, nrow(metadata))
    }
  }
  metadata <- metadata[required]
  metadata$country_code <- as.character(metadata$country_code)
  metadata$country_name <- as.character(metadata$country_name)
  metadata$year <- suppressWarnings(as.integer(metadata$year))
  metadata$region <- as.character(metadata$region)
  metadata$income_group <- as.character(metadata$income_group)
  metadata$.row_order <- seq_len(nrow(metadata))
  metadata$.key <- paste(metadata$country_code, metadata$year, sep = "_")
  keys <- unique(metadata$.key)
  rows <- vector("list", length(keys))
  conflict_count <- 0L

  for (position in seq_along(keys)) {
    group <- metadata[metadata$.key == keys[[position]], , drop = FALSE]
    completeness <- rowSums(!is.na(group[c("country_name", "region", "income_group")]) &
      nzchar(as.character(group[c("country_name", "region", "income_group")])) )
    selected <- group[order(-completeness, group$.row_order)[[1L]], , drop = FALSE]
    fields <- c("country_name", "region", "income_group")
    for (field in fields) {
      values <- unique(group[[field]][!is.na(group[[field]]) &
        nzchar(group[[field]])])
      if (length(values) > 1L) {
        selected[[field]] <- NA_character_
        conflict_count <- conflict_count + 1L
      }
    }
    rows[[position]] <- selected
  }

  result <- do.call(rbind, rows)
  result <- result[required]
  rownames(result) <- NULL
  list(
    data = result,
    status = list(
      status = if (conflict_count > 0L) "conflict" else "ok",
      conflict_count = as.integer(conflict_count)
    )
  )
}

spi_explorer_base <- function(snapshot) {
  index <- snapshot$index
  if (!is.data.frame(index) || nrow(index) == 0L) {
    return(list(
      data = spi_explorer_empty_table(),
      status = list(index = "unavailable", metadata = "unavailable")
    ))
  }
  required <- c("country_code", "country_name", "year", "score")
  missing <- setdiff(required, names(index))
  if (length(missing) > 0L) {
    stop("Explorer index is missing: ", paste(missing, collapse = ", "))
  }
  result <- index
  result$country_code <- as.character(result$country_code)
  result$country_name <- as.character(result$country_name)
  result$year <- suppressWarnings(as.integer(result$year))
  result$overall_spi <- suppressWarnings(as.numeric(result$score))
  result$score <- NULL
  result$.key <- paste(result$country_code, result$year, sep = "_")

  metadata_result <- spi_explorer_metadata_deduplicate(snapshot$metadata)
  metadata <- metadata_result$data
  if (nrow(metadata) > 0L) {
    metadata$.key <- paste(metadata$country_code, metadata$year, sep = "_")
    match_row <- match(result$.key, metadata$.key)
    result$region <- metadata$region[match_row]
    result$income_group <- metadata$income_group[match_row]
    result$country_name <- ifelse(
      is.na(result$country_name) | !nzchar(result$country_name),
      metadata$country_name[match_row],
      result$country_name
    )
  } else {
    result$region <- NA_character_
    result$income_group <- NA_character_
  }
  result$.key <- NULL
  rownames(result) <- NULL
  list(
    data = result,
    status = list(
      index = "ok",
      metadata = metadata_result$status$status,
      metadata_conflict_count = metadata_result$status$conflict_count
    )
  )
}
