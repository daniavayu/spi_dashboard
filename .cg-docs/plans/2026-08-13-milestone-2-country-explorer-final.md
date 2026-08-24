---
date: 2026-08-13
title: "Milestone 2: Country Explorer (Final Plan)"
status: in-progress
completed-date: null
completed-phases: [1, 2]
scope: "Standard"
brainstorm: "../brainstorms/2026-08-12-milestone-2-country-explorer.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-explorer, compare-countries, spiR, filters, table, pillars, dimensions, indicators, year-selector, multi-selection]
phases: 2
---

# Plan: Milestone 2: Country Explorer (Final Plan)

## Objective

Implement Country Explorer as an independent Golem module for browsing and
filtering country-level SPI data. The module will provide Pillars as the
default view and Dimensions and Indicators as alternatives, while keeping
provider interpretation outside the Shiny UI layer.

Country Explorer will load all available years once, allow the user to select
a year locally, filter by region, income level, and country name, inspect
summary statistics, use an interactive table, and select one country for a
future Country Profile handoff. It will also allow users to select multiple
countries and send them to the Compare Countries tab. Compare will provide a
first functional comparison view using the selected ISO3 country codes.
Overview keeps its current year state and behavior; changing the Country
Explorer year does not change Overview.

## Milestone 2 Scope Amendment

The original plan treated multi-country selection and Compare Countries as
later work. The product workflow now requires Country Explorer to be the entry
point for comparison, so this amendment adds the smallest useful handoff:

- Country Explorer uses checkbox-style multi-row selection.
- `Compare Selected` is enabled only when at least two countries are selected.
- The handoff stores stable ISO3 codes, not display names or table row numbers.
- The existing top-level tab navigation opens Compare Countries after handoff.
- Compare Countries displays the selected countries and a first comparison
  chart for the selected Explorer year.
- Full comparison controls, exports, weighting, ranking claims, and advanced
  comparison views remain outside this amendment.

## Context

Milestone 1 established the Golem-compatible dashboard, provider and adapter
boundary, normalized overall index/indicator/metadata objects, local fallback,
and Overview. The current provider snapshot calls index, metadata, detailed
indicators, and aggregates, while the current index normalizer does not yet
retain pillar or dimension columns. `app_server()` currently has no injectable
snapshot loader and `test-spi-provider.R` does not yet exist.

The local sibling `spiR` repository provides `spi_index()`, `spi_data()`,
`country_info()`, and `spi_aggregates()`. `spi_data()` is the confirmed source
for country-year detailed indicator data. The dashboard will load the Explorer
snapshot without a year argument, normalize all returned years centrally, and
filter the selected year locally. The sibling repository must not be modified.

The plan review requires a per-operation status contract, explicit schemas and
precedence for pillars/dimensions, deterministic duplicate handling, a clean
table dependency decision, browser-level table evidence, and an injectable app
loader. The approved scope excludes `fragile/conflict` filtering even though it
appears in the historical brainstorm.

The project charter identifies Country Explorer as the current focus. Work
remains on `main`.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Add Country Explorer as an independent Golem module. | Country Explorer brainstorm |
| R2 | Use `spiR` as the primary provider and preserve the local fallback. | Project charter / Milestone 1 contract |
| R3 | Use `spiR::spi_index()` for overall, pillar, and dimension data where the confirmed schema supports it. | Country Explorer brainstorm |
| R4 | Use `spiR::spi_data()` for country-year detailed indicator data. | Confirmed local `spiR` capability |
| R5 | Use `spiR::country_info()` for country, region, and income metadata where available. | Country Explorer brainstorm |
| R6 | Make Pillars the default view and support Dimensions and Indicators. | Approved product decision |
| R7 | Provide region, income-level, country-search, reset, and independent Country Explorer year filters. | Approved scope adjustment |
| R8 | Keep Overall SPI visible in every view and display missing values as `-`, never zero. | Country Explorer brainstorm |
| R9 | Provide average, median, and standard deviation for the visible countries and active metric. | Country Explorer brainstorm |
| R10 | Support table sorting, table search, and multi-row checkbox selection. | Scope amendment |
| R11 | Preserve partial coverage and provide controlled empty/unavailable states. | Milestone 1 data contract |
| R12 | Keep `fragile/conflict`, Country Profile, maps, downloads, rankings, weighting, and production changes out of scope. | Approved scope boundaries |
| R13 | Handoff two or more selected countries from Explorer to Compare Countries using ISO3 codes. | Scope amendment |
| R14 | Render a first functional Compare Countries view for selected countries and Explorer year. | Scope amendment |

