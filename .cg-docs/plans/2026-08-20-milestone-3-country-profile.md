---
date: 2026-08-20
title: "Milestone 3: Modular single-country Country Profile (Revised)"
status: active
scope: "Deep"
brainstorm: "../brainstorms/2026-08-20-milestone-3-country-profile.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
tags: [spi, shiny, golem, country-profile, spiR, provider-adapter, navigation, modular-visualizations, trends, pillars, dimensions, indicators, benchmarks, testing, revised]
phases: 4
---

# Plan: Milestone 3: Modular Single-country Country Profile

## Objective

Implement Country Profile as a Golem-compatible, single-country analytical
surface. A user selects a country directly from the Country Profile tab. The
profile owns its country and year state, reuses the existing `spiR`
provider/fallback boundary, and renders
score, trend, pillar, dimension, indicator, strength/improvement, and benchmark
sections independently.

The first viewport should provide a clear overview for non-specialists while
progressive disclosure exposes detail for World Bank teams and researchers.
Comparison between two or more countries remains a later tab/milestone.

This revised plan treats the local development source of `spiR` as the
provisional future API. The implementation must validate the actual sibling
checkout with `devtools::load_all()` before wiring the provider. Functions
present only in a declaration or unavailable in the loaded checkout are not
treated as supported.

## Context

Milestone 2 completed the normalized all-years provider contract, local Country
Explorer filtering, injectable snapshot loaders, independent Explorer state,
DT table behavior, and deterministic/browser validation. The current app still
renders Country Profile as a placeholder. `R/spi_provider.R` owns provider
selection and safe operation status; `R/spi_adapter.R` owns aliases and
normalized schemas; the Country Explorer module demonstrates the existing Golem
module and loader-injection pattern.

The approved brainstorm selects a modular single-country profile with
progressive disclosure. The mockup supplies the initial visual direction:
country header, overall score, pillar performance, score over time, strongest
dimensions, areas for improvement, and peer/reference context. The plan treats
those as independently testable sections rather than a monolithic render path.

The project charter still lists Milestone 2 as Current Focus. This plan does
not modify the charter; after approval of the implementation plan, the project
owner should decide whether to update that field to Milestone 3.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Implement Country Profile as an independent Golem module for one country. | Approved Milestone 3 brainstorm |
| R2 | Allow direct country selection in Country Profile; Country Explorer does not open or select a Country Profile country. | Revised Milestone 3 scope |
| R3 | Give Profile independent country and year state; do not mutate Overview or Country Explorer state. | Approved navigation decision |
| R4 | Preserve `spiR` as primary provider and the local provider as fallback. | Project charter / Milestone 2 contract |
| R5 | Keep raw provider interpretation and schema normalization in the provider/adapter boundary. | Project context / Milestone 2 solution |
| R6 | Provide normalized country header and overall score data for the selected year. | Mockup / brainstorm |
| R7 | Provide an overall time-series view with valid-year and missing-data behavior. | Mockup / brainstorm |
| R8 | Provide pillar performance, dimension detail, and indicator detail. | Mockup / brainstorm |
| R9 | Provide reproducible strongest-dimension and improvement-area outputs without unsupported ranking claims. | Approved analytical scope |
| R10 | Provide region and income-group values as contextual benchmarks only. | Approved single-country scope |
| R11 | Isolate loading, unavailable, empty, partial, and error states by visualization section. | Approved architecture decision |
| R12 | Preserve `NA` as missing and never silently convert it to zero. | Project domain rule |
| R13 | Use deterministic fixtures, Golem module tests, integration tests, and browser smoke validation. | Milestone 2 evidence pattern |
| R14 | Document the new navigation and Country Profile data behavior. | Dashboard handoff requirement |

## Phase 1: Profile data contract and provider boundary

### 1. Inspect and freeze the real source contract

