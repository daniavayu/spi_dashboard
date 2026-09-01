---
date: 2026-08-31
title: "Milestone 4: Country Comparison (Revised)"
status: active
scope: "Deep"
brainstorm: "../brainstorms/2026-08-31-milestone-4-country-comparison.md"
prior-plan: "2026-08-31-milestone-4-country-comparison.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
execution-report: "../work-reports/2026-08-31-milestone-4-country-comparison-revised.md"
tags: [spi, shiny, golem, country-comparison, spiR, provider-adapter, missing-data, dimensions, trends, testing, revised]
phases: 4
---

# Plan: Milestone 4: Country Comparison (Revised)

## Objective

Implement Compare Countries as an independent Golem module and application tab
inside the existing Shiny application. It will support descriptive comparison
of two or three countries using selected-year pillar views, all-years trends,
and a dimension-level table.

The module will use ISO3 country codes, accept direct selection and a one-time
Country Explorer handoff, and consume normalized data. It will not call raw
`spiR` functions from UI code or require changes to the external `../spiR`
repository.

## Context

Milestones 1-3 established the provider/fallback boundary, adapter layer,
Country Explorer, and Country Profile. The current Compare module is a basic
Explorer-driven overall trend. The existing adapter stores pillar and dimension
scores as wide columns in `index` and currently drops rows with missing overall
scores; this plan explicitly resolves both constraints before UI expansion.

The project charter requires a public English Shiny dashboard, `spiR` as the
preferred provider, local functions as fallback, normalized schemas outside
Shiny modules, deterministic tests, and no modification of external `spiR`.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Implement Compare as an independent Golem module/tab within the existing app. | Architecture correction |
| R2 | Support exactly two or three valid selected countries; never more than three. | Approved scope |
| R3 | Use canonical uppercase ISO3 codes as internal keys. | Approved scope |
| R4 | Support direct selection and a one-time validated Explorer handoff. | Approved navigation |
| R5 | Keep Compare country, year, and metric state independent after handoff. | Architecture correction |
| R6 | Use one global selected year for radar, bars, and dimensions. | Approved data contract |
| R7 | Use the union of available years for trends, without restricting to common years. | Approved data contract |
| R8 | Support Overall SPI and verified pillar metrics in trends. | Approved scope |
| R9 | Render five-pillar radar and grouped bars for the selected year. | Approved scope |
| R10 | Render all available indexed dimensions by default with optional filtering. | Approved scope |
| R11 | Preserve keyed observations with `NA`; never convert missing scores to zero. | Domain rule |
| R12 | Use metadata labels while retaining technical IDs. | Provider contract |
| R13 | Resolve section states independently using `pending`, `ok`, `partial`, `empty`, `unavailable`, and `error`. | Existing architecture |
| R14 | Keep transformations pure, deterministic, and fixture-testable. | Milestone 3 pattern |
| R15 | Verify `spiR` and local fallback capabilities before implementation depends on them. | Provider boundary |
| R16 | Provide executable deterministic, integration, and responsive browser verification. | Acceptance standard |

## Decisions and Exact Contracts

### Selection and handoff

- Direct selection and handoff both pass through one pure canonicalization helper.
- Canonicalization trims input, uppercases ISO3 values, removes duplicates while
  preserving first-seen order, validates against the country metadata catalog,
  and returns a structured error for invalid, empty, or more-than-three input.
- Compare requires two or three valid countries before point-in-time outputs are
  considered available.
- Explorer sends only a validated ISO3 vector and navigation event. Compare
  copies that vector into its own reactive value exactly once; subsequent
  Explorer changes do not alter Compare selection, year, or metric state.

### Global year

Use a single documented rule: after valid ISO3 selection, collect integer years
from rows for the selected countries, discard missing or malformed years, and
select the maximum year present in the selected-country union. This is a global
year, not a latest-common-year calculation. Missing rows for another selected
country are represented explicitly as `NA`. If no valid year exists, the
point-in-time sections return `empty` or `unavailable` according to the status
rules below.

### Missing values and dimensions

- The adapter preserves rows with nonblank country code and valid integer year
  even when overall score is `NA`; it must not filter on `!is.na(score)` for the
  comparison contract.
- Existing Profile/Overview behavior must be regression-tested before changing
  shared normalization. If changing shared filtering would be unsafe, add an
  explicit comparison-preserving normalization path with the same documented
  key semantics.
- Dimension scores are sourced from `index` columns matching
  `^SPI\\.DIM[0-9]+\\.[0-9]+\\.INDEX$`.
