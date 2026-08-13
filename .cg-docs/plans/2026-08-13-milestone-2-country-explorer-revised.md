---
date: 2026-08-13
title: "Milestone 2: Country Explorer (Revised)"
status: active
scope: "Standard"
brainstorm: "../brainstorms/2026-08-12-milestone-2-country-explorer.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-explorer, spiR, filters, table, pillars, dimensions, indicators, year-selector]
phases: 2
---

# Plan: Milestone 2: Country Explorer (Revised)

## Objective

Implement Country Explorer as an independent Golem module for browsing and
filtering country-level SPI data. The module will provide Pillars as the
predetermined view and Dimensions and Indicators as alternative views, while
keeping provider interpretation outside the Shiny UI layer.

Country Explorer will use an independently selectable year, region and income
filters, country search, summary statistics, an interactive table, and
single-row selection for a future Country Profile handoff. Overview keeps its
current year state and behavior; changing the Country Explorer year does not
change Overview.

## Context

Milestone 1 established the Golem-compatible dashboard, the provider and
adapter boundary, normalized overall index/indicator/metadata objects, the
local fallback, and the Overview tab. The current provider snapshot calls
index, metadata, detailed indicators, and aggregates, while the current index
normalizer does not yet retain pillar or dimension columns. Overview currently
derives its latest year internally.

The local sibling `spiR` repository provides `spi_index()`, `spi_data()`,
`country_info()`, and `spi_aggregates()`. `spi_data()` is the confirmed source
for country-year detailed indicator data. The dashboard must validate the
actual returned columns and normalize them centrally without modifying the
sibling repository.

The plan review identified the need for an explicit normalized contract for
pillars, dimensions, indicators, and country-year metadata; operation-level
capability handling; deterministic join rules; a validated table dependency;
and precise Shiny integration tests. The approved scope excludes
`fragile/conflict` filtering even though it appears in the historical
brainstorm.

The project charter identifies this Country Explorer implementation as the
current focus. Work remains on `main`.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Add Country Explorer as an independent Golem module. | Country Explorer brainstorm |
| R2 | Use `spiR` as the primary provider and preserve the local fallback. | Project charter / Milestone 1 contract |
| R3 | Use `spiR::spi_index()` for overall, pillar, and dimension data where the confirmed schema supports it. | Country Explorer brainstorm |
| R4 | Use `spiR::spi_data()` for country-year detailed indicator data. | Confirmed local `spiR` capability |
| R5 | Use `spiR::country_info()` for country, region, and income metadata where available. | Country Explorer brainstorm |
| R6 | Make Pillars the default view and support Dimensions and Indicators. | Approved product decision |
| R7 | Provide region, income-level, country-search, and independent Country Explorer year filters. | Approved scope adjustment |
| R8 | Keep Overall SPI visible in every view and display missing values as `-`, never zero. | Country Explorer brainstorm |
| R9 | Provide summary statistics for the visible countries and active metric. | Country Explorer brainstorm |
| R10 | Support sorting, search, and single-row selection in the table. | Country Explorer brainstorm |
| R11 | Preserve partial coverage and provide controlled empty/unavailable states. | Milestone 1 data contract |
| R12 | Keep `fragile/conflict`, Country Profile, Compare Countries, maps, downloads, rankings, weighting, and production changes out of scope. | Approved scope boundaries |

## Phase 1: Data Contract and Feature Logic

### 1. Confirm provider capabilities and define the normalized Country Explorer contract

- **Requirements**: R2, R3, R4, R5, R8, R11
- **Files**: `R/spi_adapter.R`, `R/spi_provider.R`, `tests/testthat/test-spi-adapter.R`, `tests/testthat/test-spi-provider.R`
- **Details**: Inspect the actual local `spiR` responses for index, detailed
  indicator, country metadata, and aggregate operations. Define normalized
  schemas for country-year overall scores, pillar scores, dimension scores,
  long indicators, indicator metadata, and country-year region/income
  metadata. Preserve reproducible technical IDs such as `SPI.D1.1.TEST`; use
  metadata labels when available and the technical ID as the visible fallback
  when metadata labels are absent. Retain `NA` values and partial coverage.
  Define a minimum usable snapshot: country-year overall data must be
  available; unsupported optional operations return an explicit empty or
  unavailable object with an explanatory status rather than failing the whole
  snapshot. Add capability detection and operation-level fallback handling for
  provider errors, missing columns, unsupported arguments, and local fallback
  responses. Do not add `fragile/conflict` fields or filters.
