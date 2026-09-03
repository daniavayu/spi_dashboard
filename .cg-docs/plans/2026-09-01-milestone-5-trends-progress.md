---
date: 2026-09-01
title: "Milestone 5: Trends and Progress"
status: active
scope: "Deep"
brainstorm: "../brainstorms/2026-09-01-milestone-5-trends-progress.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, spiR, trends, progress, coverage, pillars, stability, correlation, testing]
phases: 4
---

# Plan: Milestone 5: Trends and Progress

## Objective

Replace the current Trends & Progress placeholder with an independent Golem
module that helps users understand SPI movement over time. The module will
provide global and official-group trends, period changes, coverage context,
pillar stability, and descriptive pillar associations while consuming the
shared normalized provider snapshot.

The implementation will preserve `spiR` as the preferred data and metadata
provider, retain the local fallback, keep transformations outside Shiny
rendering code, and avoid causal or predictive interpretation.

## Context

Milestones 1 through 4 established the application entry point, provider and
adapter boundary, Overview, Country Explorer, Country Profile, and Compare
Countries. The current Trends tab is only a single `spi_plot_region_history()`
placeholder output wired directly in `R/app_server.R`.

The provider already exposes normalized `index`, `metadata`, `income_data`,
`aggregates`, pillar labels, dimension labels, available years, and operation
statuses. `spiR::country_info()` exposes official region, income-level,
lending-type, and administrative-region metadata. `spiR::spi_aggregates()`
exposes official aggregate series. Every valid row returned by
`spi_aggregates()` must remain available to Trends, preserving its group code,
group name, year, `source_id`, and score; the dashboard must not filter to a
hard-coded list of aggregate codes. The module should use these contracts
rather than calling raw `spiR` functions from UI code.

The project charter's `Current Focus` still names Milestone 2. This is stale
metadata relative to the implemented Milestones 1-4 and the approved Milestone
5 brainstorm. Updating that charter field is a documentation follow-up, not a
part of the implementation edits in this plan.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Implement Trends & Progress as an independent Golem module and replace the existing placeholder tab. | Approved Milestone 5 brainstorm |
| R2 | Use the normalized provider snapshot and injected fixture loaders; do not call raw `spiR` functions from Shiny modules. | Project charter and Milestone 4 solution |
| R3 | Preserve `spiR` as the preferred provider and local provider as fallback. | Project charter |
| R4 | Support start year and end year controls using valid snapshot years, with the full available period as the default. | Approved Milestone 5 scope |
| R5 | Support overall SPI and available pillar metrics using normalized index columns and readable pillar labels. | Approved Milestone 5 scope |
| R6 | Support all valid aggregate rows returned by `spi_aggregates()` and official metadata groupings; preserve group code, name, year, `source_id`, score, and provenance without inventing classifications or user-defined groups. | User clarification and approved Milestone 5 scope |
| R7 | Render global and selected-group trends with central tendency, distribution or dispersion context, and yearly contributor counts. | Approved Milestone 5 scope |
| R8 | Provide a sortable descriptive period-change table for countries, retaining start/end values and endpoint coverage without presenting an unsupported statistical ranking. | Approved Milestone 5 scope and review decision |
| R9 | Provide a documented pillar stability statistic and an association matrix with minimum-observation rules. | Approved Milestone 5 scope |
| R10 | Preserve missing values as `NA` and expose empty, unavailable, partial, and low-coverage states without silent exclusion. | Domain rule and prior module patterns |
| R11 | Keep analytical transformations pure and deterministic so they can be tested independently of Shiny and network data. | Milestones 2-4 testing pattern |
| R12 | Add focused module, integration, full-suite, and browser validation and update relevant documentation. | Project charter and Milestone 4 solution |

## Implementation Steps

## Phase 1: Data Contract and Pure Transformations

