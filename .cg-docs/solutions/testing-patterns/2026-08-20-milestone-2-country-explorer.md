---
date: 2026-08-20
title: "Milestone 2 Country Explorer with a normalized all-years contract"
category: "testing-patterns"
language: "R"
tags: [milestone-2, country-explorer, shiny, golem, spiR, provider-adapter, normalized-data, fixture-injection, DT, year-selector]
root-cause: "Country Explorer needed to evolve independently from upstream spiR schemas while preserving Overview state, fallback behavior, partial coverage, and deterministic offline tests."
severity: "P2"
---

# Milestone 2 Country Explorer with a Normalized All-Years Contract

## Problem

Milestone 2 added Country Explorer to the SPI Shiny dashboard. The feature needed to browse country-level data across years, support Pillars, Dimensions, and Indicators views, expose region, income, and country filters, and provide an interactive table with summaries and single-row selection. It also had to use `spiR` as the preferred provider, retain the local fallback, preserve missing values, and keep Country Explorer year selection independent from Overview.

The provider operations can fail independently or return incomplete schemas. Loading a selected year directly from the provider would have coupled the UI to upstream behavior and made local tests dependent on live data.

## Root Cause

The missing boundary was an application-owned all-years snapshot and normalized contract for Country Explorer. Without it, provider interpretation, joins, duplicate metadata handling, view preparation, and Shiny reactivity would have been mixed together. The implementation also needed an explicit dependency-injection point so module and app tests could exercise the complete workflow with deterministic fixtures.

## Solution

### Normalize once, filter locally

`spi_provider_snapshot()` loads all available years once. The mandatory overall index remains authoritative; metadata, indicators, and aggregates are optional operations with typed status records and stable empty normalized objects when unavailable.

The dashboard boundary under `R/spi_provider.R` and `R/spi_adapter.R` normalizes these objects:

- `index`: country code, country name, year, overall score, and supported pillar or dimension values.
- `indicators`: long indicator data with reproducible technical IDs, labels, pillar and dimension metadata, score, and raw value.
- `metadata`: country code, country name, year, region, and income group.
- `operation_status`: `ok`, unavailable, or error state for each provider operation.

Country Explorer selects a year from the all-years snapshot and filters locally. Pillar and dimension values supplied directly by the index take precedence over indicator-derived values. Missing values remain `NA` and render as `-`, never as zero.

### Keep pure feature logic outside Shiny

`R/country_explorer_data.R` builds the authoritative country-year table from overall index data and joins metadata by country and year. Duplicate metadata is resolved deterministically by completeness and stable source order; conflicting non-missing metadata fields become `NA` and expose a non-blocking conflict status.

`R/country_explorer_helpers.R` owns filtering, reset behavior, view preparation, summaries, and change calculations. The module receives a snapshot loader and does not call provider functions or interpret upstream schemas directly.

### Inject deterministic fixtures at the app boundary

`app_server()` accepts an optional snapshot loader for tests while production continues to use the normal provider loader. The Country Explorer module owns its own year state, so changing its year does not mutate Overview. `DT` is declared in `DESCRIPTION` and is used for sorting, search, missing-value display, and single-row selection.

A focused test strategy combines pure fixture tests, `shiny::testServer()` module tests, fixture-backed app integration, and browser smoke checks. This keeps provider errors, partial coverage, duplicate metadata, view switching, and independent year state reproducible without network calls.

## Validation

The completed execution report recorded:

- 92 testthat expectations passed with 0 failures, warnings, or skips.
- Provider and adapter fixtures covered mandatory and optional operation states, fallback behavior, schemas, IDs, missing values, and precedence.
- Country Explorer data and helper tests covered year selection, filters, reset, duplicate metadata, views, summaries, and unavailable states.
- Module and app integration tests verified fixture injection and that Explorer year changes do not change Overview.
- Browser smoke tests verified DT initialization, search, sorting, `-` for missing change values, single-row selection, desktop rendering, and a 390px viewport.
- A clean package installation reached normal byte-compilation, lazy-loading, and help-index phases with `DT` 0.34.0 available.
- Local Golem servers started with the sibling `spiR` checkout, while the live-provider browser run remained in `recalculating`; no schema or data conclusion was inferred from that unresolved state.
- The sibling `spiR` repository remained untouched.

## Prevention

- Load all years once and filter the selected year locally in Country Explorer.
- Keep provider selection, aliases, normalization, and operation status under `R/`; keep Shiny modules dependent on normalized contracts.
- Treat only the overall index as mandatory and represent optional failures explicitly.
- Join metadata on country and year with deterministic duplicate resolution.
- Preserve `NA` through calculations and table rendering.
- Inject deterministic snapshots at the app and module boundaries; keep live provider calls out of ordinary tests.
- Run browser smoke checks in addition to server tests for client-side DT behavior and responsive rendering.
- Record unresolved live-provider behavior rather than inferring a data-schema failure from a loading state.

## Related

- `.cg-docs/plans/2026-08-13-milestone-2-country-explorer-final.md`
- `.cg-docs/work-reports/2026-08-13-milestone-2-country-explorer-final.md`
- `.cg-docs/solutions/bugs/2026-08-12-milestone-1-overview-implementation.md`
- `.cg-docs/solutions/testing-patterns/2026-09-01-milestone-4-country-comparison.md`
- `README.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/country_explorer_data.R`
- `R/country_explorer_helpers.R`
- `R/mod_country_explorer.R`
- `tests/testthat/`
