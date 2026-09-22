---
date: 2026-09-20
title: "Milestone 6: Explore by Pillar and Custom Weighting (Revised)"
status: active
scope: "Deep"
brainstorm: ".cg-docs/brainstorms/2026-09-20-milestone-6-explore-by-pillar.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
execution-report: ".cg-docs/work-reports/2026-09-20-milestone-6-explore-by-pillar-revised.md"
phases: 4
completed-phases: [1, 2]
current-phase: 3
artifact-schema-version: 1
tags: [spi, shiny, golem, explore-by-pillar, custom-weighting, spiR, testing, revised]
---

# Plan: Milestone 6: Explore by Pillar and Custom Weighting

## Objective

After the project focus is explicitly synchronized to Milestone 6, deliver a
focused Explore by Pillar Golem module for one country and one year. The user
will adjust integer percentage weights for five SPI pillars, must provide an
exact 100% total, and will see an exploratory weighted score beside the
official SPI score and their difference. The custom result must remain clearly
distinct from the official SPI methodology.

## Context

The existing `pillar_explorer` module is registered in `R/mod_pillar_explorer.R`,
`R/app_ui.R`, and `R/app_server.R`, but currently only displays a pillar table.
It does not yet implement country selection, custom weights, score calculation,
missing-pillar handling, or final interpretation labels.

The shared provider boundary prefers `spiR`, normalizes overall and pillar
scores through `R/spi_provider.R` and `R/spi_adapter.R`, and supports lazy
detail loading. Existing tests use injected snapshots and `shiny::testServer`.
The browser pattern uses standalone `shinytest2` scripts at desktop and mobile
widths.

The approved brainstorm limits this milestone to direct manual weighting at
pillar level, one country, and one year. Weights start at 20% each, are integer
percentages from 0 to 100, and must sum exactly to 100. If a selected country
lacks one or more pillar scores, available scores are used and their weights
are renormalized. If available pillars have zero effective weight, the custom
result is unavailable. If the official SPI is missing, it remains unavailable
and is never converted to zero.

The charter currently names Milestone 5 as its focus and calls pillar
exploration future scope. That is now a pre-flight governance dependency: the
project owner must explicitly synchronize the charter focus through the
approved charter workflow before implementation begins. This plan does not
silently override the charter.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | Authorize Milestone 6 as the active project focus before implementation. | Plan review; charter |
| R2 | Verify a stable schema containing exactly five structural pillar scores. | Plan review; normalized provider contract |
| R3 | Provide a module for one country and one year. | Brainstorm |
| R4 | Expose one integer percentage weight for each of five pillars. | Brainstorm; plan review |
| R5 | Initialize all weights to 20% and provide reset. | Brainstorm |
| R6 | Require weights from 0 through 100 whose sum is exactly 100. | Brainstorm; plan review |
| R7 | Calculate from available pillar scores without converting `NA` to zero. | Brainstorm |
| R8 | Renormalize weights over available pillars and disclose coverage adjustment. | Brainstorm |
| R9 | Return unavailable when available effective weight is zero or no pillar score exists. | Plan review |
| R10 | Show official SPI, custom result, and difference as separate values. | Brainstorm |
| R11 | Define and test behavior when official SPI is missing. | Plan review |
| R12 | Keep calculations in pure R helpers outside Shiny. | Charter; Brain findings |
| R13 | Use the shared `spiR`-preferred snapshot and never modify external `spiR`. | Charter |
| R14 | Preserve lazy activation and injected snapshot support. | Existing architecture |
| R15 | Provide executable unit, module, integration, and browser evidence. | Completion contract |

## Implementation Steps

## Phase 1: Governance and structural data contract

### 1. Synchronize the project focus

- **Requirements**: R1
- **Files**: `compound-gpid.md`, `roadmap.json` through the approved workflow
- **Details**: Before implementation, confirm that Milestone 6 supersedes the
  current Milestone 5 focus. Update the charter only through the project
  workflow, and preserve Milestone 5's status and remaining validation work.
  Do not begin code implementation while this authorization is unresolved.
- **Test Scenarios**: authorized Milestone 6 focus; unresolved focus blocks
  implementation.
- **Tests**: Targeted charter and roadmap read.
- **Acceptance criteria**: The current focus and roadmap tell the same story,
  or an explicit owner decision records why Milestone 6 may proceed first.

### 2. Verify the five-pillar normalized schema

- **Requirements**: R2, R3, R4, R13, R14
- **Files**: `R/pillar_explorer_data.R` (new), `R/spi_adapter.R` only if a
  proven normalization gap exists, `tests/testthat/test-pillar-explorer-data.R` (new)
