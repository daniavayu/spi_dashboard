---
date: 2026-08-31
title: "Milestone 4: Country Comparison"
status: approved
scope: "Deep"
brainstorm: "../brainstorms/2026-08-31-milestone-4-country-comparison.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-comparison, spiR, provider-adapter, navigation, radar, pillars, dimensions, trends, testing]
phases: 4
---

# Plan: Milestone 4: Country Comparison

## Objective

Implement Compare Countries as an independent Golem workspace for descriptive,
side-by-side comparison of up to three countries. The workspace will combine
selected-year pillar views, an all-years trend view, and a dimension-level table
while preserving the existing provider, adapter, fallback, and module
boundaries established by Milestones 1-3.

The module will use stable ISO3 country codes internally, support both direct
selection and the existing Country Explorer handoff, and consume normalized
snapshot data rather than calling raw `spiR` functions from UI code.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Provide an independent Compare Countries Golem module. | Approved Milestone 4 scope |
| R2 | Allow selection of two or three countries, with a maximum of three. | Brainstorm decision |
| R3 | Use ISO3 country codes as stable internal selection keys. | Brainstorm decision |
| R4 | Support direct Compare selection and the existing Explorer handoff. | Approved navigation decision |
| R5 | Keep comparison state independent from Overview, Explorer, and Profile. | Existing module architecture |
| R6 | Use one global selected year for point-in-time views. | Approved data contract |
| R7 | Use all available years for trend views. | Approved data contract |
| R8 | Provide Overall SPI and supported pillar trend metrics. | Approved visualization scope |
| R9 | Provide a five-pillar radar and grouped pillar bars for the selected year. | Approved visualization scope |
| R10 | Provide a full dimension comparison table with optional filtering. | Approved visualization scope |
| R11 | Preserve `NA` values and distinguish missing coverage from zero. | Domain rule |
| R12 | Use `metadata()` labels while retaining technical IDs. | Provider/adapter contract |
| R13 | Keep section states independent: `pending`, `ok`, `partial`, `empty`, `unavailable`, `error`. | Existing architecture |
| R14 | Keep transformations pure, deterministic, and testable outside Shiny. | Milestone 3 pattern |
| R15 | Use `spiR` first and the local provider as explicit fallback. | Project charter |
| R16 | Validate deterministic behavior, integration, and responsive browser output. | Milestone acceptance standard |

## Product Contract

### Selection

- The user can select two or three countries directly in Compare Countries.
- The module accepts an explicit ISO3 handoff from Country Explorer.
- Duplicate, invalid, and over-limit selections are rejected or normalized by
  pure helpers before rendering.
- Compare selection does not mutate selection state in other modules.
- Country names are display metadata; ISO3 codes remain the stable keys.

### Time behavior

- A single global selected year controls the radar, grouped bars, and dimension
  table.
- The default selected year is the latest year available in the comparison
  snapshot according to the defined global-year rule. The implementation must
  document the rule and use explicit missing cells when a selected country has
  no observation for that year.
- Trends retain every available year returned by the normalized snapshot and do
  not silently restrict to common years.
- Missing observations remain `NA`, are not imputed as zero, and appear as gaps
  or unavailable states in charts and as `-` in tables.

### Views

1. **Pillar Comparison**: a five-pillar radar for the selected year, with one
   series per selected country.
2. **Score by Pillar**: grouped bars using the same selected-year pillar data.
3. **Score Trends Over Time**: one series per country for Overall SPI or a
   selected supported pillar.
4. **Dimension-Level Comparison**: all available indexed dimensions by default,
   labeled from metadata, with optional filtering and continuous descriptive
   score coloring.

The interface must not add indicator-level comparison, custom weighting,
rankings, downloads, causal claims, or significance testing in this milestone.

## Architecture and Files

### Shared data boundary

Reuse `spi_provider_snapshot()` and the normalized objects from
`R/spi_provider.R` and `R/spi_adapter.R`. The Compare module must not call raw
`spiR` functions or `spiR::spi_plot_*()` directly. Provider operation failures
must be represented in normalized section results so one unavailable section
does not prevent other sections from rendering.

Use the existing metadata hierarchy path for readable pillar and dimension
labels. Preserve technical pillar and dimension IDs alongside display labels.
Do not parse the malformed root metadata CSV at runtime and do not modify the
external `../spiR` repository.

### Planned implementation surfaces

- `R/country_compare_data.R`: pure preparation functions for selected-country
  data, global years, selected-year pillars, trends, dimensions, and section
  statuses.
