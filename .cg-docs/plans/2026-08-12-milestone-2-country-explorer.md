---
date: 2026-08-12
title: "Milestone 2: Country Explorer"
status: active
scope: "Standard"
brainstorm: "../brainstorms/2026-08-12-milestone-2-country-explorer.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-explorer, spiR, filters, table, pillars, dimensions, indicators]
phases: 2
---

# Plan: Milestone 2: Country Explorer

## Objective

Implement the Country Explorer tab as an independent Golem module. The tab
will use `spiR` as the primary provider, retain the local fallback from
Milestone 1, and present an interactive country table with Pillars as the
predetermined view and Dimensions and Indicators as alternative views.

The finished feature will let users filter by region, income level, country
name, and year; inspect summary statistics; sort and search the table; and
select one country as the future handoff to Country Profile.

## Context

Milestone 1 established the provider and adapter boundary, normalized index,
indicator, metadata, and aggregate objects, and a shared Overview year flow.
Country Explorer is currently a placeholder tab in `R/app_ui.R` and has no
feature module or table implementation.

The approved brainstorm keeps the dashboard mockup's table-centered layout but
adds a `Pillars / Dimensions / Indicators` view selector. Pillars is the
starting view. Dimensions may be narrowed by pillar, and Indicators should
show one selected indicator at a time to keep the table readable.

`spiR` remains in a separate local repository during development. The feature
must consume its functions through the dashboard provider boundary rather than
modifying the `spiR` repository or interpreting upstream schemas in Shiny UI
code.

No `compound-gpid.md` or `compound-gpid.local.md` exists. This plan proceeds
without project charter or local workflow configuration. Work remains on
`main`, as selected during planning.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Add Country Explorer as an independent Golem module. | Country Explorer brainstorm |
| R2 | Use `spiR` as the primary data source and preserve the local fallback. | Milestone 1 plan / brainstorm |
| R3 | Use `spiR::spi_index()` for overall SPI and pillar/dimension data where supported. | Country Explorer brainstorm |
| R4 | Use `spiR::spi_data()` for detailed indicator data. | Country Explorer brainstorm |
| R5 | Use `spiR::country_info()` for country, region, and income metadata. | Country Explorer brainstorm |
| R6 | Make Pillars the default view and support Dimensions and Indicators. | Country Explorer brainstorm |
| R7 | Provide region, income-level, country-search, and year filters. | Approved scope adjustment |
| R8 | Keep `Overall SPI` visible in every view and display missing values as `-`, never zero. | Country Explorer brainstorm |
| R9 | Provide summary statistics for the visible countries and active metric. | Country Explorer brainstorm |
| R10 | Support sorting, search, and single-row selection in the table. | Country Explorer brainstorm |
| R11 | Preserve partial coverage and provide controlled empty states. | Milestone 1 data contract |
| R12 | Keep Country Profile, Compare Countries, maps, downloads, and fragile/conflict filtering out of scope. | Approved scope boundaries |

## Phase 1: Data Contract and Feature Logic

### 1. Confirm the `spiR` schema and extend the shared adapter if necessary

- **Requirements**: R2, R3, R4, R5, R8, R11
- **Files**: `R/spi_adapter.R`, `R/spi_provider.R`, `tests/testthat/test-spi-adapter.R`, `tests/testthat/test-spi-provider.R` if needed
- **Details**: Confirm the current local `spiR` columns and identifiers for
  overall SPI, pillars, dimensions, indicators, country names, region, income
  level, year, and missing scores. Extend the adapter only for aliases or
  fields needed by Country Explorer. Preserve the normalized snapshot contract
  and the explicit local fallback. Do not add fragile/conflict fields or
  filters.
- **Test Scenarios**: `spiR` schema happy path; local fallback; missing score;
  partial indicator coverage; absent optional metadata; year filtering.
- **Tests**: Extend deterministic adapter/provider tests with fixtures for the
  Country Explorer fields.
- **Acceptance criteria**: Country Explorer can receive one normalized data
  object without calling provider functions from its UI module, and both the
  preferred provider and fallback remain testable.

### 2. Build pure Country Explorer data and view helpers

- **Requirements**: R3, R4, R5, R6, R7, R8, R9, R11
- **Files**: `R/country_explorer_data.R`, `R/country_explorer_helpers.R`, `tests/testthat/test-country-explorer-data.R`, `tests/testthat/test-country-explorer-helpers.R`
- **Details**: Create application-owned functions that combine normalized
  index, indicator, and metadata data. Implement filtering by region, income
  level, country search, and year. Implement view preparation for Pillars,
  Dimensions, and one selected Indicator. Keep `Overall SPI` in every output,
  retain `NA` for missing values, calculate average/median/standard deviation
  for the active metric, and calculate `Change` only when a valid prior-year
  observation exists. Return explicit empty data frames with stable columns
  when no rows match.
