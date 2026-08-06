---
date: 2026-08-06
title: "Milestone 1: Repository Setup and Global Overview"
status: active
scope: "Deep"
brainstorm: "../brainstorms/2026-08-06-spi-shiny-dashboard.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
phases: 3
artifact-schema-version: 1
tags: [spi, shiny, golem, overview, spiR, flourish, r]
---

# Plan: Milestone 1: Repository Setup and Global Overview

## Objective

Create a minimal, maintainable golem application foundation and implement the
Overview vertical slice for the public SPI dashboard. The result must isolate
data acquisition from Shiny modules, use `spiR` as the primary provider when
available, preserve the local functions as a temporary fallback, and expose a
stable data interface for later dashboard tabs.

## Context

The repository currently contains local R data-access functions under
`functions/` and visualization functions under `viz_functions/`, but no valid
golem application structure. The existing `App` artifact is not a valid R
entry point and must be assessed during foundation work rather than assumed to
be reusable.

The local data functions already expose useful provider operations including
`spi_index()`, `spi_aggregates()`, and `country_info()`. The visualization code
currently performs its own package loading, relative-path discovery, data
loading, and global object creation. Milestone 1 should introduce one
application-owned adapter boundary before connecting those visualizations to
Shiny.

The public mockup defines the Overview as a year-aware world view with an SPI
map, score distribution, regional summaries, and income-group summaries. The
map must use Flourish; non-map charts must use R.

No `compound-gpid.md`, `compound-gpid.local.md`, or `roadmap.json` currently
exists. This plan proceeds from the validated brainstorm and works directly on
`main` without creating branches.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Establish a minimal golem application structure. | Brainstorm / Milestone 1 |
| R2 | Keep data acquisition and normalization separate from Shiny UI modules. | Brainstorm decision |
| R3 | Use `spiR` as the primary provider and retain local functions as a temporary fallback. | Brainstorm requirements |
| R4 | Provide normalized index, country metadata, aggregate, year, and indicator interfaces. | Brainstorm devil's advocate |
| R5 | Exclude countries with no data for the selected year. | User requirements |
| R6 | Preserve countries with partial indicator coverage and groups with limited observations. | User requirements |
| R7 | Handle new years and upstream column-name changes in one adapter/schema layer. | Brainstorm requirements |
| R8 | Implement an English Overview with a shared year selector and core filters. | Mockup / Milestone 1 |
| R9 | Use Flourish for the Overview map and R for non-map visualizations. | User requirements |
| R10 | Keep the app public without authentication and omit downloads from this milestone. | User requirements |
| R11 | Work directly on `main` without creating branches. | User decision |

## Phase 1: Foundation and Data Contract

### 1. Inventory the repository and choose the golem boundary

- **Requirements**: R1, R2, R11
- **Files**: `App`, `functions/`, `viz_functions/`, new golem project files
- **Details**: Confirm the current file types, identify reusable exported and
  internal functions, classify the existing `App` artifact, and define the
  minimal golem layout needed for the Overview. Use the reference dashboard
  only for architectural patterns. Do not scaffold future tab modules yet.
- **Test Scenarios**: the repository can be loaded from its root; no source
  file depends on an implicit working directory after migration.
- **Tests**: repository structure check and clean-session source-loading test.
- **Acceptance criteria**: the target golem structure and ownership of each
  existing function are documented before implementation proceeds.

### 2. Create the minimal golem application foundation

- **Requirements**: R1, R8, R10
- **Files**: `DESCRIPTION`, `NAMESPACE`, `R/`, `inst/`, `app.R`, golem config
- **Details**: Create the smallest valid golem app that can launch a Shiny
  application in English. Add only dependencies required for the foundation
  and Overview. Keep the public app unauthenticated. Replace or retire the
  invalid `App` entry point only after its role is confirmed.
- **Test Scenarios**: app launches from a clean R session; missing optional
  local fallback does not prevent package loading when `spiR` is installed.
- **Tests**: golem load/launch smoke test and package dependency check.
- **Acceptance criteria**: a documented local launch command starts the app
  shell without requiring files outside the repository.

### 3. Implement the shared SPI provider and normalization adapter

- **Requirements**: R2, R3, R4, R5, R6, R7
- **Files**: `R/mod_spi_data.R` or equivalent adapter module, provider helpers,
  `tests/testthat/`
- **Details**: Define one application-owned interface for index scores,
  country metadata, and group aggregates. Prefer `spiR::spi_index()`,
  `spiR::country_info()`, and `spiR::spi_aggregates()` when available; source
  local functions only through an explicit fallback path. Normalize identifiers,
  years, score columns, missing-value sentinels, pillar names, and aggregate
  labels in this boundary. Derive available years and map-ready records from
  normalized data rather than hard-coding current years or column names.
- **Test Scenarios**: selected year excludes countries without a score;
  partial indicator coverage remains present; limited group observations remain
  present; a renamed upstream score column is mapped by the adapter contract.