## Phase 1: Data Contract and Feature Logic

### 1. Define the all-years provider snapshot and normalized contract

- **Requirements**: R2, R3, R4, R5, R8, R11
- **Files**: `R/spi_adapter.R`, `R/spi_provider.R`, `tests/testthat/test-spi-adapter.R`, `tests/testthat/test-spi-provider.R`
- **Details**: Load provider operations without a year filter for Country
  Explorer. Define `spi_provider_snapshot()` as an all-years snapshot with a
  mandatory `index` operation and optional `metadata`, `indicators`, and
  `aggregates` operations. Wrap every optional call in a safe operation
  boundary that captures `ok`, `status`, and a concise `error` message. On
  missing columns, unsupported arguments, provider errors, or local fallback
  errors, return a typed empty normalized object and status rather than aborting
  the whole snapshot. The minimum usable snapshot contains country code,
  country name, year, and overall score.

  Define exact normalized schemas: `index` has
  `country_code`, `country_name`, `year`, `score`, plus normalized pillar and
  dimension score columns when directly supplied; `indicators` is long with
  `indicator_id`, `indicator_label`, `pillar_id`, `pillar_label`,
  `dimension_id`, `dimension_label`, `country_code`, `country_name`, `year`,
  `score`, and `raw_value`; `metadata` has `country_code`, `country_name`,
  `year`, `region`, and `income_group`; `operation_status` records each
  operation's state.

  Preserve reproducible technical IDs such as `SPI.D1.1.TEST`. Use metadata
  labels when available and the technical ID as the visible fallback when
  labels are absent. Pillar/dimension scores from direct `spi_index()` columns
  take precedence over indicator-derived values; indicator-derived values are
  used only when the direct value is absent and the derivation is defined by
  the existing data contract. Never silently combine conflicting values.
- **Test Scenarios**: all-years `spi_data()` response; direct pillar/dimension
  columns; absent direct columns; reproducible IDs; missing labels; missing
  scores; partial rows; metadata absent; each optional operation failing;
  unsupported year argument; local fallback; available-year extraction.
- **Tests**: Create `tests/testthat/test-spi-provider.R` with provider stubs
  for success, malformed response, unsupported operation, error, and fallback.
  Extend `test-spi-adapter.R` with exact schema and precedence fixtures. Keep
  live provider calls out of deterministic tests.
- **Acceptance criteria**: Country Explorer receives one all-years normalized
  snapshot. Overall data remains available when optional operations fail, and
  every operation exposes a predictable status and empty-object fallback.

### 2. Build pure Country Explorer joins, filters, views, and summaries

- **Requirements**: R3, R4, R5, R6, R7, R8, R9, R11
- **Files**: `R/country_explorer_data.R`, `R/country_explorer_helpers.R`, `tests/testthat/test-country-explorer-data.R`, `tests/testthat/test-country-explorer-helpers.R`
- **Details**: Build an authoritative country-year base table from overall
  index data keyed by `country_code + year`. Join metadata on the same key.
  Before joining, collapse duplicate metadata deterministically: prefer a row
  with non-missing region and income values; then prefer the row with the
  greatest source completeness; then use original stable row order as the
  final tie-breaker. If equally complete rows contain conflicting values,
  retain the overall score, set the conflicting metadata field to `NA`, and
  expose a non-blocking conflict status.

  Filter locally from the all-years snapshot: selected year first, then region,
  income level, and case-insensitive partial country search. Reset restores the
  latest available Explorer year and clears the other filters. Prepare stable
  table-ready outputs for Pillars, Dimensions, and one selected Indicator.
  Keep Overall SPI in every output, preserve `NA`, calculate average/median/
  standard deviation for the active metric, and calculate Change only when a
  valid prior-year observation exists. Return stable empty frames and status
  information for no matches or unavailable optional operations.