### 1. Define the normalized Trends data contract
- **Requirements**: R2, R3, R5, R6, R10, R11
- **Files**: `R/spi_adapter.R`, `R/trends_progress_data.R`, `R/trends_progress_helpers.R`
- **Details**: Confirm the normalized inputs and extend metadata normalization
  only as needed to expose official `admin_region`, `lending_type`, and
  corresponding codes alongside the existing region and income fields. Define
  stable metric descriptors for overall SPI and detected `pillar_*_score`
  columns, including IDs, labels, and score bounds. Extend aggregate
  normalization so every valid `spi_aggregates()` row is retained with
  `group_code`, `group_name`, `year`, `source_id`, `score`, and a provenance
  or classification descriptor. Known `source_id` values may receive a
  validated label; unknown values remain visible as unclassified official
  aggregates rather than being discarded. Define grouping descriptors from
  metadata columns or these aggregate rows, and keep absent operations,
  invalid rows, and empty data distinguishable.
- **Test Scenarios**: complete snapshot, missing metadata fields, missing
  pillar labels, duplicate country-year metadata, unknown aggregate source,
  duplicate aggregate rows, unsupported metadata grouping, and empty index.
- **Tests**: `tests/testthat/test-spi-adapter.R`, new
  `tests/testthat/test-trends-progress-data.R`
- **Acceptance criteria**: A fixture snapshot can be converted into a stable
  Trends contract without raw-provider column names leaking into module code.

  Do not add `collapse` for this milestone. Use the packages already declared
  by the project and base R/`dplyr` operations consistent with neighboring
  modules; if profiling later demonstrates a need for `collapse`, record that
  as a separate dependency decision rather than adding an undeclared package
  during Trends implementation.

### 2. Implement period, metric, and grouping preparation
- **Requirements**: R4, R5, R6, R7, R10, R11
- **Files**: `R/trends_progress_data.R`, `R/trends_progress_helpers.R`
- **Details**: Implement pure helpers for available years, validated period
  selection, metric selection, group catalog discovery, country-year joins,
  global annual summaries, and official-group annual summaries. Use explicit
  country counts and non-missing observation counts for coverage. Preserve
  missing years and scores instead of converting them to zero. Use every valid
  official aggregate row returned by `spi_aggregates()`, exposing `source_id`
  and provenance in the group catalog. For metadata groupings, compute
  transparent country-level descriptive summaries from joined metadata and
  label the source accordingly. Never apply a hard-coded aggregate-code
  filter.
- **Test Scenarios**: reversed or unavailable years, one-year period, mixed
  country coverage, groups with no observations, unknown aggregate sources,
  all-aggregation retention, and a metric whose column is absent.
- **Tests**: `tests/testthat/test-trends-progress-data.R`
- **Acceptance criteria**: Pure helpers return deterministic data frames with
  documented columns and explicit status information for valid, empty, and
  unavailable inputs.

### 3. Define change, stability, association, and coverage statistics
- **Requirements**: R7, R8, R9, R10, R11
- **Files**: `R/trends_progress_data.R`, `R/trends_progress_helpers.R`
- **Details**: Define period change as end-period score minus start-period
  score for countries observed with valid scores at both endpoints, with
  endpoint coverage reported. Return a sortable descriptive table ordered by
  change, but label it as period change rather than a statistical ranking;
  include ties without arbitrary tie-breaking claims. Define global and group
  dispersion using median, IQR, and valid contributor counts. Define pillar
  stability as the pooled standard deviation of valid country-level changes
  between consecutive observed years within each country over the selected
  period. Require at least two valid changes for a stability value, report the
  number of countries and changes, and state that lower values indicate less
  variation under this measure. Define pillar associations as pairwise Pearson
  correlations over complete country-year pairs, requiring at least three
  complete pairs and non-zero variance in both pillars; otherwise return `NA`
  with an `insufficient_data` status. Deduplicate country-year rows
  deterministically before all calculations. Do not perform significance tests
  or causal interpretation.
- **Test Scenarios**: identical values, constant series, one valid pair,
  one valid stability change, insufficient correlation observations,
  non-consecutive years, duplicate country-year rows, missing endpoints, and
  changing coverage.
- **Tests**: `tests/testthat/test-trends-progress-data.R`
- **Acceptance criteria**: Every statistic has a named formula, minimum-data
  rule, and tests covering both valid and insufficient-data states.

## Phase 2: Shiny Module and Application Integration

