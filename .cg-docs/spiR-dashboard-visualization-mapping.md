# spiR to Dashboard Visualization Mapping

**Date:** 2026-08-21  
**Scope:** Current SPI dashboard and the local development checkout of `spiR`  
**Purpose:** Keep `spiR` as the single source of truth for reusable SPI visualizations so the dashboard can be replicated for any country, year, and future data release.

## Principle

The dashboard should own navigation, controls, layout, loading states, and error states. The `spiR` package should own reusable data retrieval and visualization logic. A dashboard wrapper is acceptable when it adapts Shiny state to an `spiR` function, but it should not reimplement the same chart.

The preferred call pattern is:

```r
spiR::spi_plot_function(...)
```

The dashboard must load and verify the development package with:

```r
devtools::load_all("../spiR")
```

The external `spiR` repository must not be modified from this dashboard repository.

## Official spiR Visualization API

The following functions were verified as exported by the local `spiR` checkout:

| spiR function | Signature | Intended output |
|---|---|---|
| `spi_plot_pillars()` | `country`, `pillars`, `version` | Five SPI pillar scores over time for one country |
| `spi_plot_trend()` | `countries`, `value_col`, `version` | One SPI series over time for one or more countries |
| `spi_plot_country_vs_region()` | `country`, `value_col`, `version` | One country versus its official regional aggregate over time |
| `spi_plot_radar()` | `country`, `year`, `version` | Country pillar profile versus its official regional aggregate |
| `spi_plot_regions()` | `regions`, `value_col`, `version` | SPI series over time for official regional aggregates |
| `spi_plot_region_pillars()` | `region`, `weighted`, `pillars`, `version` | Official regional pillar trajectories over time |
| `spi_plot_map()` | `value_col`, `year`, `country`, `zoom`, `interactive`, `label`, `version`, `resolution` | Static or interactive world map |

## Dashboard Mapping

### Visual Order by Window

The table below follows the current dashboard layout. Numbering runs from top
to bottom; visualizations on the same row are numbered from right to left.
Controls, KPI cards, tables, and explanatory text are excluded because this
inventory covers visualizations only.

| No. | Window / tab | Position in window | Visualization | Current source | Target `spiR` function | Status |
|---:|---|---|---|---|---|---|
| 1 | Overview | Row 1, full width | SPI scores by country map | Flourish embed/live map | `spiR::spi_plot_map()` | Pending migration |
| 2 | Overview | Row 2, full width | Score Distribution | Local `hist()` | None currently available | Dashboard-specific |
| 3 | Overview | Row 3, right | Average SPI by Income Group | Local summary plus `spi_plot_horizontal_bars()` | None currently available | Dashboard-specific |
| 4 | Overview | Row 3, left | Average SPI by Region | Local `spi_plot_regions()` wrapper | `spiR::spi_plot_regions()` | Partial |
| 1 | Country Profile | Row 1, right | Score Over Time | `spi_profile_official_trend()` | `spiR::spi_plot_trend()` | Connected |
| 2 | Country Profile | Row 1, left | Pillar Performance radar | `spi_profile_official_radar()` | `spiR::spi_plot_radar()` | Connected |
| 1 | Trends & Progress | Row 1, full width | Regional history | `spi_plot_region_history()` | `spiR::spi_plot_regions()` | Partial |

Country Explorer, Explore by Pillar, and Data & Downloads do not currently
contain a rendered visualization in the application. Compare Countries
renders pillar and trend comparisons plus a dimension-gap table. The Country
Profile tables are excluded from this chart inventory.

The visualizations that are available in `spiR` but not currently displayed in
the dashboard are `spi_plot_pillars()`,
`spi_plot_country_vs_region()`, and `spi_plot_region_pillars()`. The map
function `spi_plot_map()` is available as well, but Overview still uses the
existing Flourish implementation.

The `Strongest Dimensions` and `Areas for Improvement` panels do not require a
new `spiR` visualization function. The dashboard can use the dimension scores
returned by the existing `spiR` data functions, filter to the selected country
and year, sort the scores, and keep the top or bottom three. This is a simple
presentation transformation, not duplicated SPI data logic.

### Overview

| Dashboard visual | Current implementation | Target `spiR` function | Status | Required follow-up |
|---|---|---|---|---|
| SPI scores by country map | Existing Flourish embed/live map through `flourish_live_map_ui()` | `spiR::spi_plot_map()` | Pending migration | Replace or offer `spi_plot_map()` as the package-backed map. Preserve Flourish only if it remains an explicit product requirement. |
| Score Distribution | `hist()` in `app_server.R` using `overview_score_distribution()` | None currently available | Dashboard-specific | Keep local unless a distribution function is added to `spiR`. |
| Average SPI by Region | `spi_plot_regions()` in `R/spi_visualizations.R`, currently computes a local summary and draws local horizontal bars | `spiR::spi_plot_regions()` | Partial | Pass region selections and the correct value column directly to `spiR`; remove the local chart implementation once the output is equivalent. |
| Average SPI by Income Group | `spi_plot_horizontal_bars()` using `overview_income_group_summary()` | None currently available | Dashboard-specific | Keep local unless `spiR` adds an income-group visualization. |
| Regional history | `spi_plot_region_history()` wraps `spiR::spi_plot_regions()` and adds local layers using internal package objects | `spiR::spi_plot_regions()` | Partial | Use the public function directly and avoid `getFromNamespace()` for internal `spiR` objects. If extra layers are needed, add a supported public option or function to `spiR`. |

