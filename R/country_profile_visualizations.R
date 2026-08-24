spi_profile_coord_radar <- function(theta = "x", start = 0, direction = 1) {
  theta <- match.arg(theta, c("x", "y"))
  radius <- if (theta == "x") "y" else "x"
  ggplot2::ggproto(
    "CoordRadar", ggplot2::CoordPolar,
    theta = theta, r = radius, start = start,
    direction = sign(direction),
    is_linear = function(coord) TRUE
  )
}

spi_profile_radar_data <- function(index, metadata, country_code, year) {
  empty <- data.frame(
    country_code = character(), country_name = character(),
    region = character(), year = integer(), pillar = character(),
    value = numeric(), series = character(),
    stringsAsFactors = FALSE
  )
  if (!is.data.frame(index) || nrow(index) == 0L) return(empty)
  pillar_columns <- grep("^pillar_[0-9]+_score$", names(index), value = TRUE)
  if (length(pillar_columns) == 0L) return(empty)
  selected <- index[
    index$year == as.integer(year) &
      as.character(index$country_code) == as.character(country_code),
    , drop = FALSE
  ]
  if (nrow(selected) == 0L) return(empty)
  selected <- selected[1L, , drop = FALSE]
  region <- NA_character_
  if (is.data.frame(metadata) && nrow(metadata) > 0L) {
    metadata_row <- metadata[
      as.character(metadata$country_code) == as.character(country_code) &
        metadata$year == as.integer(year),
      , drop = FALSE
    ]
    if (nrow(metadata_row) > 0L && "region" %in% names(metadata_row)) {
      region <- as.character(metadata_row$region[[1L]])
    }
  }
  if (is.na(region) || !nzchar(region)) return(empty)
  country_name <- as.character(selected$country_name[[1L]])
  country_values <- data.frame(
    country_code = as.character(selected$country_code[[1L]]),
    country_name = country_name,
    region = region,
    year = as.integer(year),
    pillar = sub("^pillar_", "", sub("_score$", "", pillar_columns)),
    value = suppressWarnings(as.numeric(unlist(
      selected[1L, pillar_columns, drop = FALSE], use.names = FALSE
    ))),
    series = "country",
    stringsAsFactors = FALSE
  )
  region_rows <- index[index$year == as.integer(year), , drop = FALSE]
  region_codes <- metadata$country_code[metadata$year == as.integer(year) &
    metadata$region == region]
  region_rows <- region_rows[
    as.character(region_rows$country_code) %in% as.character(region_codes),
    , drop = FALSE
  ]
  region_values <- data.frame(
    country_code = NA_character_, country_name = NA_character_,
    region = region, year = as.integer(year),
    pillar = sub("^pillar_", "", sub("_score$", "", pillar_columns)),
    value = vapply(pillar_columns, function(column) {
      values <- suppressWarnings(as.numeric(region_rows[[column]]))
      if (all(is.na(values))) NA_real_ else mean(values, na.rm = TRUE)
    }, numeric(1L)),
    series = "region",
    stringsAsFactors = FALSE
  )
  rbind(country_values, region_values)
}