- `R/country_compare_helpers.R`: pure validation, selection, year, metric, and
  optional dimension-filter helpers.
- `R/mod_country_compare.R`: independent UI/server module, rendering the four
  views and their section-specific states.
- `R/app_ui.R`, `R/app_server.R`: register or connect the Compare workspace while
  preserving existing module state and navigation behavior.
- `tests/testthat/test-country-compare-data.R`: deterministic data contracts and
  transformations.
- `tests/testthat/test-country-compare-helpers.R`: selection, year, metric, and
  filter behavior.
- `tests/testthat/test-country-compare-module.R`: injected snapshot module tests,
  including independent section states.
- `tests/testthat/test-app-integration.R`: navigation, handoff, and state
  isolation regression coverage.
- `tests/browser/country-compare-smoke.R`: named browser smoke artifact for
  desktop and approximately 390px responsive layout, if the existing harness
  supports it.
- `README.md` or the relevant dashboard documentation: user-facing scope,
  missing-data behavior, provider boundary, and exclusions.

## Phase 1: Define and verify the comparison data contract

### 1. Normalize comparison inputs

- **Requirements**: R2, R3, R6, R7, R11, R12, R13, R15
- **Tests**: `test-country-compare-data.R`

Define the minimum normalized inputs required by comparison:

- overall index rows keyed by `country_code` and `year`;
- pillar rows keyed by country, year, and technical pillar ID;
- dimension rows keyed by country, year, pillar, and technical dimension ID;
- country display metadata;
- hierarchy labels and provider/source status.

Keep score columns numeric, preserve `NA`, retain technical IDs, and avoid
creating synthetic zero rows. Ensure duplicate keys are handled deterministically
and that valid country-year rows can exist even when a score is missing.

Create section-result objects with `data`, `status`, `message`, `coverage`, and
`source`, using the established status vocabulary. Test complete, partial,
empty, unavailable, error, and missing-label fixtures.

### 2. Verify the provider surface

- **Requirements**: R12, R15
- **Tests**: focused provider/adapter regression tests where needed

Confirm that the existing snapshot loader can supply all comparison inputs from
public `spiR` operations and the local fallback. Use controlled development
calls only for API verification; ordinary tests remain offline and fixture
backed. Record any provider limitation in the implementation report rather than
adding data-access logic to the module.

## Phase 2: Implement pure comparison helpers

### 3. Selection, year, and metric helpers

- **Requirements**: R2, R3, R4, R5, R6, R7, R8
- **Tests**: `test-country-compare-helpers.R`

Implement pure helpers to:

- validate and deduplicate ISO3 selections;
- enforce the two-to-three country comparison limit;
- combine direct selections with an explicit Explorer handoff;
- compute the documented global selected-year choice;
- preserve selected countries when the year changes;
- enumerate Overall SPI and supported pillar metrics;
- reject unsupported metric IDs without changing current state.

The helpers must not depend on Shiny inputs, global mutable state, or raw
provider calls.

### 4. Prepare charts and dimension table

- **Requirements**: R7, R8, R9, R10, R11, R12
- **Tests**: `test-country-compare-data.R`, `test-country-compare-helpers.R`

Prepare deterministic long-form objects for:

- all-years overall and pillar trends;
- selected-year five-pillar radar data;
- selected-year grouped-bar data;
- selected-year dimensions joined to pillar and metadata labels;
- optional dimension filtering without changing the underlying full data.

Use a continuous descriptive color scale for score cells, with a neutral missing
state. Do not label colors as normative performance categories unless the
existing dashboard contract provides those categories. Ensure incomplete
coverage is visible and that dimension rows remain stable by technical ID.

## Phase 3: Build and integrate the module

### 5. Expand Compare Countries UI and server

- **Requirements**: R1, R2, R4, R5, R6, R8, R9, R10, R13
- **Tests**: `test-country-compare-module.R`

Expand `R/mod_country_compare.R` to provide:

- direct country selection with a visible two/three-country validation state;
- Explorer handoff support using ISO3 values;
- one selected-year control for point-in-time views;
- trend metric selector for Overall SPI and supported pillars;
- radar, grouped bars, trend, and dimension table outputs;
- optional dimension filtering while retaining the full default table;
- explicit empty, partial, unavailable, and error states per section;
- clear missing-value display and readable country labels.

Inject the normalized snapshot or prepared section results in tests. The module
must remain independently testable and must not share reactive selection state
with other modules.

### 6. Register navigation and preserve handoff behavior

- **Requirements**: R4, R5, R16
- **Tests**: `test-app-integration.R`, existing Explorer/Profile/Overview tests

