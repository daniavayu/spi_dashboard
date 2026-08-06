# install.packages(c("dplyr", "readr", "ggplot2", "sf", "stringr", "ggiraph"))
library(dplyr)
library(readr)
library(ggplot2)
library(sf)
library(stringr)
library(ggiraph)   # makes map interactive

# ------------------------------------------------------------
# spiR data API: pull SPI scores with spi_index(). While the
# spiR package is not yet installed, source the functions/
# folder as a fallback so spi_index() is available.
# ------------------------------------------------------------
if (requireNamespace("spiR", quietly = TRUE)) {
  library(spiR)
} else {
  suppressMessages(library(data.table))
  fn_dir <- if (dir.exists("functions")) "functions" else file.path("..", "functions")
  invisible(lapply(list.files(fn_dir, pattern = "\\.R$", full.names = TRUE),
                   function(f) try(source(f), silent = TRUE)))
}

# ------------------------------------------------------------
# Looks for a file in data/ from the current wd or the parent
# folder (works from the project root or from viz_functions/)
# ------------------------------------------------------------
find_data <- function(rel) {
  for (p in c(rel, file.path("..", rel))) {
    if (file.exists(p)) return(p)
  }
  stop("Cannot find ", rel, ". Open SPI_viz.Rproj or set the working ",
       "directory to the 'spi_viz/' folder.")
}

# ============================================================
# 1. WB official boundaries (admin 0 layer, countries)
#    Read DIRECTLY from the .zip using GDAL's virtual filesystem
#    (/vsizip/), so no extraction is needed.
# ============================================================
wb_boundaries_zip <- "data/World Bank Official Boundaries - Admin 0.zip"
wb_boundaries_shp <- "WB_GAD_ADM0.shp"   # shapefile inside the zip

load_wb_boundaries <- function(zip = wb_boundaries_zip,
                               shp = wb_boundaries_shp) {
  vsi_path <- file.path("/vsizip", normalizePath(find_data(zip), winslash = "/"), shp)
  b <- sf::st_read(vsi_path, quiet = TRUE)

  # auto-detect the column containing the ISO3 code
  iso_col <- names(b)[str_detect(
    names(b),
    regex("^(ISO_A3|WB_A3|ISO3|ISO_3|ISO_A3_EH)$", ignore_case = TRUE)
  )][1]
  if (is.na(iso_col)) {
    stop("ISO3 column not found. Available columns: ",
         paste(names(b), collapse = ", "))
  }

  # auto-detect the country name column (used in the hover tooltip)
  name_col <- names(b)[str_detect(
    names(b),
    regex("^(NAM_0|WB_NAME|NAME_EN|NAME|ADMIN|COUNTRY)$", ignore_case = TRUE)
  )][1]

  b <- b %>%
    mutate(
      iso3    = toupper(as.character(.data[[iso_col]])),
      country = if (!is.na(name_col)) as.character(.data[[name_col]]) else iso3
    ) %>%
    filter(!is.na(iso3), iso3 != "-99")

  b %>% select(iso3, country, geometry)
}

world <- load_wb_boundaries()   # loaded once at startup

# ============================================================
# 2. SPI data — load ALL columns (wide), not just SPI.INDEX
#    Every non-metadata column is a pillar / dimension / indicator.
# ============================================================
spi_all <- as.data.frame(spi_index()) %>%
  mutate(
    iso3 = toupper(trimws(iso3c)),
    year = as.integer(date)
  ) %>%
  filter(!is.na(iso3), nchar(iso3) == 3)

# metadata columns (NOT mappable values); everything else is a value column
meta_cols  <- c("country", "iso3c", "iso3", "date", "year")
value_cols <- setdiff(names(spi_all), meta_cols)

