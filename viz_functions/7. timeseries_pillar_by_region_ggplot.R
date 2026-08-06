# install.packages(c("dplyr", "readr", "tidyr", "ggplot2"))

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

# ============================================================
# 1. SPI data: 5 pillars + population in long format
# ============================================================
# --- spiR data API: pull SPI scores with spi_index() ---------
# region/population come from country_info(); joined by iso3c + date.
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
region_meta <- as.data.frame(country_info())[, c("iso3c", "date", "region", "population")]
spi_index   <- merge(spi_index, region_meta, by = c("iso3c", "date"), all.x = TRUE)

pillar_cols <- c("SPI.INDEX.PIL1", "SPI.INDEX.PIL2", "SPI.INDEX.PIL3",
                 "SPI.INDEX.PIL4", "SPI.INDEX.PIL5")

pillar_labels <- c("SPI.INDEX.PIL1" = "PIL1: Data Use",
                   "SPI.INDEX.PIL2" = "PIL2: Data Services",
                   "SPI.INDEX.PIL3" = "PIL3: Data Products",
                   "SPI.INDEX.PIL4" = "PIL4: Data Sources",
                   "SPI.INDEX.PIL5" = "PIL5: Data Infrastructure")

spi_long <- spi_index %>%
  select(country, region, date, population, all_of(pillar_cols)) %>%
  pivot_longer(cols = all_of(pillar_cols),
               names_to = "pillar", values_to = "value") %>%
  mutate(date = as.integer(date),
         value = as.numeric(value),
         population = as.numeric(population)) %>%
  filter(!is.na(value), !is.na(region))

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
pillar_colors <- c("PIL1: Data Use"            = "#34A7F2",  # cat1
                   "PIL2: Data Services"       = "#FF9800",  # cat2
                   "PIL3: Data Products"       = "#664AB6",  # cat3
                   "PIL4: Data Sources"        = "#4EC2C0",  # cat4
                   "PIL5: Data Infrastructure" = "#F3578E")  # cat5

# ============================================================
# 3. Function: create_pillars_by_region(region, weighted)
#    The 5 pillars over time for a region, as a population-
#    weighted average (weighted = TRUE) or simple mean (FALSE).
# ============================================================
#' Plot all SPI pillar trajectories over time for a WB region
#'
#' Draws one line per SPI pillar across all available years for the
#' selected WB region. The regional score per pillar-year can be computed
#' as a population-weighted average (default) or a simple (unweighted)
#' average across member countries.
#'
#' @param region Character. WB region name as it appears in
#'   \code{spi_index.csv} (e.g. \code{"Latin America & Caribbean"}).
#' @param weighted Logical. If \code{TRUE} (default), computes a
#'   population-weighted average; requires a \code{population} column
#'   in \code{data}. If \code{FALSE}, uses a simple (unweighted) mean.
#' @param pillars Character vector of pillar codes to display. Accepts
#'   short codes (\code{"PIL1"} through \code{"PIL5"}) or full column
#'   names. Defaults to all five pillars.
#' @param data Data frame in long format with columns \code{country},
#'   \code{region}, \code{date}, \code{population}, \code{pillar},
#'   \code{value}. Defaults to the \code{spi_long} object created at
#'   load time.
#'
#' @return A \code{ggplot} object.
#'
#' @examples
#' create_pillars_by_region("Latin America & Caribbean")
#' create_pillars_by_region("Sub-Saharan Africa", weighted = FALSE)
create_pillars_by_region <- function(region,
                                     weighted = TRUE,
                                     pillars  = pillar_cols,
                                     data     = spi_long) {

  # accepts "PIL1" or the full column name
  pillars <- ifelse(grepl("^PIL[1-5]$", pillars, ignore.case = TRUE),
                    paste0("SPI.INDEX.", toupper(pillars)), pillars)
  pillars <- pillars[pillars %in% pillar_cols]
  if (length(pillars) == 0) stop("No valid pillars found. Use PIL1..PIL5.")

  if (!region %in% data$region) {
    stop("Region not found: ", region, ". Use one of: ",
         paste(sort(unique(data$region)), collapse = ", "))
  }

  df <- data %>% filter(.data$region == !!region, .data$pillar %in% !!pillars)

  if (weighted) {
    df <- df %>% filter(!is.na(population))
    region_summary <- df %>%
      group_by(pillar, date) %>%
      summarise(value = sum(value * population, na.rm = TRUE) /
                        sum(population, na.rm = TRUE),
                .groups = "drop")
    agg_label <- "population-weighted average"
  } else {
    region_summary <- df %>%
      group_by(pillar, date) %>%
      summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
    agg_label <- "simple (unweighted) average"
  }

  plot_df <- region_summary %>%
    arrange(date) %>%
    mutate(pillar_lab = factor(pillar_labels[pillar],
                               levels = pillar_labels[pillar_cols]))

  ggplot(plot_df, aes(x = date, y = value, colour = pillar_lab)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_colour_manual(values = pillar_colors, name = NULL) +
    scale_y_continuous(limits = c(0, 100)) +
    labs(
      title    = paste0("SPI pillars over time: ", region),
      subtitle = agg_label,
      x        = NULL,
      y        = "Score",
      caption  = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = wb_grid),
      plot.title       = element_text(face = "bold", colour = wb_text),
      plot.subtitle    = element_text(colour = wb_text_subtle),
      plot.caption     = element_text(colour = wb_text_subtle),
      axis.text        = element_text(colour = wb_text_subtle),
      axis.title       = element_text(colour = wb_text),
      legend.position  = "top"
    )
}

# ============================================================
# 4. Examples
# ============================================================
create_pillars_by_region("Latin America & Caribbean")             # ponderado
create_pillars_by_region("Sub-Saharan Africa", weighted = FALSE)  # simple
