prepare_flourish_metadata_blocks <- function(metadata_raw) {
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("The data.table package is required to prepare Flourish metadata.")
  }

  raw <- data.table::as.data.table(metadata_raw)
  first_text <- function(value) {
    value <- iconv(as.character(value), from = "", to = "UTF-8", sub = "")
    value <- value[!is.na(value) & nzchar(trimws(value))]
    if (!length(value)) "" else value[[1L]]
  }

  indicators <- raw[
    !is.na(indicator) & nzchar(trimws(indicator)),
    .(
      indicator_name = first_text(indicator_name),
      indicator_code = first_text(indicator),
      indicator_description = first_text(indicator_description),
      indicator_scoring = first_text(indicator_scoring)
    ),
    by = .(pillar, dimension, indicator)
  ]

  indicator_lines <- indicators[
    , paste0("- ", indicator_name, " (", indicator_code, ")"),
    by = .(pillar, dimension)
  ][
    , .(indicators = paste(V1, collapse = "\n")),
    by = .(pillar, dimension)
  ]

  blocks <- raw[
    , .(
      pillar_name = first_text(pillar_name),
      dimension_name = first_text(dimension_name),
      dimension_description = first_text(dimension_description)
    ),
    by = .(pillar, dimension)
  ]

  blocks <- merge(blocks, indicator_lines, by = c("pillar", "dimension"), all.x = TRUE)
  blocks[is.na(indicators), indicators := "No indicators currently available."]
  blocks[, indicator_count := lengths(strsplit(indicators, "\n", fixed = TRUE))]
  blocks[, pillar_label := paste0("Pillar ", pillar, ": ", sub("^Pillar [0-9]+: ", "", pillar_name))]
  blocks[, dimension_label := dimension_name]
  blocks[, tooltip := paste(
    pillar_label,
    dimension_label,
    dimension_description,
    "Indicators:",
    indicators,
    sep = "\n\n"
  )]

  blocks[
    order(as.integer(pillar), dimension),
    .(
      pillar = as.integer(pillar),
      pillar_label,
      dimension = dimension_label,
      indicator_count,
      tooltip
    )
  ]
}