---
date: 2026-09-20
title: "Milestone 6: Explore by Pillar and Custom Weighting"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-09-20-milestone-6-explore-by-pillar.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
phases: 3
artifact-schema-version: 1
tags: [spi, shiny, golem, explore-by-pillar, custom-weighting, spiR, testing]
---

# Plan: Milestone 6: Explore by Pillar and Custom Weighting

## Objective

Deliver a focused Explore by Pillar Golem module for one country and one year.
The user will adjust weights for the five SPI pillars, must provide an exact
100% total, and will see an exploratory weighted score beside the official SPI
score and their difference. The result must remain clearly distinct from the
official SPI methodology.

## Context

The application already registers an initial `pillar_explorer` module in
`R/mod_pillar_explorer.R`, `R/app_ui.R`, and `R/app_server.R`. That module
currently displays a pillar table but does not implement country selection,
custom weights, score calculation, missing-pillar handling, or the final
interpretation labels.

The shared provider boundary already prefers `spiR`, normalizes overall and
pillar scores through `R/spi_provider.R` and `R/spi_adapter.R`, and supports
lazy detail loading. Existing module tests use injected snapshots and
`shiny::testServer`; the browser smoke pattern uses `shinytest2` at desktop and
mobile widths.

The approved brainstorm chose direct manual weighting at pillar level. The
five weights start at 20%, must total exactly 100%, and the first version is
limited to one country and one year. If a selected country lacks one or more
pillar scores, available scores are used and their weights are renormalized;
the interface must disclose that adjustment.

The project charter currently names Milestone 5 as its current focus. This
plan is intentionally scoped to the approved Milestone 6 roadmap item and does
not update the charter.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Provide a dedicated Explore by Pillar module for one country and one year. | Brainstorm; `R/mod_pillar_explorer.R` |
| R2 | Expose the five normalized pillar scores and one editable weight per pillar. | Brainstorm; `R/spi_adapter.R` |
| R3 | Initialize all weights to 20% and provide a reset action. | Brainstorm |
| R4 | Require the five weights to sum exactly to 100% before calculating a custom score. | Brainstorm |
| R5 | Calculate a weighted result from available pillar scores without treating `NA` as zero. | Brainstorm; project memory |
| R6 | Renormalize weights over available pillars when one or more scores are missing, and disclose the adjustment. | Brainstorm |
| R7 | Show official SPI, user-weighted SPI, and the difference as separate values and labels. | Brainstorm |
| R8 | Keep calculation and validation in pure R helpers, outside the Shiny module. | Charter; Brain findings |
| R9 | Use the shared `spiR`-preferred provider snapshot and do not modify the external `spiR` repository. | Charter; Brain findings |
| R10 | Preserve lazy loading and injected snapshot support for deterministic tests. | Existing app architecture |
| R11 | Keep the first version limited to pillars, one country, and one year. | Brainstorm |
| R12 | Validate arithmetic, reactive states, integration, responsive UI, and documentation. | Completion contract |

## Implementation Steps

## Phase 1: Core data contract and calculation

### 1. Define the pure pillar weighting contract

- **Requirements**: R4, R5, R6, R7, R8
- **Files**: `R/pillar_explorer_data.R` (new), `R/pillar_explorer_helpers.R` (new), `tests/testthat/test-pillar-explorer-data.R` (new), `tests/testthat/test-pillar-explorer-helpers.R` (new)
- **Details**: Define stable helper contracts for discovering the five pillar
  score columns, validating numeric weights, requiring a finite total of exactly
  100% (using one documented comparison rule), selecting a country-year row,
  preserving missing scores, renormalizing weights over available pillars, and
  returning a structured result with official score, custom score, difference,
  available pillars, effective weights, coverage status, and error/status text.
  Keep all score transformations deterministic and independent of Shiny.
