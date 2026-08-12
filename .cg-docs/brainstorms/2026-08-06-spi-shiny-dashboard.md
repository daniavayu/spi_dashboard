---
date: 2026-08-06
title: "SPI Shiny Dashboard Reconstruction"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Minimal golem foundation plus Overview"
tags: [spi, shiny, golem, dashboard, spiR, flourish, world-bank, r]
---

# SPI Shiny Dashboard Reconstruction

## Context

The current Statistical Performance Indicators (SPI) webpage is a useful first
point of access, but the project needs a simpler and clearer public experience
for exploring the SPI index. The new dashboard should also be easy to modify,
reproduce, and update when new SPI years or package changes become available.

The dashboard will rebuild and extend the current SPI experience using R Shiny
and the golem framework. The existing `functions/` and `viz_functions/` folders
contain the initial R data and visualization functions. The `spiR` package is
the intended data source and will become available on CRAN; local functions
remain available during the transition.

The mockup at `C:/Users/wb661551/Downloads/dashboard_mockup.html` is the
initial product reference. The `InnovationHubDashboard` repository and the
World Bank Innovation Hub website are architectural and design references, not
the source of truth for this project.

## Requirements

- The application must be publicly accessible without authentication.
- The initial application language is English.
- The project must use R Shiny and the golem framework.
- The repository must be organized around reproducible, maintainable modules.
- Data acquisition and transformation should be isolated from user-interface
  modules so future SPI updates do not require rewriting every visualization.
- The Overview map must use Flourish.
- Non-map visualizations should use R-based visualization methods.
- The application should use `spiR` as the primary data package when available.
- A shared reactive data flow should use the latest year with valid data for
  the Overview; a functional year selector is deferred.
- Countries without data for the selected year should not be displayed.
- Countries with partial indicator coverage should be displayed using available
  data.
- Regional aggregates should use the available aggregate rows, while
  income-group summaries should use the available country observations.
- New years and changes in `spiR` column names should be accommodated through
  the data interface rather than hard-coded independently in each tab.
- Downloads in CSV, Excel, and Stata formats are not required for the first
  milestone.
- Work will continue directly on `main`; no feature branches are required.

## Milestones

### Milestone 1: Repository Setup and Global Overview

- Establish the minimal golem application structure.
- Organize the existing data and visualization functions.
- Define stable shared data interfaces for the application modules.
- Integrate `spiR`, with local functions available during the transition.
- Implement the latest-year Overview and core filters.
- Implement the Overview tab with the Flourish map and summary views.
- Leave the repository reproducible, ordered, and easy to update.

### Milestone 2: Country Explorer

Add country browsing and filtering by region, income level, fragile and
conflict status, and country search.

### Milestone 3: Country Profile

Add country-level scores, pillar performance, trends, strengths, areas for
improvement, detailed pillar and dimension scores, and peer comparisons.

### Milestone 4: Compare Countries

Add side-by-side comparison for up to six countries across pillars, trends,
and dimensions.

### Milestone 5: Trends and Progress

Add global, regional, and income-group trends, improvement and decline views,
convergence analysis, and pillar-specific trends.

### Milestone 6: Explore by Pillar

Add pillar-specific exploration, pillar correlations, cross-pillar analysis,
and the custom weighting tool.

### Milestone 7: Data and Downloads

Add data access, methodology, citation information, and download features when
they become a priority.

## Approaches Considered

### Approach 1: Full golem structure first

Create the complete golem skeleton and all planned module placeholders before
implementing the Overview.

This establishes the final architecture early, but delays a working user-facing
result and creates structure before the first milestone has been validated.

### Approach 2: Minimal golem foundation plus Overview

Create only the golem foundation and shared architecture required by the
Overview. Organize the existing functions, connect `spiR`, implement the
global data flow, and build the first tab end to end. Add later tabs as
independent modules in their own milestones.

This provides a working vertical slice quickly while preserving modularity and
avoiding premature scaffolding. This is the selected approach.

### Approach 3: Reproduce the reference dashboard structure first

Use `InnovationHubDashboard` as the initial application skeleton and adapt its
patterns to SPI.

This reduces architectural uncertainty, but risks importing assumptions that
do not fit the SPI data model. The reference project will therefore be used for
patterns and conventions rather than copied as the project structure.

## Decision

Use Approach 2. The first implementation target is a minimal, maintainable
golem foundation plus a complete Overview vertical slice. The Overview is the
best first validation because it exercises the full path from data acquisition
through shared reactive state to public-facing visualizations.

The architecture should be based on stable documented data interfaces rather
than individual plots. This will allow `spiR` to evolve and make later tabs
independent modules that consume shared prepared data.

## Devil's Advocate

The main risk is trying to make the repository fully ready before defining the
shared data contract. If the contract is unstable, every future tab may need
custom data preparation. The first milestone should therefore validate the
normalized data objects consumed by the Overview, including year filtering,
country availability, partial coverage, and group aggregates.

The scope is large, but the milestone structure makes it manageable: the first
vertical slice creates immediate value, while the remaining mockup tabs remain
planned rather than being treated as out of scope.

## Next Steps

1. Inspect the existing R functions and visualization functions against the
   mockup's Overview requirements.
2. Inspect the `spiR` public API and the reference `InnovationHubDashboard`
   architecture.
3. Create the minimal golem project structure directly on `main`.
4. Define and document the shared Overview data contract.
5. Implement and validate the Overview tab, including the Flourish map
   integration boundary and summary visualizations.
6. Register the seven milestones in the project roadmap.