- **Test Scenarios**: confirmed `spi_data()` country-year response; pillar and
  dimension columns present or absent; reproducible indicator IDs; missing
  labels; missing scores; partial indicator rows; missing metadata; provider
  operation error; unsupported operation; local fallback; year filtering.
- **Tests**: Extend adapter/provider tests with deterministic fixtures and
  controlled provider stubs. Keep live provider calls out of ordinary tests.
- **Acceptance criteria**: One normalized snapshot contract is available to
  Country Explorer without upstream schema logic in the UI. A missing
  optional operation does not prevent overall data from being returned, and
  both preferred provider and fallback behavior are testable.

### 2. Build pure Country Explorer data and view helpers

- **Requirements**: R3, R4, R5, R6, R7, R8, R9, R11
- **Files**: `R/country_explorer_data.R`, `R/country_explorer_helpers.R`, `tests/testthat/test-country-explorer-data.R`, `tests/testthat/test-country-explorer-helpers.R`
- **Details**: Build application-owned functions that combine normalized
  overall, pillar, dimension, indicator, and metadata objects. Use one
  authoritative country-year base table keyed by `country_code + year` and
  define duplicate resolution before joining. Apply the independent selected
  year first, then region, income level, and case-insensitive partial country
  search. Define explicit behavior for missing or conflicting metadata without
  silently excluding otherwise valid overall scores. Prepare stable table-ready
  outputs for Pillars, Dimensions, and one selected Indicator. Keep Overall SPI
  in every output, preserve `NA`, calculate average/median/standard deviation
  for the active metric, and calculate Change only when a valid prior-year
  observation exists. Return stable empty frames and status information when
  no rows match or an optional view is unavailable.
- **Test Scenarios**: each filter; combined filters; independent year filter;
  case-insensitive partial search; changed region/income over time; duplicate
  metadata; absent metadata; no matches; missing scores; partial indicators;
  no prior year; all three views; unavailable pillar/dimension operation.
- **Tests**: Pure deterministic fixtures only; no Shiny or live provider calls.
- **Acceptance criteria**: Helpers are deterministic and independent of
  Shiny, use documented country-year joins, and return stable outputs for all
  supported and unavailable view states.

## Phase 2: Golem Module, Integration, and Handoff

### 3. Validate the table implementation and implement the Country Explorer module

- **Requirements**: R1, R6, R7, R8, R9, R10, R11
- **Files**: `R/mod_country_explorer.R`, `DESCRIPTION`, `NAMESPACE`, `tests/testthat/test-country-explorer-module.R`
- **Details**: First validate whether `DT` is compatible with the current
  Shiny/Golem package and test environment. If compatible, declare it in the
  correct package dependency section and namespace usage. If not compatible,
  evaluate one native Shiny table alternative and stop for a user decision if
  neither option supports the required behavior. Implement module UI/server
  with independent year input, region, income, country search, reset, and a
  Pillars/Dimensions/Indicators selector. Add dependent pillar and dimension
  selectors, summary outputs, sorting, table search, missing-value display as
  `-`, empty/unavailable states, and single-row selection. The module receives
  an injected snapshot or loader and never calls provider functions directly.
- **Test Scenarios**: default Pillars view; independent year initialization and
  changes; view switching; dependent selectors; filter reactivity; empty
  result; unavailable optional view; `NA` display; table sorting/search;
  single-row selection; provider error status.
- **Tests**: `shiny::testServer()` with deterministic snapshot fixtures and
  table dependency behavior tests.
- **Acceptance criteria**: The module renders in isolation with fixtures and
  supports the approved interaction contract without network calls or
  provider schema interpretation in the UI.

### 4. Register the module and preserve Overview behavior

- **Requirements**: R1, R6, R7, R12
- **Files**: `R/app_ui.R`, `R/app_server.R`, `R/mod_overview.R`, `R/shared_state.R` if required, app integration tests
- **Details**: Replace the Country Explorer placeholder with the module UI and
  register its server. Give Country Explorer an independent year owner and
  available-year set derived from its own snapshot; do not connect its year
  input to Overview. Preserve Overview's existing latest-year behavior unless
  a separate compatibility change is required and tested. Keep Country
  Profile, Compare Countries, and other placeholders unchanged. Do not add
  maps, downloads, multi-row selection, rankings, weighting, or
  `fragile/conflict` filtering.
- **Test Scenarios**: clean app launch; Explorer opens with Pillars selected;
  Explorer year changes without changing Overview; Overview remains
  functional; other placeholders remain unchanged; no-row state.
