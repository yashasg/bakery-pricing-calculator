---
name: "swiftui-wheel-picker-sheet"
description: "Tap-to-present iOS wheel picker in a half-sheet with a keyboard-fallback path for decimal inputs"
domain: "ios-ui, swiftui, accessibility"
confidence: "low"
source: "observed"
---

## Context

When a numeric input field needs the iOS slot-machine wheel UX (`Picker(.wheel)`) but an
always-visible wheel takes too much vertical space (≥200pt per field × N fields = unusable),
use a **tap-to-open half-sheet** pattern:

- The field renders as a compact pill/button showing the current value.
- One tap presents a bottom sheet containing the wheel.
- An optional "Type" toggle inside the sheet swaps the wheel for a `TextField(.decimalPad)`,
  preserving fractional inputs.

This pattern appeared first in the `GaugeWheelField` component (Edison-8, 2026-05-20).

## Patterns

### 1. Field button (tap target)

```swift
Button {
    wheelSelection = currentIntValue   // seed from current text
    typeText = text                    // seed keyboard fallback
    isTypeMode = false
    isPickerShowing = true
} label: {
    HStack {
        Text(value)          // prominent numeric display
        Text(unitSuffix)     // inline suffix ("st", "ro")
        Spacer(minLength: 4)
        Image(systemName: "chevron.down")  // iOS affordance
    }
    .frame(minHeight: 44)
    // … pill styling …
}
.accessibilityHint("Double-tap to change value, opens picker")
.accessibilityAdjustableAction { direction in
    // swipe-up/down still works WITHOUT opening sheet
    switch direction {
    case .increment: value = "\(clamped(current + 1))"
    case .decrement: value = "\(clamped(current - 1))"
    @unknown default: break
    }
}
.sheet(isPresented: $isPickerShowing) {
    WheelPickerSheet(...)
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
}
.onChange(of: wheelSelection) { _, newValue in
    if isPickerShowing && !isTypeMode { value = "\(newValue)" }
}
```

### 2. Half-sheet content

```swift
VStack(spacing: 0) {
    HStack {
        Button(isTypeMode ? "Wheel" : "Type") { isTypeMode.toggle() }
            .accessibilityIdentifier("wheel-picker-type-toggle")
        Spacer()
        Button("Done") { onCommit(committedValue) }
            .accessibilityIdentifier("wheel-picker-done")
    }
    Divider()
    if isTypeMode {
        TextField(title, text: $typeText)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier("wheel-picker-type-field")
    } else {
        Picker(title, selection: $wheelSelection) {
            ForEach(1...99, id: \.self) { Text("\($0) \(unit)").tag($0) }
        }
        .pickerStyle(.wheel)
    }
}
.presentationDetents([.height(320)])
```

### 3. Commit semantics

- **Live**: `.onChange(of: wheelSelection)` writes the bound state while the sheet is open.
- **Done tap**: commits the current wheel or typed value; dismisses the sheet.
- **Swipe-down / tap-outside**: `isPresented` binds to sheet so swipe-down also dismisses
  (committing the live wheel value, since it was already written).

### 4. Binding type choice

Keep the existing binding type (`String`) when the upstream state uses Strings.
Use a new helper (`[DomainMath].parseGaugeTypeText`) to normalise decimal inputs from the keyboard fallback. Don't widen upstream bindings unless the domain genuinely needs `Double` storage.

### 5. XCTest interaction

```swift
// ✅ Correct: use adjust(toPickerWheelValue:)
let picker = app.pickerWheels.firstMatch
picker.adjust(toPickerWheelValue: "32 st")
let doneBtn = app.buttons["wheel-picker-done"]
tapElement(doneBtn)

// ❌ Avoid: type-mode in UI tests — keyboard covers Done button
//    Test decimal parsing at the unit level instead.
```

The field is a `Button` in the accessibility tree. Use `app.buttons["identifier"]`, not
`app.textFields["identifier"]`.

## Anti-Patterns

- **Always-visible `Picker(.wheel)`** — takes 200pt per field; N fields × 200pt = layout
  disaster on compact phones. Always hide it behind a sheet.
- **Deferred commit on Done only** — users expect the background UI to update as they spin
  the wheel. Live update is the standard iOS pattern; deferred makes the field feel broken.
- **Keyboard fallback in UI tests** — typing in a sheet's `TextField` triggers the keyboard,
  which can cover the sheet's Done button (since the sheet height is fixed). Test the parsing
  logic in unit tests; test the wheel itself via `adjust(toPickerWheelValue:)`.
- **Adding `.accessibilityAdjustableAction` to break the button trait** — in practice SwiftUI
  preserves `.isButton` when `.accessibilityAdjustableAction` is added, but put the
  adjustable action on the button itself (not a wrapper) and verify with `app.buttons` in tests.
- **Sheet height `.medium` (50%+)** — too tall for a single wheel field. Use `.height(320)`
  for a single-column wheel + header row. Adjust if multiple columns are needed.