### 4. Build the Trends & Progress module UI
- **Requirements**: R1, R4, R5, R6, R7, R9, R10
- **Files**: `R/mod_trends_progress.R`, `R/app_ui.R`
- **Details**: Add namespaced controls for start year, end year, metric, and
  official grouping. Build progressive-disclosure sections for global trend,
  selected-group trend, period changes, coverage, pillar stability, and pillar
  associations. Include visible status text and method notes. Keep dimensions
  and controls responsive and consistent with existing dashboard styles; remove
  the old `overview_region_history` placeholder from the Trends tab.
  When hierarchy labels are unavailable, use deterministic labels such as
  `Pillar 1` and show a partial or unavailable label status rather than
  exposing raw provider column names. Render every valid aggregate source in
  the group selector or as an explicit unclassified official-aggregate option.
- **Test Scenarios**: initial load, no valid period, unavailable metadata,
  mobile-width layout, and a selected pillar/group.
- **Tests**: new `tests/testthat/test-trends-progress-module.R`, existing
  integration test updated in Step 5.
- **Acceptance criteria**: The Trends tab has no placeholder output and exposes
  all approved controls and analytical sections through namespaced IDs.

### 5. Wire the module into the application server
- **Requirements**: R1, R2, R3, R10, R12
- **Files**: `R/app_server.R`, `tests/testthat/test-app-integration.R`
- **Details**: Reuse the existing `detail_snapshot()` and `explorer_loader()`
  path for Trends so detailed tabs do not load inconsistent provider snapshots.
  Ensure the shared loader requests `load_details = TRUE`,
  `load_metadata = TRUE`, and `load_aggregates = TRUE` when it initializes the
  cached detail snapshot. Call `trends_progress_server()` with that loader.
  Remove the direct `spi_plot_region_history()` render path and preserve all
  existing Overview, Explorer, Profile, and Compare wiring.
- **Test Scenarios**: fixture snapshot with complete data, fixture with failed
  optional operations, and regression checks for existing KPI and tab outputs.
- **Tests**: `tests/testthat/test-app-integration.R`,
  `tests/testthat/test-trends-progress-module.R`
- **Acceptance criteria**: `app_server()` loads the module with a fixture
  snapshot and existing application tests continue to pass.
  The loader must initialize one cached snapshot per app session and return
  the same normalized object to Trends and the other detailed tabs; tests must
  verify that the provider is not called again when the module reads the
  snapshot.

## Phase 3: Validation and Edge Cases

### 6. Add deterministic data and module tests
- **Requirements**: R4, R5, R6, R7, R8, R9, R10, R11, R12
- **Files**: `tests/testthat/test-trends-progress-data.R`,
  `tests/testthat/test-trends-progress-module.R`,
  `tests/testthat/test-app-integration.R`
- **Details**: Build small fixture snapshots with multiple years, countries,
  official regions, income groups, lending types, pillar scores, changing
  coverage, duplicate metadata, and missing values. Test pure outputs and
  `shiny::testServer()` outputs without network access. Assert that low
  coverage is reported, unsupported classifications are not manufactured, and
  no missing score becomes zero.
- **Details continued**: Include deterministic duplicate-resolution fixtures:
  define the precedence for duplicate country-year observations before
  calculation (prefer a valid score, then stable `source_id`/row order), and
  test that repeated runs return identical rows and values. Assert Pearson
  correlations require at least three complete pairs and stability requires at
  least two valid consecutive-year changes, with `NA` values and explicit
  `insufficient_data` statuses otherwise.
- **Test Scenarios**: happy path, partial provider response, empty snapshot,
  invalid controls, missing group coverage, and insufficient pillar pairs.
- **Tests**: focused `testthat` files and the full `tests/testthat` directory.
- **Acceptance criteria**: Focused tests pass and provide regression coverage
  for every public Trends helper and module state.

### 7. Run regression diagnostics and full test suite
- **Requirements**: R2, R3, R10, R12
- **Files**: touched R files and test files
- **Details**: Run focused tests first, then the complete deterministic suite.
  Inspect R diagnostics for touched files and repair only issues caused by this
  milestone. Verify that no external `spiR` files were modified and that the
  provider still falls back correctly when the mandatory index fails.
