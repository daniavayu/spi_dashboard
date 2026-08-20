---
date: 2026-08-12
title: "Milestone 1 Overview implementation for the SPI Shiny dashboard"
category: "bugs"
language: "R"
tags: [milestone-1, overview, R, Shiny, golem, spiR, Flourish, provider-adapter, testing]
root-cause: "The dashboard needed an application-owned Overview boundary to coordinate two repositories, normalize spiR or local-provider data, and keep map and summary visualizations independent from upstream schemas."
severity: "P2"
---

# Milestone 1 Overview Implementation for the SPI Shiny Dashboard

## Problem

Milestone 1 required a maintainable public Overview for the SPI dashboard. The app had to use R Shiny and Golem, prefer the `spiR` package while it was still changing in a separate repository, preserve a local fallback, provide a shared latest-year data flow, retain the existing Flourish 2024 map, and render non-map summaries in R.

The repository also contained legacy functions and visualization scripts with implicit working-directory assumptions and direct data loading. Copying those scripts into Shiny modules would have coupled the UI to unstable upstream column names and made future SPI updates expensive.

## Root Cause

The core risk was an unclear ownership boundary between the dashboard and the `spiR` repository. The dashboard needed to consume provider functions without interpreting every upstream schema variation in its UI code. Regional aggregates also required semantic care because `spiR::spi_aggregates()` contains geographic regions, subregions, income groups, lending groups, and other aggregates in one table.

The project additionally needed local development against an unmerged sibling checkout. A normal `golem::run_dev()` attempted dependency resolution through `pak` and treated the local package name as a package to find remotely.

## Solution

### Application foundation and launch

The repository uses a minimal Golem-compatible package structure with `app.R` as the documented launch entry point. For local development against the sibling `spiR` checkout, `dev/run_dev.R` loads the local package first:

```r
spiR_path <- Sys.getenv(
  "SPIR_PATH",
  unset = file.path(getwd(), "..", "spiR")
)
if (dir.exists(spiR_path)) {
  devtools::load_all(spiR_path, quiet = TRUE)
}

pkgload::load_all(
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE
)
options(golem.app.prod = FALSE)
spiDashboard::run_app()
```

Start local development without remote dependency solving:

```r
golem::run_dev(install_required_packages = FALSE)
```

### Provider boundary and normalization

`R/spi_provider.R` selects `spiR` when available and otherwise loads the explicit local provider. The provider exposes stable operations for index data, indicators, country metadata, and aggregates. `spi_provider_snapshot()` retrieves the inputs once and returns normalized objects for the Overview.

The adapter in `R/spi_adapter.R` owns aliases, year conversion, score conversion, missing-value handling, country metadata, income data, and aggregate normalization. Shiny modules receive normalized data and do not call upstream functions or interpret source column names directly.

The effective contract is:

```r
snapshot <- list(
  provider = "spiR" or "local",
  index = normalized country-year index,
  indicators = normalized long indicator data,
  income_data = country scores joined to income metadata,
  metadata = normalized country metadata,
  aggregates = normalized official aggregate rows,
  years = available years with valid index scores
)
```

### Shared Overview state

The Overview server creates one shared reactive snapshot and derives the latest year with valid index data. Country rows without a valid score in that year are excluded. Partial indicator coverage and limited income-group observations remain available instead of being converted to zeroes.

The map remains explicitly scoped to 2024 for Milestone 1. R-based summaries use the shared latest-year state.

### Flourish map

The existing Flourish visualization remains the map implementation. `R/flourish_payload.R` prepares the required 2024 payload with `Economy` and `SPI.INDEX`, while the Live API integration keeps the deployment key outside source code. Without a key, the public Flourish embed remains the display fallback.

Dynamic Flourish updates for years other than 2024 are outside Milestone 1.

### Overview summaries and visualizations

The score distribution uses normalized country index data. Average SPI by Region uses official aggregate rows. The correct seven geographic region codes are:

```r
c("EAP", "ECA", "LAC", "MNA", "NAC", "SAS", "SSF")
```

These must not be replaced by the complete aggregate-code list, which includes subregions and income or lending groups. Display labels are shortened in `R/overview_summary.R` so the horizontal bar chart remains readable:

```r
c(
  EAP = "East Asia & Pacific",
  ECA = "Europe & Central Asia",
  LAC = "Latin America & Caribbean",
  MNA = "Middle East & North Africa",
  NAC = "North America",
  SAS = "South Asia",
  SSF = "Sub-Saharan Africa"
)
```

The latest-year regional comparison uses horizontal bars. A time-series plot based on `spiR::spi_plot_regions()` belongs in the later Trends & Progress surface, not in the latest-year comparison panel. The `spiR` plotting function itself remains unchanged.

Income-group summaries are calculated from available country observations joined to income metadata; they are not substituted with geographic aggregate rows.

## Validation

The Milestone 1 execution report records the following evidence:

- Clean-session foundation and package installation checks passed.
- Provider capability and normalized adapter tests passed.
- Missing-score, partial-row, limited-group, and official-aggregate scenarios passed.
- `shiny::testServer()` and app-object smoke tests passed.
- Overview summary and aggregate-source tests passed.
- The fixed-2024 Flourish payload test passed.
- Real `spiR` data returned exactly seven regional codes: `EAP`, `ECA`, `LAC`, `MNA`, `NAC`, `SAS`, `SSF`.
- The regional summary test passed with 11 assertions.
- The live Flourish embed remains pending because no deployment API key is available locally; no credential was committed.

## Prevention

- Keep provider selection and schema normalization in `R/spi_provider.R` and `R/spi_adapter.R`.
- Pass normalized snapshots into Shiny modules rather than loading data inside plots or UI code.
- Treat `spiR` as the primary provider and the local functions as an explicit temporary fallback.
- Keep the fixed 2024 Flourish scope visible and separate from the reactive R summaries.
- Validate aggregate semantics by code set and source ID, not only by row count.
- Use short display labels while preserving source codes and values.
- Use bars for latest-year comparisons and lines for trends over time.
- Keep ordinary tests deterministic and offline; isolate optional live provider and Flourish checks.
- Do not silently migrate unrelated visualization files or later dashboard tabs during Milestone 1.

## Status and Scope

Phase 1 of the refined Milestone 1 plan is complete. Phase 2 Overview implementation is complete except for the credentialed Live Flourish embed smoke test. Phase 3 acceptance and handoff evidence remain the next project-level steps. The out-of-scope surfaces are Country Explorer, Country Profile, Compare Countries, Trends & Progress, Explore by Pillar, Data and Downloads, dynamic Flourish years, downloads, authentication, multilingual support, and production deployment.

## Related

- `.cg-docs/brainstorms/2026-08-06-spi-shiny-dashboard.md`
- `.cg-docs/plans/2026-08-06-milestone-1-repository-overview-refined.md`
- `.cg-docs/work-reports/2026-08-06-milestone-1-repository-overview-refined.md`
- `.cg-docs/solutions/bugs/2026-08-12-spi-region-visualization.md`
- `.cg-docs/solutions/testing-patterns/2026-08-20-milestone-2-country-explorer.md`
- `README.md`
- `dev/run_dev.R`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/overview_summary.R`
- `R/flourish_payload.R`
- `tests/testthat/`