- **Details**: Define the structural contract separately from row-level
  missingness. Confirm the normalized snapshot exposes exactly five expected
  pillar score columns and stable pillar IDs/labels from `spiR::metadata()` or
  the normalized hierarchy. A structurally incomplete snapshot must return a
  controlled unavailable state rather than rendering five empty controls. Row-
  level `NA` values remain valid partial coverage and are handled later.
- **Test Scenarios**: five expected pillar columns; extra unrelated columns;
  fewer than five columns; malformed hierarchy; valid hierarchy labels;
  duplicate country-year rows already normalized; missing optional metadata.
- **Tests**: `testthat::test_file("tests/testthat/test-pillar-explorer-data.R")`
  with explicit `sys.source()` setup in an isolated environment.
- **Acceptance criteria**: The data layer distinguishes structural schema
  failure from a valid country row with missing pillar scores.

## Phase 2: Pure weighting and selection logic

### 3. Implement integer weight validation and pure calculation

- **Requirements**: R6, R7, R8, R9, R10, R12
- **Files**: `R/pillar_explorer_helpers.R` (new),
  `tests/testthat/test-pillar-explorer-helpers.R` (new)
- **Details**: Use integer percentage inputs in the closed interval 0–100.
  Validate `sum(weights) == 100L` exactly after integer coercion/validation;
  reject missing, non-finite, negative, decimal, non-numeric, and wrong-length
  inputs. Calculate with full numeric precision and round only display values.
  For available pillar scores, divide available weights by their effective
  total. If that total is zero, return `status = "unavailable"` with an
  explanatory message. Return official score, custom score, difference,
  available pillars, effective weights, coverage, and status in a stable list.
- **Test Scenarios**: equal weights; unequal valid weights; totals 99 and 101;
  decimal input; negative input; `NA`; `Inf`; zero-weight pillars; all
  available pillars weighted zero; one missing pillar; all pillars missing;
  missing official SPI; exact expected difference.
- **Tests**: `testthat::test_file("tests/testthat/test-pillar-explorer-helpers.R")`
  with functions loaded by `sys.source()` into a test environment.
- **Acceptance criteria**: No valid case returns `NaN` or `Inf`; no missing score
  becomes zero; invalid totals never produce a custom score.

### 4. Define country-year selection and official-score policy

- **Requirements**: R3, R7, R10, R11, R14
- **Files**: `R/pillar_explorer_data.R`,
  `tests/testthat/test-pillar-explorer-data.R`
- **Details**: Build country and year choices from normalized rows with at
  least one valid pillar score, not only from `spi_available_years()`. This
  keeps a country-year selectable when its official SPI is missing but pillar
  scores exist. Display official SPI as unavailable and suppress the
  difference in that case; the custom pillar result may still be shown with an
  explicit note. Rows with no valid pillar score are unavailable for custom
  analysis. Keep country-year identity deterministic.
- **Test Scenarios**: valid official and pillars; missing official with valid
  pillar; official valid with partial pillars; no valid pillars; multiple years.
- **Tests**: Extend `test-pillar-explorer-data.R` using isolated fixture
  environments.
- **Acceptance criteria**: Selection behavior is explicit and consistent with
  the displayed availability states.

## Phase 3: Golem module and application integration

### 5. Implement the focused weighting UI

- **Requirements**: R3, R4, R5, R6, R10, R14
- **Files**: `R/mod_pillar_explorer.R`, `R/app_ui.R` only for minimal shared
  styling if required, `tests/testthat/test-pillar-explorer-module.R` (new)
- **Details**: Replace the placeholder with namespaced country and year
  selectors, five integer weight controls, a visible exact total, reset-to-20%
  action, official/custom/difference outputs, and coverage/status text. Use
  unambiguous labels such as `Official SPI` and `User-weighted exploratory
  score`. Keep only pillar controls; do not add dimensions, indicators, or
  multi-country controls. Use existing packages and responsive CSS patterns.
- **Test Scenarios**: defaults; reset; invalid total; missing pillar notice;
  zero effective weight; missing official score; empty structural schema.
- **Tests**: `shiny::testServer` plus namespaced UI string assertions, with all
  module dependencies loaded explicitly by `sys.source()`.
- **Acceptance criteria**: The interface never presents an invalid custom score
  and makes official versus exploratory values visually and textually distinct.

### 6. Wire lazy state and integration

