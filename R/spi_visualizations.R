spi_plot_regions <- function(snapshot, year) {
  data <- overview_group_summary(snapshot, year)
  data <- head(data[order(data$score, decreasing = TRUE), ], 7L)

  if (!nrow(data)) {
    plot.new()
    text(0.5, 0.5, "No regional data for the selected year")
    return(invisible(NULL))
  }

  graphics::barplot(
    rev(data$score),
    names.arg = rev(data$group_name),
    horiz = TRUE,
    las = 1L,
    col = "#0b9ed0",
    border = NA,
    xlim = c(0, 100),
    main = "",
    xlab = "SPI score"
  )
}