- **Tests**: Existing Overview tests, Country Explorer module tests, and an
  app smoke test with fixture injection.
- **Acceptance criteria**: Country Explorer is navigable in the running Golem
  app, its year selector is independent, and Milestone 1 outputs do not
  regress.

### 5. Document, validate, and record the milestone evidence

- **Requirements**: R1, R2, R6, R7, R8, R10, R11, R12
- **Files**: `README.md`, `tests/testthat/`, `.cg-docs/work-reports/` if an execution report is produced
- **Details**: Document local `spiR` loading, the independent Country Explorer
  year, views, filters, table dependency, missing-data behavior, optional
  operation states, and boundaries with later tabs. Run focused tests after
  each implementation slice, then the complete deterministic suite. Run a
  local Golem smoke test with the sibling `spiR` checkout and verify the table
  at desktop and narrow viewport sizes. Record unresolved live-data or
  optional-provider limitations rather than inferring them. Review changed
  files to confirm the sibling `spiR` repository was not modified.
- **Test Scenarios**: clean local launch; deterministic fixtures; local
  `spiR` checkout; fallback provider; provider operation failure; zero-result
  filters; partial data; independent year change; narrow table layout.
- **Tests**: `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"`, parse/diagnostic checks, focused module tests, and local Golem smoke test.
- **Acceptance criteria**: Another contributor can launch, use, test, and
  understand Country Explorer without reading provider implementation details.

## Testing Strategy

- Test adapter and provider capabilities separately from pure feature helpers.
- Use deterministic fixtures and injected loaders for all ordinary tests.
- Use `shiny::testServer()` for initialization, independent year changes,
  filters, views, selectors, summaries, empty states, missing values, and row
  selection.
- Keep live `spiR` calls and Flourish credentials out of deterministic tests.
- Run the existing Overview tests after integration.
- Run the full test suite and a local Golem smoke test before completion.
- Verify the table visually at desktop and narrow viewport sizes.

## Documentation Checklist

- [ ] Country Explorer launch and navigation.
- [ ] `spiR` preferred provider and local fallback.
- [ ] `spi_data()` as country-year indicator source.
- [ ] Normalized pillars, dimensions, indicators, and metadata contract.
- [ ] Pillars, Dimensions, and Indicators behavior.
- [ ] Independent Country Explorer year selection.
- [ ] Region, income-level, and country-search filters.
- [ ] Missing values, partial coverage, and unavailable-operation states.
- [ ] Table dependency, sorting, search, and single-row selection.
- [ ] Explicit statement that `fragile/conflict` filtering is not part of this milestone.
- [ ] Boundary with Country Profile and Compare Countries.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `spiR` response schemas differ from the dashboard contract. | Confirm real responses first, normalize aliases centrally, and fixture every supported operation. |
| `spi_data()` indicator IDs are technical or metadata labels are absent. | Preserve reproducible IDs and use them as visible fallbacks; test ID stability and optional labels. |
| Pillar or dimension operation is unsupported or partially returned. | Detect capabilities per operation and return controlled unavailable states while preserving overall data. |
| Metadata has duplicates, missing values, or changes by year. | Use a country-year authoritative base table, define duplicate resolution, and test temporal metadata cases. |
| A table dependency is unavailable or incompatible. | Validate `DT` before declaring it; evaluate one native alternative and stop for a decision if needed. |
| Independent Explorer year diverges from its own data. | Derive the selector from the Explorer snapshot, test initialization and changes, and keep it separate from Overview. |
| Missing values are mistaken for zeroes. | Preserve `NA` through helpers and assert rendered `-` output. |
| Feature logic leaks into app wiring. | Keep provider, adapter, data, and helper logic in owned files; test module isolation. |
| Scope expands into later tabs. | Keep single-row selection only and preserve downstream placeholders. |

## Out of Scope

- `fragile/conflict` status and filtering.
- Country Profile analysis.
- Multi-country comparison or multi-row selection.
- New maps or Flourish changes.
- Downloads and exports.
- Custom weighting.
- Ranking claims.
- Production deployment changes.
- Changes to the separate `spiR` repository.

## Completion Contract

### Outcome

