# install.packages(c("dplyr", "readr", "tidyr", "ggplot2"))

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

# ============================================================
# 1. SPI data: 5 pillars in long format
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

spi_index <- as.data.frame(spi_index())

pillar_cols <- c("SPI.INDEX.PIL1", "SPI.INDEX.PIL2", "SPI.INDEX.PIL3",
                 "SPI.INDEX.PIL4", "SPI.INDEX.PIL5")

pillar_labels <- c("SPI.INDEX.PIL1" = "Pillar 1: Data Use",
                   "SPI.INDEX.PIL2" = "Pillar 2: Data Services",
                   "SPI.INDEX.PIL3" = "Pillar 3: Data Products",
                   "SPI.INDEX.PIL4" = "Pillar 4: Data Sources",
                   "SPI.INDEX.PIL5" = "Pillar 5: Data Infrastructure")

spi_long <- spi_index %>%
  select(country, iso3c, date, all_of(pillar_cols)) %>%
  pivot_longer(cols = all_of(pillar_cols),
               names_to = "pillar", values_to = "value") %>%
  mutate(date = as.integer(date), value = as.numeric(value)) %>%
  filter(!is.na(value))

# ============================================================
# 2. Official WB Data Viz Style Guide palette + brand categorical colours (5 pillars)
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_text        <- "#111111"   # text
wb_text_subtle <- "#666666"   # textSubtle
wb_grid        <- "#EBEEF4"   # grey100 -> grid lines

# WB Data Viz Style Guide "Basic Category Colors" (cat1..cat5), in order.
# Category colors distinguish the pillars in the same chart. (The dedicated
# "Pillar Colors" are NOT meant to be used together to distinguish categories.)
# https://worldbank.github.io/data-visualization-style-guide/colors#category-colors
pillar_colors <- c("Pillar 1: Data Use"            = "#34A7F2",  # cat1
                   "Pillar 2: Data Services"       = "#FF9800",  # cat2
                   "Pillar 3: Data Products"       = "#664AB6",  # cat3
                   "Pillar 4: Data Sources"        = "#4EC2C0",  # cat4
                   "Pillar 5: Data Infrastructure" = "#F3578E")  # cat5

# ============================================================
# 3. Function: create_pillars_by_country(country, pillars)
#    One line per SPI pillar over time for a single country.
# ============================================================
#' Plot all SPI pillar trajectories over time for a single country
#'
#' Draws one line per SPI pillar across all available years for the
#' selected country. Each pillar is shown in a distinct WB brand colour.
#' Useful for identifying a country's relative strengths and weaknesses
#' and how each pillar has evolved.
#'
#' @param country Character. Full country name as it appears in
#'   \code{spi_index.csv} (e.g. \code{"Chile"}).
#' @param pillars Character vector of pillar codes to display. Accepts
#'   short codes (\code{"PIL1"} through \code{"PIL5"}) or full column
#'   names (\code{"SPI.INDEX.PIL1"} etc.). Defaults to all five pillars.
#' @param data Data frame in long format with columns \code{country},
#'   \code{date}, \code{pillar}, \code{value}.
#'   Defaults to the \code{spi_long} object created at load time.
#'
#' @return A \code{ggplot} object.
#'
#' @examples
#' create_pillars_by_country("Chile")
#' create_pillars_by_country("Kenya", c("PIL1", "PIL3"))
create_pillars_by_country <- function(country,
                                      pillars = pillar_cols,
                                      data    = spi_long) {

  # accepts "PIL1" or the full column name
  pillars <- ifelse(grepl("^PIL[1-5]$", pillars, ignore.case = TRUE),
                    paste0("SPI.INDEX.", toupper(pillars)), pillars)
  pillars <- pillars[pillars %in% pillar_cols]
  if (length(pillars) == 0) {
    stop("No valid pillars found. Use PIL1..PIL5 or SPI.INDEX.PIL1..PIL5")
  }

  if (!country %in% data$country) {
    stop("Country not found: ", country)
  }

  plot_df <- data %>%
    filter(.data$country == !!country, .data$pillar %in% !!pillars) %>%
    arrange(date) %>%
    mutate(pillar_lab = factor(pillar_labels[pillar],
                               levels = pillar_labels[pillar_cols]))

  ggplot(plot_df, aes(x = date, y = value, colour = pillar_lab)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_colour_manual(values = pillar_colors, name = NULL) +
    scale_y_continuous(limits = c(0, 100)) +
    labs(
      title    = paste0("SPI pillars over time: ", country),
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
create_pillars_by_country("Chile")
# create_pillars_by_country("Kenya", c("PIL1", "PIL3"))
