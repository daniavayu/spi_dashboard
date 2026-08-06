# install.packages(c("dplyr", "readr", "tidyr", "ggplot2"))

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)

# ============================================================
# 1. SPI data (long format: one pillar per row)
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

spi_index   <- as.data.frame(spi_index())
region_meta <- as.data.frame(country_info())[, c("iso3c", "date", "region")]
spi_index   <- merge(spi_index, region_meta, by = c("iso3c", "date"), all.x = TRUE)

spi_long <- spi_index %>%
  pivot_longer(
    # all SPI columns: overall index, pillars, dimensions, and indicators
    cols      = starts_with("SPI."),
    names_to  = "pillar",
    values_to = "value"
  )

# human-readable labels for the index and the 5 pillars
pillar_labels <- c(
  "SPI.INDEX"      = "SPI Overall Index",
  "SPI.INDEX.PIL1" = "Pillar 1: Data Use",
  "SPI.INDEX.PIL2" = "Pillar 2: Data Services",
  "SPI.INDEX.PIL3" = "Pillar 3: Data Products",
  "SPI.INDEX.PIL4" = "Pillar 4: Data Sources",
  "SPI.INDEX.PIL5" = "Pillar 5: Data Infrastructure"
)

# all valid column names available for comparison
all_spi_cols <- spi_long %>% pull(pillar) %>% unique()

# ============================================================
# 2. Official WB Data Viz Style Guide palette
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_country    <- "#0071BC"   # selection1  -> selected country
wb_reference  <- "#8A969F"   # reference   -> regional benchmark
wb_text       <- "#111111"   # text
wb_text_subtle<- "#666666"   # textSubtle
wb_grid       <- "#EBEEF4"   # grey100     -> grid lines

# ============================================================
# 3. Function: create_country_vs_region(country, pillar)
#    Compares a country (solid line) against its regional average
#    (dashed line) for a given pillar over time.
# ============================================================
#' Plot SPI time series for a country vs. its regional average
#'
#' Draws two lines over time for a given SPI pillar (or overall index):
#' the selected country (solid blue) and the unweighted average of all
#' countries in the same WB region (dashed grey). Colours follow the
#' WB Data Viz Style Guide.
#'
#' @param country Character. Full country name as it appears in
#'   \code{spi_index.csv} (e.g. \code{"Chile"}).
#' @param pillar Character. Any SPI column name or short code.
#'   Accepts short codes \code{"PIL1"}–\code{"PIL5"} (expanded to
#'   \code{"SPI.INDEX.PIL1"} etc.), dimension codes such as
#'   \code{"SPI.DIM2.1.INDEX"}, individual indicator codes such as
#'   \code{"SPI.D3.1.POV"}, or \code{"SPI.INDEX"} for the overall index.
#'   Defaults to \code{"SPI.INDEX.PIL1"}.
#' @param data Data frame in long format with columns \code{country},
#'   \code{region}, \code{date}, \code{pillar}, \code{value}.
#'   Defaults to the \code{spi_long} object created at load time.
#'
#' @return A \code{ggplot} object.
#'
#' @examples
#' create_country_vs_region("Chile", "PIL1")
#' create_country_vs_region("Kenya", "SPI.INDEX.PIL3")
#' create_country_vs_region("Peru",  "SPI.INDEX")          # overall index
#' create_country_vs_region("Brazil", "SPI.DIM2.1.INDEX")  # dimension
#' create_country_vs_region("India",  "SPI.D3.1.POV")      # indicator
create_country_vs_region <- function(country,
                                      pillar = "SPI.INDEX.PIL1",
                                      data   = spi_long) {

  # --- normalise input ---
  # short codes: "PIL1" -> "SPI.INDEX.PIL1"
  if (grepl("^PIL[1-5]$", pillar, ignore.case = TRUE)) {
    pillar <- paste0("SPI.INDEX.", toupper(pillar))
  }
  # if still not found, try prefixing with "SPI."
  if (!pillar %in% all_spi_cols && paste0("SPI.", pillar) %in% all_spi_cols) {
    pillar <- paste0("SPI.", pillar)
  }
  if (!pillar %in% all_spi_cols) {
    stop("Column not found: '", pillar, "'.\n",
         "Available columns start with SPI. — e.g. SPI.INDEX, SPI.INDEX.PIL1, ",
         "SPI.DIM2.1.INDEX, SPI.D3.1.POV")
  }

  # human-readable label: use lookup table, else the column name itself
  pillar_label <- if (pillar %in% names(pillar_labels)) pillar_labels[[pillar]] else pillar

  # auto-detect the region of the selected country
  region <- data %>%
    filter(.data$country == !!country) %>%
    pull(region) %>%
    unique()
  region <- region[!is.na(region)][1]
  if (is.na(region) || length(region) == 0) {
    stop("Region not found for country: ", country)
  }

  # country time series
  country_data <- data %>%
    filter(.data$country == !!country, .data$pillar == !!pillar) %>%
    arrange(date) %>%
    transmute(date, value, serie = "country")

  # regional average per year (benchmark)
  region_data <- data %>%
    filter(.data$region == !!region, .data$pillar == !!pillar) %>%
    group_by(date) %>%
    summarise(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
    arrange(date) %>%
    transmute(date, value, serie = "region")

  plot_df <- bind_rows(country_data, region_data) %>%
    mutate(serie = factor(serie, levels = c("country", "region")))

  # legend labels with actual names
  serie_labels <- c(country = country,
                    region  = paste0(region, " (avg.)"))

  ggplot(plot_df, aes(x = date, y = value,
                      colour = serie, linetype = serie)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_colour_manual(values = c(country = wb_country,
                                   region  = wb_reference),
                        labels = serie_labels, name = NULL) +
    scale_linetype_manual(values = c(country = "solid",
                                     region  = "dashed"),
                          labels = serie_labels, name = NULL) +
    scale_y_continuous(limits = c(0, NA)) +    # start at 0; upper limit auto
    labs(
      title    = pillar_label,
      subtitle = paste0(country, " vs. ", region, " regional average"),
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
create_country_vs_region("Chile", "SPI.D4.1.8.BZSVY")
create_country_vs_region("Kenya", "SPI.INDEX.PIL3")
# create_country_vs_region("Peru",  "SPI.INDEX")            # overall index
# create_country_vs_region("Brazil", "SPI.DIM2.1.INDEX")    # dimension
# create_country_vs_region("India",  "SPI.D3.1.POV")        # indicator
