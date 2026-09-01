---
date: 2026-08-31
title: "Milestone 4: Country Comparison"
status: decided
scope: "Deep"
chosen-approach: "Modular comparison workspace with up to three countries"
language: "R"
tags: [spi, shiny, golem, country-comparison, spiR, reproducibility, pillars, dimensions, trends]
artifact-schema-version: 1
---

# Milestone 4: Country Comparison

## Context

Milestones 1, 2, and 3 established the Golem-compatible dashboard, the
provider and normalization boundary, Country Explorer, and the modular
single-country Country Profile. The next milestone is a dedicated comparison
workspace for users who need to examine several countries side by side.

The reference design suggests four complementary views: pillar comparison,
score by pillar, score trends over time, and dimension-level comparison. The
implementation should preserve the dashboard's existing architecture and use
reproducible R data wherever possible.

## Product Purpose

Country Comparison should let users compare the relative SPI performance of a
small set of countries without presenting the result as a causal analysis or a
global ranking. The interface should support a quick visual comparison while
also providing enough detail for technical users to inspect dimensions and
missing coverage.

## Decisions

### Comparison size

- Support a maximum of three countries at one time.
- Use stable ISO3 country codes as internal keys.
- Display country names and ISO3 codes in legends and table headers where
  space allows.
- Preserve the existing Country Explorer handoff, while also allowing country
  selection directly in Compare Countries if practical.

Three countries balance comparative usefulness with readable legends, radar
polygons, grouped bars, and table columns.

### Time and point-in-time views

- Trends use all available years returned by the normalized provider snapshot.
- A selected year controls the point-in-time pillar, radar, and dimension views.
- The trend metric has a selector for Overall SPI and supported pillar scores.
- Missing observations remain missing and are not imputed as zero.

### Visual views

The comparison page should include:

1. **Pillar Comparison**: radar chart comparing the five pillar scores for the
   selected year.
2. **Score by Pillar**: grouped bars using the same selected-year pillar data.
3. **Score Trends Over Time**: one line per country for Overall SPI or a
   selected pillar.
4. **Dimension-Level Comparison**: a table comparing dimension scores for the
   selected year, with readable labels from `metadata()` and optional visual
   score coloring.

The dimension table shows all available indexed dimensions by default. A
selection control or filter may narrow the visible rows for focused analysis,
while a clear indicator communicates that the full comparison remains
available.

### Provider and reproducibility boundary

- Follow the Golem structure and keep Compare Countries as an independent
  Shiny module.
- Use the shared provider and adapter layer rather than calling raw provider
  functions from the UI module.
- Use `spiR` as the preferred provider and retain the local provider as an
  explicit fallback.
- Prefer public `spiR` functions and normalized dashboard data over duplicated
  data-access logic.
- Use `spi_index()` for overall, pillar, and dimension scores where supported.
- Use `spi_data()` only when detailed indicator-level comparison is explicitly
  included in scope.
- Use `metadata()` for pillar, dimension, and indicator labels.
- Do not modify the external `spiR` repository.
- Keep comparison transformations transparent and reproducible in pure R
  helpers outside the Shiny module.

The comparison visualizations do not need to be implemented inside `spiR` if
all values and labels can be obtained from its public data functions. The
dashboard may own layout, selection, reshaping, filtering, and rendering.

### Missing data and interpretation

- Preserve `NA` values throughout normalization and comparison preparation.
- Show missing values consistently as `-` in tables and an explicit gap or
  unavailable state in charts.
- Do not calculate a country ranking from incomplete dimensions unless the
  coverage rule is documented.
- Present comparisons as descriptive score comparisons, not causal claims,
  performance verdicts, or unsupported league tables.
- Expose empty, partial, unavailable, and error states without preventing other
  comparison sections from rendering.

## Proposed User Flow

1. The user enters Compare Countries from the top navigation or from the
   Country Explorer handoff.
2. The user selects two or three countries.
3. The page defaults to the latest common or selected available year according
   to the defined year rule.
4. The radar and grouped bars show the selected-year pillar comparison.
5. The trend chart shows Overall SPI over all available years.
6. The user switches the trend selector to a supported pillar.
7. The dimension table shows all dimensions and allows focused filtering.
8. The user can change the selected year and inspect the point-in-time views.

## Data Contract Questions To Resolve Before Planning

- Should the selected year be the latest year shared by all selected countries,
  the latest year available for each country, or a global selected year with
  explicit missing cells?
- Should direct Compare Countries selection be implemented in this milestone,
  or should the Explorer handoff remain the only entry path initially?
- Should the dimension table include all dimensions in one view or group rows
  by pillar with collapsible sections?
- Should score coloring use fixed thresholds, a continuous red-to-green scale,
  or remain neutral to avoid implying a normative ranking?
- Should indicator-level comparison be excluded from the first implementation
  and deferred until a clear use case emerges?

## Scope Boundaries

### Included

- Independent Golem Compare Countries module.
- Selection and validation of up to three countries.
- Selected-year pillar radar and grouped bars.
- All-years trend chart with Overall SPI and pillar metric selection.
- Dimension comparison table with full/default coverage and optional filter.
- Shared normalized provider snapshot and deterministic fixture tests.
- Responsive desktop and mobile browser validation.

### Excluded from this milestone

- More than three simultaneous countries.
- Indicator-level comparison unless separately approved.
- Custom weighting or user-created composite scores.
- Causal inference, significance testing, or global ranking claims.
- Downloads and exports.
- New external data sources.
- Changes to the `spiR` repository.

## Architecture Direction

Use a Golem module under `R/mod_country_compare.R` with pure comparison data
and helper functions in dedicated `R/` files. The module should consume an
injected normalized snapshot in tests and the shared provider snapshot in
production. Each output should receive a section-specific prepared object so
that a missing trend series does not prevent the pillar radar or dimension
table from rendering.

The implementation should reuse the existing `spi_provider_snapshot()` and
normalized `index`, `indicators`, `metadata`, and label lookup objects. Any
country-selection state should remain local to Compare Countries, except for
the existing explicit ISO3 handoff from Country Explorer.

## Testing Direction

Use deterministic fixtures to test:

- two-country and three-country selection;
- duplicate and invalid country selections;
- selected-year behavior and missing country-year observations;
- pillar and dimension reshaping;
- trend metric selection;
- incomplete dimension coverage;
- stable labels and technical IDs;
- empty, partial, unavailable, and error section states;
- independent Compare Countries state;
- responsive and client-rendered outputs through browser smoke checks.

## Decision

Adopt a modular comparison workspace based on the reference images: up to
three countries, four complementary comparison views, all dimensions visible
by default with optional filtering, and a reproducible R data path backed by
`spiR`. The remaining data and presentation questions should be resolved in
the implementation plan before coding begins.

## Related

- `.cg-docs/brainstorms/2026-08-06-spi-shiny-dashboard.md`
- `.cg-docs/brainstorms/2026-08-20-milestone-3-country-profile.md`
- `.cg-docs/plans/2026-08-20-milestone-3-country-profile-revised.md`
- `.cg-docs/solutions/testing-patterns/2026-08-31-milestone-3-country-profile.md`
- `.cg-docs/spiR-dashboard-visualization-mapping.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
- `R/mod_country_compare.R`