- **Requirements**: R4, R5, R6, R7, R8, R10
- **Files**: `R/spi_provider.R`, `R/spi_adapter.R`, `R/country_explorer_data.R`, `R/country_explorer_helpers.R`, `dev/run_dev.R`, local `spiR` source only for read-only inspection if available
- **Details**: Validate the provisional development API against the actual sibling checkout before implementation. Use `devtools::load_all(Sys.getenv("SPIR_PATH", unset = file.path(getwd(), "..", "spiR")), quiet = TRUE)`, then verify each operation with `getNamespaceExports()`, `exists(..., envir = asNamespace("spiR"), inherits = FALSE)`, `formals()`, and one controlled representative call. Record the loaded source path and branch/commit in the execution report. The verified source mirror contains `spi_versions()`, `spi_get()`, `spi_data()`, `spi_index()`, `spi_aggregates()`, `spi_indicator()`, `country_info()`, `metadata()`, `metadata_pillars()`, `metadata_dimensions()`, `spi_clear_cache()`, `spi_update_inventory()`, and `spi_clear_inventory()`. The dashboard must classify every operation as `available`, `provisional`, `fallback-supported`, or `unavailable` based on the loaded checkout and representative call. Do not change the external `spiR` repository. Record unsupported fields as explicit unavailable states instead of inventing upstream calculations.
- **Profile section contract**:

	| Profile section | `spiR` source | Required normalized inputs | Unavailable behavior |
	|---|---|---|---|
	| Header and country context | `country_info()` plus `metadata_*()` | `country_code`, country label, year, region, income group, lending type, population | Header remains visible with available identity fields; missing context is rendered as `-` |
	| Overall score and coverage | `spi_index()` | country-year overall score and valid-year keys | `empty` when no country rows exist; missing score remains missing |
	| Overall trend | `spi_index()` | country-year overall series | `empty` or `partial` according to the status contract; no zero imputation |
	| Pillar performance | `spi_index()` plus `metadata_pillars()` | pillar IDs, labels, scores, order | Section-level `unavailable` or `empty` |
	| Dimensions | `spi_data()` plus `metadata_dimensions()` | dimension IDs, labels, scores, pillar IDs | Section-level `unavailable` or `empty` |
	| Indicators | `spi_data()` or `spi_indicator()` plus `metadata()` | indicator IDs, labels, values, dimensions | Section-level `unavailable` or `empty` |
	| Strengths and improvement areas | normalized pillar/dimension values from `spi_index()`/`spi_data()` | selected-year candidates, coverage, deterministic ordering | `unavailable` when the required candidate level is unsupported |
	| Region and income benchmarks | `spi_aggregates()` plus `country_info()` | benchmark type, group code/label, year, score | Each benchmark is independently `unavailable` when its official aggregate is absent |

	`spi_get()` is the low-level source contract and may be used by the provider
	implementation where a higher-level wrapper does not expose the required
	filter. The `spi_plot_*()` functions are not a Profile dependency: the
	verified source mirror does not currently provide the listed plotting API,
	and Profile must render from normalized data so the fallback and deterministic
	fixtures remain supported. Existing dashboard visualization helpers or
	future upstream plotting functions may inform visual conventions, but they
	must not be called directly from Shiny code or bypass the provider/adapter
	boundary. `spi_clear_cache()` may support an explicit provider refresh.
	Inventory operations remain maintenance-only and must not run in the normal
	Profile load path; the unimplemented tree crawler must not be treated as a
	Profile dependency.
- **Test Scenarios**: profile-required fields present; optional fields absent; malformed provider response; provider operation error; local fallback response; direct pillar/dimension columns and indicator-derived fallback where the existing contract permits it; region and income aggregate rows classified separately; loaded source versus installed namespace; incompatible operation signatures.
- **Tests**: Add a provider-contract test that loads the configured development checkout, verifies presence and `formals()` for each supported operation, and records representative-call status without making ordinary tests depend on live network data. Keep deterministic data tests fixture-backed and offline.
- **Acceptance criteria**: The plan for each profile section names its normalized input and unavailable behavior, no UI code depends on raw provider column names, and the actual development checkout has a recorded API verification result.

