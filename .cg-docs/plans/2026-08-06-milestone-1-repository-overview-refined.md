---
date: 2026-08-06
title: "Milestone 1: Repository Setup and Global Overview (Refined)"
status: active
execution-report: "../work-reports/2026-08-06-milestone-1-repository-overview-refined.md"
scope: "Deep"
brainstorm: "../brainstorms/2026-08-06-spi-shiny-dashboard.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
completed-phases: [1]
current-phase: 2
phases: 3
artifact-schema-version: 1
tags: [spi, shiny, golem, overview, spiR, flourish, r, refined]
---

# Plan: Milestone 1: Repository Setup and Global Overview (Refined)

## Objective

Create a minimal, maintainable golem application foundation and implement the
Overview vertical slice for the public SPI dashboard. The result will isolate
data acquisition from Shiny modules, use `spiR` as the preferred provider with
an explicit local fallback during the transition, and expose stable interfaces
for later dashboard tabs.

Milestone 1 will use the existing Flourish map as a fixed 2024 visualization.
Dynamic Flourish updates for other years will be deferred to a later milestone
or iteration, while the R-based Overview summaries will use the shared reactive
year state.

## Context

The repository contains local R data-access functions under `functions/` and
visualization functions under `viz_functions/`, but no valid golem application
structure. The extensionless `App` artifact is not a valid R entry point and
requires an explicit final disposition. The existing Flourish implementation
is in `viz_functions/flourish_map.R`; it uses Flourish Live API visualization
`26427135`, replaces the `regions` dataset, and expects `Economy` and
`SPI.INDEX` fields.

The local data API exposes `spi_index()`, `spi_data()`, `spi_aggregates()`, and
`country_info()`. Existing visualization scripts mix package loading, relative
paths, data loading, and global objects. Milestone 1 will adapt only the
provider and Overview-related helpers; unrelated visualization files will stay
available for their future milestones.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Establish a minimal golem application structure. | Brainstorm / Milestone 1 |
| R2 | Keep data acquisition and normalization separate from Shiny UI modules. | Brainstorm decision |
| R3 | Prefer `spiR` and retain local functions as an explicit temporary fallback. | Plan review decision |
| R4 | Provide normalized index, indicator, country metadata, aggregate, and latest-year interfaces. | Brainstorm and plan review |
| R5 | Exclude countries with no data for the latest year with valid data. | User requirements |
| R6 | Preserve partial country coverage and groups with limited observations. | User requirements |
| R7 | Handle new years and upstream column-name changes in one adapter/schema layer. | Brainstorm requirements |
| R8 | Implement an English Overview that displays the latest year with valid data and R-based summaries. | User decision / Milestone 1 |
| R9 | Retain the required Flourish map using the existing 2024 visualization. | User and plan review decisions |
| R10 | Keep the app public without authentication and omit downloads. | User requirements |
| R11 | Work directly on `main` without creating branches. | User decision |

## Phase 1: Foundation and Data Contract

### 1. Inventory the repository and settle the golem boundary

- **Requirements**: R1, R2, R11
- **Files**: `App`, `functions/`, `viz_functions/`, new golem files
- **Details**: Confirm reusable provider and Overview helpers, classify the
  extensionless `App` file, and document the target golem ownership boundary.
  Do not scaffold future tab modules or migrate unrelated visualization files.
- **Test Scenarios**: clean root-session source loading; one documented app
  launch path; no implicit working-directory dependency in migrated code.
- **Tests**: repository structure check and clean-session source-loading test.
- **Acceptance criteria**: the final status of `App` is documented, and the
  README identifies exactly one canonical launch path.

### 2. Create the minimal golem application foundation

- **Requirements**: R1, R8, R10
- **Files**: `DESCRIPTION`, `NAMESPACE`, `R/`, `inst/`, `app.R`, golem config
- **Details**: Create the smallest valid golem app that launches in English and
  remains unauthenticated. Declare required Shiny/golem and Overview packages.
  Treat `spiR` as optional during the transition and document the provider
  fallback. Remove or retire `App` once its role is confirmed.
