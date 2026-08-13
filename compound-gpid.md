---
project-name: "Statistical Performance Indicators Dashboard"
team: "DECDG / GPID -- World Bank"
created: "2026-08-12"
last-reviewed: "2026-08-12"
---

# Statistical Performance Indicators Dashboard

## Objective

Provide a public English Shiny dashboard for the World Bank Statistical Performance Indicators (SPI). The application prefers `spiR`, preserves a local fallback, and isolates provider schema normalization from Shiny modules.

## Key Deliverables

- A launchable Shiny dashboard with `app.R` as the canonical application entry point.
- A Milestone 1 Overview implementation.
- A shared provider and normalization layer under `R/`.
- A required Flourish map using the 2024 payload.
- R-rendered non-map summaries and visualizations.
- Deterministic `testthat` tests under `tests/testthat/`.
- Deployment support through `rsconnect::deployApp()`.

## Constraints

- The application is unauthenticated.
- `spiR` is the preferred provider; local functions under `functions/` are retained as an explicit fallback.
- The Flourish map is scoped to the 2024 payload for Milestone 1.
- `FLOURISH_API_KEY` must come from deployment configuration and must not be committed.
- Later dashboard tabs are outside the stated Milestone 1 scope.
- The extensionless `App` artifact is retired; `app.R` is the only application entry point.
- The separate `spiR` repository is an external dependency/provider boundary and must not be modified.

## Current Focus

Implement Milestone 2: Country Explorer, including the contract normalizado de datos, el año global seleccionable y la tabla interactiva integrada con el proveedor `spiR` y su fallback local.
