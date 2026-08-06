# install.packages(c("dplyr", "readr", "tidyr", "ggplot2"))

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

# ============================================================
# 1. SPI data: keep ALL columns (wide)
#    Every non-metadata column is a pillar / dimension / indicator
#    and can be compared over time by its EXACT name in the CSV.
# ============================================================
# --- spiR data API: pull SPI scores with spi_index() ---------
# While the spiR package is not yet installed, source the
# functions/ folder as a fallback so spi_index() is available.
if (requireNamespace("spiR", quietly = TRUE)) {
  library(spiR)
} else {
  suppressMessages(library(data.table))
  fn_dir <- if (dir.exists("functions")) "functions" else file.path("..", "functions")
  invisible(lapply(list.files(fn_dir, pattern = "\\.R$", full.names = TRUE),
                   function(f) try(source(f), silent = TRUE)))
}

spi_index <- as.data.frame(spi_index()) %>%
  mutate(date = as.integer(date))

# metadata columns (NOT comparable values); everything else is a value column
meta_cols  <- intersect(c("country", "iso3c", "date", "region"), names(spi_index))
value_cols <- setdiff(names(spi_index), meta_cols)

# ============================================================
# 2. Official WB Data Viz Style Guide palette
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_text        <- "#111111"   # text
wb_text_subtle <- "#666666"   # textSubtle
wb_grid        <- "#EBEEF4"   # grey100 -> grid lines

# WB Data Viz Style Guide "Basic Category Colors" (cat1..cat9), in order.
# Use these to distinguish categories such as country lines in a line chart.
# https://worldbank.github.io/data-visualization-style-guide/colors#category-colors
country_palette <- c("#34A7F2", "#FF9800", "#664AB6", "#4EC2C0", "#F3578E",
                     "#081079", "#0C7C68", "#AA0000", "#DDDA21")

# Linetypes that cycle across countries so overlapping lines remain distinguishable
country_linetypes <- c("solid", "dashed", "dotted", "dotdash", "longdash",
                       "twodash", "solid", "dashed", "dotted")

# ============================================================
# 3. Function: create_pillar_comparison(countries, value_col)
#    ANY SPI column over time, one line per country, to compare
#    multiple trajectories.
# ============================================================
#' Compare ANY SPI column over time across multiple countries
#'
#' Draws one line per country across all available years for a single SPI
#' value column (overall index, pillar, dimension or indicator). Useful for
#' benchmarking a country's trajectory against peers or regional neighbours.
#' Up to 10 countries can be distinguished with the WB brand colour palette.
#'
#' @param countries Character vector. Full country names as they appear in
#'   \code{spi_index.csv} (e.g. \code{c("Chile", "Peru", "Colombia")}).
#'   Countries not found in the data are silently dropped with a warning.
#' @param value_col Character. EXACT column name as written in the original
#'   database, e.g. \code{"SPI.INDEX"}, \code{"SPI.INDEX.PIL2"},
#'   \code{"SPI.DIM2.1.INDEX"}, \code{"SPI.D2.1.GDDS"}. Defaults to
#'   \code{"SPI.INDEX"}.
#' @param label Character. Optional title/legend label. Defaults to
#'   \code{value_col} (raw column name).
#' @param data Data frame (wide) with all SPI columns plus \code{country} and
#'   \code{date}. Defaults to the \code{spi_index} object created at load time.
#'
#' @return A \code{ggplot} object.
#'
#' @examples
#' create_pillar_comparison(c("Chile", "Peru", "Colombia"), "SPI.INDEX.PIL1")
#' create_pillar_comparison(c("Kenya", "Nigeria"), "SPI.DIM2.1.INDEX")
#' create_pillar_comparison(c("Chile", "Peru"), "SPI.D2.1.GDDS")
create_pillar_comparison <- function(countries,
                                     value_col = "SPI.INDEX",
                                     label     = NULL,
                                     data      = spi_index) {

  # --- validate the requested column (exact name from the CSV) ---
  if (!value_col %in% names(data)) {
    stop("Column '", value_col, "' not found.\nAvailable value columns:\n  ",
         paste(value_cols, collapse = ", "))
  }

  faltan <- setdiff(countries, unique(data$country))
  if (length(faltan) > 0) {
    warning("Countries not found (skipped): ",
            paste(faltan, collapse = ", "))
  }
  countries <- intersect(countries, unique(data$country))
  if (length(countries) == 0) stop("No valid countries to compare.")

  ttl <- if (is.null(label)) value_col else label

  plot_df <- data %>%
    select(country, date, value = all_of(value_col)) %>%
    mutate(
      value = as.numeric(value),
      value = dplyr::na_if(value, -99)          # -99 sentinel -> NA
    ) %>%
    filter(.data$country %in% !!countries) %>%  # keep NAs; only exclude wrong countries
    arrange(country, date) %>%
    # fill in missing year-country combinations with NA so geom_line shows gaps
    complete(country, date = seq(min(date, na.rm = TRUE),
                                 max(date, na.rm = TRUE))) %>%
    mutate(country = factor(country, levels = countries))

  # --- detect scale automatically: 0-1 (dim/indicator) vs 0-100 (index/pillar) ---
  is_share <- max(plot_df$value, na.rm = TRUE) <= 1
  lims     <- if (is_share) c(0, 1) else c(0, 100)

  pal    <- setNames(rep(country_palette,   length.out = length(countries)), countries)
  ltypes <- setNames(rep(country_linetypes, length.out = length(countries)), countries)

  ggplot(plot_df, aes(x = date, y = value,
                      colour = country, group = country, linetype = country)) +
    geom_line(linewidth = 1, na.rm = FALSE) +
    geom_point(size = 2, na.rm = TRUE) +
    scale_colour_manual(values = pal,    name = NULL) +
    scale_linetype_manual(values = ltypes, name = NULL) +
    scale_y_continuous(limits = lims) +
    labs(
      title    = paste0(ttl, " Overtime"),
      x        = NULL,
      y        = "Score",
      caption  = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = wb_grid),
      plot.title       = element_text(face = "bold", colour = wb_text),
      plot.caption     = element_text(colour = wb_text_subtle),
      axis.text        = element_text(colour = wb_text_subtle),
      axis.title       = element_text(colour = wb_text),
      legend.position  = "top"
    )
}

# ============================================================
# 4. Examples
# ============================================================
create_pillar_comparison(c("Chile", "Peru", "Colombia"), "SPI.INDEX")
create_pillar_comparison(c("Chile", "Peru"), "SPI.D2.1.GDDS")
create_pillar_comparison(c("Chile"), "SPI.INDEX")
# create_pillar_comparison(c("Kenya", "Nigeria"), "SPI.DIM2.1.INDEX")
# create_pillar_comparison(c("Chile", "Peru"), "SPI.D2.1.GDDS")