- **Test Scenarios**: clean-session app launch; package loads when `spiR` is
  absent but the local fallback is available.
- **Tests**: golem load/launch smoke test and dependency check.
- **Acceptance criteria**: the documented launch command starts the app shell
  without requiring files outside the repository.

### 3. Implement the shared SPI provider and normalization adapter

- **Requirements**: R2, R3, R4, R5, R6, R7
- **Files**: `R/spi_provider.R`, `R/spi_adapter.R`, `tests/testthat/`
- **Details**: Prefer `spiR::spi_index()`, `spiR::spi_data()`,
  `spiR::country_info()`, and `spiR::spi_aggregates()` when the package and
  required schemas are available. Otherwise use an explicit local fallback
  loader. Fail clearly if neither provider is usable. Normalize index, pillar,
  dimension, and indicator records, including indicator ID/label, pillar,
  dimension, country, year, scored value, optional raw value, missing values,
  and score scale. Expose both wide map/chart-ready data and a long analytical
  indicator interface. Use official aggregate rows for regional summaries and
  available country observations for income-group summaries.
- **Test Scenarios**: provider selection; missing-year countries excluded;
  partial indicator rows preserved; limited groups preserved; upstream aliases
  normalized; official aggregate rows selected.
- **Tests**: deterministic fixture-based adapter and provider capability tests.
- **Acceptance criteria**: Overview modules consume normalized objects only and
  contain no direct provider loading or schema interpretation.

### 4. Organize only Overview-related functions and dependencies

- **Requirements**: R1, R2, R3, R7
- **Files**: Overview-related files under `functions/` and `viz_functions/`,
  `DESCRIPTION`, dependency manifest, documentation
- **Details**: Wrap or move only provider and Overview helpers into the golem
  ownership model. Remove runtime package installation and fragile relative
  path discovery from migrated code. Keep the remaining visualization scripts
  unchanged as future milestone inputs. Document `spiR` as the preferred
  optional provider and the local fallback transition.
- **Test Scenarios**: clean checkout with declared dependencies; no runtime
  package installation; migrated data loading works from the app launch path.
- **Tests**: dependency load check and source-loading test.
- **Acceptance criteria**: contributors can identify provider, adapter,
  Overview helper, and app-module ownership without migrating unrelated tabs.

## Phase 2: Overview Implementation

### 5. Build shared Overview state and latest-year display

- **Requirements**: R4, R5, R6, R8
- **Files**: `R/mod_overview.R`, shared UI/server modules, Overview tests
- **Details**: Implement the English Overview with one shared reactive
  snapshot and derive the latest year with valid index data from the adapter.
  Do not add a functional year selector in this milestone. Use the latest year
  for all R-based summaries and preserve the explicit fixed-2024 scope of the
  Flourish map.
- **Test Scenarios**: the latest year is derived from valid index data;
  countries without latest-year data disappear; limited group observations
  remain.
- **Tests**: `shiny::testServer()` tests for state and filters.
- **Acceptance criteria**: all R Overview outputs use one shared data snapshot
  and the latest valid year, while the map clearly identifies its fixed 2024
  scope.

### 6. Integrate the existing Flourish 2024 map

- **Requirements**: R2, R4, R5, R9
- **Files**: `viz_functions/flourish_map.R`, `R/mod_overview_map.R`, Flourish
  configuration/resources, documentation
- **Details**: Extract the existing script's data shaping into a testable
  function that prepares the 2024 `regions` payload with `Economy` and
  `SPI.INDEX`. Preserve visualization `26427135`, geometry, styling, and
  bindings. Keep provider calls outside UI code. Do not implement dynamic
  non-2024 updates in this milestone. Handle the Flourish API key through the
  approved deployment configuration and do not commit secrets.
- **Test Scenarios**: payload contains the expected fields and only valid 2024
  country records; missing values are handled; the map embed renders locally.