- **Test Scenarios**: each filter alone; combined filters; case-insensitive
  partial search; no results; missing scores; one country with partial
  indicators; no prior year; all three view modes.
- **Tests**: Pure helper tests using deterministic fixtures only.
- **Acceptance criteria**: Helpers are deterministic, independent of Shiny,
  and return stable table-ready data for all three views.

## Phase 2: Golem Module, Integration, and Handoff

### 3. Implement the Country Explorer Golem module and table

- **Requirements**: R1, R6, R7, R8, R9, R10, R11
- **Files**: `R/mod_country_explorer.R`, `DESCRIPTION`, `NAMESPACE`, table-related tests
- **Details**: Implement `mod_country_explorer_ui()` and
  `mod_country_explorer_server()` using the project's existing Golem module
  conventions. Add filters for region, income level, search, and year; a
  `Pillars / Dimensions / Indicators` selector; dependent pillar and dimension
  selectors; summary outputs; an interactive table with sorting and search;
  and single-row selection. Use the smallest compatible table dependency,
  expected to be `DT`, only after confirming installation compatibility. Keep
  `Overall SPI` visible and render missing values as `-`.
- **Test Scenarios**: default Pillars view; switching modes; dependent
  selectors; filter reactivity; empty result state; table row selection.
- **Tests**: `shiny::testServer()` module tests and a focused app smoke test.
- **Acceptance criteria**: The module renders in isolation with fixtures and
  supports the approved interaction contract without provider calls in the UI.

### 4. Register the module and reuse shared app state

- **Requirements**: R1, R6, R7, R12
- **Files**: `R/app_ui.R`, `R/app_server.R`, `R/mod_overview.R` or a new shared state helper if required
- **Details**: Replace the Country Explorer placeholder with the module UI and
  register its server from the application server. Reuse the global year state
  established by Overview or extract that state into an application-owned
  shared reactive interface; do not create an incompatible second year model.
  Keep Country Profile and Compare Countries as placeholders. Do not add a map,
  downloads, multi-row selection, rankings, or fragile/conflict filtering.
- **Test Scenarios**: clean app launch; Overview remains functional; Country
  Explorer opens with Pillars selected; year changes propagate consistently;
  other placeholder tabs remain unchanged.
- **Tests**: Existing Overview tests, module smoke test, and full testthat suite.
- **Acceptance criteria**: Country Explorer is navigable in the running Golem
  app and does not regress Milestone 1 outputs.

### 5. Document and validate the milestone

- **Requirements**: R1, R2, R6, R7, R8, R10, R11, R12
- **Files**: `README.md`, `tests/testthat/`, `.cg-docs/work-reports/` if an execution report is produced
- **Details**: Document local `spiR` loading, the Country Explorer views and
  filters, the table dependency, missing-data behavior, and the boundary with
  Country Profile and Compare Countries. Run deterministic tests and a local
  launch smoke test. Record any unresolved `spiR` schema or optional live-data
  limitation instead of silently inferring it.
- **Test Scenarios**: clean local launch; deterministic fixtures; local `spiR`
  checkout; fallback provider; zero-result filters; partial data.
- **Tests**: `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"`,
  parse/diagnostic checks, and local Golem smoke test.
- **Acceptance criteria**: Another contributor can launch, use, test, and
  understand Country Explorer without reading provider implementation details.

## Testing Strategy

- Test pure filter and view helpers with deterministic data frames.
- Test provider and adapter behavior separately from Shiny.
- Use `shiny::testServer()` for module inputs, reactive filters, view modes,
  summary outputs, and row selection.
- Keep live `spiR` calls out of ordinary deterministic tests.
- Run the full existing test suite after module integration.
- Verify the table visually at desktop and narrow viewport sizes during the
  local smoke test.

## Documentation Checklist