- **Test Scenarios**: equal 20% weights reproduce the weighted average of
  available pillars; valid unequal weights produce the expected result; totals
  below and above 100% are invalid; negative, non-finite, and non-numeric
  weights are invalid; zero weights are allowed when the total is 100%; one
  missing pillar renormalizes the remaining effective weights; all pillars
  missing return an unavailable custom result; missing official score does not
  silently become zero.
- **Tests**: `testthat::test_file("tests/testthat/test-pillar-explorer-data.R")`; `testthat::test_file("tests/testthat/test-pillar-explorer-helpers.R")`
- **Acceptance criteria**: Pure helpers return stable, documented structures
  for valid, invalid, partial, and empty fixtures, with no Shiny dependency.

### 2. Confirm snapshot and label preparation

- **Requirements**: R1, R2, R5, R9, R10
- **Files**: `R/spi_adapter.R` (only if a proven normalization gap exists), `R/pillar_explorer_data.R`, `tests/testthat/test-pillar-explorer-data.R`
- **Details**: Consume normalized `snapshot$index` for country, year, overall
  score, and pillar scores. Use normalized hierarchy labels when available,
  falling back to stable technical labels only when metadata is unavailable.
  Do not read the malformed metadata CSV at runtime and do not add provider
  calls from the UI. Confirm that the loader can operate with an injected
  fixture and that no changes to `spiR` are required.
- **Test Scenarios**: five pillar columns with hierarchy labels; technical
  fallback labels; absent hierarchy; duplicate country-year rows already
  normalized; unavailable optional metadata without blocking pillar scores.
- **Tests**: Extend `test-pillar-explorer-data.R`; run the relevant adapter tests
  if normalization is changed.
- **Acceptance criteria**: The data layer produces one deterministic country-
  year pillar record with labels and explicit availability metadata.

## Phase 2: Golem module and application integration

### 3. Replace the placeholder UI with the focused weighting workspace

- **Requirements**: R1, R2, R3, R4, R7, R11
- **Files**: `R/mod_pillar_explorer.R`, `R/app_ui.R` only if registration or
  styling requires a minimal change
- **Details**: Build namespaced controls for year and country, five pillar
  weight inputs, a visible weight total, a reset-to-equal action, and a compact
  score summary showing official, user-weighted, and difference values. Add
  clear labels that the custom result is exploratory and user-defined. Keep the
  existing dashboard visual language, avoid dimension/indicator controls, and
  design the layout for narrow screens without adding packages.
- **Test Scenarios**: default country/year selection; five weights initialized
  to 20%; reset restores 20%; invalid total shows validation state; no country
  or no year shows a controlled unavailable state.
- **Tests**: `tests/testthat/test-pillar-explorer-module.R` (new), using
  `shiny::testServer` and rendered UI string checks.
- **Acceptance criteria**: The module exposes only the approved first-version
  controls and presents the official/custom distinction without ambiguous
  wording.

### 4. Wire reactive state, lazy loading, and calculation results

- **Requirements**: R4, R5, R6, R7, R8, R10
- **Files**: `R/mod_pillar_explorer.R`, `R/app_server.R` only if the existing
  registration needs adjustment, `tests/testthat/test-pillar-explorer-module.R`,
  `tests/testthat/test-app-integration.R`
- **Details**: Keep a module-local snapshot loaded only when the tab is active,
  matching the existing lazy-loading pattern. Update country/year choices from
  the snapshot, derive the selected country-year row, pass weights to pure
  helpers, and render validation, result, coverage, and error states without
  breaking other tabs. Preserve `snapshot_loader` injection for tests.
- **Test Scenarios**: inactive module does not call its loader; activation loads
  once; country/year changes update pillar values; valid weights render a custom
  score; invalid totals suppress the custom score; missing pillars show
  renormalization; loader errors show a controlled status.
- **Tests**: Focused pillar module tests and the app integration test with a
  fixture snapshot containing all five pillars and a partial-coverage row.