- **Tests**: map-payload unit test and local embed smoke test.
- **Acceptance criteria**: the required existing Flourish map renders SPI 2024
  data and can be updated without rewriting the provider adapter.

### 7. Implement the non-map Overview visualizations in R

- **Requirements**: R4, R5, R6, R8
- **Files**: `R/mod_overview_summary.R`, only the required Overview chart helpers
- **Details**: Implement the mockup's score distribution, average SPI by region,
  and average SPI by income group using R. Use normalized country/index data
  where appropriate and preserve the available country observations for income
  group summaries.
  Handle missing values explicitly and preserve World Bank styling without
  global data objects.
- **Test Scenarios**: valid latest-year charts render; empty subsets show a
  controlled empty state; partial scores do not become zeros; income summaries
  use available country observations.
- **Tests**: plot-data unit tests, `shiny::testServer()` output tests, and app
  smoke test.
- **Acceptance criteria**: all non-map Overview charts render from the shared
  reactive interface; regional summaries use supplied aggregate rows and income
  summaries use available country observations.

## Phase 3: Validation and Handoff

### 8. Add milestone tests, documentation, and reproducibility checks

- **Requirements**: R1, R2, R3, R4, R5, R6, R7, R8, R9, R10
- **Files**: `tests/`, `README.md`, dependency manifest, data-contract docs
- **Details**: Document setup, dependency installation, provider fallback,
  adapter contract, 2024 Flourish configuration, Overview launch, test
  commands, and the maintainer procedure for future years/schema changes.
  Keep ordinary tests offline and deterministic.
- **Test Scenarios**: clean setup; offline fixtures; optional live provider
  smoke test when dependencies are available.
- **Tests**: testthat suite, package/load check, documented launch command.
- **Acceptance criteria**: another contributor can install, test, launch, and
  understand how to update the adapter and map configuration.

### 9. Run the final Milestone 1 acceptance gate

- **Requirements**: R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11
- **Files**: all Milestone 1 files; `.cg-docs/work-reports/` during execution
- **Details**: Run the complete validation surface, inspect the Overview at the
  documented launch path, verify the 2024 Flourish map, verify no later tab was
  silently implemented, and record evidence for every contract row.
- **Test Scenarios**: clean launch, R summary year update, missing/partial data,
  official aggregates, and 2024 Flourish payload.
- **Tests**: full testthat suite, package validation, local Shiny smoke test.
- **Acceptance criteria**: all required evidence passes or is explicitly
  accepted under the `ask` deviation policy.

## Testing Strategy

- Use deterministic local fixtures for provider, schema, missing-data,
  partial-coverage, and aggregate scenarios.
- Test the provider adapter separately from Shiny modules.
- Use `shiny::testServer()` for latest-year state and Overview server logic.
- Test the Flourish 2024 payload independently from the embed layer.
- Isolate optional live GitHub/Flourish checks from ordinary offline tests.
- Run package-level checks after foundation work and at final acceptance.

## Documentation Checklist

- [ ] Setup and dependency installation.
- [ ] `spiR` preferred-provider and local fallback behavior.
- [ ] Normalized index and indicator data contract.
- [ ] Aggregate source and missing-data behavior, including the distinction
  between official regional rows and country-derived income summaries.
- [ ] Fixed 2024 Flourish map configuration and API-key handling.
- [ ] Overview launch and validation commands.
- [ ] Future procedure for dynamic Flourish years and upstream schema changes.
- [ ] Final disposition of the `App` artifact.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `shiny`/`golem` are absent from the current R environment. | Install and verify dependencies before implementation; document versions. |
| `spiR` is not yet available in the environment. | Use tested capability detection and an explicit local fallback. |
| `spiR` schema evolves. | Centralize aliases and normalization with fixtures. |
| Existing helpers assume globals or working-directory paths. | Migrate only Overview helpers behind explicit inputs and resource resolution. |
| Flourish API credentials are exposed. | Keep secrets out of source and use deployment configuration; fixed 2024 payload limits integration scope. |
| Official aggregate semantics are bypassed. | Use `spiR` aggregate rows and assert their source in tests. |
| Milestone expands into later tabs. | Keep unrelated visualization files out of the migration boundary. |
| Invalid `App` file confuses launch tooling. | Settle its disposition and document one canonical launch command. |