### 2. Define profile-specific normalized objects and safe operation states

- **Requirements**: R5, R6, R7, R8, R9, R10, R11, R12
- **Files**: New `R/country_profile_data.R`; possibly targeted additions to `R/spi_adapter.R` and `R/spi_provider.R`; new `tests/testthat/test-country-profile-data.R`
- **Details**: Add pure preparation functions that select one country across available years and produce stable objects for: header, overall series, pillar scores, dimension scores, indicator details, strengths/improvement candidates, and regional/income benchmarks. Preserve country-year keys and technical IDs even when the overall score is `NA`; compute valid years separately for each requested metric. Define a common section result contract `list(data, status, message, coverage, source)` with statuses `pending`, `ok`, `partial`, `empty`, `unavailable`, and `error`. `pending` is produced before a loader result exists; `unavailable` means the operation is absent or unsupported; `error` means the operation or normalization failed; `empty` means a supported operation returned no matching rows; and `partial` means the section has rows but incomplete requested coverage. Keep optional operation failures local to their sections while retaining available pillar/dimension data when overall is missing.
- **Test Scenarios**: valid country/year; unknown country; year without score; explicit overall `NA` with valid pillar/dimension values; duplicate country-year rows; partial pillar/dimension/indicator coverage; missing metadata; missing benchmark; conflicting or duplicate metadata; no prior year; one available observation; all optional operations unavailable; mandatory index failure.
- **Tests**: Pure deterministic fixtures in `test-country-profile-data.R`; extend adapter/provider tests only for shared schema behavior.
- **Acceptance criteria**: Profile data preparation is Shiny-independent, deterministic, schema-stable, and returns a usable status for every section.

## Phase 2: Pure analytical helpers and visualization contracts

### 3. Implement country selection, year selection, and summary helpers

- **Requirements**: R2, R3, R6, R7, R9, R10, R12
- **Files**: New `R/country_profile_helpers.R`; new `tests/testthat/test-country-profile-helpers.R`
- **Details**: Implement direct country lookup and country choices from normalized metadata/index data. Initialize the profile year to the latest valid year to display for the selected country, allow earlier valid years, and preserve the selected country when the year changes. Add helpers for overall score/change, country coverage, benchmark labels, and stable display values. Ensure missing values remain missing and summary text does not imply change when no valid prior observation exists. Country Explorer is not a source of Profile selection or navigation state.
- **Test Scenarios**: default/latest year; direct country change; invalid country; year with no score; no prior year; partial metadata; missing benchmark; display rounding and `-` behavior.
- **Tests**: Pure helper tests with deterministic fixtures.
- **Acceptance criteria**: Country/year state decisions are deterministic and independent from Shiny session state.

### 4. Implement independent section transforms for trends, pillars, details, strengths, and benchmarks

- **Requirements**: R7, R8, R9, R10, R11, R12
- **Files**: `R/country_profile_helpers.R`; `tests/testthat/test-country-profile-helpers.R`
- **Details**: Create one pure transform per visualization/content section. The trend transform returns valid country-year values and an optional reference series. Pillar and dimension transforms preserve stable IDs/labels and missing scores. Indicator detail supports controlled selection or a readable long/table view without becoming Country Explorer. Strengths and improvement areas use a frozen within-country rule: candidates are dimensions for the selected year, a candidate must have a non-missing score and meet the configured coverage threshold across available observations, results are ordered by score and then technical ID, and the UI displays at most three highest and three lowest observed candidates. Display these as “highest observed dimensions” and “lowest observed dimensions under the coverage rule”, not causal strengths, weaknesses, or global rankings. Benchmark transforms return country, region, and income reference values as separate official-reference series.
- **Test Scenarios**: complete and partial series; explicit overall `NA` with valid lower-level values; direct versus derived pillar values; missing labels with technical-ID fallback; no dimensions; tied values; sparse coverage below threshold; all missing values; benchmark unavailable; region/income misclassification; section-specific errors.
- **Tests**: Pure helper tests asserting exact columns, ordering, values, and statuses.
- **Acceptance criteria**: Each section can be tested and consumed independently, and one empty/error result does not change the other section outputs.