Country Explorer is a standalone Golem module with an interactive table,
Pillars as the default view, Dimensions and Indicators as alternatives, and
filters for region, income level, country search, and an independently
selectable year. It uses a normalized dashboard provider boundary,
preserves a local fallback, handles optional provider operations without
crashing the whole feature, displays missing values as `-`, and leaves
Overview, Country Profile, and Compare Countries within their approved
boundaries.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|---:|---|---|---|
| V1 | 1 | Real `spiR` schemas and capabilities confirmed. | Adapter/provider fixtures and focused tests | yes |
| V2 | 1 | Normalized overall, pillar, dimension, indicator, label, and metadata contracts pass. | `test-spi-adapter.R`, `test-spi-provider.R` | yes |
| V3 | 1 | Operation-level fallback and minimum usable snapshot are controlled. | Provider error/partial-response tests | yes |
| V4 | 1 | Country-year joins, filters, all views, missing values, and empty states pass. | Country Explorer data/helper tests | yes |
| V5 | 2 | Table dependency is compatible and declared, or validated alternative is used. | Package dependency check and table behavior tests | yes |
| V6 | 2 | Independent Explorer year works without changing Overview. | `shiny::testServer()` and integration test | yes |
| V7 | 2 | Module behavior is verified with injected fixtures. | Country Explorer module test | yes |
| V8 | 2 | App integration preserves Overview and placeholders. | App smoke test and existing Overview tests | yes |
| V9 | final | Full deterministic suite passes. | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` | yes |
| V10 | final | Local sibling `spiR` development works and remains unmodified. | `devtools::load_all(spiR_path)` plus Golem smoke test and changed-file review | yes |

### Constraints

| ID | Phase | Constraint | Check |
|---|---:|---|---|
| C1 | 1 | UI receives normalized data and does not interpret upstream schemas. | Module/provider boundary review and tests |
| C2 | 1 | `spi_data()` is the country-year detailed indicator source when available. | Fixture and live-schema confirmation |
| C3 | 1 | A minimum snapshot requires overall country-year data; optional operation failure is controlled. | Provider capability tests |
| C4 | 1 | Reproducible technical IDs are preserved; missing labels fall back to IDs. | Indicator normalization tests |
| C5 | 1 | Country-year joins and duplicate metadata behavior are explicit. | Join fixtures and assertions |
| C6 | 2 | Country Explorer owns an independent year selector; it does not mutate Overview. | Integration test |
| C7 | 2 | `DT` is used only after compatibility validation and correct package declaration. | Dependency and behavior tests |
| C8 | all | Missing values never become zero. | Helper and rendered-table tests |
| C9 | all | No `fragile/conflict` input or logic is introduced. | Scope review |
| C10 | all | The separate `spiR` repository is not modified. | Changed-file review |
| C11 | all | Work remains on `main`. | `git branch --show-current` |

### Boundaries

- **Allowed**: dashboard adapter/provider changes, normalized Country Explorer
  data contract, pure helpers, independent Explorer year state, compatible
  table dependency, Golem module, tests, documentation, and app registration.
- **Out of scope**: `fragile/conflict`, Country Profile, Compare Countries,
  multi-row selection, new maps, downloads, rankings, weighting, production
  deployment, and edits to `spiR`.

### Iteration Policy

1. Confirm actual provider schemas before selecting aliases, labels, or IDs.
2. Treat `spi_data()` as the detailed country-year source and verify its
   normalized output rather than rediscovering a different source.
3. Repair adapter/provider and pure helpers before changing UI rendering.
4. Require only a minimum usable overall snapshot; make optional operations
   explicitly unavailable when unsupported.
5. Keep Country Explorer year state independent from Overview and test both
   behaviors.
6. Validate `DT` before adding it; evaluate only one alternative if needed.
7. Use fixtures and injected loaders for offline Shiny tests.
8. Run focused tests after each slice, then the full suite and smoke test.
9. Under `deviation-policy: ask`, pause for user approval before any scope or
   provider-boundary deviation.

### Blocked-Stop Conditions

- `spi_data()` and the local fallback cannot provide usable country-year data
  with country, year, and reproducible indicator values.
- Indicator identifiers cannot be preserved reproducibly across countries and
  years, even when technical IDs are used as labels.
- No minimum snapshot with overall country-year data can be returned in a
  controlled way after an optional operation fails.
- The independent Country Explorer year selector cannot initialize or update
  Explorer data without changing or breaking Overview.
- Neither `DT` nor one evaluated native alternative supports sorting, search,
  missing-value display, and single-row selection.
- A focused test failure cannot be isolated or repaired without hiding a
  regression or crossing an approved boundary.
- Continuing requires modifying `spiR` or expanding the approved scope.
- Required executable evidence cannot be run or remains failed after allowed
  recovery attempts.
