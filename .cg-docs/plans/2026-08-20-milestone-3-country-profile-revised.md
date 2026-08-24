---
date: 2026-08-20
title: "Milestone 3: Modular single-country Country Profile (Revised)"
status: completed
completed-date: 2026-08-20
execution-report: .cg-docs/work-reports/2026-08-20-milestone-3-country-profile-revised.md
scope: "Deep"
brainstorm: "../brainstorms/2026-08-20-milestone-3-country-profile.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-profile, spiR, provider-adapter, navigation, modular-visualizations, trends, pillars, dimensions, indicators, benchmarks, testing, revised]
phases: 4
completed-phases: [1, 2, 3, 4]
post-completion-correction: "Added the existing five-pillar radar as the primary Profile visualization, including regional benchmark series and focused tests."
---

# Plan: Milestone 3: Modular Single-country Country Profile (Revised)

## Objective

Implement Country Profile as an independent Golem-compatible view for one
country. The user selects the country directly in Country Profile; Country
Explorer does not select a country for Profile and has no handoff contract.
Profile owns its country and year state and keeps Overview and Country Explorer
state unchanged. Country comparison, downloads, weighting, and new maps remain
out of scope.

This revised plan treats the local development source of `spiR` as a
provisional future API. The actual sibling checkout must be loaded with
`devtools::load_all()` and its exports, signatures, and representative calls
must be verified before provider wiring. A declaration or export without a
working implementation is not treated as supported.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Implement Country Profile as an independent Golem module for one country. | Approved Milestone 3 scope |
| R2 | Provide direct country selection in Profile; no Explorer-to-Profile handoff. | Revised navigation decision |
| R3 | Keep Profile country and year state independent from Overview and Explorer. | Approved architecture decision |
| R4 | Preserve `spiR` as preferred provider and local functions as fallback. | Project charter |
| R5 | Keep provider interpretation and normalization outside Shiny UI code. | Project context |
| R6 | Provide header, overall score, trend, pillars, dimensions, indicators, strengths/improvements, and contextual benchmarks. | Brainstorm and mockup |
| R7 | Preserve missing values as `NA`; never convert missing values to zero. | Domain rule |
| R8 | Isolate `pending`, `ok`, `partial`, `empty`, `unavailable`, and `error` by section. | Approved architecture decision |
| R9 | Use deterministic fixtures, module tests, integration tests, and browser validation. | Milestone 2 evidence |
| R10 | Document the provider contract, direct navigation, state isolation, and exclusions. | Dashboard handoff requirement |

## Phase 1: Provider and data contract

### 1. Verify the development `spiR` source

- **Requirements**: R4, R5, R6
- **Tests**: provider-contract test and configured `spiR` source-load report

Inspect `R/spi_provider.R`, `R/spi_adapter.R`, `dev/run_dev.R`, and the
configured sibling checkout. Load the checkout with:

```r
devtools::load_all(
  Sys.getenv("SPIR_PATH", unset = file.path(getwd(), "..", "spiR")),
  quiet = TRUE
)
```

Verify each operation with `getNamespaceExports()`, `exists()` inside the
namespace, `formals()`, and one controlled representative call. Record source
path and branch/commit in the execution report. The verified development
source currently contains:

- `spi_versions()` for version discovery.
- `spi_get()` for `data`, `index`, and `aggregates` datasets.
- `spi_data()` for country-year indicator data.
- `spi_index()` for overall, pillar, dimension, and index data where supported.
- `spi_indicator()` for selected indicator columns.
- `country_info()` for country metadata, region, income, lending type, and population.
- `metadata()`, `metadata_pillars()`, and `metadata_dimensions()` for hierarchy labels.
- `spi_aggregates()` for official aggregate rows.
- `spi_clear_cache()`, `spi_update_inventory()`, and `spi_clear_inventory()` for maintenance only.

Classify every operation as `available`, `provisional`, `fallback-supported`, or
`unavailable`. The listed `spi_plot_*()` functions are not a Profile dependency:
Profile renders from normalized data so fallback and fixture tests remain
possible. Inventory operations and the unimplemented tree crawler do not run in
the normal Profile load path. Do not modify external `spiR`.

**Tests:** Add a provider-contract test for exports, signatures, and controlled
call status. Keep ordinary deterministic tests offline and fixture-backed.

### 2. Define normalized Profile objects and section states

- **Requirements**: R5, R6, R7, R8
- **Tests**: `tests/testthat/test-country-profile-data.R`

Add `R/country_profile_data.R` and `tests/testthat/test-country-profile-data.R`.
Create pure preparation functions for header, overall series, pillars,
dimensions, indicators, strengths/improvements, and region/income benchmarks.
Preserve country-year keys and technical IDs even when overall score is `NA`.
Compute valid years separately for each metric.