## Phase 3: Golem module, navigation, and application integration

### 5. Build the Country Profile module shell and independent outputs

- **Requirements**: R1, R3, R6, R7, R8, R9, R10, R11, R12
- **Files**: New `R/mod_country_profile.R`; `R/app_ui.R`; existing stylesheet block in `R/app_ui.R` only as needed; new `tests/testthat/test-country-profile-module.R`
- **Details**: Create namespaced module UI/server following the Country Explorer pattern. Add direct country selector, profile year selector, country header, overall score, section containers, and section-level status outputs. Use independent reactives/renderers for the header, trend, pillars, dimensions/indicators, strengths/improvements, and benchmark sections. Render from injected normalized section results; do not call `spiR::spi_plot_*()` or raw provider functions from UI code. Use existing project visualization conventions and namespace-qualified calls. Keep the initial layout readable on desktop and narrow screens; use stable dimensions for plot areas and avoid nested UI failures.
- **Test Scenarios**: default country/year; direct country selection; year change; all sections valid; one section unavailable; no country; no year; missing values; module inactive until Profile tab is selected if lazy loading is used.
- **Tests**: `shiny::testServer()` with fixtures; assert section outputs/status independently and verify no provider call is made from UI code.
- **Acceptance criteria**: The module renders a single-country profile from an injected normalized loader and exposes independent section state without raw provider calls.

### 6. Register Profile navigation and preserve module independence

- **Requirements**: R2, R3, R14
- **Files**: `R/app_ui.R`, `R/app_server.R`, `R/mod_country_explorer.R`, `R/mod_country_profile.R`; new or extended `tests/testthat/test-app-integration.R` and `tests/testthat/test-country-explorer-module.R`
- **Details**: Replace the Country Profile placeholder and register the module. Profile owns a direct country selector and its own year state. Do not add a Country Explorer-to-Profile handoff, row action, navigation bridge, or shared selection state. Update the existing Explorer prompt so it does not promise Profile navigation. Preserve Country Explorer as an independent exploration surface and keep Overview, Explorer, and Profile state isolated. The existing top-level tab navigation is sufficient; do not introduce a routing dependency.
- **Test Scenarios**: direct Profile country selection; selected country absent; switching tabs; Profile year change leaves Explorer and Overview state unchanged; placeholder Compare tab remains unchanged.
- **Tests**: Fixture-backed app integration and module tests; app object smoke test.
- **Acceptance criteria**: Profile can be opened through the existing tab navigation and selects its country independently; Explorer behavior remains unchanged and has no Profile navigation contract.

## Phase 4: Verification, documentation, and handoff evidence

### 7. Add full regression, browser, and responsive validation

- **Requirements**: R1, R2, R3, R11, R13
- **Files**: `tests/testthat/`; browser smoke artifact or test harness used by the repository; `.cg-docs/work-reports/` if an execution report is produced
- **Details**: Run focused data/helper/module tests after each phase, then the complete deterministic suite. Launch the fixture-backed Golem app and verify direct Profile selection, year change, section rendering, local empty/error state, missing-value display, and tab navigation. Run desktop and narrow viewport checks for overflow, stable plot sizing, readable headers, and independent section layout using the repository's established browser harness if present; otherwise add a named browser smoke artifact and command before claiming V10. Start the local app with the configured development `spiR` only as a smoke check; do not infer schema correctness from a live recalculating state when fixtures can verify the contract.
- **Test Scenarios**: clean fixture launch; live-provider/fallback startup; unknown country; missing section; narrow viewport; tab switching; reload/direct selection if a deep link is implemented.
- **Tests**: `tests/testthat/`; full `testthat` suite; `get_errors` on touched R/test files; browser smoke checks at desktop and approximately 390px; package/load smoke as used in Milestone 2.
- **Commands**: `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` plus the repository's browser and app smoke commands.
- **Acceptance criteria**: The full suite passes without regressions, the browser path is usable at both target widths, and all required verification IDs have recorded evidence.

