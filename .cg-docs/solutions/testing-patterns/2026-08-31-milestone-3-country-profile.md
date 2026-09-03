---
date: 2026-08-31
title: "Milestone 3 Country Profile with independent normalized sections"
category: "testing-patterns"
language: "R"
tags: [milestone-3, country-profile, shiny, golem, spiR, provider-adapter, normalized-data, fixtures, benchmarks, missing-data, modularity]
root-cause: "Country Profile required a single-country analytical surface without coupling its sections to raw spiR schemas, shared navigation state, or one another's loading failures."
severity: "P2"
---

# Milestone 3 Country Profile with Independent Normalized Sections

## Problem

Milestone 3 required a modular Country Profile for one country. The page had to
show the overall score, pillar performance, score over time, dimensions,
indicators, highest and lowest observed dimensions, and regional or income
reference values. It also needed independent country and year controls,
explicit missing and partial-data behavior, and deterministic tests while
using the development checkout of `spiR` as the preferred provider.

The profile could not depend on Country Explorer state or assume that every
optional provider operation would return complete data.

## Root Cause

The key architectural risk was allowing the profile UI to interpret raw
provider schemas or to make one visualization's failure block the rest of the
page. A second risk was treating dimension extremes or contextual benchmarks
as unsupported rankings instead of defining their coverage, filtering, and
ordering rules explicitly.

## Solution

### Verify the external package before wiring it

The sibling `spiR` checkout is loaded during development with
`devtools::load_all()` and verified through its exports, formals, and controlled
representative calls. The dashboard does not modify that repository.

The provider boundary in `R/spi_provider.R` prefers these public operations:

- `spi_index()` for overall, pillar, dimension, and time-series values.
- `spi_data()` for detailed indicator values.
- `country_info()` for country, region, income, and related metadata.
- `spi_aggregates()` for official aggregate reference rows.
- `metadata()` for pillar, dimension, and indicator labels.

The dashboard retains its local provider as an explicit fallback. Provider
selection, aliases, schema interpretation, normalization, and operation
status remain outside the Shiny module.

### Build section-specific normalized objects

`R/country_profile_data.R` prepares separate results for the profile header,
overall series, pillars, dimensions, indicators, dimension extremes, and
benchmarks. Each section carries data, status, message, coverage, and source
information. Supported states are `pending`, `ok`, `partial`, `empty`,
`unavailable`, and `error`.

The module in `R/mod_country_profile.R` owns its country and year controls and
consumes the normalized section results. It does not use Country Explorer's
selection state. Missing values stay as `NA` and are displayed as `-`.

Dimension extremes are limited to dimensions with non-missing scores that meet
the configured coverage rule. They are ordered deterministically by score and
technical ID and are described as highest or lowest observed dimensions, not
as causal strengths, weaknesses, or global rankings. Regional and income-group
values are contextual official-reference benchmarks.

### Keep visualization rendering replaceable

The profile visualization layer in
`R/country_profile_visualizations.R` prioritizes the official `spiR` radar and
trend functions when available and retains controlled local fallbacks for
offline fixtures. The profile remains testable because its data preparation is
separate from rendering and the fallback consumes normalized data.

## Validation

The completed execution report recorded:

- All four implementation phases completed with no deviations or accepted exceptions.
- The complete deterministic `testthat` suite passed at each phase gate.
- Fixtures covered missing values, partial coverage, duplicate country-year rows,
  missing benchmarks, unavailable operations, and provider errors.
- Module and app integration tests verified direct Profile selection,
  independent country/year state, and isolated section statuses.
- Browser smoke validation covered profile navigation, country and year
  selection, visible missing-value behavior, desktop rendering, and a roughly
  390px responsive layout.
- Golem package loading succeeded, and the sibling `spiR` source loaded with
  the verified public operations and representative calls.
- The external `spiR` repository remained untouched.

## Prevention

- Load and verify the development `spiR` checkout before treating an API as supported.
- Keep provider calls and schema normalization in `R/spi_provider.R` and
  `R/spi_adapter.R`; keep modules dependent on normalized contracts.
- Give each profile section its own status and data object so optional failures
  do not cascade.
- Define missing-data, coverage, benchmark, and ordering rules before adding
  presentation logic.
- Use deterministic fixtures for ordinary tests and reserve live provider calls
  for controlled smoke checks.
- Preserve a local rendering fallback when official package plotting functions
  are unavailable, without changing the external package.

## Related

- `.cg-docs/plans/2026-08-20-milestone-3-country-profile-revised.md`
- `.cg-docs/brainstorms/2026-08-20-milestone-3-country-profile.md`
- `.cg-docs/work-reports/2026-08-20-milestone-3-country-profile-revised.md`
- `.cg-docs/solutions/testing-patterns/2026-08-20-milestone-2-country-explorer.md`
- `.cg-docs/solutions/testing-patterns/2026-09-01-milestone-4-country-comparison.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/country_profile_data.R`
- `R/country_profile_helpers.R`
- `R/country_profile_visualizations.R`
- `R/mod_country_profile.R`
- `tests/testthat/`