spi_profile_pillar_radar <- function(data, country_code, year) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("The ggplot2 package is required for the Profile radar.")
  }
  if (!is.data.frame(data) || nrow(data) == 0L) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No pillar radar data available")
    return(invisible(NULL))
  }
  labels <- c(
    `1` = "Pillar 1:\nData Use",
    `2` = "Pillar 2:\nData Services",
    `3` = "Pillar 3:\nData Products",
    `4` = "Pillar 4:\nData Sources",
    `5` = "Pillar 5:\nData Infrastructure"
  )
  data$pillar <- factor(data$pillar, levels = as.character(1:5),
    labels = unname(labels[as.character(1:5)]))
  data$series <- factor(data$series, levels = c("country", "region"))
  region_name <- unique(data$region[data$series == "region"])[1L]
  country_name <- unique(data$country_name[data$series == "country"])[1L]
  region_label <- if (is.na(region_name)) "regional average" else
    paste0(region_name, " average")
  ggplot2::ggplot(data, ggplot2::aes(
    x = pillar, y = value, group = series
  )) +
    ggplot2::geom_polygon(ggplot2::aes(
      colour = series, fill = series, linetype = series
    ), linewidth = 1, alpha = 0.15, na.rm = TRUE) +
    ggplot2::geom_point(ggplot2::aes(colour = series), size = 2.2,
      na.rm = TRUE) +
    spi_profile_coord_radar() +
    ggplot2::scale_y_continuous(limits = c(0, 100),
      breaks = c(20, 40, 60, 80, 100)) +
    ggplot2::scale_colour_manual(
      values = c(country = "#0071BC", region = "#8A969F"),
      labels = c(country = country_name, region = region_label), name = NULL
    ) +
    ggplot2::scale_fill_manual(
      values = c(country = "#0071BC", region = "#8A969F"),
      labels = c(country = country_name, region = region_label), name = NULL
    ) +
    ggplot2::scale_linetype_manual(
      values = c(country = "solid", region = "dashed"),
      labels = c(country = country_name, region = region_label), name = NULL
    ) +
    ggplot2::labs(
      title = "SPI Pillar Performance",
      subtitle = paste0(country_name, " vs. ", region_label, " | ", year),
      x = NULL, y = NULL,
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(colour = "#666666", size = 8),
      axis.text.x = ggplot2::element_text(colour = "#111111", face = "bold"),
      plot.title = ggplot2::element_text(face = "bold", colour = "#111111"),
      plot.subtitle = ggplot2::element_text(colour = "#666666"),
      plot.caption = ggplot2::element_text(colour = "#666666"),
      legend.position = "top"
    )
}

spi_profile_official_radar <- function(country, year, fallback_data = NULL) {
  if (requireNamespace("spiR", quietly = TRUE) &&
    exists("spi_plot_radar", asNamespace("spiR"), inherits = FALSE)) {
    official <- tryCatch(
      spiR::spi_plot_radar(country = country, year = year),
      error = function(error) NULL
    )
    if (!is.null(official)) return(official)
  }
  spi_profile_pillar_radar(fallback_data, country, year)
}

spi_profile_official_trend <- function(country, fallback_data = NULL,
                                       year = NULL) {
  if (requireNamespace("spiR", quietly = TRUE) &&
    exists("spi_plot_trend", asNamespace("spiR"), inherits = FALSE)) {
    official <- tryCatch(
      suppressWarnings(spiR::spi_plot_trend(countries = country)),
      error = function(error) NULL
    )
    if (!is.null(official)) return(official)
  }
  spi_profile_score_trend(fallback_data, country, year)
}

spi_profile_score_trend <- function(data, country_name, year) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("The ggplot2 package is required for the Profile trend.")
  }
  data <- data[!is.na(data$year) & !is.na(data$score), , drop = FALSE]
  if (nrow(data) == 0L) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "No score trend data available")
    return(invisible(NULL))
  }
  data <- data[order(data$year), , drop = FALSE]
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = year, y = score))
  if (nrow(data) > 1L) {
    plot <- plot + ggplot2::geom_line(colour = "#079bd3", linewidth = 1.1)
  }
  plot +
    ggplot2::geom_point(colour = "#079bd3", size = 2.4) +
    ggplot2::geom_text(
      data = data[data$year == year, , drop = FALSE],
      ggplot2::aes(label = sprintf("%.1f", score)),
      colour = "#079bd3", hjust = -0.15, fontface = "bold", size = 3.2
    ) +
    ggplot2::scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
    ggplot2::scale_x_continuous(breaks = sort(unique(data$year))) +
    ggplot2::labs(x = NULL, y = NULL, subtitle = "Overall SPI trend") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = "#667985", size = 8),
      plot.subtitle = ggplot2::element_text(colour = "#7890a0", size = 9),
      plot.margin = ggplot2::margin(8, 18, 4, 4)
    )
}
