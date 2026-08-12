---
date: 2026-08-12
title: "Milestone 2: Country Explorer"
status: decided
scope: "Standard"
artifact-schema-version: 1
language: "R"
tags: [spi, shiny, golem, country-explorer, spiR, filters, table, pillars, dimensions, indicators]
---

# Milestone 2: Country Explorer

## Context

Milestone 1 established the Golem-compatible SPI dashboard foundation, the
provider and normalization boundary, and the public Overview tab. Milestone 2
adds the Country Explorer tab described in the initial dashboard brainstorm and
refined using the supplied dashboard mockup.

The primary user need is to browse, filter, and inspect countries without
requiring the full analytical depth of Country Profile. Country Profile remains
a later milestone, and multi-country comparison remains a separate future
milestone.

## Product Decision

Country Explorer will use an interactive table as its primary experience. The
mockup's general layout is retained: filters above the table, summary statistics
above the results, and a dense country comparison table. A map is not required
for this milestone because the Overview already provides the Flourish map and a
table is better suited to precise filtering and sorting.

## View Modes

The default view is **Pillars**. A segmented control or equivalent selector
will switch between:

- **Pillars**: overall SPI and the five pillar scores.
- **Dimensions**: dimension scores, optionally narrowed by a selected pillar.
- **Indicators**: one selected indicator at a time, optionally narrowed by
  pillar and dimension, to keep the table readable.

`Overall SPI` remains visible in all three modes. Missing values are displayed
as `-`, never as zero.

## Shared Filters

All view modes use the same filters:

- Region.
- Income level.
- Fragile and conflict status.
- Country-name search with partial matching.
- Global year selection.
- Reset filters.

The result summary reports the number of visible countries and statistics for
the active metric: average, median, and standard deviation where meaningful.

## Table Behavior

The table shows one row per country and supports sorting by its columns. The
initial Pillars view includes:

- Country.
- Region.
- Income group.
- Overall SPI.
- Five pillar scores.
- Change from the previous year only when a valid prior-year observation exists.

Rows are selectable one country at a time. Selecting a row is the future
navigation point to Country Profile. Multiple row selection is intentionally
out of scope because multi-country selection belongs to Compare Countries.

## Data and Package Boundary

`spiR` is the primary data source. Country Explorer must reuse the package
functions rather than duplicate their calculations:

```r
spiR::spi_index()       # Overall SPI, pillars, dimensions
spiR::spi_data()        # Detailed indicator data
spiR::country_info()    # Country, region, income, fragile/conflict metadata
spiR::spi_aggregates()  # Official aggregate rows only when needed
```

The dashboard owns only the application adapter, filtering, reshaping, and
presentation. It must continue to support the local fallback established in
Milestone 1 while the sibling `spiR` repository is not merged or installed as a
released package.

During local development, load the sibling checkout in the same R session:

```r
spiR_path <- "C:/Users/wb661551/OneDrive - WBG/Desktop/Internship/SPI/spiR"
devtools::load_all(spiR_path)
golem::run_dev(install_required_packages = FALSE)
```

## Golem Structure

Country Explorer remains an independent Golem module and does not put feature
logic directly in `app_server.R` or `app_ui.R`.

```text
R/
  mod_country_explorer.R
  country_explorer_data.R
  country_explorer_helpers.R
```

Responsibilities:

- `mod_country_explorer.R`: module UI, Shiny inputs, reactives, outputs, and
  table connection.
- `country_explorer_data.R`: obtains and combines the normalized provider data
  needed by the explorer.
- `country_explorer_helpers.R`: pure filtering, searching, view preparation,
  statistics, missing-value handling, and prior-year change calculations.
- `R/spi_provider.R` and `R/spi_adapter.R`: remain the shared provider and
  schema boundary; Country Explorer must not reinterpret upstream schemas in
  the UI module.

`app_ui.R` and `app_server.R` should only register and connect the module.

## Scope Boundaries

In scope:

- Interactive table.
- Pillars as the default view.
- Dimensions and indicators as dependent view modes.
- Shared filters and search.
- Summary statistics.
- Missing-data display.
- Single-row selection as a future Country Profile handoff.
- Tests for filtering, view preparation, latest-year behavior, and empty states.

Out of scope:

- Full Country Profile analysis.
- Multi-country comparison.
- A dedicated map for Country Explorer.
- Downloads and exports.
- Custom weighting.
- Ranking claims unless explicitly validated and approved.
- Production deployment changes.

## Open Implementation Questions

- Confirm the exact five pillar names and the dimension/indicator metadata
  columns exposed by the current local `spiR` checkout.
- Confirm which `country_info()` field represents fragile/conflict status and
  how missing or unclassified values should appear in the filter.
- Select the table implementation already supported by the project dependency
  set, preferring the smallest package addition compatible with Golem.
- Decide whether the global year selector is reused directly from Overview or
  moved into shared app state during implementation.

## Acceptance Shape

A contributor should be able to load the local `spiR` checkout, launch the
Golem app, open Country Explorer, leave Pillars selected by default, filter the
country table, switch to Dimensions or Indicators, and see controlled empty
states without changing provider code. The module should be independently
testable with deterministic fixtures and should leave Country Profile and
Compare Countries available for later milestones.

## Related

- `.cg-docs/brainstorms/2026-08-06-spi-shiny-dashboard.md`
- `.cg-docs/solutions/bugs/2026-08-12-milestone-1-overview-implementation.md`
- `README.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/mod_overview.R`