- Each matched column is reshaped to rows with `country_code`, `country_name`,
  `year`, `pillar_id`, `dimension_id`, and `score`; `pillar_id` is the first
  numeric component and `dimension_id` is the `P.D` suffix.
- The metadata dimension catalog supplies the expected IDs and labels. Missing
  dimension columns or missing country-year cells remain represented as `NA`
  where the contract requires a comparison cell, never as zero.
- Dimension labels are joined by technical `dimension_id`; absent labels fall
  back to the technical ID and produce a `partial` status when values exist.

### Duplicate policy

For each logical key, identical duplicate scores collapse to one row. If
non-missing duplicate scores conflict, the prepared score becomes `NA`, the
section is `partial`, and the conflict count is recorded in `coverage` and
`message`. A missing value never overwrites a non-missing value unless all
values are missing. No duplicate is silently selected by input order.

### Section status policy

Resolve statuses in this order:

1. Provider call/normalization failure: `error`.
2. Operation absent or explicitly unsupported: `unavailable`.
3. No rows or no valid key domain: `empty`.
4. Rows exist but requested countries, years, pillars, dimensions, or labels are
   incomplete: `partial`.
5. Requested coverage is complete, including explicit complete `NA` cells where
   the provider confirms the key exists: `ok`.
6. `pending` is reserved for an uninitialized reactive loader state.

Each section returns `data`, `status`, `message`, `coverage`, and `source`.
A section with `error` or `unavailable` must not prevent other sections from
rendering.

## Implementation Steps

## Phase 1: Provider and normalized comparison contract

### 1. Verify provider and fallback matrix

- **Requirements**: R11, R12, R15
- **Files**: `R/spi_provider.R`, `R/spi_adapter.R`, provider tests
- **Tests**: Provider contract tests and recorded development API checks
- **Details**: Verify public operations, signatures, expected columns, all-years
  behavior, five-pillar coverage, dimension-column coverage, metadata labels,
  and local fallback behavior for `spiR` and fallback providers. Record
  unavailable/provisional operations and do not add raw provider calls to UI.
- **Test scenarios**: successful `index`, missing operation, provider error,
  fallback response, missing metadata, incomplete pillar/dimension coverage.
- **Acceptance criteria**: A provider matrix exists in tests or the execution
  report, and implementation assumptions match verified outputs.

### 2. Preserve keyed rows and normalize dimensions

- **Requirements**: R6, R7, R10, R11, R12, R13, R14
- **Files**: `R/spi_adapter.R`, `R/country_compare_data.R`, adapter tests
- **Tests**: Adapter and comparison data tests
- **Details**: Preserve nonblank country/year keys with `NA` scores; implement
  the exact wide-to-long dimension reshape above; retain technical IDs; join
  metadata labels; create section-result objects and status precedence.
- **Test scenarios**: overall `NA` with valid pillars, missing dimension column,
  missing cell, malformed year, duplicate identical score, duplicate conflict,
  missing label, empty and unavailable operation.
- **Acceptance criteria**: Fixtures prove that missing data remains `NA`, all
  dimension rows have deterministic IDs, and every status is reproducible.

## Phase 2: Pure comparison transforms

### 3. Implement selection, year, metric, and filter helpers

- **Requirements**: R2, R3, R4, R5, R6, R7, R8, R10, R14
- **Files**: `R/country_compare_helpers.R`, helper tests
- **Tests**: `tests/testthat/test-country-compare-helpers.R`
- **Details**: Add canonical ISO3 validation, two/three-country limit, one-time
  handoff normalization, union-year selection, supported metric enumeration,
  unsupported metric rejection, and optional dimension filtering.
- **Test scenarios**: lowercase/whitespace ISO3, invalid code, duplicate input,
  empty input, one country, four countries, unequal coverage, no valid year,
  unsupported metric, filter that matches no rows.
- **Acceptance criteria**: Pure helpers return stable structured results without
  Shiny state or provider calls.

### 4. Prepare radar, bars, trends, and dimensions

- **Requirements**: R6, R7, R8, R9, R10, R11, R12, R13, R14
- **Files**: `R/country_compare_data.R`, data/helper tests
- **Tests**: `tests/testthat/test-country-compare-data.R` and helper tests
- **Details**: Produce deterministic long-form data for selected-year five-pillar
  radar and grouped bars, all-years overall/pillar trends, and labeled dimension
  tables. Preserve explicit missing cells and return coverage metadata. Use a
  continuous descriptive score color and a neutral missing state.