- **Acceptance criteria**: The tab works through the normal `app_server()` path,
  remains lazy when hidden, and keeps official and custom values independent.

## Phase 3: Verification, responsive behavior, and documentation

### 5. Add deterministic and browser validation

- **Requirements**: R4, R5, R6, R7, R10, R12
- **Files**: `tests/testthat/test-pillar-explorer-data.R`, `tests/testthat/test-pillar-explorer-helpers.R`, `tests/testthat/test-pillar-explorer-module.R`, `tests/testthat/test-app-integration.R`, `tests/browser/pillar-explorer-smoke.R` (new), `tests/browser/fixture-app/app.R` only if the fixture needs the new tab
- **Details**: Add a browser smoke test following the existing `shinytest2`
  pattern. Exercise the tab at desktop and mobile widths, select a country and
  year, verify the default and invalid weight totals, reset weights, and check
  official/custom labels. Keep browser assertions focused on observable
  behavior, not fragile chart internals.
- **Test Scenarios**: happy path with equal weights; invalid total; reset;
  missing-pillar notice; mobile layout; empty/error state.
- **Tests**: Focused testthat files, app integration, and the new browser smoke
  command supported by the repository's existing test workflow.
- **Acceptance criteria**: All required verification surface entries V1-V9 have
  executable evidence or a documented environment blocker.

### 6. Document methodology and operational boundaries

- **Requirements**: R6, R7, R9, R11, R12
- **Files**: `README.md`, `.cg-docs/work-reports/` (new report only if the
  project workflow requires one), `.cg-docs/plans/2026-09-20-milestone-6-explore-by-pillar.md`
- **Details**: Document that the result is a user-defined exploratory score,
  not the official SPI; describe exact 100% validation, missing-pillar
  renormalization, data provenance through `spiR`, and out-of-scope
  dimensions/indicators and multi-country analysis. Record executed tests and
  any environment limitations in the milestone work report if requested by the
  project workflow. Do not update the charter as part of implementation unless
  separately approved.
- **Test Scenarios**: documentation names the same formula and missingness
  behavior implemented by the helpers; links and paths resolve.
- **Tests**: Markdown review and final `git diff --check`.
- **Acceptance criteria**: A user can understand which values are official,
  which are exploratory, and how missing data affected the displayed result.

## Testing Strategy

- Prefer pure helper tests for all arithmetic and validation. Fixtures should
  include all five pillars, zero weights, invalid totals, partial coverage, and
  no coverage.
- Use `shiny::testServer` for module state, lazy loading, reset behavior,
  country/year selection, and controlled error states.
- Use app integration with an injected snapshot to verify registration without
  network calls.
- Use `shinytest2` for one focused browser smoke path at desktop and mobile
  widths. Assert visible labels and values rather than implementation details.
- Run diagnostics on all touched R files after implementation.
- Run the focused tests before the broader suite; unrelated existing failures
  remain outside this plan unless the change directly causes them.

## Documentation Checklist

- [ ] Explain official SPI versus user-weighted exploratory result.
- [ ] Explain exact 100% weight validation.
- [ ] Explain missing-pillar renormalization and coverage disclosure.
- [ ] Identify `spiR` as the preferred provider and the local fallback boundary.
- [ ] State that dimensions, indicators, rankings, multiple countries, and
  saved scenarios are out of scope.
- [ ] Record focused, integration, and browser verification results.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Users interpret the custom score as official SPI | Distinct labels, side-by-side values, explanatory status text, and tests for output wording |
| Missing pillars distort the weighted result | Preserve `NA`, renormalize only available weights, show effective coverage and a notice |
| Floating-point totals reject valid user input unexpectedly | Use a documented tolerance or integer percentage contract consistently in helper and UI tests |
| Existing normalized schema has fewer than five pillar columns | Detect available columns, render a controlled unavailable state, and verify against live `spiR` before adapting |
| Lazy loading leaves controls empty or stale | Load only on activation, update choices reactively, and test activation after an initial inactive state |
| Module changes regress existing tabs | Keep app wiring minimal and run app integration plus existing focused module tests |
| Browser assertions become brittle | Assert stable namespaced outputs, labels, and dimensions rather than rendered table internals |
| Scope expands into a second weighting methodology | Treat dimensions, indicators, multiple countries, rankings, and saved scenarios as blocked deviations requiring approval |