- **Test Scenarios**: normal local environment, optional provider failure, and
  missing optional hierarchy or aggregates.
- **Tests**: `Rscript -e "testthat::test_file('tests/testthat/test-trends-progress-data.R')"`,
  `Rscript -e "testthat::test_file('tests/testthat/test-trends-progress-module.R')"`,
  `Rscript -e "testthat::test_dir('tests/testthat')"`, and VS Code diagnostics.
- **Acceptance criteria**: Focused and full tests pass; touched-file diagnostics
  contain no new errors; external provider repository remains unchanged.

## Phase 4: Documentation and Browser Verification

### 8. Update project documentation and visualization mapping
- **Requirements**: R1, R2, R3, R6, R8, R9, R12
- **Files**: `README.md`, `.cg-docs/spiR-dashboard-visualization-mapping.md`,
  `compound-gpid.context.md`
- **Details**: Document the Trends module, supported official classifications,
  period and coverage interpretation, stability formula, correlation method,
  explicit descriptive limitations, and restart-based data refresh behavior.
  Record which views use public `spiR` outputs and which are dashboard-side
  descriptive transformations. Update the stale charter/context focus only in
  the appropriate documentation workflow after implementation; do not modify
  the external `spiR` repository.
- **Test Scenarios**: documentation matches implemented controls and no claim
  exceeds the available data contract.
- **Tests**: targeted text review and stale-reference search.
- **Acceptance criteria**: A new developer can identify the provider source,
  formulas, coverage rules, and out-of-scope analyses from project docs.

### 9. Verify the rendered application in desktop and mobile viewports
- **Requirements**: R1, R4, R5, R6, R7, R9, R10, R12
- **Files**: a new `tests/browser/trends-progress-smoke.R` fixture-backed
  `shinytest2` artifact, plus any required app fixture wiring
- **Details**: Launch the existing fixture app with a deterministic snapshot
  containing three years, two official groups, one missing metric value, and
  one unavailable optional operation. Navigate to Trends & Progress, change
  period, metric, and grouping controls, and verify that plots, the sortable
  descriptive change table, status messages, and coverage notes update without
  overlap. Check a desktop viewport and a 390px-wide mobile viewport. Confirm
  the old placeholder output is absent and empty/unavailable states remain
  readable.
- **Test Scenarios**: initial render, changed metric, changed grouping, narrow
  viewport, and a low-coverage fixture or unavailable optional operation.
- **Tests**: the project browser smoke command compatible with the existing
  `shinytest2` setup; record any environment limitation explicitly, including
  when a browser binary is unavailable.
- **Acceptance criteria**: Trends is usable at both target viewport sizes and
  no control or output is visually clipped or misleading.

## Testing Strategy

Pure transformation tests are the primary safety net because they can verify
formulas, coverage, missing-data behavior, grouping discovery, and status
contracts without network access. Module tests use injected snapshots and
`shiny::testServer()` to verify reactive control state and output availability.
The integration test verifies that `app_server()` wires Trends without
regressing existing tabs. The complete `tests/testthat` suite runs only after
focused tests pass. Browser validation is the final check for layout and
control behavior, not the source of analytical correctness.

## Documentation Checklist

- [ ] README describes Trends & Progress and its `spiR`-first data source.
- [ ] Official grouping availability and fallback behavior are documented.
- [ ] Period-change, coverage, stability, and correlation definitions are
  documented with limitations.
- [ ] Visualization mapping distinguishes public `spiR` views from dashboard
  transformations.
- [ ] Restart-based refresh behavior is retained.
- [ ] Stale charter focus is updated through the appropriate documentation
  workflow after implementation.
- [ ] Convergence, causal analysis, prediction, significance testing,
  clustering, and custom groups remain listed as out of scope.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `spiR` metadata fields or aggregate schemas change | Keep aliases and normalization in the provider/adapter boundary; validate columns and return explicit unavailable states. |
