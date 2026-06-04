# Skill: SwiftUI equal-width inline errors

**Slug:** `swiftui-equal-width-inline-errors`
**Author:** Edison
**Date:** 2026-05-21T12:33:05-07:00

## Problem

A row contains two peer SwiftUI fields, but only one field may show inline validation text below it. A plain `HStack` with `.frame(maxWidth: .infinity)` on each child does **not** guarantee equal widths once one side reports a larger ideal size.

## Solution

Use an explicit equal-column container for the row at non-accessibility sizes, and keep the inline error message conditional below the offending field.

- Non-accessibility sizes: `LazyVGrid` with two `GridItem(.flexible(minimum: 0))` columns
- Accessibility sizes: fall back to a vertical `VStack`
- Keep the mismatch/error text visible, wrapped, and attached to the offending field
- Verify all four states: no error, left-only, right-only, both

## Example

```swift
private var columns: [GridItem] {
    [
        GridItem(.flexible(minimum: 0), spacing: spacing),
        GridItem(.flexible(minimum: 0)),
    ]
}

if dynamicTypeSize.isAccessibilitySize {
    VStack(alignment: .leading, spacing: spacing) {
        leading().frame(maxWidth: .infinity, alignment: .topLeading)
        trailing().frame(maxWidth: .infinity, alignment: .topLeading)
    }
} else {
    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
        leading().frame(maxWidth: .infinity, alignment: .topLeading)
        trailing().frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
```

## Why it works

The grid owns the two columns, so sibling intrinsic sizes no longer negotiate the width. Inline error copy can increase row height, but it cannot steal horizontal space from the other field.

## Anti-patterns

- `HStack` + `.frame(maxWidth: .infinity)` and assuming that means equal widths
- Moving error text out of the row just to avoid layout pressure
- Verifying only one error state; paired-field layouts need `none` / `left` / `right` / `both`