- **Test Scenarios**: latest-year initialization; change to an earlier year;
  each filter; combined filters; reset; changed metadata by year; identical
  duplicate metadata; conflicting duplicate metadata; absent metadata; no
  matches; missing scores; partial indicators; no prior year; all three views;
  unavailable pillar/dimension operation.
- **Tests**: Pure deterministic fixtures only; no Shiny or live provider calls.
- **Acceptance criteria**: Helpers are deterministic, independent of Shiny,
  use documented country-year joins and duplicate rules, and return stable
  data plus status for every supported or unavailable state.

## Phase 2: Golem Module, Integration, and Handoff

### 3. Validate the table dependency and implement the Country Explorer module

- **Requirements**: R1, R6, R7, R8, R9, R10, R11
- **Files**: `R/mod_country_explorer.R`, `DESCRIPTION`, `NAMESPACE`, `tests/testthat/test-country-explorer-module.R`
- **Details**: Validate `DT` in a clean package environment before editing
  dependencies. If selected, add `DT` to `Imports`, use namespace-qualified
  calls, and verify package installation without a preloaded DT namespace. If
  DT is incompatible, evaluate one native Shiny alternative and stop for a
  user decision if neither option supports the contract.

  Implement module UI/server with independent year input, region, income,
  country search, reset, and a Pillars/Dimensions/Indicators selector. Add
  dependent pillar and dimension selectors, summary outputs, table sorting,
  table search, `NA` display as `-`, empty/unavailable states, and single-row
  selection. The module receives an injected all-years snapshot loader and
  never calls provider functions directly.
- **Test Scenarios**: default Pillars; latest-year initialization; change year
  locally; view switching; dependent selectors; filters; reset; empty result;
  unavailable operation; `NA` display; table sorting/search; single-row
  selection; provider error status.
- **Tests**: `shiny::testServer()` with deterministic fixtures for module
  logic. Browser-level smoke test for the rendered table widget.
- **Acceptance criteria**: Module renders in isolation with fixtures and
  supports the interaction contract without network calls or upstream schema
  interpretation in the UI.

### 4. Register the module and add explicit fixture injection at app level

- **Requirements**: R1, R6, R7, R12
- **Files**: `R/app_ui.R`, `R/app_server.R`, `R/mod_overview.R`, `R/shared_state.R` if required, `tests/testthat/test-app-integration.R`
- **Details**: Replace the Country Explorer placeholder with module UI and
  register its server. Add an optional `snapshot_loader` argument to
  `app_server()` or an equivalent dependency object passed to both modules;
  production defaults remain the current provider loader, while tests pass a
  deterministic all-years fixture. Country Explorer derives its available
  years and local selected year from its own all-years snapshot and never
  mutates Overview. Overview retains its current latest-year behavior.
  Preserve Country Profile, Compare Countries, and other placeholders.
- **Test Scenarios**: production default wiring; fixture injection; Explorer
  year change without Overview change; Overview remains functional; clean app
  launch; placeholder tabs unchanged; no-row state.
- **Tests**: Existing Overview tests, new app integration test, Country
  Explorer module test, and a fixture-backed app smoke test.
- **Acceptance criteria**: The application registers Country Explorer without
  changing production defaults, supports isolated fixture tests, keeps the
  Explorer year independent, and does not regress Milestone 1.

### 5. Verify the browser experience, document, and record evidence

