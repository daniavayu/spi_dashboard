---
date: 2026-09-01
title: "Milestone 4 Country Comparison with a modular spiR-backed workflow"
category: "testing-patterns"
language: "R"
tags: [milestone-4, country-comparison, shiny, golem, spiR, provider-adapter, normalized-data, fixture-injection, reproducibility]
root-cause: "Country Comparison needed an independent comparison workspace without coupling Shiny modules to raw spiR schemas or changing the established provider boundary."
severity: "P2"
---

# Milestone 4 Country Comparison with a Modular spiR-Backed Workflow

## Problem

Milestone 4 added a Country Comparison workspace to the SPI dashboard. Users
needed to compare two or three countries across a selected year, inspect pillar
scores and dimension gaps, and view overall trends over time. The feature had
to preserve the Golem-compatible structure, use the separate `spiR` package as
the source of data, remain reproducible as new data are released, and avoid
turning a descriptive comparison into a causal ranking.

The dashboard also needed to remove a regional benchmark panel whose behavior
was no longer part of the approved comparison workflow, while preserving the
Country Profile context benchmarks.

## Root Cause

The main architectural risk was allowing Compare Countries to call raw `spiR`
functions or interpret upstream column names directly. That would duplicate
provider logic, make schema changes expensive, and make the new module depend
on live data in ordinary tests. A second risk was forcing the local fallback in
the application server, which contradicted the documented `spiR`-first design
and prevented new package data from becoming the application source of truth.

A smaller provider-boundary issue appeared when the local hierarchy reader
returned a `data.table`: the fallback selected columns with data.frame syntax,
so optional hierarchy loading failed before labels could be normalized.

## Solution

### Keep Compare Countries as an independent Golem module

`R/mod_country_compare.R` owns the module UI, selection state, handoff from
Country Explorer, year state, and output rendering. Pure comparison preparation
remains in the comparison data and helper files. The module consumes the
normalized snapshot and does not interpret raw provider schemas.

The implemented workspace supports:

- up to three countries keyed by normalized ISO3 codes;
- a selected year for point-in-time pillar and dimension comparisons;
- an all-years overall trend;
- a largest-dimension-gap table with readable hierarchy labels; and
- explicit empty or unavailable states rather than imputing missing scores.

The regional benchmark panel was removed from Compare Countries. Regional and
income-group context remains available in Country Profile, where it is treated
as official reference context rather than a ranking.

### Make the provider contract match the documentation

The production loaders in `R/app_server.R` now call
`spi_provider_snapshot(preferred = "spiR", ...)`. `R/spi_provider.R` still
falls back to the local provider when the mandatory `spiR` index cannot load.
This means restarting the dashboard after updating the development or installed
`spiR` package picks up new data without copying data into the dashboard
repository.

The existing adapter remains responsible for aliases, country/year keys,
missing values, metadata deduplication, and label normalization. Compare and
Profile therefore share one reproducible data contract.

### Make optional fallbacks robust to data.table

The raw hierarchy fallback converts the reader result to a base data frame
before selecting columns. This keeps the fallback behavior identical whether
the local provider returns a `data.frame` or a `data.table`, without adding a
hard dependency to module code.

## Validation

The focused module, integration, adapter, and provider tests passed. The full
`testthat` suite passed after the data.table fallback was corrected. VS Code
R diagnostics reported no errors in the touched R files.

The external sibling `spiR` repository was not modified.

## Prevention

- Keep `spiR` calls, fallback selection, aliases, and normalization inside
  `R/spi_provider.R` and `R/spi_adapter.R`.
- Inject normalized snapshot loaders into modules and app tests; do not make
  ordinary tests depend on network data.
- Treat comparison transformations as pure, descriptive R operations and
  preserve `NA` values rather than replacing them with zero.
- Prefer public `spiR` visualization/data functions, and document dashboard-
  specific charts where no public package equivalent exists.
- When supporting local fallback readers, normalize `data.table` and
  `data.frame` inputs at the provider boundary.
- Update the README and visualization mapping whenever a milestone changes the
  visible dashboard workflow or provider source-of-truth behavior.

## Related

- `.cg-docs/brainstorms/2026-08-31-milestone-4-country-comparison.md`
- `.cg-docs/solutions/testing-patterns/2026-08-20-milestone-2-country-explorer.md`
- `.cg-docs/solutions/testing-patterns/2026-08-31-milestone-3-country-profile.md`
- `.cg-docs/solutions/bugs/2026-08-12-milestone-1-overview-implementation.md`
- `.cg-docs/spiR-dashboard-visualization-mapping.md`
- `R/mod_country_compare.R`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/app_server.R`
- `tests/testthat/`