- [ ] Country Explorer launch and navigation.
- [ ] `spiR` preferred provider and local fallback.
- [ ] Pillars, Dimensions, and Indicators view behavior.
- [ ] Region, income-level, country-search, and year filters.
- [ ] Missing values and empty-result behavior.
- [ ] Table dependency and local setup.
- [ ] Single-row selection as the future Country Profile handoff.
- [ ] Explicit statement that fragile/conflict filtering is not part of this milestone.
- [ ] Boundary with Country Profile and Compare Countries.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Local `spiR` schemas differ from the Milestone 1 adapter contract. | Confirm schemas first, extend aliases centrally, and add fixtures before module work. |
| Pillar, dimension, or indicator metadata is not exposed consistently. | Use stable identifiers from `spiR`; make unsupported dependent selectors return a controlled empty state. |
| No compatible interactive table dependency is installed. | Evaluate the smallest compatible dependency before editing `DESCRIPTION`; stop if it cannot be installed. |
| Table rendering becomes too wide on small screens. | Keep Indicators single-select, use responsive table options, and test narrow viewports. |
| Missing values are mistaken for zeroes. | Preserve `NA` through helpers and test display formatting explicitly. |
| Year state diverges between Overview and Country Explorer. | Reuse or extract one shared year reactive instead of creating a second source of truth. |
| Feature logic leaks into `app_server.R`. | Keep data, helpers, and module logic in dedicated files and test module isolation. |
| Scope expands into Country Profile or Compare Countries. | Keep single-row selection only and treat downstream views as placeholders. |

## Out of Scope

- Fragile/conflict status and filtering.
- Country Profile analysis.
- Multi-country comparison or multi-row selection.
- New maps or Flourish changes.
- Downloads and exports.
- Custom weighting.
- Ranking claims.
- Production deployment.
- Changes to the separate `spiR` repository.

## Completion Contract

### Outcome

Country Explorer is a standalone Golem module with an interactive table,
Pillars as the default view, Dimensions and Indicators as alternatives, and
filters for region, income level, country search, and year. It uses the
normalized `spiR` provider boundary, preserves the local fallback, displays
missing values as `-`, and leaves Country Profile and Compare Countries out of
scope.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Required |
|----|-------------------|------------------|----------|
| V1 | Module files parse and diagnostics are clear. | `Rscript --vanilla -e "parse(...)"` plus editor diagnostics | yes |
| V2 | Provider and adapter expose the Country Explorer contract. | Focused provider/adapter tests with fixtures | yes |
| V3 | Filters and all three view modes return correct table data. | `test-country-explorer-helpers.R` and `test-country-explorer-data.R` | yes |
| V4 | Missing values, partial coverage, and empty states are controlled. | Pure helper tests and module tests | yes |
| V5 | Shiny module supports default view, dependent selectors, summary, and row selection. | `shiny::testServer()` module test | yes |
| V6 | Country Explorer is registered without regressing Overview. | App smoke test and existing Overview tests | yes |
| V7 | Full deterministic suite passes. | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` | yes |
| V8 | Local two-repository development works. | `devtools::load_all(spiR_path)` then `golem::run_dev(install_required_packages = FALSE)` | yes |

### Constraints

| ID | Constraint | Check |
|---|---|---|
| C1 | Follow Golem module structure. | Feature UI/server live in `mod_country_explorer.R`. |
| C2 | `spiR` is the primary provider. | Module consumes provider snapshot, not direct local data functions. |
| C3 | Preserve local fallback. | Provider fallback test passes. |
| C4 | Do not modify `spiR`. | Review changed-file list. |
| C5 | Missing values never become zero. | Fixture assertions and rendered table checks. |
| C6 | Stay on `main`; do not create a branch. | `git branch --show-current`. |
| C7 | Exclude fragile/conflict filtering. | No related input, helper, or requirement in implementation. |
| C8 | Keep Country Profile and Compare Countries out of scope. | Placeholder tabs remain unchanged. |

### Boundaries

- **Allowed**: Country Explorer module, adapter extensions required by its
  contract, table dependency, tests, documentation, and shared year-state
  extraction.
- **Out of scope**: fragile/conflict, Country Profile, Compare Countries,
  multi-selection, maps, downloads, rankings, weighting, production changes,
  and edits to `spiR`.

### Iteration Policy

1. Confirm the real `spiR` schema before choosing aliases or UI labels.
2. Repair provider/adapter or pure helpers before changing module rendering.
3. If the selected table dependency is unavailable, evaluate one compatible
   alternative and stop for a decision if both fail.
4. Keep unsupported metadata visible as unavailable rather than inferring it.
5. Run focused tests after each implementation slice, then the full suite.
6. Record any accepted deviation in the execution report instead of widening
   scope silently.

### Blocked-Stop Conditions

- Neither `spiR` nor the local fallback can provide country-level data.
- Stable pillar, dimension, or indicator identifiers cannot be established.
- The table dependency cannot be installed or rendered with the project Shiny
  version.
- The shared year state cannot be reused without breaking Milestone 1.
- Existing Milestone 1 tests regress for reasons unrelated to the feature and
  cannot be isolated.
