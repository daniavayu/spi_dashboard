# install.packages(c("dplyr", "readr", "tidyr", "ggplot2"))

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

# ============================================================
# 0. coord_radar(): coord_polar with straight sides between axes
#    (required so the radar renders as a polygon, not with curved
#    sides). Based on the standard ggplot pattern.
# ============================================================
coord_radar <- function(theta = "x", start = 0, direction = 1) {
  theta <- match.arg(theta, c("x", "y"))
  r <- if (theta == "x") "y" else "x"
  ggproto("CoordRadar", CoordPolar,
          theta = theta, r = r, start = start,
          direction = sign(direction),
          is_linear = function(coord) TRUE)
}

# ============================================================
# 1. SPI data: only the 5 pillars in long format
# ============================================================
# --- spiR data API: pull SPI scores with spi_index() ---------
# region/income come from country_info(); joined by iso3c + date.
# While the spiR package is not yet installed, source the
# functions/ folder as a fallback so the API is available.
if (requireNamespace("spiR", quietly = TRUE)) {
  library(spiR)
} else {
  suppressMessages(library(data.table))
  fn_dir <- if (dir.exists("functions")) "functions" else file.path("..", "functions")
  invisible(lapply(list.files(fn_dir, pattern = "\\.R$", full.names = TRUE),
                   function(f) try(source(f), silent = TRUE)))
}

spi_index   <- as.data.frame(spi_index())
region_meta <- as.data.frame(country_info())[, c("iso3c", "date", "region", "income_level")]
spi_index   <- merge(spi_index, region_meta, by = c("iso3c", "date"), all.x = TRUE)

pillar_cols <- c("SPI.INDEX.PIL1", "SPI.INDEX.PIL2", "SPI.INDEX.PIL3",
                 "SPI.INDEX.PIL4", "SPI.INDEX.PIL5")

# short labels for the radar axes
pillar_short <- c("SPI.INDEX.PIL1" = "Pillar 1:\nData Use",
                  "SPI.INDEX.PIL2" = "Pillar 2:\nData Services",
                  "SPI.INDEX.PIL3" = "Pillar 3:\nData Products",
                  "SPI.INDEX.PIL4" = "Pillar 4:\nData Sources",
                  "SPI.INDEX.PIL5" = "Pillar 5:\nData Infrastructure")

spi_pillars <- spi_index %>%
  select(country, iso3c, date, region, income_level, all_of(pillar_cols)) %>%
  pivot_longer(
    cols      = all_of(pillar_cols),
    names_to  = "pillar",
    values_to = "value"
  )

# ============================================================
# 2. Official WB Data Viz Style Guide palette
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_country     <- "#0071BC"   # selection1  -> selected country
wb_reference   <- "#8A969F"   # reference   -> regional benchmark
wb_text        <- "#111111"   # text
wb_text_subtle <- "#666666"   # textSubtle
wb_grid        <- "#EBEEF4"   # grey100     -> grid lines

# ============================================================
# 3. Function: create_pillar_performance(country, year)
#    Radar of the 5 country pillars (filled) vs. the regional
#    average (dashed line) for a given year.
# ============================================================
#' Radar chart of SPI pillar scores for a country vs. its region
#'
#' Plots a radar (spider) chart showing the scores of all five SPI pillars
#' for the selected country (filled blue polygon) and the unweighted
#' regional average (dashed grey line) for a given year.
#'
#' @note The WB Data Viz Style Guide discourages radar charts because filled
#'   areas can be misleading and exact values are hard to read. Interpret the
#'   polygon area with care and rely on the plotted points for exact values.
#'
#' @param country Character. Full country name as it appears in
#'   \code{spi_index.csv} (e.g. \code{"Chile"}).
#' @param year Integer. Year to display. Defaults to \code{2024}.
#' @param data Data frame in long format with columns \code{country},
#'   \code{region}, \code{date}, \code{pillar}, \code{value}.
#'   Defaults to the \code{spi_pillars} object created at load time.
#'
#' @return A \code{ggplot} object using \code{coord_radar()} (polar
#'   coordinates with straight sides).
#'
#' @examples
#' create_pillar_performance("Chile")
#' create_pillar_performance("Kenya", 2020)
create_pillar_performance <- function(country,
                                      year = 2024,
                                      data = spi_pillars) {

  # --- validate year ---
  if (!year %in% data$date) {
    stop("Year not available: ", year, ". Use one of: ",
         paste(sort(unique(data$date)), collapse = ", "))
  }
  df_year <- data %>% filter(.data$date == !!year)

  # --- validate country ---
  if (!country %in% df_year$country) {
    stop("Country not found for ", year, ": ", country)
  }

  # --- auto-detect region ---
  region <- df_year %>%
    filter(.data$country == !!country) %>%
    pull(region) %>%
    unique()
  region <- region[!is.na(region)][1]
  if (is.na(region) || length(region) == 0) {
    stop("Region not found for country: ", country)
  }

  # --- country series ---
  country_df <- df_year %>%
    filter(.data$country == !!country) %>%
    transmute(pillar, value, serie = "country")

  # --- regional average per pillar (benchmark) ---
  region_df <- df_year %>%
    filter(.data$region == !!region) %>%
    group_by(pillar) %>%
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
    mutate(serie = "region")

  plot_df <- bind_rows(country_df, region_df) %>%
    mutate(
      pillar = factor(pillar, levels = pillar_cols, labels = pillar_short[pillar_cols]),
      serie  = factor(serie, levels = c("country", "region"))
    )

  # legend labels with actual names
  serie_labels <- c(country = country,
                    region  = paste0(region, " (avg.)"))

  ggplot(plot_df, aes(x = pillar, y = value, group = serie)) +
    geom_polygon(aes(colour = serie, fill = serie, linetype = serie),
                 linewidth = 1, alpha = 0.15) +
    geom_point(aes(colour = serie), size = 2.2) +
    coord_radar() +
    scale_y_continuous(limits = c(0, 100),
                       breaks = c(20, 40, 60, 80, 100)) +
    scale_colour_manual(values = c(country = wb_country,
                                   region  = wb_reference),
                        labels = serie_labels, name = NULL) +
    scale_fill_manual(values = c(country = wb_country,
                                 region  = NA),
                      labels = serie_labels, name = NULL) +
    scale_linetype_manual(values = c(country = "solid",
                                     region  = "dashed"),
                          labels = serie_labels, name = NULL) +
    labs(
      title    = "SPI Pillar Performance",
      subtitle = paste0(country, " vs. ", region, " regional average  \u00b7  ", year),
      x        = NULL,
      y        = NULL,
      caption  = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = wb_grid),
      axis.text.y      = element_text(colour = wb_text_subtle, size = 8),
      axis.text.x      = element_text(colour = wb_text, face = "bold"),
      plot.title       = element_text(face = "bold", colour = wb_text),
      plot.subtitle    = element_text(colour = wb_text_subtle),
      plot.caption     = element_text(colour = wb_text_subtle),
      legend.position  = "top"
    )
}

# ============================================================
# 4. Examples
# ============================================================
create_pillar_performance("Chile")
# create_pillar_performance("Kenya", 2020)
# create_pillar_performance("Peru",  2024)
