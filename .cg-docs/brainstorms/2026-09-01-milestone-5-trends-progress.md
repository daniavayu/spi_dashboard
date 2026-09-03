---
date: 2026-09-01
title: "Milestone 5: Trends and Progress"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Trends analítico modular basado exclusivamente en spiR"
tags: [spi, shiny, golem, spiR, trends, progress, groups, pillars, stability, correlation, reproducibility]
---

# Milestone 5: Trends and Progress

## Context

Milestones 1 through 4 established the Golem-compatible SPI dashboard, the
shared provider and normalization boundary, Country Explorer, Country Profile,
and Compare Countries. The next window, Trends & Progress, should be the main
interpretive surface for understanding how the SPI changes over time rather
than a collection of disconnected charts.

The dashboard must remain replicable for other users. Therefore, all data,
metadata, official groupings, and reusable visualizations must come from the
public API of the `spiR` package. The dashboard may perform transparent
presentation transformations over the normalized snapshot, but it must not
introduce private data or unsupported classifications.

## Requirements

### Users and purpose

The window serves both general users and technical analysts. It should provide
an immediate executive reading while allowing deeper methodological detail
through controls, coverage information, and expandable explanatory text.

The primary questions are:

- How has the SPI moved globally over the available period?
- How have official regions, income groups, and other available `spiR`
  groupings changed over time?
- Which countries improved or declined most over a selected period?
- Which pillars are more stable or more variable over time?
- How are pillar scores associated with one another?
- How much of the apparent movement reflects changes in country coverage?

### Controls and data

- Allow the user to choose a start and end year from years available in the
  normalized `spiR` snapshot.
- Provide a sensible default using the full available period.
- Allow selection of the metric: overall SPI or a supported pillar score.
- Allow selection of an official grouping exposed by `spiR`, such as region,
  income group, lending type, or another validated aggregate classification.
- Do not create user-defined groups in this milestone.
- Keep all calculations descriptive and reproducible from the normalized
  country-level data and official aggregate data.

### Planned views

1. Global SPI trend with annual central tendency and a visible distribution
   band, such as median and interquartile range.
2. Trend by selected official grouping, with one line per group and a clear
   indication of the number of countries contributing in each year.
3. Period change table showing largest improvements and declines, with start,
   end, change, and coverage.
4. Pillar stability view ranking pillars by a documented temporal variability
   measure, such as standard deviation of annual country changes or an
   equivalent transparent statistic.
5. Pillar association view showing pairwise correlations between pillar
   scores, explicitly labeled as associations and not causal relationships.
6. Coverage and comparability information so users can distinguish a true
   change from a change in the set of countries observed.

### Missing data and low coverage

Do not hide groups automatically. Show them with missing values or a muted
state, and report the number of countries and observations behind each result.
A user-selectable minimum coverage filter may be added, but the default should
preserve transparency and avoid silently removing groups.

Missing values must remain missing. No zero imputation, prediction, causal
interpretation, significance testing, or unsupported ranking should be added.

## Approaches Considered

### Approach 1: Trends essential

A small global trend, group trends, and improvement/decline table using the
normalized snapshot.

Pros: small implementation and low methodological risk.

Cons: does not answer the requested questions about pillar stability,
associations, or coverage composition.

Effort: small/medium.

### Approach 2: Trends analítico modular

A layered window combining executive global and group trends with transparent
modules for period changes, coverage, pillar stability, and pairwise pillar
associations.

Pros: answers the main analytical questions, remains reproducible from `spiR`,
keeps transformations testable in pure R helpers, and supports both general
and technical users.

Cons: requires careful definitions for stability, correlation, coverage, and
official grouping availability; the interface must avoid becoming too dense.

Effort: medium.

### Approach 3: Trends tipo laboratorio

Add free-form grouping, convergence analysis, interactive scatter plots,
regressions, and exploratory statistical analysis.

Pros: broad exploratory power.

Cons: exceeds the current need, risks unsupported interpretations, and is less
replicable unless additional methodological contracts are established.

Effort: large.

## Decision

Choose **Approach 2: Trends analítico modular basado exclusivamente en `spiR`**.

The first implementation should prioritize a clear executive reading and then
progressively disclose technical detail. It should use `spiR` as the provider
of scores, metadata, official groupings, and public plotting/data functions
where they fit. Dashboard-owned transformations are acceptable for summaries,
coverage, stability, and association views because `spiR` does not need to
provide a separate function for every descriptive presentation.

Convergence analysis, interpretive scatter plots, causal analysis, prediction,
regression, significance testing, advanced clustering, and user-invented groups
are explicitly outside this milestone. They can be reconsidered later if
`spiR` exposes suitable public contracts and the methodology is agreed.

## Devil's Advocate

The main risk is analytical overreach. A line moving upward can reflect a
changing country sample, a correlation between pillars does not establish a
mechanism, and a stability ranking depends on the chosen variability measure.
Every chart should therefore expose its period, metric, coverage, and concise
method note. The simplest high-value first slice is global trend, selected
official-group trend, period change table, and coverage; stability and
associations should follow as separate modules with tests for their formulas.

A second risk is including every aggregate returned by `spiR`. The interface
should validate group types and show only classifications with interpretable
metadata and sufficient observations, while still reporting unavailable or
low-coverage states transparently.

## Next Steps

1. Inspect the current `spiR` public API and normalized snapshot for all
   available grouping metadata and pillar columns.
2. Define the exact period-change, coverage, stability, and association
   contracts before coding.
3. Create pure data helpers under `R/` and an independent Golem module for
   Trends & Progress.
4. Add deterministic fixture tests for periods, group trends, missing data,
   coverage, stability, correlations, and empty states.
5. Add browser smoke checks for controls, responsive layout, and visible
   coverage/methodology states.
6. Update the project charter and visualization mapping when implementation
   scope is finalized.

## Related

- `.cg-docs/brainstorms/2026-08-06-spi-shiny-dashboard.md`
- `.cg-docs/brainstorms/2026-08-31-milestone-4-country-comparison.md`
- `.cg-docs/solutions/testing-patterns/2026-09-01-milestone-4-country-comparison.md`
- `.cg-docs/solutions/testing-patterns/2026-08-31-milestone-3-country-profile.md`
- `.cg-docs/spiR-dashboard-visualization-mapping.md`
- `R/spi_provider.R`
- `R/spi_adapter.R`
