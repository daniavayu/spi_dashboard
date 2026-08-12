spi_plot_horizontal_bars <- function(
  data,
  label_col = "group_name",
  bar_colors = "#0b9ed0"
) {
  if (!nrow(data)) {
    plot.new()
    text(0.5, 0.5, "No data for the latest available year")
    return(invisible(NULL))
  }

  data <- data[order(data$score, decreasing = TRUE), , drop = FALSE]
  data <- data[seq_len(min(nrow(data), 7L)), , drop = FALSE]
  labels <- as.character(data[[label_col]])
  scores <- as.numeric(data$score)
  if (length(bar_colors) == 1L) {
    bar_colors <- rep(bar_colors, nrow(data))
  } else if (!is.null(names(bar_colors)) && "group_code" %in% names(data)) {
    bar_colors <- unname(bar_colors[as.character(data$group_code)])
    bar_colors[is.na(bar_colors)] <- "#0b9ed0"
  } else {
    bar_colors <- rep(bar_colors, length.out = nrow(data))
  }
  graphics::plot.new()
  graphics::plot.window(
    xlim = c(-55, 100),
    ylim = c(0.4, nrow(data) + 0.6)
  )
  positions <- rev(seq_len(nrow(data)))

  graphics::rect(
    xleft = 0,
    ybottom = positions - 0.33,
    xright = 100,
    ytop = positions + 0.33,
    col = "#e7e7e7",
    border = NA
  )
  graphics::rect(
    xleft = 0,
    ybottom = positions - 0.33,
    xright = scores,
    ytop = positions + 0.33,
    col = bar_colors,
    border = NA
  )
  graphics::text(
    x = -2,
    y = positions,
    labels = labels,
    adj = c(1, 0.5),
    xpd = NA,
    col = "#3f5365",
    cex = 0.85
  )
  graphics::text(
    x = pmax(scores - 2, 2),
    y = positions,
    labels = round(scores),
    adj = c(1, 0.5),
    col = "white",
    font = 2,
    cex = 0.85
  )
  graphics::axis(
    side = 1,
    at = seq(0, 100, by = 20),
    labels = FALSE,
    tck = -0.015,
    col = "#b8c3ca",
    col.ticks = "#b8c3ca"
  )
  invisible(NULL)
}

spi_plot_regions <- function(snapshot, year) {
  data <- overview_region_summary(snapshot, year)
  spi_plot_horizontal_bars(data)
}

spi_plot_region_history <- function() {
  if (!requireNamespace("spiR", quietly = TRUE)) {
    stop("The spiR package is required for the regional history visualization.")
  }
  plot <- spiR::spi_plot_regions(value_col = "SPI.INDEX")
  regions <- getFromNamespace(
    "SPI_PLOT_GEOGRAPHIC_REGIONS",
    "spiR"
  )
  region_data <- getFromNamespace(
    ".spi_plot_fetch_aggregates",
    "spiR"
  )(
    value_cols = "SPI.INDEX",
    region = regions
  )
  plot +
    ggplot2::geom_line(
      data = region_data,
      mapping = ggplot2::aes(
        x = date,
        y = value,
        color = region,
        linetype = region,
        group = region
      ),
      linewidth = 0.8,
      inherit.aes = FALSE
    ) +
    ggplot2::scale_linetype_manual(
      values = rep(c("solid", "dashed", "dotted", "dotdash"),
        length.out = length(regions)
      )
    ) +
    ggplot2::scale_x_continuous(
      limits = c(2016, 2024)
    )
}
