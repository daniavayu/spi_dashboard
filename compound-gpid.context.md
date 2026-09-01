# Project Context

Additional context for Copilot and the Compound GPID plugin. Edit freely —
this file is committed to git and shared with the team.

## Data Sources

- Primary provider: separate local sibling repository `spiR`.
- Local fallback: provider functions under `functions/`.
- Flourish map payload is scoped to 2024 for Milestone 1.

## Domain Rules

- Keep provider selection and schema normalization in the dashboard boundary under `R/spi_provider.R` and `R/spi_adapter.R`.
- Do not modify the separate `spiR` repository.
- Preserve missing values as missing; do not convert them to zero.
- Keep fragile/conflict filtering out of Milestone 2 Country Explorer.

## Work in Progress

Milestone 2 Country Explorer: normalized country-level data, selectable shared year, interactive table, Pillars/Dimensions/Indicators views, and deterministic Shiny tests.

## Workspace Notes

- **spiR sibling repository**: Local unmerged package used as the preferred SPI data provider during development.

## Wiki Configuration
<!-- folder: wiki -->
<!-- audience: developers -->
<!-- tone: technical -->

### Completed Milestone 3

- Country Profile uses independent normalized section objects for header, overall series, pillars, dimensions, indicators, dimension extremes, and official-reference benchmarks. The module owns its country/year state and preserves explicit pending, partial, empty, unavailable, and error statuses.
- The sibling `spiR` checkout is loaded with `devtools::load_all()` during development and verified before provider wiring. `spi_index()`, `spi_data()`, `country_info()`, `spi_aggregates()`, and `metadata()` provide the profile data; the external `spiR` repository remains untouched.