## Out of Scope

- Dynamic Flourish updates for years other than 2024.
- Country Explorer, Country Profile, Compare Countries, Trends and Progress,
  Explore by Pillar, and Data and Downloads.
- Migration of unrelated visualization files.
- Custom weighting, downloads, authentication, multilingual support, and
  production deployment.
- Wholesale copying of `InnovationHubDashboard`.

## Completion Contract

### Outcome

Milestone 1 leaves a valid golem application with a documented shared SPI data
contract and an English Overview vertical slice. The Overview uses the
existing Flourish map for 2024, R-based summaries driven by shared reactive
data, `spiR` with a local fallback, and official aggregate rows.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | Minimal golem structure loads from a clean R session. | Package/load check and launch smoke test | yes |
| V2 | 1 | Dependencies and provider fallback are reproducible. | Dependency manifest and provider tests | yes |
| V3 | 1 | Adapter returns normalized index, indicators, metadata, aggregates, and years. | Fixture-based adapter tests | yes |
| V4 | 1 | Missing-year countries are excluded while partial and limited group data remain. | Data-contract tests | yes |
| V5 | 2 | Overview renders in English with shared state; map is clearly fixed to 2024. | `shiny::testServer()` and app smoke test | yes |
| V6 | 2 | R summaries consume shared data and official aggregate rows. | Plot-data and server tests | yes |
| V7 | 2 | Existing Flourish map renders the 2024 payload. | Map-payload test and embed smoke test | yes |
| V8 | 3 | Only Overview-related functions are reorganized. | Structure review and source-loading test | yes |
| V9 | final | Milestone acceptance checklist is complete. | Full tests, package validation, documented launch | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | 1 | Work remains on `main`. | `git branch --show-current` |
| C2 | 1 | Project artifacts and UI text are English. | Source/UI review |
| C3 | 1 | `spiR` is preferred and local functions are explicit fallback. | Provider tests |
| C4 | 1 | Data preparation is separate from UI modules. | Adapter/module review |
| C5 | 2 | Existing Flourish map is retained for 2024. | Map review |
| C6 | 2 | Dynamic Flourish years are deferred. | Scope review |
| C7 | 2 | Official `spiR` aggregate rows are used. | Aggregate-source test |
| C8 | 1 | Only Overview-related functions are migrated. | File-scope review |
| C9 | 1 | `App` has one documented final disposition. | README/launch review |

### Boundaries

- Allowed: golem foundation, provider/fallback adapter, normalized indicator
  interface, Overview controls, 2024 Flourish map, R summary charts, tests,
  fixtures, dependencies, and documentation.
- Out of scope: dynamic non-2024 Flourish updates, later tabs, unrelated
  visualization migration, downloads, custom weighting, authentication,
  multilingual support, and production deployment.

### Iteration Policy

1. Preserve Approach 2 and implement only the Overview vertical slice.
2. Reuse the existing Flourish map and configuration rather than replacing it.
3. Prefer `spiR`; use local functions only through a tested fallback.
4. Use official aggregate rows instead of recomputing group averages.
5. Update the adapter and tests before changing UI modules for schema changes.
6. Pause for user approval before architectural deviation.
7. Preserve the original plan and record execution evidence in the work report.

### Blocked-Stop Conditions

- Required R dependencies cannot be installed or loaded.
- Neither `spiR` nor the local fallback provides the required data.
- The existing Flourish map cannot render its 2024 payload.
- Flourish credentials cannot be handled through acceptable deployment config.
- Required validation cannot run reproducibly.
- A protected project boundary must be crossed.
- A required deviation is discovered under `deviation-policy: ask`.
- Evidence would have to be marked passed from static inspection only.