Connect Compare Countries to the existing top-level navigation. Preserve the
current Explorer handoff contract, including ISO3 validation, without making
Explorer or Profile depend on Compare state. Verify that changing Compare's
year, metric, or countries does not mutate other modules.

## Phase 4: Verification and documentation

### 7. Test and browser-validate the workflow

- **Requirements**: R1-R16
- **Tests**: focused tests, complete deterministic suite, named browser smoke

Run focused comparison tests first, then the complete deterministic suite:

```powershell
Rscript --vanilla -e "testthat::test_dir('tests/testthat')"
```

Use the established browser harness to verify direct selection, Explorer
handoff, two- and three-country layouts, selected-year updates, trend metric
changes, missing-data rendering, dimension filtering, desktop layout, and
approximately 390px responsive layout. Browser acceptance requires an explicit
named executable smoke artifact; a visual inspection alone is insufficient.

### 8. Document the implemented contract

- **Requirements**: R4, R5, R6, R7, R10, R11, R15, R16
- **Tests**: documentation review and changed-file review

Document the maximum of three countries, ISO3 selection, direct and Explorer
entry paths, global-year behavior, all-years trends, supported metrics, metadata
labels, missing-data treatment, independent section states, and descriptive
interpretation. Explicitly record exclusions: indicators, weighting, rankings,
causal claims, significance testing, downloads, new sources, and external
`spiR` changes.

## Verification Surface

| ID | Evidence | Required |
|----|----------|----------|
| V1 | Normalized comparison inputs with stable ISO3, pillar, dimension, and year keys | yes |
| V2 | Provider/fallback contract using public `spiR` functions | yes |
| V3 | Pure selection, year, metric, trend, pillar, and dimension helpers | yes |
| V4 | Deterministic fixtures for complete, missing, partial, empty, unavailable, and error states | yes |
| V5 | Five-pillar radar and grouped-bar preparation | yes |
| V6 | Overall/pillar all-years trend preparation | yes |
| V7 | Full labeled dimension table with optional filtering and missing-value treatment | yes |
| V8 | Module tests using injected normalized data | yes |
| V9 | Direct selection and Explorer handoff | yes |
| V10 | State isolation from Overview, Explorer, and Profile | yes |
| V11 | Complete deterministic test suite | yes |
| V12 | Named responsive browser smoke artifact | yes |
| V13 | Documentation and changed-file review | yes |

## Acceptance Criteria

- A user can compare two or three valid countries and cannot create a fourth
  comparison.
- Direct selection and Explorer handoff produce the same ISO3-based state.
- Radar, grouped bars, and dimensions use one selected global year.
- Trends show all available years and switch between Overall SPI and supported
  pillar metrics.
- All five pillars are represented by technical ID and readable metadata label.
- The dimension table shows all available dimensions by default and supports a
  focused optional filter.
- Missing values remain missing, render as `-` in tables, and do not become
  zero-valued chart observations.
- A failure or unavailable result in one section does not hide valid sections.
- Comparison state remains independent from all existing dashboard modules.
- Focused tests, the complete deterministic suite, and named browser smoke
  validation pass, or any unrelated pre-existing failure is documented.

## Out of Scope

- More than three simultaneous countries.
- Indicator-level comparison.
- User-defined weighting or composite scores.
- Global rankings, league tables, causal inference, or significance testing.
- Downloads, exports, citation packages, and new external data sources.
- New provider APIs or changes to the external `spiR` repository.
- Automatic refresh, production deployment, or unrelated module refactors.

## Deviation Policy

This plan is approved for the stated product and data contract. Ask before
changing the comparison limit, year rule, visualization set, provider boundary,
missing-data semantics, or scope exclusions. Small implementation choices that
preserve these contracts may be made locally and recorded in the execution
report.

## Blocked-Stop Conditions

Stop and report the blocker if:

- the verified provider/fallback contract cannot supply required overall,
  pillar, dimension, or metadata inputs;
- a required visualization cannot be rendered with available dependencies or
  an established dashboard alternative;
- browser acceptance cannot be tied to a named executable harness;
- integration regresses Overview, Explorer, or Profile behavior;
- completion would require modifying external `spiR`; or
- the global-year rule creates ambiguous or silently imputed values that cannot
  be represented transparently.

## Related

- `../brainstorms/2026-08-31-milestone-4-country-comparison.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/mod_country_compare.R`
- `tests/testthat/test-country-compare-module.R`
- `../solutions/testing-patterns/2026-08-31-milestone-3-country-profile.md`
