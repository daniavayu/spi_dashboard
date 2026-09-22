---
date: 2026-09-20
title: "Milestone 6: Explore by Pillar and Custom Weighting"
status: decided
scope: "Deep"
artifact-schema-version: 1
chosen-approach: "Direct pillar weighting with exact 100% validation"
tags: [spi, shiny, golem, explore-by-pillar, custom-weighting, spiR, reproducibility]
---

# Milestone 6: Explore by Pillar and Custom Weighting

## Context

The dashboard needs an Explore by Pillar workspace that adds analytical value
without repeating Country Explorer, Country Profile, Compare Countries, or
Trends & Progress. The reference implementation at
`https://datanalytics.worldbank.org/SPI/?tab=custom-weights` provides the
functional basis: users adjust weights and inspect a customized composite
score alongside the original score.

This milestone is intentionally limited to pillar-level exploration. The
custom result is an exploratory user-defined scenario and must never be
presented as a replacement for the official SPI.

## Requirements

- Support one selected country and one selected year.
- Expose the five pillar scores and one user-controlled weight for each pillar.
- Require the five weights to sum exactly to 100% before calculating the
  customized result.
- Start with equal weights of 20% per pillar.
- Provide a reset action that restores equal weights.
- Show the official SPI, the user-weighted result, and the difference between
  them side by side.
- Calculate the weighted result from pillar scores obtained through the shared
  `spiR`-preferred provider and normalization boundary.
- Preserve missing pillar values as missing rather than treating them as zero.
- If one or more pillar scores are missing, calculate from available pillars
  and renormalize their weights proportionally. Clearly indicate that this
  coverage adjustment occurred.
- Label the customized result as user-weighted or exploratory, distinct from
  the official SPI.
- Keep the feature as an independent Golem-compatible module with pure R
  calculation helpers outside the Shiny UI module.
- Keep the first version simple and responsive.

## Approaches Considered

### Approach 1: Direct pillar weighting

The user adjusts five pillar weights and the application calculates a weighted
average from the available pillar scores. This is closest to the current SPI
custom-weights experience and is straightforward to test.

Pros: small implementation surface, transparent formula, direct alignment
with the user's goal, and easy comparison with the official score.

Cons: it does not allow dimension- or indicator-level customization.

Effort: small to medium.

### Approach 2: Linked controls with automatic redistribution

Moving one pillar weight would automatically adjust the other four weights so
the total remains 100%.

Pros: avoids invalid totals and creates a smooth interaction.

Cons: changing one priority silently changes several others and can make the
user's intended weighting harder to inspect.

Effort: medium.

### Approach 3: Manual controls with validation

The user edits all five weights, while the interface displays the current
total and enables calculation only when the total is exactly 100%.

Pros: maximally transparent and easy to explain; invalid scenarios are
explicit rather than silently repaired.

Cons: the user must manually correct the total after edits.

Effort: small.

## Decision

Combine Approach 1 and Approach 3: implement direct pillar weighting with
manual controls and exact 100% validation. The interface will show the current
weight total, disable or withhold the customized result for invalid totals,
and offer a reset to equal 20% weights.

The weighted score will use available pillar values only. The weights attached
to available pillars will be renormalized to their available-weight total when
some pillar values are missing. The output must disclose this adjustment and
must remain visibly separate from the official SPI.

The dashboard will own the scenario calculation and presentation, while
`spiR` remains the preferred source for the underlying official scores and
metadata. The external `spiR` repository will not be modified as part of this
milestone.

## Devil's Advocate

The core problem is real because users need to explore different priorities,
and the current SPI custom-weights page demonstrates an established use case.
The simplest viable solution is still only five controls and one pure weighted
average; adding dimensions, multiple countries, or saved scenarios would
increase risk without being necessary for the first release.

The main methodological risk is false equivalence with the official SPI. The
interface must distinguish official and user-weighted values, avoid ranking
claims, document the missing-data renormalization, and test the arithmetic
independently from the UI. This approach aligns with the project charter's
requirements to use `spiR`, preserve missingness, and keep provider logic
separate from Golem modules.

## Next Steps

- Define a pure helper contract for validating weights and calculating the
  weighted pillar result.
- Confirm normalized pillar names and labels from the shared provider snapshot.
- Build the Explore by Pillar Golem module around injected snapshot data.
- Add deterministic tests for equal weights, valid custom weights, invalid
  totals, zero weights, missing pillars, and all-pillars-missing states.
- Add a focused browser smoke check for country/year selection, weight total
  validation, reset behavior, and official-versus-custom labeling.
- Keep dimensions, indicators, multi-country comparison, rankings, saved
  scenarios, and external data out of this milestone.
