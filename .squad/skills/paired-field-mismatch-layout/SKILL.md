---
name: "paired-field-mismatch-layout"
description: "Keep side-by-side compact form fields visually equal when only one shows mismatch, without adding row height"
domain: "ios-ui, ui-ux, accessibility"
confidence: "highest"
source: "validated"
---

## Context

When two compact inputs are presented as a comparison pair, users read them as one unit. If one field gains warning state and the row gets taller, the layout may stay technically correct but still violate the product’s vertical-space budget.

## Superseded pattern

The earlier recommendation to place mismatch text **below** the affected field and let the pair grow vertically is **superseded for vertically constrained surfaces** like `YourGaugeCard`.

Why it is superseded:
- it consumes vertical real estate in a dense calculator
- it becomes harder, not easier, at AX sizes
- the product constraint here is fixed row footprint, not flexible card height

## Current pattern

### 1. Pair invariants

- Keep **equal column widths** in side-by-side layout.
- Preserve the compact-field floor of **140 pt minimum per column** in non-accessibility sizes.
- At accessibility text sizes, **stack fields vertically** and let each take full width.
- Mismatch state must **not** add a new line above or below the field row.

### 2. Warning placement

- Keep the field title visible (`Rows`, `Stitches`).
- Keep the mismatch border.
- Put the warning symbol **inside the existing trailing accessory / picker area** instead of adding a new row.
- Reuse the existing **44×44** picker button if the warning affordance is interactive.
- Use **SF Symbols** (`exclamationmark.triangle.fill`) rather than custom assets.
- Put the full mismatch sentence in accessibility metadata and in the field’s existing modal / picker surface, not below the field.

### 3. Accessibility rules

- Warning state must use **more than color**: border + symbol + spoken warning.
- VoiceOver should expose mismatch on the field’s spoken **value/hint**, not as a separate helper-text focus stop.
- Keep focus order unchanged: **field → picker button → next control**.
- On dismissing the modal / picker surface, return focus to the originating button.
- Speak natural-language units (`rows`, `stitches`), not internal abbreviations (`ro`, `st`).
- At AX5, prefer a sheet or larger presentation surface for the long warning sentence; do not push that sentence back into the field row.

## Anti-patterns

- One field appearing visually narrower than its paired sibling
- Any reserved or conditional below-field mismatch slot on a height-constrained card
- Replacing the visible field title with a long warning sentence
- Moving the only visible warning summary to distant card-header chrome
- Tiny tappable warning badges smaller than **44×44 pt**
- Icon-only warning state with no spoken error text

## Validation note

Validated on 2026-05-21T14:09:26-07:00 in `GaugeStepperField` + `GaugeMeasurementPair`: equal-width pair stayed stable, downstream card position stayed fixed across `none / stitches / rows / both`, and the full mismatch sentence moved into accessibility + the wheel sheet without reintroducing a new focus stop.

## References

- Apple Human Interface Guidelines: Layout, Controls, SF Symbols, Dynamic Type, VoiceOver, Switch Control, Touch Targets
- WCAG 2.2: 1.3.1 Info and Relationships, 1.4.1 Use of Color, 1.4.4 Resize Text, 1.4.10 Reflow, 2.4.3 Focus Order, 2.5.8 Target Size (Minimum), 3.3.1 Error Identification, 3.3.3 Error Suggestion