## Out of Scope

- Weighting dimensions or indicators.
- Multiple-country scenarios or comparison views.
- Global rankings, quintiles, or league tables based on customized scores.
- Persistent or shareable saved weighting scenarios.
- Changes to official SPI values or methodology.
- New external data sources or modifications to the external `spiR` repository.
- Automatic weight redistribution while editing.
- New charting dependencies.
- Automatic refresh during an open session.

## Completion Contract

### Outcome

The Shiny dashboard exposes a responsive Explore by Pillar workspace where one
country and year can be evaluated under user-defined weights for five pillars.
The app validates a 100% total, computes a transparent exploratory score from
available pillar values, discloses renormalization when needed, and keeps the
official SPI visibly separate.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Phase | Required |
|---|-------------------|------------------|-------|----------|
| V1 | Weight validation and arithmetic pass deterministic fixtures | Focused `testthat` files | 1 | yes |
| V2 | Missingness and effective-weight behavior pass fixtures | Focused `testthat` files | 1 | yes |
| V3 | Snapshot preparation exposes five pillars and labels | Data-layer tests | 1 | yes |
| V4 | Module defaults, reset, validation, and result states pass | `shiny::testServer` | 2 | yes |
| V5 | Lazy activation and loader injection pass | Module and app integration tests | 2 | yes |
| V6 | Official/custom/difference outputs are observable | Module tests and browser smoke | 2/3 | yes |
| V7 | Desktop and mobile workflow passes | `shinytest2` browser smoke | 3 | yes |
| V8 | Documentation matches calculation and scope | README/work report review | 3 | yes |
| V9 | Touched files have no diagnostics | `get_errors` | 3 | yes |

### Constraints

| ID | Constraint | Check |
|---|------------|-------|
| C1 | Use `spiR`-preferred shared provider boundary | Snapshot configuration and integration fixture |
| C2 | Do not modify external `spiR` | Repository diff/status |
| C3 | Preserve missingness and disclose renormalization | Helper tests and UI output |
| C4 | Require exact 100% weights | Validation helper and module tests |
| C5 | Preserve Golem module boundaries | File ownership and app wiring review |
| C6 | No new dependencies | `DESCRIPTION` unchanged unless separately approved |

### Boundaries

- Allowed: `R/` module/data/helper changes, focused tests, browser fixture
  additions, minimal app registration adjustments, and related documentation.
- Out of scope: dimensions, indicators, multi-country analysis, rankings,
  saved scenarios, official methodology changes, new data sources, and external
  `spiR` modifications.

### Iteration Policy

1. Fix pure calculation defects before adjusting UI behavior.
2. Preserve the normalized snapshot contract; resolve schema gaps at the
   provider/adapter boundary only when evidenced by tests.
3. Keep invalid totals visibly invalid rather than silently normalizing them.
4. Treat missing-pillar renormalization as an explicit result state.
5. Ask before changing formulas, scope, dependencies, or official-score
   interpretation.
6. Rerun the narrowest failing test after each local repair, then broaden
   validation only after the focused check passes.

### Blocked-Stop Conditions

- Pillar scores cannot be obtained reliably from the normalized `spiR`-backed
  snapshot.
- A reproducible distinction between official and custom scores cannot be
  maintained.
- Missingness requires an unapproved imputation rule.
- Focused arithmetic tests reveal unexplained numeric discrepancies.
- Existing modules regress and the cause is outside this plan's boundaries.
- External `spiR` changes or an unapproved dependency become necessary.

### Deviation Policy

`ask`