# ============================================================
# 3. Official WB Data Viz Style Guide palette
#    Sequential "Bad to Good" scale (seq1..seq5): higher SPI = better.
#    https://worldbank.github.io/data-visualization-style-guide/colors
# ============================================================
wb_seq_good    <- c("#FDF6DB", "#A1CBCF", "#5D99C2", "#2868A0", "#023B6F")  # seq1..seq5
wb_no_data     <- "#CED4DE"   # noData
wb_border      <- "#FFFFFF"   # country border colour
wb_text        <- "#111111"   # text
wb_text_subtle <- "#666666"   # textSubtle

# ============================================================
# 4. Function: create_spimap_col()
#    Maps ANY SPI column (index, pillar, dimension or indicator).
# ============================================================
#' World choropleth map of ANY SPI column
#'
#' Plots a world map coloured by any SPI value column (overall index, pillar,
#' dimension or indicator) for a given year, using the World Bank official
#' boundaries and the WB Data Viz sequential colour scale (bad-to-good).
#'
#' When \code{country} is provided, the default behaviour keeps the WHOLE
#' world visible and highlights the selected countries (the rest are dimmed to
#' the no-data grey). Set \code{zoom = TRUE} to crop the map to the selection
#' instead (useful for a full region such as South America).
#'
#' @param value_col Character. Exact column name to map, e.g. "SPI.INDEX",
#'   "SPI.INDEX.PIL2", "SPI.DIM2.1.INDEX", "SPI.D2.1.GDDS".
#' @param year Integer. Year to display (must exist in \code{spi_data}).
#' @param country Character vector of ISO3 codes (optional). Highlighted (or,
#'   with \code{zoom = TRUE}, the map is cropped to them).
#' @param zoom Logical. If \code{FALSE} (default) show the whole world and
#'   highlight \code{country}. If \code{TRUE} crop the map to \code{country}.
#' @param interactive Logical. If \code{TRUE} (default) returns a \code{girafe}
#'   widget with hover tooltips. If \code{FALSE} returns a plain \code{ggplot}.
#' @param label Character. Optional title/legend label. Defaults to
#'   \code{value_col} (raw column name).
#' @param spi_data Data frame (wide) with all SPI columns. Defaults to
#'   \code{spi_all}.
#' @param world_sf \code{sf} object with columns \code{iso3}, \code{country},
#'   \code{geometry}. Defaults to \code{world}.
#'
#' @return A \code{girafe} widget (interactive) or a \code{ggplot} object
#'   (static), both ready to print or save with \code{ggsave()}.
#'
#' @examples
#' create_spimap_col("SPI.INDEX", 2024)
#' create_spimap_col("SPI.INDEX.PIL2", 2024)
#' create_spimap_col("SPI.DIM2.1.INDEX", 2024)
#' create_spimap_col("SPI.D2.1.GDDS", 2024)
#' create_spimap_col("SPI.INDEX", 2024, country = c("CHL", "PER", "COL"))
#' create_spimap_col("SPI.INDEX", 2024, country = c("CHL", "PER"), zoom = TRUE)
create_spimap_col <- function(value_col,
                              year,
                              country     = NULL,
                              zoom        = FALSE,
                              interactive = TRUE,
                              label       = NULL,
                              spi_data    = spi_all,
                              world_sf    = world) {

  # --- validate the requested column ---
  if (!value_col %in% names(spi_data)) {
    stop("Column '", value_col, "' not found.\nAvailable value columns:\n  ",
         paste(value_cols, collapse = ", "))
  }

  yr  <- as.integer(year)
  ttl <- if (is.null(label)) value_col else label

  df <- spi_data %>%
    transmute(
      iso3  = .data$iso3,
      year  = .data$year,
      value = as.numeric(.data[[value_col]])
    ) %>%
    mutate(value = dplyr::na_if(.data$value, -99)) %>%   # -99 sentinel -> NA
    filter(!is.na(.data$value), .data$year == yr)

  sel <- if (!is.null(country) && length(country) > 0) toupper(country) else NULL

  # --- zoom mode: crop map + data to the selected countries ---
  if (!is.null(sel) && isTRUE(zoom)) {
    world_sf <- world_sf %>% filter(.data$iso3 %in% sel)
    df       <- df       %>% filter(.data$iso3 %in% sel)
    if (nrow(world_sf) == 0)
      stop("No matching ISO3 codes found: ", paste(sel, collapse = ", "))
  }

  # --- detect scale automatically: 0-1 (dim/indicator) vs 0-100 (index/pillar) ---
  vals     <- df$value[!is.na(df$value)]
  is_share <- length(vals) > 0 && max(vals, na.rm = TRUE) <= 1
  lims     <- if (is_share) c(0, 1) else c(0, 100)
  digits   <- if (is_share) 3 else 1

  map_df <- world_sf %>%
    left_join(df, by = "iso3") %>%
    mutate(
      # highlight flag: TRUE for selected countries (all TRUE when no selection)
      highlight = if (is.null(sel)) TRUE else .data$iso3 %in% sel,
      # in highlight mode, dim non-selected countries to no-data grey
      value = if (!is.null(sel) && !isTRUE(zoom)) {
        ifelse(.data$highlight, .data$value, NA_real_)
      } else {
        .data$value
      },
      tooltip = paste0(
        country, " (", iso3, ")\n",
        ttl, ": ",
        ifelse(is.na(value), "no data",
               format(round(value, digits), nsmall = digits))
      )
    )

  p <- ggplot(map_df) +
    geom_sf_interactive(
      aes(fill = value, tooltip = tooltip, data_id = iso3),
      color = wb_border, linewidth = 0.1
    ) +
    scale_fill_gradientn(
      colours  = wb_seq_good,
      na.value = wb_no_data,
      limits   = lims,                       # fixed scale -> comparable across years
      name     = ttl
    ) +
    coord_sf(crs = "+proj=natearth") +       # change to "+proj=robin" if preferred
    labs(
      title   = paste0(ttl, " | ", yr),
      caption = "Source: World Bank Statistical Performance Indicators (SPI)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      axis.text    = element_blank(),
      axis.ticks   = element_blank(),
      panel.grid   = element_blank(),
      plot.title   = element_text(face = "bold", colour = wb_text),
      plot.caption = element_text(colour = wb_text_subtle),
      legend.title = element_text(colour = wb_text)
    )

  # static (plain ggplot) or interactive (HTML widget with tooltip)
  if (!interactive) return(p)

  girafe(
    ggobj = p,
    options = list(
      opts_hover(css = "stroke:#111111;stroke-width:0.8px;"),
      opts_tooltip(css = paste0(
        "background:#FFFFFF;color:#111111;border:1px solid #CED4DE;",
        "padding:6px 8px;border-radius:4px;font-family:sans-serif;font-size:12px;"
      ))
    )
  )
}

# --- convenience shortcut: overall SPI index (backward compatible) ---
create_spimap <- function(year, country = NULL, zoom = FALSE, interactive = TRUE) {
  create_spimap_col("SPI.INDEX", year = year, country = country,
                    zoom = zoom, interactive = interactive)
}

# ============================================================
# 5. Examples
# ============================================================
create_spimap_col("SPI.D3.2.HNGR", 2024, country="CHL")                         # overall index (0-100)
create_spimap_col("SPI.INDEX", 2024)  
create_spimap_col(2024)  

# overall index (0-100)
# create_spimap_col("SPI.INDEX.PIL2", 2024)                  # pillar 2 (0-100)
create_spimap_col("SPI.DIM2.1.INDEX", 2024)       # dimension 2.1 (0-1)
# create_spimap_col("SPI.D2.1.GDDS", 2024)                   # indicator (0-1)
# create_spimap_col("SPI.INDEX", 2024, country = c("CHL","PER","COL"))          # highlight
# create_spimap_col("SPI.INDEX", 2024, country = c("CHL","PER"), zoom = TRUE)   # crop