- **Requirements**: R3, R6, R8, R10, R13, R14
- **Files**: `R/mod_pillar_explorer.R`, `R/app_server.R` only if registration
  needs adjustment, `tests/testthat/test-pillar-explorer-module.R`,
  `tests/testthat/test-app-integration.R`
- **Details**: Load the shared detailed snapshot only when the tab activates,
  preserving the existing cache and loader injection. The requirement is
  activation deferral, not a new provider request with a reduced payload.
  Update choices reactively, pass selected row and weights to pure helpers,
  and render controlled loader, schema, validation, unavailable, and success
  states.
- **Test Scenarios**: inactive loader call count zero; activation loads once;
  shared cache is reused; country/year changes update values; invalid totals
  suppress custom output; partial coverage announces renormalization; loader
  error is controlled.
- **Tests**: Focused module tests and app integration fixture tests.
- **Acceptance criteria**: The normal app path works without network calls in
  fixtures, hidden tabs remain lazy, and existing modules are not regressed.

## Phase 4: Executable verification and documentation

### 7. Build complete fixtures and browser smoke

- **Requirements**: R2, R3, R5, R6, R8, R10, R11, R15
- **Files**: `tests/browser/fixture-app/app.R`,
  `tests/browser/pillar-explorer-smoke.R` (new), all focused test files
- **Details**: Extend the browser fixture explicitly with five pillar columns,
  stable labels, a complete row, a partial-coverage row, and a no-coverage
  row. Add the tab and loader path needed by the smoke test. Execute from the
  repository root with:
  `& "C:\\Program Files\\R\\R-4.5.3\\bin\\Rscript.exe" --vanilla tests/browser/pillar-explorer-smoke.R`
  (or the selected R installation path documented by the environment). The
  script must use `shinytest2::AppDriver`, wait for namespaced outputs, test
  defaults, invalid total, reset, partial coverage, and desktop/mobile sizes.
- **Test Scenarios**: complete valid workflow; invalid sum; reset; partial
  coverage; zero effective weight; missing official; 1280px and 390px.
- **Tests**: Focused testthat files, app integration, and the exact browser
  command above.
- **Acceptance criteria**: Browser evidence is reproducible from the project
  root and does not depend on live network data.

### 8. Document and close verification

- **Requirements**: R1, R6, R8, R10, R13, R15
- **Files**: `README.md`, `.cg-docs/work-reports/` if required by project
  workflow
- **Details**: Document official versus exploratory values, integer 100%
  validation, full-precision calculation/display rounding, partial-coverage
  renormalization, zero-effective-weight and missing-official states, `spiR`
  provenance, exact browser command, and out-of-scope behavior. Record test
  outcomes and blockers. Do not silently change the charter during this step.
- **Test Scenarios**: documentation matches helper behavior and commands work
  from the documented directory.
- **Tests**: Markdown review and `git diff --check`.
- **Acceptance criteria**: A user and maintainer can reproduce and correctly
  interpret every displayed score.

## Testing Strategy

- Load pure helper/data files explicitly with `sys.source()` into isolated
  environments, matching existing repository test patterns.
- Test arithmetic independently from Shiny with complete, partial, empty,
  zero-effective-weight, invalid-weight, and missing-official fixtures.
- Use `shiny::testServer` for module state, reset, lazy activation, selections,
  and controlled status outputs.
- Use the injected snapshot path for integration tests; do not require network
  access.
- Use a complete five-pillar `shinytest2` fixture and the documented Rscript
  command for browser validation at desktop and mobile widths.
- Run focused tests first, then existing impacted integration/module tests, then
  diagnostics and formatting checks.

## Documentation Checklist

- [ ] Charter focus authorization is recorded before implementation.
- [ ] Five-pillar structural schema and row-level missingness are distinguished.
- [ ] Integer weights, exact 100% validation, and display rounding are stated.
- [ ] Official SPI versus user-weighted result is explained.
- [ ] Partial coverage, zero effective weight, and missing official states are explained.
- [ ] `spiR` provider boundary and local fallback are identified.
- [ ] Browser command and prerequisites are documented.
- [ ] Dimensions, indicators, rankings, multiple countries, and saved scenarios remain out of scope.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Milestone 6 conflicts with the charter focus | Make charter synchronization a blocking pre-flight step |
| Live schema exposes fewer than five pillars | Validate structural schema and return controlled unavailable state |
| Floating-point totals produce inconsistent validation | Use integer percentage inputs and exact integer sum |
| Available scores have zero effective weight | Return explicit unavailable status and test it |
| Official SPI is missing for a selected year | Allow only rows with at least one valid pillar; show official and difference as unavailable |
| Missing pillars distort the result | Preserve `NA`, renormalize effective weights, and disclose coverage |
| Lazy state remains stale | Test activation, call count, cache reuse, and reactive choice updates |
| Browser fixture cannot cover real states | Include complete, partial, and no-coverage rows explicitly |
| Tests fail because functions are not loaded | Use explicit `sys.source()` setup in every new test environment |
| Browser validation is not reproducible | Pin the command shape, working directory, fixture app, and R prerequisite |
| Existing tabs regress | Keep app wiring minimal and run impacted integration tests |
| Scope expands into other weighting levels | Treat dimensions, indicators, rankings, saved scenarios, and multi-country behavior as deviations requiring approval |

