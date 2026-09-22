# Statistical Performance Indicators Dashboard

Shiny dashboard for the World Bank Statistical Performance Indicators (SPI).

## Overview

This project renders a dashboard for exploring SPI results across countries, regions, income groups, and time. The application is organized as a Shiny app with a shared snapshot loader, module-based screens, and provider abstraction for SPI data.

The dashboard currently includes:

- Global Overview
- Country Explorer
- Country Profile
- Compare Countries
- Trends & Progress
- Explore by Pillar
- Data & Downloads (in progress; see [Known gaps](#known-gaps))

## Project structure

- [app.R](app.R): canonical app entry point
- [R](R): Shiny UI/server modules and app logic
- [functions](functions): legacy/data-access helpers and provider wrappers
- [tests/testthat](tests/testthat): automated regression and UI/data validation tests
- [inst](inst): app config and static assets
- [DESCRIPTION](DESCRIPTION): package metadata and dependencies

## Run locally

From the repository root, launch the app with:

```powershell
Rscript --vanilla app.R
```

You can also open [app.R](app.R) in RStudio and use the Run App button.

### Notes for local development

The launcher expects a local development copy of `spiR` in a sibling folder by default:

```r
Sys.getenv("SPI_R_ROOT", unset = file.path(getwd(), "..", "spiR"))
```

If you have a different dev copy, set the environment variable before running:

```powershell
$env:SPI_R_ROOT = "C:/path/to/spiR"
Rscript --vanilla app.R
```

## App architecture

The app uses a layered approach:

1. Data source abstraction
   - `spiR` is preferred as the source for SPI data.
   - Local fallback functions remain available in [functions](functions) and [R/spi_provider.R](R/spi_provider.R) for resilience and testability.
    - The dashboard never writes to the sibling `spiR` repository. Its provider
       boundary records the status of each optional operation and keeps the
       normalized snapshot usable when metadata, indicators, or aggregates are
       unavailable.

2. Snapshot normalization
   - The snapshot loader consolidates index, metadata, and aggregate information.
   - Module logic consumes a normalized snapshot instead of raw upstream columns.

3. Shiny modules
   - [R/app_ui.R](R/app_ui.R): dashboard shell and tab layout
   - [R/app_server.R](R/app_server.R): app wiring and shared outputs
   - [R/mod_country_explorer.R](R/mod_country_explorer.R): country-level filtering and table exploration
   - [R/mod_country_profile.R](R/mod_country_profile.R): detailed country dashboard
   - [R/mod_country_compare.R](R/mod_country_compare.R): multi-country comparisons
   - [R/mod_trends_progress.R](R/mod_trends_progress.R): trends and progress views
   - [R/mod_pillar_explorer.R](R/mod_pillar_explorer.R): exploratory pillar-level
     analysis for a single country/year. Shows official pillar scores as cards
     (with year-over-year change and weighted contribution), lets the user set
     custom integer weights (must sum to 100) to compute an exploratory score
     distinct from the official SPI, and includes a pillar correlation heatmap
     and a cross-pillar scatter explorer with selectable X/Y pillars.
   - [R/mod_data_downloads.R](R/mod_data_downloads.R): CSV downloads from the normalized snapshot

## Data and provider behavior

The dashboard is designed to normalize provider data before rendering UI. In practice:

- `spiR` provides index, pillar, and metadata values when available.
- Local providers are used as fallback when required data is missing or unavailable.
- The app keeps provider-specific logic separate from visualization code.
- Missing values are handled consistently and displayed as blanks/`-` in the user interface.
- The Overview map is an embedded Flourish visualization; its payload is prepared
   by the dashboard and is not an `spiR` plot.
- Pillar and dimension tables, comparisons, and Trends summaries are dashboard
   calculations over the normalized snapshot. They preserve `NA` values rather
   than imputing zeros.

## Trends and numerical definitions

- Annual global summaries use the median, interquartile range (IQR), number of
   non-missing contributors, and number of countries represented in each year.
- Official group trends use the matching aggregate supplied by the provider when
   available. Their IQR and contributor counts are intentionally `NA`, because an
   aggregate score is not a country-level sample.
- Period change is `end - start` and is reported only for countries with both
   endpoint scores.
- Pillar stability is the standard deviation of observed year-over-year changes
   within the selected period. It is descriptive and is not a convergence or
   causal measure.
- Pillar associations use Pearson correlation on complete pairs with at least
   three observations and non-zero variation. They describe association only.
- Coverage and unavailable states are shown explicitly; missing observations are
   never converted to zero.

## Testing

Run the project test suite from the repository root:

```r
Rscript -e "testthat::test_dir('tests/testthat')"
```

The repo includes tests covering:

- provider and snapshot behavior
- country comparison logic
- country profile logic
- trend/progress calculations
- dashboard integration points

The deterministic suite is the release gate. Browser smoke coverage
(`tests/browser`, using `shinytest2` + headless Chrome via `chromote`) spans
all six ready tabs — Country Explorer, Country Profile, Compare Countries,
Trends & Progress, and Explore by Pillar — against a shared fixture app
(`tests/browser/fixture-app`). Run a smoke test with:

```r
Rscript tests/browser/country-profile-smoke.R
```

Note: `shinytest2::AppDriver$new()` must set both `load_timeout` (initial page
load) and `timeout` (used internally by `wait_for_idle()` on every
`set_window_size()`/`click()`); the default `timeout` (~15s) is too short once
the app's full reactive graph is loaded.

## Known gaps

- **Data & Downloads** (`R/mod_data_downloads.R`) is the one tab that is not
  yet finished: it has no dedicated `tests/testthat` coverage and its UI does
  not yet follow the `spi-card`/`spi-panel` visual system used by the other
  six tabs. Tracked as `milestone-7-data-downloads` in `roadmap.json`. It is
  also the only tab without browser smoke coverage.

## Deployment notes

This project is structured around a local development workflow and is not meant to be deployed by silently copying raw data into the repo. For deployment, use the RStudio/rsconnect workflow after validating the app locally.

## Important conventions

- Keep [app.R](app.R) as the canonical launch entry point.
- Prefer normalized snapshot data over raw provider objects in module code.
- Do not add credentials or API keys to the repository.
- New screens must follow the Golem module boundary: namespaced `*_ui()` and
   `*_server()` functions, injected snapshot loaders in tests, and no direct raw
   provider calls from UI modules.

## Related files

- [DESCRIPTION](DESCRIPTION)
- [NAMESPACE](NAMESPACE)
- [R/spi_provider.R](R/spi_provider.R)
- [R/trends_progress_data.R](R/trends_progress_data.R)
- [R/mod_trends_progress.R](R/mod_trends_progress.R)