- **Test scenarios**: all five pillars, missing pillar, unequal trend years,
  metric switch, dimension filter, missing score, incomplete labels.
- **Acceptance criteria**: Pure-data assertions verify IDs, countries, years,
  scores, `NA` gaps, labels, and selected metric; no plot can silently invent a
  zero-valued observation.

## Phase 3: Module and integration

### 5. Expand the Compare module

- **Requirements**: R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, R13
- **Files**: `R/mod_country_compare.R`, `tests/testthat/test-country-compare-module.R`
- **Tests**: `tests/testthat/test-country-compare-module.R`
- **Details**: Replace the Explorer-only trend surface with direct selection,
  one-time handoff ingestion, independent year and metric controls, radar,
  grouped bars, trend, filtered dimension table, validation messages, and
  section-specific states. Inject normalized snapshots/prepared results in tests.
- **Test scenarios**: valid two/three-country view, invalid selection,
  incomplete coverage, section error with other sections valid, clear selection,
  direct-versus-handoff equivalence, year/metric updates.
- **Acceptance criteria**: Module outputs remain independently renderable and
  Compare controls do not read or mutate Explorer/Profile/Overview state.

### 6. Register the tab and preserve application contracts

- **Requirements**: R1, R4, R5, R16
- **Files**: `R/app_ui.R`, `R/app_server.R`, integration tests
- **Tests**: `tests/testthat/test-app-integration.R` and regression tests
- **Details**: Register Compare in the existing top-level tabset. Replace the
  current reactive coupling with a validated one-time handoff. Keep the existing
  `app.R` entry point and provider injection pattern.
- **Test scenarios**: navigation from Overview and Explorer, Explorer handoff,
  later Explorer changes, Compare clear, existing Profile/Overview regressions.
- **Acceptance criteria**: App integration confirms independent Compare state and
  no regression in existing module navigation.

## Phase 4: Verification and documentation

### 7. Add executable browser coverage

- **Requirements**: R2, R4, R5, R6, R8, R9, R10, R11, R16
- **Files**: `DESCRIPTION`, `tests/browser/fixture-app/app.R`,
  `tests/browser/country-compare-smoke.R`
- **Tests**: `tests/browser/country-compare-smoke.R`
- **Details**: Declare `shinytest2` in test dependencies or document the exact
  environment prerequisite. Expand the fixture to at least three countries,
  unequal years, and explicit missing values. Name the exact smoke command and
  assert direct selection, handoff, visible outputs, missing cells, and 1280px
  plus approximately 390px layouts.
- **Test scenarios**: two and three countries, fourth-country rejection,
  selected-year update, trend metric update, missing-data display, mobile width.
- **Acceptance criteria**: A named executable smoke artifact passes; visual
  inspection alone is not treated as acceptance.

### 8. Document and complete regression verification

- **Requirements**: R4, R5, R6, R7, R10, R11, R12, R15, R16
- **Files**: `README.md` or relevant dashboard documentation, test suite
- **Tests**: Full deterministic test suite and documentation review
- **Details**: Document module/tab architecture, direct and Explorer entry
  paths, one-time handoff, ISO3 keys, global-year algorithm, all-years trends,
  labels, missing values, section states, provider/fallback behavior, and all
  exclusions. Run focused tests, then the complete deterministic suite.
- **Test scenarios**: documentation review, full test suite, changed-file review.
- **Acceptance criteria**: No undocumented provider assumption, excluded feature,
  or changed missing-data semantic remains.

## Testing Strategy

Use offline injected fixtures for ordinary tests. Test pure normalization and
transforms before Shiny behavior, then module and app integration, then browser
smoke. Add lightweight output assertions for selected metric/year and section
state; use pure prepared-data assertions for plot correctness. The complete
suite command is:

```powershell
Rscript --vanilla -e "testthat::test_dir('tests/testthat')"
```

The browser command must be recorded with the smoke artifact and use the
repository's `shinytest2` harness.

## Documentation Checklist

- [ ] Compare is described as a module/tab in the existing app, not a second app.
- [ ] Direct selection and one-time Explorer handoff are documented.
- [ ] ISO3 canonicalization and two/three-country limit are documented.
- [ ] Global-year union rule and explicit missing cells are documented.
- [ ] Trends use all available years and supported metrics are listed.
- [ ] Metadata labels and technical IDs are both described.
- [ ] `NA`, partial coverage, and section states are explained.
- [ ] Provider matrix and fallback limitations are recorded.
- [ ] Indicators, weighting, rankings, causal claims, downloads, and new sources
      remain explicitly excluded.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Shared adapter change affects Overview/Profile | Add regression fixtures first; use a comparison-specific path if needed. |