- **Tests**: deterministic `testthat` fixtures for each scenario plus provider
  selection tests.
- **Acceptance criteria**: Overview modules consume normalized objects only and
  contain no direct `spiR` or local-function loading logic.

### 4. Organize existing functions and define reproducible dependencies

- **Requirements**: R1, R2, R3, R7
- **Files**: `functions/`, `viz_functions/`, `DESCRIPTION`, `renv.lock` or
  chosen dependency manifest, project documentation
- **Details**: Move or wrap reusable data and visualization functions into the
  golem ownership model without duplicating data downloads. Remove ad hoc
  package installation commands from runtime source. Replace fragile relative
  paths with package/project resource resolution. Document the temporary local
  fallback and the transition to the CRAN `spiR` release.
- **Test Scenarios**: clean checkout with declared dependencies; app source does
  not install packages; data loading works from the project root and launch
  entry point.
- **Tests**: dependency installation/load check and source-loading test.
- **Acceptance criteria**: a new contributor can identify where data access,
  normalization, visualization helpers, and app modules belong.

## Phase 2: Overview Implementation

### 5. Build the shared Overview state and controls

- **Requirements**: R4, R5, R6, R8
- **Files**: `R/mod_overview.R`, shared UI/server modules, Overview tests
- **Details**: Implement the global year selector and Overview filter state as
  shared reactive inputs. Populate choices from the adapter's available data,
  preserve valid defaults, and pass filtered normalized data to each Overview
  output. Keep English UI labels and make the controls stable for later tabs.
- **Test Scenarios**: changing year updates all Overview outputs; unavailable
  countries disappear; groups remain visible when observations are limited.
- **Tests**: `shiny::testServer()` tests for reactive state and filter outputs.
- **Acceptance criteria**: all Overview outputs use the same selected year and
  data snapshot.

### 6. Implement the Flourish map integration boundary

- **Requirements**: R8, R9
- **Files**: `R/mod_overview_map.R`, Flourish configuration/resource files,
  documentation
- **Details**: Prepare the map-ready country/year/index payload in the shared
  adapter and connect the Overview map to Flourish. Keep Flourish embedding or
  publication configuration separate from data normalization and do not place
  provider calls inside UI code. Define the expected country identifier,
  score, label, year, and no-data fields.
- **Test Scenarios**: selected year and index selection produce the expected
  map payload; countries with no selected-year score are omitted; map boundary
  configuration is reproducible.
- **Tests**: map-payload unit tests and Overview smoke test with a deterministic
  Flourish configuration fixture.
- **Acceptance criteria**: the Overview uses Flourish for the map and the
  integration can be updated without rewriting the adapter or other charts.

### 7. Implement non-map Overview visualizations in R

- **Requirements**: R8, R9
- **Files**: `R/mod_overview_summary.R`, adapted `viz_functions/` helpers
- **Details**: Implement the mockup's score distribution, average SPI by region,
  and average SPI by income group using R-based visualization functions. Use
  normalized data and explicit missing-value handling. Preserve consistent
  World Bank styling while avoiding global data objects.
- **Test Scenarios**: charts render for a valid year; empty subsets return a
  controlled empty state; partial scores do not silently become zeros.
- **Tests**: plot-data unit tests, `shiny::testServer()` output tests, and a
  local app smoke test.
- **Acceptance criteria**: all non-map Overview visualizations render from the
  shared reactive data interface.

## Phase 3: Validation and Handoff

### 8. Add milestone-level tests, documentation, and reproducibility checks

- **Requirements**: R1, R2, R3, R5, R6, R7, R8, R9, R10
- **Files**: `tests/`, `README.md`, dependency lock/manifest, data-contract
  documentation
- **Details**: Document setup, dependency installation, local fallback behavior,
  app launch, Flourish configuration, data refresh expectations, and the
  normalized adapter contract. Add deterministic fixtures so tests do not need
  live network access. Include a short maintainer checklist for new years or
  upstream schema changes.
- **Test Scenarios**: clean-environment setup; offline fixture tests; live
  provider smoke test when dependencies are available.
- **Tests**: testthat suite, package/load check, and documented launch command.
- **Acceptance criteria**: another contributor can install dependencies, run
  tests, launch the Overview, and understand how to update the data boundary.

### 9. Run the final Milestone 1 acceptance gate

- **Requirements**: R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11
- **Files**: all Milestone 1 files; `.cg-docs/work-reports/` during execution
- **Details**: Run the complete safe validation surface, inspect the Overview
  at the supported launch path, verify that no later milestone was silently
  implemented, and record evidence for each completion-contract row.
- **Test Scenarios**: clean-session launch, selected-year update, missing and
  partial data behavior, aggregate summaries, and Flourish map payload.
- **Tests**: full `testthat` suite, package validation, and local Shiny smoke
  test.
- **Acceptance criteria**: all required verification items pass or are
  explicitly accepted as exceptions under the `ask` deviation policy.

## Testing Strategy