| A group trend is mistaken for a comparable time series when membership changes | Show yearly contributor counts, endpoint coverage, and method notes; do not silently use a fixed sample. |
| Stability ranking depends on an arbitrary statistic | Document the year-over-year standard-deviation formula, expose observation counts, and label it as one descriptive measure. |
| Correlation is interpreted causally | Use association language in labels and documentation; omit significance or causal claims. |
| Optional metadata or aggregate operations fail | Render independent section statuses and retain global index-based views where possible. |
| Added controls make the tab dense or unusable on mobile | Use responsive layout, progressive disclosure, stable plot dimensions, and browser checks at narrow width. |
| Existing modules regress through shared snapshot changes | Add adapter/provider regression tests and run the complete deterministic suite. |
| Live provider data makes tests nondeterministic | Inject fixture snapshots for all ordinary tests and use live data only for explicit smoke validation. |

## Out of Scope

- Convergence analysis or beta/sigma convergence claims.
- Scatter plots intended to imply relationships beyond the association matrix.
- Causal analysis, regression, prediction, significance testing, or confidence
  inference.
- Clustering, custom user-defined groups, or invented classifications.
- Modifications to the external `spiR` repository.
- Active-session automatic refresh.
- Downloads or a separate data-export workflow.

## Completion Contract

### Outcome

The Trends & Progress tab is a namespaced, tested Golem module that provides
reproducible global and official-group trends, period changes, coverage,
pillar stability, and descriptive pillar associations from the normalized
`spiR`-first snapshot. Existing dashboard tabs remain functional, missing and
unavailable states are explicit, and documentation explains the methods and
limitations.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Required |
|---|---|---|---|
| V1 | Pure Trends helpers cover valid, empty, missing, and unsupported inputs | `test-trends-progress-data.R` | yes |
| V2 | Trends module responds to fixture controls and statuses | `test-trends-progress-module.R` | yes |
| V3 | Application wiring preserves existing tabs and provider preference | `test-app-integration.R` and diagnostics | yes |
| V4 | Full deterministic suite passes | `Rscript -e "testthat::test_dir('tests/testthat')"` | yes |
| V5 | Desktop/mobile browser smoke passes or limitation is recorded | Existing browser test artifact | yes |
| V6 | Documentation and visualization mapping match implementation | README, context, mapping review | yes |

### Constraints

| ID | Constraint | Check |
|---|---|---|
| C1 | Use `spiR` first and local fallback second | Provider wiring and fallback test |
| C2 | Keep raw provider schemas out of Shiny modules | Targeted search for direct raw-provider calls |
| C3 | Preserve `NA` and expose coverage | Pure helper tests and UI states |
| C4 | Use only official validated groupings | Group catalog tests and metadata contract |
| C5 | Keep claims descriptive, not causal | Labels, method notes, and docs |
| C6 | Do not modify external `spiR` | Git status/diff outside dashboard repository |

### Boundaries

- Allowed: official region, income, lending, administrative, and aggregate
  classifications when present and validated; descriptive summaries and
  coverage statistics.
- Out of scope: causal, predictive, inferential, convergence, clustering, and
  custom-group analyses.

### Iteration Policy

1. Implement and validate the normalized contract before building UI.
2. Repair failing tests in the same layer before expanding scope.
3. Treat unavailable provider operations as explicit section states.
4. Never solve missing data by zero imputation or silent filtering.
5. Run focused tests before the full suite and browser checks.
6. Record any browser or live-provider limitation without weakening deterministic
   acceptance criteria.

### Blocked-Stop Conditions

- Required official grouping metadata cannot be obtained from public `spiR`
  outputs or normalized fallback data.
- A stable normalized contract cannot be maintained without changing external
  `spiR`.
- Existing dashboard modules regress and the cause is outside this milestone's
  permitted files.
- Focused or full tests cannot run in the available R environment.
- Browser validation cannot be executed and no existing compatible smoke path
  is available.

## Handoff

After approval and saving, the next action should be either `/cg-work` to
implement the plan or `/cg-plan-review` to challenge the plan. The roadmap
currently contains only the completed Country Profile milestone; link or add
Milestone 5 through `@cg-roadmap` rather than editing `roadmap.json` directly.
