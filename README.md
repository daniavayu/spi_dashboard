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
- placeholder sections for future pillar and data-download functionality

## Project structure

- [app.R](app.R): canonical app entry point
- [R](R): Shiny UI/server modules and app logic
- [functions](functions): legacy/data-access helpers and provider wrappers
- [tests/testthat](tests/testthat): automated regression and UI/data validation tests
- [inst](inst): app config and static assets
- [viz_functions](viz_functions): visualization helpers and legacy chart code
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

## Data and provider behavior

The dashboard is designed to normalize provider data before rendering UI. In practice:

- `spiR` provides index, pillar, and metadata values when available.
- Local providers are used as fallback when required data is missing or unavailable.
- The app keeps provider-specific logic separate from visualization code.
- Missing values are handled consistently and displayed as blanks/`-` in the user interface.

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

## Deployment notes

This project is structured around a local development workflow and is not meant to be deployed by silently copying raw data into the repo. For deployment, use the RStudio/rsconnect workflow after validating the app locally.

## Important conventions

- Keep [app.R](app.R) as the canonical launch entry point.
- Prefer normalized snapshot data over raw provider objects in module code.
- Do not add credentials or API keys to the repository.
- Keep legacy visualization files in [viz_functions](viz_functions) unless they are intentionally migrated.

## Related files

- [DESCRIPTION](DESCRIPTION)
- [NAMESPACE](NAMESPACE)
- [R/spi_provider.R](R/spi_provider.R)
- [R/trends_progress_data.R](R/trends_progress_data.R)
- [R/mod_trends_progress.R](R/mod_trends_progress.R)
