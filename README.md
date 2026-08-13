# Statistical Performance Indicators Dashboard

Public Dashboard for the World Bank Statistical Performance
Indicators (SPI).

## Launch

From the repository root, run the single canonical launch command:

```powershell
Rscript --vanilla app.R
```

The launcher follows the standard golem/rsconnect pattern: it loads the
package with `pkgload::load_all()` and then calls `spiDashboard::run_app()`.
In RStudio, open `app.R` and use the blue Run App button. For deployment,
use `rsconnect::deployApp()` after configuring the deployment account.

The application is unauthenticated. The Overview and Country Explorer tabs
are available in the current milestones; later dashboard tabs remain outside
the implemented scope.

## Country Explorer

Country Explorer loads an all-years snapshot once and filters the selected
year locally, independently of the Overview year. Pillars are the default
view; Dimensions and Indicators are available from the view selector. The
table keeps Overall SPI visible and supports region, income-group, country
search, reset, sorting, search, and single-row selection. Summary statistics
describe the visible countries and active metric. Missing values are shown as
`-`, and `fragile/conflict` indicators are outside this milestone.

The Explorer uses normalized provider data: `spiR::spi_index()` supplies
overall, pillar, and dimension values where available, `spiR::spi_data()`
supplies detailed indicators, and `spiR::country_info()` supplies metadata.
The local provider functions remain the fallback. Metadata is joined by
country and year; duplicate metadata rows are resolved deterministically,
with conflicting non-missing values treated as missing. Optional provider
operations expose controlled unavailable/error states while the mandatory
overall index remains authoritative.

Country Profile, Compare Countries, maps, downloads, rankings, weighting, and
production deployment are not part of this milestone.

## Data provider

The application prefers the `spiR` package and keeps the local functions in
`functions/` as an explicit fallback. Provider selection and schema
normalization are isolated under `R/` so Shiny modules do not interpret
upstream column names directly.

## Development checks

Run the deterministic tests from the repository root:

```r
Rscript -e "testthat::test_dir('tests/testthat')"
```

The Flourish map remains the required existing visualization and is scoped to
the 2024 payload during Milestone 1. When `FLOURISH_API_KEY` is available in
the deployment environment, the app prepares the 2024 `regions` dataset in R
and injects it into the existing visualization through the Flourish Live API.
The API key must be supplied by deployment configuration and must not be
committed to the repository. Without the key, the public Flourish embed is
used as a display fallback.

## Repository boundary

The extensionless `App` artifact is retired. `app.R` is the only application
entry point. Existing files under `viz_functions/` remain available as inputs
for later milestones and are not silently migrated here.