## Out of Scope

- Weighting dimensions or indicators.
- Multiple-country scenarios or comparison views.
- Global rankings or quintiles based on customized scores.
- Persistent or shareable saved scenarios.
- Changes to official SPI values or methodology.
- New external data sources or modifications to external `spiR`.
- Automatic redistribution of other weights while editing.
- New dependencies.
- Automatic refresh during an open session.

## Completion Contract

### Outcome

After Milestone 6 is authorized as the active focus, the dashboard exposes a
responsive Explore by Pillar workspace for one country and year. It validates
integer weights summing exactly to 100, calculates a transparent exploratory
score from available pillar values, discloses all unavailable/renormalized
states, and keeps the official SPI visibly separate.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Phase | Required |
|---|-------------------|------------------|-------|----------|
| V1 | Focus authorization is explicit | Charter/roadmap targeted read | 1 | yes |
| V2 | Five-pillar structural schema is verified | Data-layer fixtures and snapshot check | 1 | yes |
| V3 | Integer weights and exact 100% validation pass | Focused helper tests | 2 | yes |
| V4 | Weighted arithmetic and difference pass | Focused helper tests | 2 | yes |
| V5 | Missingness, zero effective weight, and missing official pass | Data/helper tests | 2 | yes |
| V6 | Module defaults, reset, selections, and status states pass | `shiny::testServer` | 3 | yes |
| V7 | Lazy activation and injected loader pass | Module/integration tests | 3 | yes |
| V8 | Complete browser fixture covers all required states | Fixture review and smoke test | 4 | yes |
| V9 | Desktop/mobile browser workflow passes | Exact Rscript smoke command | 4 | yes |
| V10 | Documentation matches implementation | README/work report review | 4 | yes |
| V11 | Touched files have no diagnostics | `get_errors` | 4 | yes |

### Constraints

| ID | Constraint | Check |
|---|------------|-------|
| C1 | Milestone 6 focus is authorized first | Charter and roadmap |
| C2 | Exactly five structural pillars are required | Schema helper and fixture |
| C3 | Weights are integer percentages summing exactly 100 | Helper and module tests |
| C4 | `NA` is preserved; no imputation to zero | Numeric fixtures |
| C5 | Zero effective weight is unavailable | Edge-case test |
| C6 | Missing official SPI is visibly unavailable | Selection/module test |
| C7 | Use shared `spiR`-preferred provider and no external edits | Integration and repository diff |
| C8 | No new dependencies | `DESCRIPTION` review |
| C9 | Preserve Golem boundaries and lazy activation | Module wiring/tests |

### Boundaries

- Allowed: charter synchronization through its approved workflow, `R/` module/data/helper changes, focused tests, complete browser fixture, browser smoke script, and related documentation.
- Out of scope: dimensions, indicators, multiple countries, rankings, saved scenarios, official methodology changes, new dependencies, and external `spiR` modifications.

### Iteration Policy

1. Resolve focus authorization before implementation.
2. Verify the five-pillar schema before rendering controls.
3. Fix pure calculation defects before UI defects.
4. Keep invalid totals invalid and never silently normalize them.
5. Keep `NA` explicit and report renormalization or unavailable states.
6. Rerun the narrowest failing test after each local repair.
7. Ask before changing formula, scope, dependency, or official-score policy.

### Blocked-Stop Conditions

- Focus authorization is unresolved.
- Five stable structural pillars cannot be obtained from the normalized snapshot.
- Official and custom values cannot remain distinguishable.
- Missingness requires an unapproved imputation rule.
- Browser smoke cannot run reproducibly with the documented fixture/command.
- Tests reveal unexplained numeric discrepancies.
- External `spiR` changes or a new dependency become necessary.

### Deviation Policy

`ask`