### 8. Document Country Profile behavior and update project handoff artifacts

- **Requirements**: R2, R4, R5, R11, R13, R14
- **Files**: `README.md`; `.cg-docs/work-reports/` if produced; `compound-gpid.md` only through a separately approved charter update, not as part of implementation
- **Details**: Document direct Profile country selection, the single-country boundary, independent year state, provider/fallback behavior, the verified/provisional `spiR` function-to-section contract, benchmark interpretation, missing/unavailable states, visual independence, testing commands, and explicit exclusions. Update the existing Explorer prompt and README so neither promises Profile handoff. Record the configured `spiR` source path and branch/commit where available. Record live-provider limitations without presenting them as confirmed data errors. Do not document Explorer handoff or country comparison as part of this milestone.
- **Test Scenarios**: README examples match the actual launcher and navigation; no out-of-scope feature is presented as implemented.
- **Tests**: Markdown/link validation if available; manual review against the completion contract.
- **Acceptance criteria**: Another contributor can launch, navigate to, test, and understand Country Profile without reading provider internals.

## Testing Strategy

- Keep provider selection and raw-schema interpretation in `R/spi_provider.R` and `R/spi_adapter.R`.
- Test profile data and transforms as pure functions before testing Shiny behavior.
- Use injected all-years fixtures for deterministic country/year and partial-data scenarios.
- Use `shiny::testServer()` for module state, section isolation, and direct Profile navigation.
- Use fixture-backed app integration to prove Profile and Explorer state separation.
- Use browser smoke checks for tab navigation, direct selection, missing-value display, absence of Explorer handoff, and responsive layout.
- Keep live `spiR` calls and credentials out of ordinary tests.
- Run the complete suite after integration and verify existing Overview/Country Explorer tests remain green.

## Documentation Checklist

- [ ] Country Profile is a single-country analytical view.
- [ ] Direct country selection in Country Profile.
- [ ] Independent Profile country and year state.
- [ ] Header and overall score.
- [ ] Overall time series and valid-year behavior.
- [ ] Pillars, dimensions, and indicators.
- [ ] Strengths and improvement-area rule.
- [ ] Region and income-group benchmarks as context, not filters.
- [ ] Missing, partial, empty, unavailable, and error behavior.
- [ ] Independent visualization contracts.
- [ ] `spiR` provider and local fallback.
- [ ] Deterministic, module, integration, and browser tests.
- [ ] Responsive layout verification.
- [ ] Explicit exclusions: comparison tab, multi-country comparison, downloads, weighting, new maps, and external `spiR` changes.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| The live `spiR` schema lacks a field needed by the mockup. | Inspect the real contract first; represent unsupported sections as unavailable and avoid inventing provider calculations. |
| Profile becomes a second Country Explorer. | Keep one country as the only subject; use detail selectors/sections rather than a multi-country table or broad filters. |
| One failing visualization blocks the page. | Use section-specific data objects, reactives, statuses, and tests. |
| Profile selection couples module state or breaks tab navigation. | Keep Profile selection local to its module and test state isolation explicitly. |
| Strengths/improvement labels imply unsupported rankings. | Define a coverage-aware within-country rule and document it; avoid global rank claims. |
| Partial year or indicator coverage produces misleading trends. | Preserve missing values, expose coverage, and require valid observations for change calculations. |
| Profile snapshot loading is slow. | Load the normalized snapshot once per active profile session, cache within the module, and measure fixture/live startup before optimizing. |
| Development `spiR` source differs from the installed package. | Load the configured sibling with `devtools::load_all()`, verify exports, signatures, and representative calls, and record the source commit before provider wiring. |
| New plotting dependencies increase installation risk. | Prefer existing base R/project dependencies; validate any dependency in a clean environment before adding it. |
| Responsive CSS causes overlap or unstable plot sizes. | Use stable plot dimensions, narrow viewport browser checks, and focused CSS changes. |
| Scope expands into comparison, downloads, or weighting. | Enforce the out-of-scope list and stop for a decision when a requirement crosses the boundary. |