- **Requirements**: R1, R2, R6, R7, R8, R10, R11, R12
- **Files**: `README.md`, `tests/testthat/`, `.cg-docs/work-reports/` if an execution report is produced
- **Details**: Document local `spiR` loading, all-years snapshot behavior,
  independent Country Explorer year, views, filters, duplicate metadata rule,
  optional operation statuses, table dependency, missing-data behavior, and
  later-tab boundaries. Run focused tests after each slice and the complete
  deterministic suite. Start the local Golem app with the sibling `spiR`
  checkout. Use a browser-level smoke check at desktop and narrow viewports to
  verify table initialization, search, sorting, displayed `-`, empty states,
  and single-row selection. Record unresolved live-data limitations rather
  than inferring them. Review changed files to confirm `spiR` is untouched.
- **Test Scenarios**: clean launch; fixture app; local `spiR`; fallback;
  operation failure; zero-result filter; partial data; year change; table
  browser behavior; narrow layout.
- **Tests**: `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"`, parse/diagnostic checks, focused module tests, browser smoke test, and local Golem smoke test.
- **Acceptance criteria**: Another contributor can launch, use, test, and
  understand Country Explorer without reading provider implementation details.

## Testing Strategy

- Test adapter and provider capabilities separately from pure feature helpers.
- Use all-years deterministic snapshots and injected loaders for ordinary tests.
- Use `shiny::testServer()` for module reactivity and browser automation for
  client-side table behavior.
- Keep live `spiR` calls and Flourish credentials out of deterministic tests.
- Run existing Overview tests after integration and verify the Explorer year
  does not mutate Overview.
- Run the full test suite and local Golem smoke test before completion.

## Documentation Checklist

- [ ] Country Explorer launch and navigation.
- [ ] All-years snapshot and local year filtering.
- [ ] `spiR` preferred provider and local fallback.
- [ ] `spi_data()` country-year indicator source.
- [ ] Normalized schemas and pillar/dimension precedence.
- [ ] Per-operation status and unavailable-state behavior.
- [ ] Pillars, Dimensions, and Indicators behavior.
- [ ] Independent year selection and reset behavior.
- [ ] Region, income-level, and country-search filters.
- [ ] Duplicate metadata resolution.
- [ ] Missing values and partial coverage.
- [x] Table dependency, sorting, search, and multi-row checkbox selection.
- [x] Country Explorer to Compare Countries handoff using ISO3 codes.
- [x] Initial Compare Countries view for selected countries and year.
- [ ] Browser-level verification method.
- [ ] Explicit statement that `fragile/conflict` filtering is excluded.
- [ ] Boundary with Country Profile and Compare Countries.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Provider responses differ from the dashboard contract. | Normalize aliases centrally and fixture every supported operation. |
| Optional provider failure aborts the full snapshot. | Use mandatory-index plus safe optional operation wrappers with typed statuses. |
| All-years data is too large or slow. | Load once, normalize once, and filter locally; measure the smoke path before optimizing. |
| Pillar/dimension values conflict between direct and derived sources. | Define direct-source precedence and never silently combine conflicts. |
| Duplicate metadata changes visible filters. | Apply deterministic completeness/tie rules and expose conflicts as non-blocking status. |
| DT is unavailable or omitted from clean installs. | Validate first, use `Imports` when selected, and test a clean package environment. |
| Browser behavior differs from server tests. | Require browser smoke evidence for search, sorting, missing display, and selection. |
| Fixture injection changes production wiring. | Make loader injection optional and test production defaults separately. |
| Scope expands into later tabs. | Keep Compare limited to selection handoff and one initial comparison view. |

## Out of Scope

- `fragile/conflict` status and filtering.
- Country Profile analysis.
- Advanced multi-country comparison controls beyond the initial handoff view.
- New maps or Flourish changes.
- Downloads and exports.
- Custom weighting.
- Ranking claims.
- Production deployment changes.
- Changes to the separate `spiR` repository.

## Completion Contract

### Outcome