### Country Explorer

Country Explorer is primarily a table and filter workflow. It has no chart currently rendered in the module.

| Dashboard visual | Current implementation | Target `spiR` function | Status |
|---|---|---|---|
| Pillar view table | Normalized data table | `spiR::spi_plot_pillars()` is not a table replacement | No chart mapping |
| Dimension view table | Normalized data table | No direct equivalent | No chart mapping |
| Indicator view table | Normalized data table | No direct equivalent | No chart mapping |

A future Explorer chart could use `spi_plot_pillars()` for a selected country, but the table should remain a separate dashboard interaction unless `spiR` exposes a reusable table-oriented API.

### Country Profile

| Dashboard visual | Current implementation | Target `spiR` function | Status |
|---|---|---|---|
| Pillar Performance radar | `spi_profile_official_radar()` in `R/country_profile_visualizations.R` | `spiR::spi_plot_radar(country, year)` | Connected |
| Score Over Time | `spi_profile_official_trend()` in `R/country_profile_visualizations.R` | `spiR::spi_plot_trend(countries)` | Connected |
| Pillars over time | Not currently shown as a separate chart | `spiR::spi_plot_pillars(country)` | Available, not assigned |
| Country versus region | Not currently shown as a separate chart | `spiR::spi_plot_country_vs_region(country, value_col)` | Available, not assigned |

The Profile wrappers exist only to prioritize the official package function and retain a controlled fallback for offline fixtures. New Profile visualizations should follow the same pattern.

### Compare Countries

| Dashboard visual | Current implementation | Target `spiR` function | Status |
|---|---|---|---|
| Pillar comparison | Local comparison wrapper over the normalized snapshot | No direct equivalent | Dashboard-specific |
| Overall trend | Local comparison wrapper over the normalized snapshot | `spiR::spi_plot_trend()` | Partial |
| Largest dimension gaps | Local ranking over normalized dimension scores | No direct equivalent | Dashboard-specific |

### Future Dashboard Tabs

| Future visual concept | Official `spiR` function | Status |
|---|---|---|
| Country pillar trajectories | `spiR::spi_plot_pillars()` | Available, not assigned |
| Country versus regional trajectory | `spiR::spi_plot_country_vs_region()` | Available, not assigned |
| Regional pillar trajectories | `spiR::spi_plot_region_pillars()` | Available, not assigned |
| Regional SPI trends | `spiR::spi_plot_regions()` | Available, partially used |
| World map | `spiR::spi_plot_map()` | Available, not assigned; current Overview uses Flourish |

## Coverage Summary

### Already backed by official spiR functions

- Country Profile radar: `spi_plot_radar()`.
- Country Profile score trend: `spi_plot_trend()`.
- Part of the regional history path: `spi_plot_regions()`.

### Still implemented locally or with a local rendering layer

- Overview world map: Flourish embed/live implementation.
- Overview score distribution: base R histogram.
- Overview regional average bars: local aggregation and bar renderer.
- Overview income-group bars: local aggregation and bar renderer.
- Additional layers in regional history: local code accesses internal `spiR` objects.

### Official functions available but not yet assigned

- `spi_plot_pillars()`.
- `spi_plot_country_vs_region()`.
- `spi_plot_region_pillars()`.
- `spi_plot_map()`.

## Replication Roadmap

1. Keep `spiR` function calls behind small dashboard wrappers that accept Shiny selections and return the plot object.
2. Migrate regional history away from internal namespace access and local reconstruction.
3. Evaluate `spi_plot_map()` against the current Flourish map and choose one supported source of truth.
4. Add `spi_plot_pillars()` and `spi_plot_country_vs_region()` to the Country Profile when the UX requires them.
5. Use `spiR`-provided dimension scores for simple dashboard filters such as top three and bottom three; do not add a package function for that sorting logic.
6. Add tests that verify each mapped dashboard output calls the official `spiR` function when the package is available.
7. Keep local dashboard-only charts only where there is no corresponding `spiR` function, and record those gaps here.
8. When new visualization functions are released in the official CRAN version of `spiR`, update this mapping and replace temporary fallbacks where the contracts are compatible.

## Verification Commands

From the dashboard repository root:

```r
devtools::load_all("../spiR")

getNamespaceExports("spiR")[grep(
  "plot|radar", getNamespaceExports("spiR"), ignore.case = TRUE
)]

formals(spiR::spi_plot_radar)
formals(spiR::spi_plot_trend)
```

The mapping should be reviewed whenever the `spiR` API changes or a new dashboard visualization is added.