| Wide dimension columns vary across provider versions | Derive from an explicit regex plus metadata catalog and report missing IDs. |
| Different country coverage makes year selection misleading | Use the documented union-year rule and explicit `NA` cells. |
| Duplicate source rows create unstable scores | Collapse identical duplicates and convert conflicts to `NA` with `partial`. |
| Fallback lacks required dimensions or labels | Verify the provider matrix before UI work and expose `unavailable`. |
| Explorer coupling leaks into Compare state | Copy validated handoff once and test later Explorer mutations. |
| Browser checks cannot run in a clean environment | Declare/document `shinytest2` and name the exact executable command. |

## Out of Scope

- A second application or separate deployment artifact.
- More than three simultaneous countries.
- Indicator-level comparison.
- User-defined weighting or composite scores.
- Global rankings, causal inference, significance testing, or normative verdicts.
- Downloads, exports, citation packages, and new external data sources.
- Changes to the external `spiR` repository.
- Automatic refresh, production deployment, or unrelated module refactors.

## Completion Contract

### Outcome

A user can select two or three countries directly or arrive through Explorer,
then inspect comparable selected-year pillars/dimensions and all-years
Overall/pillar trends. Missing values, partial coverage, provider limitations,
and section failures are visible without corrupting scores or coupling module
state.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Phase | Required |
|----|-------------------|------------------|-------|----------|
| V1 | Preserved keyed rows with `NA` | Adapter fixtures | 1 | yes |
| V2 | Provider/fallback capability matrix | Provider tests/report | 1 | yes |
| V3 | Exact dimension wide-to-long contract | Adapter/data tests | 1 | yes |
| V4 | Deterministic duplicate and status policy | Data tests | 1 | yes |
| V5 | Canonical ISO3, limit, handoff, year, metric helpers | Helper tests | 2 | yes |
| V6 | Radar/bar/trend prepared-data assertions | Data tests | 2 | yes |
| V7 | Full labeled dimension table and filter | Data/helper tests | 2 | yes |
| V8 | Independent module outputs and states | Module tests | 3 | yes |
| V9 | App tab, handoff, and state isolation | Integration tests | 3 | yes |
| V10 | Three-country responsive browser fixture | `tests/browser/country-compare-smoke.R` | 4 | yes |
| V11 | Full deterministic suite | `testthat::test_dir()` command | 4 | yes |
| V12 | Scope/provider/missing-data documentation | Documentation review | 4 | yes |

### Constraints

| ID | Constraint | Check | Phase |
|----|------------|-------|-------|
| C1 | Do not modify `../spiR`. | Changed-file review | final |
| C2 | UI consumes normalized data only. | Static search/review | 3 |
| C3 | Maximum three valid ISO3 countries. | Helper/module tests | 2/3 |
| C4 | `NA` is never converted to zero. | Fixture and prepared-data assertions | 1/2 |
| C5 | Compare state is independent after handoff. | Integration test | 3 |
| C6 | No indicators, weights, rankings, causal claims, downloads, or new sources. | Scope review | final |
| C7 | Browser acceptance has a named executable harness. | Smoke command/artifact | 4 |

### Boundaries

- **Allowed**: adapter/provider changes inside this repository, pure comparison
  helpers, the existing Golem module/tab, tests, fixture updates, and relevant
  documentation.
- **Out of scope**: external `spiR` edits, a second app, unsupported metrics,
  silent imputation, and unrelated refactors.

### Iteration Policy

1. Verify provider capabilities and existing adapter behavior first.
2. Resolve `NA`, dimension shape, duplicate, status, and year contracts before
   implementing rendering.
3. Run focused data/helper tests after each pure-data change.
4. Run module/integration tests before browser validation.
5. Record provider or fallback limitations explicitly.
6. Ask before changing the country limit, year rule, visualization set, missing
   data semantics, or scope exclusions.

### Blocked-Stop Conditions

- Required provider/fallback coverage cannot be verified.
- Required keyed `NA` observations cannot be represented transparently.
- Dimension membership or labels cannot be derived without modifying `spiR`.
- A required visualization dependency is unavailable and no existing alternative
  supports it.
- No named executable browser harness can be run.
- Integration regresses Overview, Explorer, or Profile.
- Implementation would require changing the approved scope.

### Deviation Policy

`ask`: implementation choices that preserve this contract may be made locally;
changes to the contract require user approval.
