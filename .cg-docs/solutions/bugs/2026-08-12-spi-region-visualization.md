---
date: 2026-08-12
title: "Correct regional aggregates and visualization in the SPI dashboard"
category: "bugs"
language: "R"
tags: [R, Shiny, spiR, golem, regional-aggregates, visualization, package-development]
root-cause: "The dashboard filtered a broad set of World Bank aggregate codes instead of the seven geographic regions used by spiR, and long source labels were clipped in the horizontal bar chart."
severity: "P2"
---

# Correct Regional Aggregates and Visualization in the SPI Dashboard

## Problem

The `spi_dashboard` app used a local region summary for the Average SPI by Region panel. The panel included aggregate codes beyond the seven geographic regions used by `spiR`, and labels such as `Europe & Central Asia (excluding high income)` were clipped in the horizontal bar chart.

Development also required using local, not-yet-merged functions from a separate `spiR` repository. Calling `golem::run_dev()` with its default dependency installation attempted to resolve the local package as a remote dependency.

## Root Cause

`spiR::spi_aggregates()` returns multiple aggregate types: geographic regions, subregions, income groups, lending groups, and other World Bank aggregates. The dashboard filter included many of these codes:

```r
c("AFE", "AFW", "ARB", "EAP", "EAS", "SSA", ...)
```

The region plot in `spiR` intentionally supports only these seven geographic codes:

```r
c("EAP", "ECA", "LAC", "MNA", "NAC", "SAS", "SSF")
```

The source data also uses longer names for several codes, while the dashboard's base plotting helper has a fixed left label area. Those labels therefore extended beyond the plotting region.

Finally, `golem::run_dev()` defaults to installing required packages. In a two-repository local development setup, that caused `pak` to search for `spiDashboard` as a package dependency instead of using the local checkout.

## Solution

Load the local `spiR` checkout before loading and running the dashboard package. The development launcher supports an optional `SPIR_PATH` override and skips loading when the sibling repository is absent:

```r
spiR_path <- Sys.getenv(
  "SPIR_PATH",
  unset = file.path(getwd(), "..", "spiR")
)
if (dir.exists(spiR_path)) {
  devtools::load_all(spiR_path, quiet = TRUE)
}
```

Start the app without dependency resolution:

```r
golem::run_dev(install_required_packages = FALSE)
```

Restrict the dashboard's regional summary to the same seven geographic codes as `spiR`:

```r
region_codes <- c(
  "EAP", "ECA", "LAC", "MNA", "NAC", "SAS", "SSF"
)
```

Map those codes to short display labels without changing the underlying codes or values:

```r
region_labels <- c(
  EAP = "East Asia & Pacific",
  ECA = "Europe & Central Asia",
  LAC = "Latin America & Caribbean",
  MNA = "Middle East & North Africa",
  NAC = "North America",
  SAS = "South Asia",
  SSF = "Sub-Saharan Africa"
)
data$group_name <- unname(region_labels[data$group_code])
```

Use horizontal bars for the latest-year Average SPI by Region comparison. Keep the time-series plot separate in the Trends & Progress panel, where `spiR::spi_plot_regions(value_col = "SPI.INDEX")` is appropriate. Do not modify the original functions in the separate `spiR` repository.

## Prevention

- Treat `spiR::spi_plot_regions()` as the source of truth for supported geographic regions.
- Do not use the complete aggregate-code list as a geographic-region filter; it includes income and lending groups.
- Keep source identifiers and display labels separate.
- Use bars for cross-sectional latest-year comparisons and lines for trends over time.
- When developing against an unmerged local package in another repository, call `devtools::load_all()` on that checkout in the same R session as the dashboard and use `golem::run_dev(install_required_packages = FALSE)`.
- Validate both the expected region-code set and the number of returned regions with real `spiR` data.

## Related

- `R/overview_summary.R`
- `R/app_server.R`
- `R/spi_visualizations.R`
- `dev/run_dev.R`
- `tests/testthat/test-overview-summary.R`
- Local sibling package: `../spiR/R/spi-plot-regions.R`