- Use deterministic local fixtures for schema, missing-data, partial-coverage,
  and aggregate scenarios; do not make ordinary tests dependent on live GitHub
  or Flourish services.
- Test the provider adapter separately from Shiny modules.
- Use `shiny::testServer()` for shared reactive state and Overview server logic.
- Use a lightweight app launch smoke test for UI wiring and dependency loading.
- Run package-level checks after the golem foundation and again at the final
  acceptance gate.

## Documentation Checklist

- [ ] Project setup and dependency installation.
- [ ] Local `spiR` fallback and CRAN transition behavior.
- [ ] Normalized data contract and supported score fields.
- [ ] Year filtering and missing/partial data behavior.
- [ ] Flourish map configuration and expected payload.
- [ ] Overview launch and validation commands.
- [ ] Maintainer procedure for new years and upstream column changes.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `shiny`/`golem` are not installed in the current R environment. | Make environment setup an explicit prerequisite and verify package versions before implementation. |
| `spiR` column names evolve. | Centralize schema detection and normalization; cover aliases with fixtures. |
| Existing visualization helpers assume global objects or working-directory paths. | Wrap them behind module-owned inputs and replace path discovery with explicit resource resolution. |
| Flourish integration duplicates or bypasses the shared data contract. | Define and test a map-ready payload before connecting the embed/configuration. |
| Live network data makes tests flaky. | Use deterministic fixtures for ordinary tests and isolate optional live smoke checks. |
| The first milestone expands into later tabs. | Keep the seven-tab roadmap documented but enforce the Milestone 1 boundaries during implementation. |

## Out of Scope

- Country Explorer, Country Profile, Compare Countries, Trends and Progress,
  Explore by Pillar, and Data and Downloads.
- Custom weighting and later-tab-specific visualizations.
- CSV, Excel, and Stata download workflows.
- Authentication, multilingual support, and production deployment.
- A wholesale copy of `InnovationHubDashboard`.

## Completion Contract

### Outcome

Milestone 1 leaves a valid golem application with a documented shared SPI data
contract and a working English Overview vertical slice. The Overview uses a
shared year-aware reactive flow, Flourish for the map, and R for non-map
visualizations while remaining maintainable as `spiR` evolves.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|-------|-------------------|------------------|----------|
| V1 | 1 | Golem structure loads from a clean R session. | Package/load check and golem launch smoke test | yes |
| V2 | 1 | Dependencies and provider behavior are reproducible. | `DESCRIPTION` plus dependency/provider tests | yes |
| V3 | 1 | Adapter returns normalized index, metadata, aggregates, years, and indicators. | Focused `testthat` adapter tests | yes |
| V4 | 1 | Missing-year countries are excluded while partial and limited group data remain. | Fixture-based data-contract tests | yes |
| V5 | 2 | Overview renders in English with shared year and filter state. | `shiny::testServer()` and app smoke test | yes |
| V6 | 2 | Summary charts consume shared filtered data. | Overview server and plot-data tests | yes |
| V7 | 2 | Flourish map receives a reproducible map-ready payload. | Map payload tests and Overview smoke test | yes |
| V8 | 3 | Existing functions are organized behind reusable interfaces. | Structure review and source-loading test | yes |
| V9 | final | Milestone acceptance checklist is complete. | Full tests, package validation, and documented launch | yes |

### Constraints

| ID | Phase | Constraint | Check |
|----|-------|------------|-------|
| C1 | 1 | Work remains on `main`. | `git branch --show-current` |
| C2 | 1 | Project artifacts and UI text are English. | Source/UI review |
| C3 | 1 | `spiR` is primary; local functions are fallback only. | Provider-selection tests |
| C4 | 1 | Data preparation is separate from UI modules. | Adapter/module review |
| C5 | 2 | Map uses Flourish and non-map charts use R. | Overview implementation review |
| C6 | 2 | No auth or download formats are added. | Scope review |
| C7 | 1 | Upstream schema changes are handled in the adapter. | Alias/schema fixture tests |

### Boundaries

- Allowed: minimal golem foundation, adapter layer, Overview controls,
  Flourish map boundary, R summary charts, tests, and documentation.
- Out of scope: later mockup tabs, downloads, custom weighting, authentication,
  multilingual support, and production deployment.

### Iteration Policy

1. Preserve Approach 2 and validate each phase before starting the next.
2. Prefer existing `spiR` APIs and repository patterns over new abstractions.
3. Update the adapter and tests before changing UI modules for upstream schema
   changes.
4. Pause for user approval before any architectural deviation.
5. Record all deviations and evidence in the execution report.

### Blocked-Stop Conditions

- Required R dependencies cannot be installed or loaded.
- Required `spiR` data interfaces are unavailable or incompatible.
- Flourish cannot consume the defined map-ready payload without changing the
  approved architecture.
- Required validation cannot run through a safe reproducible R environment.
- A protected project boundary must be crossed.
- A required deviation is discovered under `deviation-policy: ask` and approval
  is unavailable.
- Required evidence would have to be marked passed from static inspection only.