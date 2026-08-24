---
date: 2026-08-20
title: "Milestone 3: Single-country Country Profile"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "A modular single-country Golem profile with progressive disclosure"
language: "R"
tags: [spi, shiny, golem, country-profile, spiR, modular-visualizations, country-explorer, navigation, trends, pillars, dimensions, indicators, peers]
---

# Milestone 3: Single-country Country Profile

## Context

Milestones 1 and 2 established the Golem-compatible SPI dashboard, the provider and normalization boundary, Overview, and Country Explorer. The next milestone is Country Profile: a zoomed-in analytical view of one country. The profile should reuse the normalized provider contract and the functions from `spiR` through the dashboard adapter, while keeping each visualization independent from the other sections on the page.

The initial mockup includes a country header, overall score, pillar performance, score over time, strongest dimensions, areas for improvement, and peer comparison. The visual direction is useful, but the implementation may refine layout and interaction when that improves comprehension for the dashboard's mixed audience.

## Requirements

### Product purpose

Country Profile should help users:

1. Understand a country's overall SPI performance quickly.
2. Diagnose the pillars, dimensions, and indicators that explain the result.
3. Analyze the country's evolution over time.
4. Compare the country conceptually with its region and income group as reference benchmarks.
5. Produce evidence useful for World Bank teams, researchers, and non-specialist learners.

### Users

The audience is the same as the other dashboard sections:

- Internal World Bank teams and technical staff.
- Researchers and specialized users.
- General users who want to learn about a country's statistical performance.

The interface should therefore use progressive disclosure: a clear first reading for non-specialists, with methodological and indicator detail available without hiding the analytical depth needed by experts.

### Navigation and state

Country Profile supports two entry paths:

- Country Explorer row selection opens the profile for the selected country.
- A direct Country Profile entry allows the user to search or select a country without returning to Explorer.

The country code should be preserved in navigation state or a shareable URL when feasible. Country Profile owns its selected country and selected year state. It does not reuse or mutate the selected year of Overview or Country Explorer.

The profile is intentionally for one country. Two-country and multi-country comparisons are deferred to a later comparison tab or milestone. Regional and income-group values remain contextual reference benchmarks, not a country filter or a second full profile.

### Profile content

The first implementation should include:

- Country header with name, code, region, income group, and overall SPI score.
- Selected-year overall score and an interpretable change or trend summary where valid.
- Pillar performance visualization.
- Score-over-time visualization for the overall score, with a clear path to selecting another pillar, dimension, or indicator when supported by the data contract.
- Strongest dimensions and areas for improvement, using explicit coverage and missing-data rules rather than unsupported ranking claims.
- Detailed pillar, dimension, and indicator views.
- Region and income-group reference values where available.
- Controlled loading, unavailable, empty, and partial-data states.

Each visualization or content section must consume a normalized, section-specific data object and render independently. A failure or unavailable operation in one visualization must not prevent the other sections from rendering.

### Data and package boundary

- `spiR` remains the preferred provider.
- The dashboard's local provider remains the explicit fallback.
- Provider selection, aliases, schema normalization, and safe operation status remain under `R/spi_provider.R` and `R/spi_adapter.R`.
- Country Profile must not call raw provider functions directly from UI code.
- The external sibling `spiR` repository must not be modified.
- Missing values remain missing and must not be converted to zero.

### Testing and quality

Use deterministic fixtures for ordinary tests and keep live provider calls outside the standard suite. Test the pure country-profile data preparation separately from Shiny modules and from client-side rendering. Verify that independent visualization data and error states prevent cascading failures. Browser-level smoke checks should verify the main profile path, country navigation, year selection, visible missing-value behavior, and responsive layout after implementation.

## Approaches Considered

### Approach 1: One monolithic Country Profile module

Build all data loading, transformation, reactivity, and plots inside one large Golem module.

This is initially quick, but it couples all visualizations, makes partial failures difficult to isolate, and makes deterministic testing expensive.

### Approach 2: Modular single-country profile with progressive disclosure

Create a Country Profile shell plus pure data helpers and independent visualization sections. The shell owns country and year state; each section receives normalized data and exposes its own loading, unavailable, empty, and error state.

This provides the best balance between the mockup's rich profile and the project's existing provider/adapter architecture. It supports the mixed audience, isolates failures, and leaves room for later comparison without embedding comparison state into the profile.

### Approach 3: Full analytical workspace with comparison built in

Treat Country Profile as a broad workspace that supports one country, a second country, multiple comparison controls, detailed matrices, and advanced analytical interactions.

This could be powerful for technical users, but it would blur the boundary with the future comparison tab, increase scope substantially, and risk making the first country reading difficult for general users.

## Decision

Choose **Approach 2: modular single-country profile with progressive disclosure**.

Country Profile will focus on explaining one selected country. It will be reachable from Country Explorer and directly selectable from its own tab. It will include the mockup's core sections, refined where needed for clarity, with country and year state owned by the profile. Each visualization will be independently prepared, rendered, and tested. Region and income group will be contextual benchmarks only.

Two-country and multi-country comparison will not be implemented in Milestone 3. It will be designed as a separate future tab or milestone after the single-country profile is validated.

## Devil's Advocate

The main risk is scope growth from the mockup: trends, dimensions, indicators, strengths, improvements, and benchmarks can quietly become a second Explorer or an early comparison product. The guardrail is to keep one country as the only analytical subject, use progressive disclosure for detail, and define each section's data contract before adding visual polish.

A simpler page with only a score and a few charts would be faster, but it would not meet the stated diagnostic purpose. Conversely, embedding a second country now would create duplicated state and blur the boundary with the planned comparison experience. The modular approach is aligned with the Golem structure, the existing provider boundary, and the project's constraint that `spiR` remain external.

## Next Steps

- Inspect the current `spiR` and dashboard contracts for country-year, pillar, dimension, indicator, and benchmark data needed by the profile.
- Define section-level normalized data objects and explicit missing/unavailable behavior.
- Design the Country Profile Golem shell and independent visualization modules.
- Add navigation from Country Explorer and direct country selection in Country Profile.
- Implement deterministic fixtures and focused tests before browser smoke validation.
- Update the project charter's Current Focus after the implementation plan is approved, if the team wants the charter to track Milestone 3.

## Related

- `.cg-docs/brainstorms/2026-08-06-spi-shiny-dashboard.md`
- `.cg-docs/brainstorms/2026-08-12-milestone-2-country-explorer.md`
- `.cg-docs/solutions/testing-patterns/2026-08-20-milestone-2-country-explorer.md`
- `compound-gpid.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/mod_country_explorer.R`
- `README.md`