Every section returns:

```r
list(data = ..., status = ..., message = ..., coverage = ..., source = ...)
```

Use these meanings:

- `pending`: loader result has not arrived.
- `ok`: supported data is complete for the requested section.
- `partial`: rows exist but requested coverage is incomplete.
- `empty`: supported operation returned no matching rows.
- `unavailable`: operation is absent or unsupported.
- `error`: provider call or normalization failed.

Test explicit overall `NA` with valid pillar/dimension values, duplicate
country-year rows, missing metadata, missing benchmarks, partial coverage, and
mandatory versus optional operation failures.

## Phase 2: Pure helpers and analytical transforms

### 3. Country/year and summary helpers

- **Requirements**: R2, R3, R6, R7
- **Tests**: `tests/testthat/test-country-profile-helpers.R`

Add `R/country_profile_helpers.R` and
`tests/testthat/test-country-profile-helpers.R`. Use `country_code` as the
stable choice key. Select the latest valid year for the selected metric, retain
the country when the year changes, and render unavailable values as `-`.
Country Explorer is not a source of Profile selection or navigation state.

### 4. Independent transforms

- **Requirements**: R6, R7, R8
- **Tests**: `tests/testthat/test-country-profile-helpers.R`

Implement pure transforms for trend, pillars, dimensions, indicators,
strengths/improvements, and benchmarks. Use normalized inputs only.

Strengths and improvement areas use this deterministic rule: candidates are
dimensions for the selected year; a candidate needs a non-missing score and
must meet the configured coverage threshold; results are ordered by score and
then technical ID; display at most three highest and three lowest candidates.
The UI labels these as “highest observed dimensions” and “lowest observed
dimensions under the coverage rule”, not causal strengths, weaknesses, or
global rankings.

Benchmarks are separate official-reference series. Define canonical mappings
for region, income group, codes, names, and `source_id`; filter overall
benchmarks to the correct overall source; handle duplicate, missing, and
misclassified aggregate rows explicitly.

## Phase 3: Module and application integration

### 5. Country Profile module

- **Requirements**: R1, R3, R6, R7, R8
- **Tests**: `tests/testthat/test-country-profile-module.R`

Add `R/mod_country_profile.R`, register it in `R/app_ui.R` and
`R/app_server.R`, and add `tests/testthat/test-country-profile-module.R`.
Provide direct country and year selectors, header, score, trend, pillars,
dimensions/indicators, strengths/improvements, benchmarks, and independent
section status outputs.

The module consumes injected normalized section results. It must not call raw
provider functions or `spiR::spi_plot_*()` from UI code. Test every section
independently with valid, partial, empty, unavailable, and error fixtures.

### 6. Direct navigation and state isolation

- **Requirements**: R2, R3, R10
- **Tests**: `tests/testthat/test-app-integration.R`, `tests/testthat/test-country-explorer-module.R`

Use the existing top-level tab navigation. Do not add a Country Explorer row
action, handoff, navigation bridge, shared selection state, or routing
dependency. Update the Explorer prompt and README so neither promises Profile
navigation. Test that Profile year changes do not mutate Overview or Explorer.

## Phase 4: Verification and documentation

### 7. Regression and browser validation

- **Requirements**: R1, R2, R3, R8, R9
- **Tests**: `tests/testthat/`, named browser smoke artifact, app smoke command

Run focused data/helper/module tests, then the complete deterministic suite:

```powershell
Rscript --vanilla -e "testthat::test_dir('tests/testthat')"
```

Validate direct Profile selection, section isolation, missing-value display,
tab navigation, desktop layout, and approximately 390px responsive layout.
Use the repository's established browser harness if available; otherwise add a
named browser smoke artifact and command before claiming browser acceptance.
Record the configured `spiR` source and commit/branch. Live calls are smoke
checks only and do not establish schema correctness.

### 8. Documentation

- **Requirements**: R2, R4, R5, R8, R10
- **Tests**: README/manual completion-contract review

Update `README.md` and the existing Explorer prompt text to document direct
Profile selection, independent state, verified/provisional provider behavior,
section states, official-reference benchmarks, and explicit exclusions. Do not
document Explorer handoff or multi-country comparison as implemented.

## Verification Surface

| ID | Evidence | Required |
|----|----------|----------|
| V1 | Profile normalized objects and section statuses | yes |
| V2 | Provider/fallback contract and development `spiR` API verification | yes |
| V3 | Pure transforms for all Profile sections | yes |
| V4 | Missing, partial, and benchmark fixtures | yes |
| V5 | Country Profile module from injected data | yes |
| V6 | Direct Profile selection through existing tabs | yes |
| V7 | Profile state isolation from Overview and Explorer | yes |
| V8 | Independent section errors | yes |
| V9 | Complete deterministic test suite | yes |
| V10 | Named browser smoke artifact and responsive validation | yes |
| V11 | Golem/fixture launch | yes |
| V12 | Documentation and changed-file review | yes |

