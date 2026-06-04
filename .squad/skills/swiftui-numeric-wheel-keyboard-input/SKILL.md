---
name: "SwiftUI Numeric Wheel + Keyboard Input Field"
description: "How to implement a numeric input field that shows a UIPickerView wheel (in the keyboard slot) instead of the system keyboard, with a fallback to typed decimal entry, in a SwiftUI app via UIViewRepresentable"
domain: "iOS UI patterns, SwiftUI/UIKit interop, accessibility"
confidence: "low"
source: "observed — researched from Apple HIG, first-party app behavior, and UIKit API docs on 2026-05-20"
---

## Context

When a SwiftUI input field must support:
- A tactile wheel picker for common integer values (e.g. 1–99)
- Decimal entry for edge-case values (e.g. 22.5)
- VoiceOver `.adjustable` trait without leaving the field
- Card-surface layout (not full-screen, not a sheet)

…the correct iOS pattern is `UITextField` with `inputView = UIPickerView` + `inputAccessoryView = UIToolbar`. This replaces the system keyboard with a wheel in the standard keyboard slot. SwiftUI's `Picker(.wheel)` cannot implement this pattern — `UIViewRepresentable` is required.

## Patterns

### Core pattern: UITextField as the first-responder host

```
UITextField
├── inputView         = UIPickerView   (replaces keyboard)
├── inputAccessoryView = UIToolbar      (sits above picker/keyboard)
│   ├── Left:  "Keyboard" UIBarButtonItem → swaps inputView to nil + decimalPad
│   └── Right: "Done" UIBarButtonItem   → resignFirstResponder
└── (first responder cycle drives slide-up animation — same as keyboard)
```

### Two-component picker for integer + fraction

For a value like 22.5, use two UIPickerView components:
- Component 0: integers (e.g. 1...99)
- Component 1: fractions — keep small: `["—", ".5"]` for app; `["0","1","2"..."9"]` for general decimal

The fewer fraction rows, the faster and more precise the interaction.

### UITextField subclass for VoiceOver `.adjustable`

`UIPickerView` used as `inputView` does NOT automatically expose the `.adjustable` trait on the host UITextField. Must be explicitly added:

```swift
final class GaugePickerTextField: UITextField {
    weak var coordinator: Coordinator?

    override var accessibilityTraits: UIAccessibilityTraits {
        get { super.accessibilityTraits.union(.adjustable) }
        set { super.accessibilityTraits = newValue }
    }
    override func accessibilityIncrement() { coordinator?.incrementValue() }
    override func accessibilityDecrement() { coordinator?.decrementValue() }
}
```

Coordinator's `incrementValue()` / `decrementValue()` call `pickerView.selectRow(...)` on the integer component and write the new value to `@Binding`.

### Mode switch: picker → keyboard

```swift
@objc func toggleInputMode(_ sender: UIBarButtonItem) {
    isPickerMode.toggle()
    if isPickerMode {
        textField.inputView = pickerView
        sender.title = "Keyboard"
    } else {
        textField.inputView = nil
        textField.keyboardType = .decimalPad
        sender.title = "Picker"
    }
    textField.reloadInputViews()
    // Restore VoiceOver focus after reload:
    UIAccessibility.post(notification: .layoutChanged, argument: textField)
}
```

### @Binding flow (SwiftUI ↔ UIKit)

```
SwiftUI @State String  ←→  GaugeWheelField (bridges String ↔ Double)
                        ↕
UIViewRepresentable @Binding Double
                        ↕  (Coordinator: didSelectRow / textFieldDidEndEditing)
UIPickerView / UITextField.text
```

Keep SwiftUI state as `String` if the rest of the app uses strings; bridge to `Double` inside the wrapper.

### Input accessory view (keyboard dismissal)

Always provide a `UIToolbar` with at minimum a "Done" button. This is the only dismissal path for `.decimalPad` (which has no Return key). Without it, VoiceOver users and Switch Control users cannot dismiss the keyboard.

## Examples

**Applied in:** `GaugeWheelField` replacing `GaugeStepperField` in `ContentView.swift`, planned for Edison-9.

**Apple first-party examples:**
- Health app: weight entry (picker-only, no keyboard fallback)
- Contacts app: field label selector (picker-only)
- Settings app: Apple ID birthday (UIDatePicker as inputView)

## Anti-Patterns

- **Half-sheet with Picker + toggle button:** A `.sheet` or `.presentationDetents` is a modal presentation. It traps VoiceOver focus, covers content, and has no Apple precedent for a simple numeric field. The HIG says pickers appear "at the bottom of the screen" — in the keyboard slot, not a sheet.

- **Inline SwiftUI `Picker(.wheel)` always visible on card:** Takes ~150pt height per field. No path to `inputAccessoryView` or keyboard fallback. The `.wheel` pickerStyle in SwiftUI does not participate in the `inputView`/first-responder cycle.

- **Popover with Done (iPad pattern):** Inappropriate for iPhone-width layouts. On iPhone, popovers become full-screen sheets. VoiceOver must navigate in and out of modal focus separately.

- **Assuming `.adjustable` is automatic on inputView pickers:** It is not. The UITextField does not inherit `.adjustable` from its `inputView`. Must be explicitly subclassed and wired.

- **Calling `reloadInputViews()` without posting `.layoutChanged` to VoiceOver:** The mode switch animation completes but VoiceOver does not know the layout changed. Always post `UIAccessibility.post(notification: .layoutChanged, argument: textField)` after `reloadInputViews()`.
