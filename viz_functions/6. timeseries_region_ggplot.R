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
# region comes from country_info(); joined by iso3c + date.
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

spi_index   <- as.data.frame(spi_index()) %>%
  mutate(date = as.integer(date))
region_meta <- as.data.frame(country_info())[, c("iso3c", "date", "region")]
spi_index   <- merge(spi_index, region_meta, by = c("iso3c", "date"), all.x = TRUE)

# all valid SPI column names (used for validation and error messages)
all_spi_cols <- names(spi_index)[startsWith(names(spi_index), "SPI.")]

# all regions available in the data
all_regions <- sort(unique(spi_index$region[!is.na(spi_index$region)]))

# short region labels for the legend (standard WB codes)
region_short <- c(
  "East Asia & Pacific"                              = "EAP",
  "Europe & Central Asia"                            = "ECA",
  "Latin America & Caribbean"                        = "LAC",
  "Middle East, North Africa, Afghanistan & Pakistan"= "MENA",
  "North America"                                    = "NAM",
  "South Asia"                                       = "SAR",
  "Sub-Saharan Africa"                               = "SSA"
)

# ============================================================
# 2. Official WB Data Viz Style Guide palette
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_text        <- "#111111"   # text
wb_text_subtle <- "#666666"   # textSubtle
wb_grid        <- "#EBEEF4"   # grey100 -> grid lines

# WB Data Viz Style Guide "Basic Category Colors" (cat1..cat9), in order.
# https://worldbank.github.io/data-visualization-style-guide/colors#category-colors
region_palette <- c("#34A7F2", "#FF9800", "#664AB6", "#4EC2C0", "#F3578E",
                    "#081079", "#0C7C68")

# Linetypes that cycle so overlapping lines remain distinguishable
region_linetypes <- c("solid", "dashed", "dotted", "dotdash", "longdash",
                      "twodash", "solid")

# ============================================================
# 3. Function: create_region_comparison(regions, value_col)
#    Unweighted regional average of ANY SPI column over time,
#    one line per region, to compare regional trajectories.
# ============================================================
#' Compare ANY SPI column over time across WB regions
#'
#' Draws one line per region showing the unweighted average of all countries
#' in that region for a single SPI value column (overall index, pillar,
#' dimension or indicator). Useful for identifying regional trends and gaps.
#'
#' @param regions Character vector. WB region names as they appear in
#'   \code{spi_index.csv}. Defaults to all 7 regions. Short codes are also
#'   accepted (e.g. \code{"LAC"}, \code{"SSA"}, \code{"EAP"}).
#' @param value_col Character. EXACT column name as written in the database,
#'   e.g. \code{"SPI.INDEX"}, \code{"SPI.INDEX.PIL2"},
#'   \code{"SPI.DIM2.1.INDEX"}, \code{"SPI.D2.1.GDDS"}. Defaults to
#'   \code{"SPI.INDEX"}.
#' @param label Character. Optional override for the chart title. Defaults
#'   to \code{value_col}.
#' @param data Data frame (wide) with all SPI columns plus \code{country},
#'   \code{date}, and \code{region}. Defaults to \code{spi_index}.
#'
#' @return A \code{ggplot} object.
#'
#' @examples
#' create_region_comparison()                                        # all regions, overall index
#' create_region_comparison(value_col = "SPI.INDEX.PIL1")           # Pillar 1, all regions
#' create_region_comparison(c("LAC", "SSA"), "SPI.DIM2.1.INDEX")    # two regions, dimension
#' create_region_comparison(c("EAP", "ECA", "LAC"), "SPI.D2.1.GDDS") # indicator
create_region_comparison <- function(regions   = all_regions,
                                     value_col = "SPI.INDEX",
                                     label     = NULL,
                                     data      = spi_index) {

  # --- expand short codes (e.g. "LAC" -> full region name) ---
  short_to_full <- setNames(names(region_short), region_short)
  regions <- ifelse(regions %in% names(short_to_full),
                    short_to_full[regions], regions)

  # --- validate column ---
  if (!value_col %in% names(data)) {
    stop("Column '", value_col, "' not found.\n",
         "Available SPI columns include: SPI.INDEX, SPI.INDEX.PIL1, ",
         "SPI.DIM2.1.INDEX, SPI.D2.1.GDDS, ...")
  }

  # --- validate regions ---
  missing_r <- setdiff(regions, unique(data$region))
  if (length(missing_r) > 0) {
    warning("Regions not found (skipped): ", paste(missing_r, collapse = ", "))
  }
  regions <- intersect(regions, unique(data$region))
  if (length(regions) == 0) stop("No valid regions to compare.")

  ttl <- if (is.null(label)) value_col else label

  # --- compute unweighted regional average per year ---
  plot_df <- data %>%
    filter(.data$region %in% !!regions) %>%
    select(region, date, value = all_of(value_col)) %>%
    mutate(value = as.numeric(value),
           value = dplyr::na_if(value, -99)) %>%
    group_by(region, date) %>%
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
    mutate(value = dplyr::na_if(value, NaN)) %>%          # NaN (all-NA group) -> NA
    # fill missing year-region combinations with NA so geom_line shows gaps
    complete(region, date = seq(min(date, na.rm = TRUE),
                                max(date, na.rm = TRUE))) %>%
    arrange(region, date) %>%
    mutate(
      # use short label in legend if available, otherwise full region name
      region_lab = ifelse(region %in% names(region_short),
                          region_short[region], region),
      region_lab = factor(region_lab,
                          levels = region_short[regions[regions %in% names(region_short)]])
    )

  # --- trim x-axis: start at the first year with actual data ---
  first_year <- min(plot_df$date[!is.na(plot_df$value)], na.rm = TRUE)
  plot_df    <- filter(plot_df, date >= first_year)

  # --- detect scale: 0-1 (dimensions/indicators) vs 0-100 (pillars/index) ---
  is_share <- max(plot_df$value, na.rm = TRUE) <= 1
  lims     <- if (is_share) c(0, 1) else c(0, 100)

  pal    <- setNames(rep(region_palette,   length.out = length(regions)),
                     levels(plot_df$region_lab))
  ltypes <- setNames(rep(region_linetypes, length.out = length(regions)),
                     levels(plot_df$region_lab))

  ggplot(plot_df, aes(x = date, y = value,
                      colour   = region_lab,
                      group    = region_lab,
                      linetype = region_lab)) +
    geom_line(linewidth = 1, na.rm = FALSE) +
    geom_point(size = 2, na.rm = TRUE) +
    scale_colour_manual(values = pal,    name = NULL) +
    scale_linetype_manual(values = ltypes, name = NULL) +
    scale_y_continuous(limits = lims) +
    labs(
      title   = paste0(ttl, " by Region Over Time"),
      x       = NULL,
      y       = "Score (unweighted regional average)",
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
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
create_region_comparison()                                          # overall index, all regions
# create_region_comparison(value_col = "SPI.INDEX.PIL1")           # Pillar 1, all regions
# create_region_comparison(c("LAC", "SSA", "EAP"), "SPI.INDEX.PIL3")
# create_region_comparison(c("LAC", "SSA"), "SPI.DIM2.1.INDEX")    # dimension
# create_region_comparison(c("EAP", "ECA", "LAC"), "SPI.D2.1.GDDS") # indicator