## Out of Scope

- Country Explorer-to-Profile handoff.
- Comparing two or more countries or the Compare Countries workflow.
- Downloads, exports, citation packages, weighting, and ranking tools.
- New maps or geospatial analysis.
- Production deployment changes.
- Changes to external `spiR`.
- Unsupported global, causal, best/worst, or normative claims.

## Blocked-Stop Conditions

- Required data cannot be represented by the verified provider/fallback contract.
- A required visualization dependency is unavailable and no existing alternative supports it.
- Browser acceptance is claimed without a named executable harness.
- Integration regresses Overview or Country Explorer.
- Completing a requirement requires modifying external `spiR`.

## Context

Milestone 2 established the normalized all-years provider boundary, local
Country Explorer filtering, injected snapshot loaders, independent Explorer
state, DT behavior, and deterministic tests. Country Profile is currently a
placeholder. `R/spi_provider.R` owns provider selection and operation status;
`R/spi_adapter.R` owns aliases and normalized schemas. The configured sibling
`spiR` source is an external dependency and must not be modified.

## Testing Strategy

Test provider contracts and pure data transforms before Shiny behavior. Use
offline injected fixtures for ordinary tests, including `NA`, partial, empty,
unavailable, and error cases. Use `shiny::testServer()` for module state and
section isolation, fixture-backed app integration for state separation, and a
named browser harness for direct selection and responsive validation. Live
`spiR` calls are smoke checks only.

## Documentation Checklist

- [ ] Profile is explicitly single-country.
- [ ] Country selection is direct and local to Profile.
- [ ] No Explorer-to-Profile handoff is documented or implemented.
- [ ] Provider/fallback and provisional source verification are documented.
- [ ] `NA`, partial, empty, unavailable, and error states are documented.
- [ ] Benchmarks are labeled official contextual references.
- [ ] Comparison, downloads, weighting, and new maps are excluded.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Development `spiR` differs from installed package. | Use `devtools::load_all()`, verify exports/signatures/calls, and record source commit. |
| Overall `NA` hides valid lower-level values. | Preserve country-year keys and compute valid years by metric. |
| Aggregate rows are misclassified. | Use canonical region/income mappings and explicit source filters. |
| One failed operation blocks Profile. | Return typed section results and isolate optional operation failures. |
| Browser acceptance is not reproducible. | Require a named executable smoke artifact and command. |
| Explorer accidentally regains handoff behavior. | Test absence of row actions, callbacks, and shared selection state. |

## Completion Contract

### Outcome

A user opens Country Profile from the existing top-level navigation, selects one
country and a valid year, and sees independently rendered sections with clear
missing or unavailable states. Overview and Country Explorer remain unchanged,
and no country comparison is implemented.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|------:|-------------------|------------------|----------|
| V1 | 1 | Profile data objects preserve keys and return typed statuses | `test-country-profile-data.R` | yes |
| V2 | 1 | Development `spiR` API and provider/fallback contract are verified | Provider contract test and source-load report | yes |
| V3 | 2 | Pure transforms implement the analytical rule deterministically | `test-country-profile-helpers.R` | yes |
| V4 | 3 | Module and integration state remain independent | Module and app integration tests | yes |
| V5 | 4 | Deterministic regression suite passes | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` | yes |
| V6 | 4 | Named browser smoke and responsive validation pass | Browser smoke artifact and command | yes |

### Constraints

| ID | Constraint | Check |
|----|------------|-------|
| C1 | `spiR` remains preferred and local functions remain fallback | Provider tests and app smoke |
| C2 | External `spiR` is untouched | Changed-file review |
| C3 | Raw provider interpretation stays outside UI modules | Code review |
| C4 | Missing values remain missing | Fixtures and browser display |
| C5 | Country Profile contains one country only | UI and integration tests |

### Boundaries

- Allowed: Profile data, helper, module, provider/adapter contract extensions, app registration, tests, and documentation.
- Out of scope: Explorer handoff, comparison, downloads, weighting, new maps, production changes, and external `spiR` edits.

### Iteration Policy

1. Verify the configured development `spiR` source before writing UI assumptions.
2. Implement and test one pure section contract at a time.
3. Connect stable transforms to the module only after focused tests pass.
4. Validate direct Profile selection and state isolation before visual polish.
5. Rerun the focused check after each repair before widening scope.

### Blocked-Stop Conditions

- Required data cannot be represented by the verified provider/fallback contract.
- Browser acceptance is claimed without a named executable harness.
- Integration regresses Overview or Country Explorer.
- Completing a requirement requires modifying external `spiR`.