## Out of Scope

- Comparing two or more countries.
- The Compare Countries tab or comparison workflow.
- Downloads, exports, or citation packages.
- Custom weighting or ranking tools.
- New maps or geospatial analysis.
- Production deployment changes.
- Changes to the external `spiR` repository.
- Unvalidated global rankings or claims that a country is best or worst.

## Completion Contract

### Outcome

A user can open Country Profile from the existing tab navigation, select one country directly in Profile, choose a valid profile year, and view an independently rendered country analysis with clear states for missing or unavailable sections. Existing Overview and Country Explorer behavior remains intact, and no country comparison is implemented in this milestone.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|----|---:|---|---|---|
| V1 | 1 | Profile-specific normalized objects and statuses | `test-country-profile-data.R` | yes |
| V2 | 1 | Shared provider/fallback contract preserved and development `spiR` API verified | Provider/adapter contract tests and source-load report | yes |
| V3 | 2 | Pure transforms for all profile sections | `test-country-profile-helpers.R` | yes |
| V4 | 2 | Missing/partial/benchmark behavior is deterministic | Helper fixture assertions | yes |
| V5 | 3 | Country Profile module renders from injected data | `test-country-profile-module.R` | yes |
| V6 | 3 | Direct Profile selection works through the existing tab navigation | `test-app-integration.R` | yes |
| V7 | 3 | Profile state does not mutate Overview or Explorer | Integration assertions | yes |
| V8 | 3 | Section errors remain isolated | Module status assertions | yes |
| V9 | 4 | Complete deterministic test suite passes | `Rscript --vanilla -e "testthat::test_dir('tests/testthat')"` | yes |
| V10 | 4 | Browser navigation and responsive layout pass | Named browser smoke artifact and command | yes |
| V11 | 4 | Golem/fixture launch succeeds | Local launcher/app smoke | yes |
| V12 | 4 | Documentation and changed-file boundary are correct | README and git review | yes |

### Constraints

| ID | Constraint | Check |
|---|---|---|
| C1 | `spiR` remains preferred; local fallback remains available | Provider tests and app smoke |
| C2 | External `spiR` repository is untouched | Changed-file review |
| C3 | Raw provider interpretation stays under provider/adapter boundary | Code review |
| C4 | Profile contains one country only | UI and integration tests |
| C5 | No comparison tab/workflow in this milestone | Scope review |
| C6 | Missing values remain missing | Fixtures and browser display |
| C7 | Visualizations fail independently | Module tests |
| C8 | Existing Overview/Explorer behavior does not regress | Full test suite |

### Boundaries

- Allowed: new Country Profile data/helpers/module files, targeted provider/adapter extensions for shared normalized contracts, app registration, direct country selection, documentation, and tests.
- Out of scope: multi-country comparison, comparison tab, downloads, weighting, new maps, production changes, and external `spiR` edits.

### Iteration Policy

1. Resolve real provider schema questions before writing UI assumptions.
2. Implement one pure section contract at a time and run its focused tests.
3. Connect sections to the module only after their pure transforms are stable.
4. Validate direct Profile selection and tab navigation before adding visual polish.
5. Run the same focused check again after every repair before widening scope.
6. Record live-provider uncertainty rather than inferring a schema defect from a loading state.

### Blocked-Stop Conditions

- Required profile data cannot be represented by the actual provider/fallback contract.
- A navigation bridge would require a new routing dependency without approval.
- A required visualization dependency is unavailable and no existing alternative supports the contract.
- Integration causes regressions in Overview or Country Explorer.
- Completing a requirement requires modifying external `spiR`.

## Handoff Notes

The charter's Current Focus still names Milestone 2. Decide separately whether to update it to Milestone 3 before implementation begins. The repository's artifact-view contract file is absent from this checkout; use the available `cg-render-artifact` validation and report that limitation if it persists.