Country Explorer is a standalone Golem module with Pillars as the default,
Dimensions and Indicators as alternatives, an all-years normalized snapshot,
local year selection independent of Overview, filters, summary statistics,
and an interactive table. Optional provider failures are controlled, missing
values display as `-`, and the sibling `spiR` repository remains unchanged.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|---:|---|---|---|
| V1 | 1 | Real provider schemas and capabilities confirmed. | Fixtures and adapter/provider tests | yes |
| V2 | 1 | Exact normalized schemas and pillar/dimension precedence pass. | `test-spi-adapter.R` | yes |
| V3 | 1 | All-years snapshot returns overall data and per-operation statuses. | `test-spi-provider.R` | yes |
| V4 | 1 | Joins, duplicate rules, filters, views, summaries, and empty states pass. | Data/helper tests | yes |
| V5 | 2 | DT is compatible, in `Imports`, and works in a clean environment. | Dependency and widget tests | yes |
| V6 | 2 | Loader injection works without changing production defaults. | `test-app-integration.R` | yes |
| V7 | 2 | Explorer year changes without changing Overview. | `shiny::testServer()` integration test | yes |
| V8 | 2 | Browser table behavior is verified. | Browser smoke artifact/screenshots or documented equivalent | yes |
| V9 | final | Full deterministic suite passes. | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` | yes |
| V10 | final | Local sibling development works and sibling repo is unchanged. | `devtools::load_all()` + Golem smoke + changed-file review | yes |

### Constraints

| ID | Phase | Constraint | Check |
|---|---:|---|---|
| C1 | 1 | Only overall index is mandatory; optional operation failures are typed and non-fatal. | Provider status tests |
| C2 | 1 | Country Explorer uses one all-years snapshot and filters year locally. | Available-year and year-change tests |
| C3 | 1 | Pillars/dimensions have exact schemas and direct-source precedence. | Adapter fixtures |
| C4 | 1 | Metadata joins use `country_code + year` and deterministic duplicate resolution. | Join fixtures |
| C5 | 2 | Explorer loader injection is optional and production defaults remain unchanged. | App integration test |
| C6 | 2 | Explorer year does not mutate Overview. | Integration test |
| C7 | 2 | DT, if selected, is declared under `Imports` and tested cleanly. | Package check |
| C8 | 2 | Client-side table behavior has browser-level evidence. | Browser smoke artifact |
| C9 | all | Missing values never become zero and `fragile/conflict` is absent. | Helper, UI, and scope tests |
| C10 | all | `spiR` is not modified and work remains on `main`. | Changed-file list and branch check |

### Boundaries

- **Allowed**: dashboard adapter/provider changes, all-years normalized
  snapshot, pure helpers, independent Explorer year state, optional loader
  injection, compatible table dependency, Golem module, tests, documentation,
  and app registration.
- **Out of scope**: `fragile/conflict`, Country Profile, advanced comparison
  controls, new maps, downloads, rankings, weighting, production
  deployment, and edits to `spiR`.

### Iteration Policy

1. Confirm real provider responses before selecting aliases or labels.
2. Implement the all-years snapshot and exact operation-status contract first.
3. Define pillar/dimension precedence and deterministic metadata resolution.
4. Repair adapter/provider and pure helpers before UI work.
5. Validate DT in a clean environment before declaring it under Imports.
6. Add optional fixture injection without changing production defaults.
7. Use server tests for reactivity and browser evidence for widget behavior.
8. Run focused tests after each slice, then the full suite and smoke tests.
9. Under `deviation-policy: ask`, pause before any scope or boundary deviation.

### Blocked-Stop Conditions

- `spi_data()` and the local fallback cannot provide country-year data with
  country, year, and reproducible indicator IDs.
- Exact pillar/dimension schemas or source precedence cannot be established
  from the confirmed provider responses.
- The all-years snapshot cannot return overall data with controlled statuses
  for optional operation failures.
- Local year filtering cannot update Explorer without changing or breaking
  Overview.
- DT or one evaluated native alternative cannot support sorting, search,
  missing-value display, and single-row selection.
- Fixtures cannot be injected without real provider calls or production
  behavior changes.
- Browser-level evidence cannot be collected or an equivalent is not
  explicitly documented and accepted.
- A focused test cannot be repaired without hiding a regression or crossing an
  approved boundary.
- Continuing requires modifying `spiR` or expanding approved scope.
- Required executable evidence cannot be run or remains failed.
