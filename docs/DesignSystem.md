# Hearth Design System — SwiftUI Agent Reference

A single-file reference for building Hearth iOS utility apps in SwiftUI.
Read this and you have everything you need.

---

## What Hearth is

A design system for a family of **single-purpose iOS 26 utility apps** (timers, trackers, converters, habit tools, etc.). Each app:

- Has its **own accent color** — the one value that makes it feel distinct.
- Uses iOS 26 **"Liquid Glass"** materials and Human Interface Guidelines throughout.
- Is **dark-mode first** (dark required; same semantic colors handle light automatically).
- Sets body/display type in **Satoshi**; falls back to the system font where Satoshi is unavailable.
- Uses **SF Symbols** exclusively for all icons.

The system's core premise: **one `Color` value changes per app (`appAccent`); everything else is shared.**

---

## Typeface

**Satoshi** (variable, 300–900 weight). Include `Satoshi-Variable.ttf` and `Satoshi-VariableItalic.ttf` in the app bundle and declare them in `Info.plist` under `UIAppFonts`.

### Dynamic Type — the critical rule

Always pass `relativeTo:` when declaring custom font sizes. This makes Satoshi scale with the user's accessibility text size setting, exactly like SF Pro. **Never** call `.custom("Satoshi-Variable", size: 17)` without `relativeTo:` — it will stay frozen at that point regardless of accessibility settings.

```swift
extension Font {
    // The correct pattern — relativeTo: links each custom size to a system
    // text style so it scales in lockstep with Dynamic Type.
    static func satoshi(_ size: CGFloat, relativeTo style: TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom("Satoshi-Variable", size: size, relativeTo: style).weight(weight)
    }

    // Apple text-style equivalents — all Dynamic Type aware
    static let appLargeTitle = satoshi(34, relativeTo: .largeTitle,  weight: .bold)
    static let appTitle1     = satoshi(28, relativeTo: .title,       weight: .bold)
    static let appTitle2     = satoshi(22, relativeTo: .title2,      weight: .bold)
    static let appTitle3     = satoshi(20, relativeTo: .title3,      weight: .semibold)
    static let appHeadline   = satoshi(17, relativeTo: .headline,    weight: .semibold)
    static let appBody       = satoshi(17, relativeTo: .body)
    static let appCallout    = satoshi(16, relativeTo: .callout)
    static let appSubhead    = satoshi(15, relativeTo: .subheadline)
    static let appFootnote   = satoshi(13, relativeTo: .footnote)
    static let appCaption1   = satoshi(12, relativeTo: .caption)
    static let appCaption2   = satoshi(11, relativeTo: .caption2,    weight: .medium)
}
```

Satoshi runs slightly tighter than SF Pro. Apply negative `tracking` on display sizes:

```swift
// Tracking values by text style
extension View {
    func appTracking(_ style: Font.TextStyle) -> some View {
        switch style {
        case .largeTitle: return self.tracking(-0.4) as! Self // -0.4
        case .title:      return self.tracking(-0.3) as! Self
        case .title2:     return self.tracking(-0.2) as! Self
        case .title3, .headline: return self.tracking(-0.1) as! Self
        default:          return self.tracking(0) as! Self
        }
    }
}

// Or inline — most common usage:
Text("Today").font(.appLargeTitle).tracking(-0.4)
Text("Settings").font(.appTitle2).tracking(-0.2)
```

For **live-updating numbers** (timers, counters): use `.monospacedDigit()` so digits don't shift width as they change.

---

## Accent System

**There is no system default accent.** Every app defines its own by injecting one value into the environment. Use this pattern:

```swift
// In each app's root view:
ContentView()
    .environment(\.appAccent, Color(red: 1, green: 0.584, blue: 0.039)) // amber

// Environment key
struct AppAccentKey: EnvironmentKey {
    static let defaultValue: Color = .orange // fallback only
}
extension EnvironmentValues {
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

// Usage anywhere in the tree:
@Environment(\.appAccent) var accent
```

**Accent palette** — pick one per app:

| Name | SwiftUI Color |
|---|---|
| Amber | `Color(red: 1.00, green: 0.584, blue: 0.039)` |
| Coral | `Color(red: 1.00, green: 0.322, blue: 0.353)` |
| Green | `Color(red: 0.188, green: 0.820, blue: 0.588)` |
| Blue | `Color(red: 0.039, green: 0.518, blue: 1.000)` |
| Indigo | `Color(red: 0.369, green: 0.361, blue: 0.902)` |
| Pink | `Color(red: 1.000, green: 0.216, blue: 0.373)` |

**Use the accent sparingly:** one primary CTA button, selected tab item, toggle tint, and key glyphs. Color is a spotlight, not wallpaper.

### Light mode — use Asset Catalog color pairs

A hardcoded `Color(red:green:blue:)` stays the same in both modes. For most accents this is fine (vivid colors read well on both black and white), but always check contrast (see Accessibility section). If the same hue needs to be different in light mode, define it as an Asset Catalog color:

```
// In Assets.xcassets → New Color Set → name it e.g. "AppAccentAmber"
// Any: rgb(255, 149, 10)
// Dark: rgb(255, 149, 10)   ← same here; adjust light value if needed
```

```swift
// Then reference it type-safely:
extension Color {
    static let accentAmber  = Color("AppAccentAmber")
    static let accentCoral  = Color("AppAccentCoral")
    // etc.
}

// Inject at root:
ContentView().environment(\.appAccent, .accentAmber)
```

For most Hearth accents the same vivid value works on both backgrounds. The ones to watch: **Amber** and **Yellow** may need a darker variant (−20% brightness) for light mode to maintain contrast on white.

---

## Color — Semantic Tokens

Always use **semantic system colors** so dark/light mode works automatically. Never hardcode hex/rgb values for UI elements.

```swift
// Labels
Color.primary                    // --label
Color.secondary                  // --label-secondary
Color(uiColor: .tertiaryLabel)   // --label-tertiary
Color(uiColor: .quaternaryLabel) // --label-quaternary

// Backgrounds
Color(uiColor: .systemBackground)           // base screen
Color(uiColor: .secondarySystemBackground)  // cards, raised surfaces
Color(uiColor: .tertiarySystemBackground)   // nested

// Grouped (lists / settings)
Color(uiColor: .systemGroupedBackground)
Color(uiColor: .secondarySystemGroupedBackground)  // inset list group bg
Color(uiColor: .tertiarySystemGroupedBackground)

// Fills
Color(uiColor: .systemFill)
Color(uiColor: .secondarySystemFill)
Color(uiColor: .tertiarySystemFill)    // search fields, steppers
Color(uiColor: .quaternarySystemFill)  // hover/press wash

// Separators
Color(uiColor: .separator)       // hairline dividers
Color(uiColor: .opaqueSeparator)
```

### System vivid colors — semantic use ONLY (not decoration)

```swift
Color.red     // destructive actions
Color.orange  // caution, energy
Color.yellow  // warnings
Color.green   // success, completion
Color.mint
Color.teal
Color.cyan
Color.blue
Color.indigo
Color.purple
Color.pink
Color.brown
```

---

## Materials (Liquid Glass)

Use SwiftUI `.background(.ultraThinMaterial)` / `.thinMaterial` / `.regularMaterial` / `.thickMaterial` for glass surfaces.

```swift
// Tab bar / nav bar (floating over content)
.background(.regularMaterial)

// Bottom sheet
.background(.thickMaterial)

// Context menus, popovers
.background(.thickMaterial)

// Glass stroke (top hairline) on floating bars:
.overlay(alignment: .top) {
    Rectangle()
        .frame(height: 0.5)
        .foregroundStyle(.white.opacity(0.10))
}
```

**When to use materials:** floating tab bar, nav bar (scroll-edge), sheets, popovers, alerts, menus.
**Flat `Color` fills:** page content cards, list group backgrounds, inset rows. Never glass on static content.

---

## Elevation / Shadows

**Shadows appear ONLY on floating UI.** Page content has no shadow.

```swift
// Floating elements (tab bar, FAB)
.shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 8)
.shadow(color: .black.opacity(0.30), radius: 8, x: 0, y: 2)

// Sheets (cast upward)
.shadow(color: .black.opacity(0.55), radius: 60, x: 0, y: -24)

// Popovers / context menus
.shadow(color: .black.opacity(0.55), radius: 40, x: 0, y: 12)
```

List rows, cards, and in-flow buttons have **no shadow** — separate them with hairlines and fills.

---

## Corner Radii (concentric)

Corner radii are **fixed geometric values** — they intentionally don't scale with text size (a card is still a card at any font size). Inner controls use a smaller radius than their container so corners nest evenly.

```swift
// Define once as constants — do NOT use @ScaledMetric here.
enum Radius {
    static let xs:  CGFloat = 6    // tags, small chips
    static let sm:  CGFloat = 10
    static let md:  CGFloat = 14   // standard controls: fields, steppers
    static let lg:  CGFloat = 20   // cards, inset list groups
    static let xl:  CGFloat = 28   // sheets, large surfaces
    // Pill / capsule → use .capsule shape or RoundedRectangle(cornerRadius: 999)
}
```

For continuous ("squircle") curves matching iOS app icons and cards:
```swift
.clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
```

---

## Spacing (4pt grid)

Fixed layout spacing (screen margins, section gaps) stays constant — it's structural, not typographic. Use `@ScaledMetric` only for spacing that is **directly tied to text size**, like the padding inside a text-bearing control.

```swift
// Fixed structural spacing — plain constants
enum Spacing {
    static let tight:  CGFloat = 8    // gap between tightly related elements
    static let inner:  CGFloat = 12   // padding inside controls
    static let margin: CGFloat = 16   // standard screen edge margin
    static let gap:    CGFloat = 20
    static let section:CGFloat = 24   // space between list sections
    static let loose:  CGFloat = 32
    static let target: CGFloat = 44   // minimum tap target — never go smaller
}

// Spacing that should grow with text — use @ScaledMetric
// Example: vertical padding inside a custom text field
struct MyTextField: View {
    @ScaledMetric(relativeTo: .body) private var verticalPad: CGFloat = 12
    // ...
}
```

**Layout rules:**
- Screen edge margin: `Spacing.margin` (16pt) — fixed
- Inset list groups: `Spacing.margin` from screen edges, `Radius.lg` continuous corner radius
- Tab bar: floating, centered, ≥18pt bottom margin (above home indicator) — fixed
- All interactive elements: minimum 44×44pt tap target (`Spacing.target`) — fixed HIG floor

---

## Motion

Use SwiftUI's built-in animations. Match these personalities:

```swift
// Most transitions (nav push, tab switch, fades)
.animation(.easeInOut(duration: 0.28), value: someState)

// Toggles, selection, sheet appearance — gentle spring
.animation(.spring(response: 0.4, dampingFraction: 0.7), value: someState)

// Press feedback — fast
.scaleEffect(isPressed ? 0.96 : 1.0)
.animation(.easeInOut(duration: 0.18), value: isPressed)
```

**Press feedback:**
- Filled buttons/cards: `.scaleEffect(0.96)` on press
- Plain text buttons: `.opacity(0.7)` on press
- Switches: spring to new position (system `Toggle` handles this)
- Row highlights: `Color(uiColor: .systemFill)` overlay on press

---

## Components

### Button styles

```swift
// Filled — ONE per screen (primary CTA)
Button("Add reminder") { }
    .buttonStyle(.borderedProminent)
    .tint(accent)
    .font(.appHeadline)
    .controlSize(.large)            // system scales internally

// Tinted — secondary
Button("Snooze") { }
    .buttonStyle(.bordered)
    .tint(accent)

// Plain — most common (lowest visual weight)
Button("Cancel") { }
    .buttonStyle(.plain)
    .foregroundStyle(accent)

// Circular glass (toolbar / floating action)
// @ScaledMetric ties the tap-target size to the body text style
struct GlassCircleButton: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 38
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)   // scales with Dynamic Type; no hardcoded size
                .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .background(.regularMaterial, in: Circle())
    }
}
```

### Toggle (Switch)

```swift
Toggle("Repeat weekly", isOn: $isOn)
    .tint(accent)  // accent color on track
```

### Segmented control

```swift
Picker("Range", selection: $range) {
    Text("Week").tag("week")
    Text("Month").tag("month")
}
.pickerStyle(.segmented)
```

### Stepper

```swift
Stepper("Times per day: \(count)", value: $count, in: 1...12)
```

### Search field

```swift
List {
    // ...
}
.searchable(text: $query, prompt: "Search")
```

Or for inline (padding scales with body text):
```swift
struct InlineSearchField: View {
    @Binding var query: String
    @ScaledMetric(relativeTo: .body) private var verticalPad: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var horizontalPad: CGFloat = 12

    var body: some View {
        TextField("Search", text: $query)
            .font(.appBody)
            .padding(.vertical, verticalPad)
            .padding(.horizontal, horizontalPad + 22) // leave room for icon
            .background(Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(alignment: .leading) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)   // scales; no hardcoded size
                    .foregroundStyle(.tertiary)
                    .padding(.leading, horizontalPad)
            }
    }
}
```

### Inset grouped list

Icon chip size scales with body text via `@ScaledMetric` so the chip stays proportional at all accessibility sizes.

```swift
// Reusable icon chip — size tracks body text style
struct IconChip: View {
    let systemName: String
    let color: Color
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat  = 15

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color)
            .frame(width: chipSize, height: chipSize)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}

List {
    Section {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Morning routine").font(.appBody)
                Text("Every day · 7:00 AM").font(.appFootnote).foregroundStyle(.secondary)
            }
        } icon: {
            IconChip(systemName: "bell.fill", color: .orange)
        }
    } header: {
        Text("Reminders")  // auto-uppercased by List
    } footer: {
        Text("Habits reset each morning at 4:00 AM.")
    }
}
.listStyle(.insetGrouped)
```

### Large-title navigation

```swift
NavigationStack {
    List { /* ... */ }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { } label: {
                    Image(systemName: "plus")
                }
            }
        }
}
```

### Tab bar

Standard SwiftUI `TabView` on iOS 26 automatically adopts the floating glass tab bar:

```swift
TabView(selection: $selectedTab) {
    TodayView()
        .tabItem { Label("Today", systemImage: "sun.max.fill") }
        .tag(0)
    InsightsView()
        .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
        .tag(1)
    SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag(2)
}
.tint(accent)  // selected tab item inherits accent
```

### Bottom sheet

```swift
.sheet(isPresented: $showAdd) {
    AddHabitView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
}
```

### Context menu

```swift
.contextMenu {
    Button("Edit") { }
    Button("Duplicate") { }
    Button("Pin to top") { }
    Divider()
    Button("Delete", role: .destructive) { }  // red, always last
}
```

### Progress ring

Ring size tracks the body text style. Pass `relativeTo:` so it grows proportionally at larger accessibility sizes.

```swift
struct ProgressRing: View {
    var value: Double  // 0–1
    var lineWidth: CGFloat = 5
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 52
    @Environment(\.appAccent) var accent

    var body: some View {
        let radius = (diameter - lineWidth) / 2
        let circumference = 2 * .pi * radius
        ZStack {
            Circle()
                .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value)
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
        }
        .frame(width: diameter, height: diameter)
    }
}
```

---

## Iconography

Use **SF Symbols exclusively** for all UI icons.

```swift
// Let the font drive the size — match adjacent text style, never hardcode
Image(systemName: "bell.fill")
    .font(.appBody)          // matches body text; scales with Dynamic Type

// For toolbar symbols — match headline weight
Image(systemName: "plus")
    .font(.headline)
    .fontWeight(.semibold)

// Hierarchical rendering (icon adapts to background)
Image(systemName: "bell.fill")
    .symbolRenderingMode(.hierarchical)
    .font(.appBody)

// Tinted with accent
Image(systemName: "star.fill")
    .font(.appBody)
    .foregroundStyle(accent)

// Leading icon chip in a list row — use the IconChip component above.
// It handles @ScaledMetric sizing; never hardcode width/height directly
// on an Image(systemName:) inside a chip.
IconChip(systemName: "bell.fill", color: .orange)
```

**Rules:**
- **Never** set `.font(.system(size: N))` on a symbol used next to text — use a text style (`.font(.headline)`, `.font(.body)`, etc.) so the symbol scales with the user's preferred size
- Filled symbols (`*.fill`) for selected tab items and list glyphs on colored chips
- Outline symbols for toolbars and secondary actions
- Never custom PNG icons for standard UI glyphs
- Never emoji as UI icons

---

## Copy / Voice

**In one line:** a competent friend who respects your time.

| Rule | Correct | Wrong |
|---|---|---|
| Sentence case everywhere | `Add reminder` | `Add Reminder` |
| Verbs for buttons | `Save` / `Start` / `Done` | `Click here to save` |
| Nouns for titles | `Today` / `Settings` | `Your Today View` |
| Short empty states | `Nothing due today. Enjoy it.` | `You have no tasks! 🎉` |
| Destructive confirm | `Delete 3 items?` | `Are you sure you want to delete?` |
| Numerals always | `3 items` / `2 min` | `three items` |
| Errors: warm + next step | `Couldn't sync. Retrying shortly.` | `Error 0x4: sync failed` |

- **No exclamation marks** in regular chrome (one allowed in a genuine celebration — use it once a year)
- **No "we"** in UI — refer to the app by name, or use "you"
- **No emoji** in product UI
- **Ellipsis (…)** only for truncation or a menu item that opens further UI
- **Buttons are verbs.** Titles are nouns.

---

### Swipe actions

```swift
Row(icon: "bell.fill", title: "Morning routine")
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        Button(role: .destructive) { delete() } label: {
            Label("Delete", systemImage: "trash")
        }
        Button { snooze() } label: {
            Label("Snooze", systemImage: "alarm")
        }
        .tint(accent)
    }
    .swipeActions(edge: .leading) {
        Button { pin() } label: {
            Label("Pin", systemImage: "pin")
        }
        .tint(.yellow)
    }
```

Rules: destructive action always trailing-most, full-swipe enabled only for delete, leading swipe for non-destructive shortcuts only.

---

### Empty state

Use when a list or screen has no content yet. Centered, minimal — one symbol, one line of context, optional CTA.

```swift
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String?
    let action: (label: String, handler: () -> Void)?
    @Environment(\.appAccent) var accent

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))   // display — not body text, fixed OK
                .foregroundStyle(accent.opacity(0.6))
            Text(title).font(.appTitle3).multilineTextAlignment(.center)
            if let message {
                Text(message).font(.appBody).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let action {
                Button(action.label, action: action.handler)
                    .buttonStyle(.borderedProminent).tint(accent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Usage
EmptyState(
    systemImage: "checkmark.circle",
    title: "Nothing due today.",
    message: "Enjoy it.",
    action: ("Add habit", { showAdd = true })
)
```

---

### Loading & error states

```swift
// Loading — use .redacted for skeleton screens
List { ForEach(0..<5, id: \.self) { _ in PlaceholderRow() } }
    .redacted(reason: isLoading ? .placeholder : [])
    .allowsHitTesting(!isLoading)

// Inline spinner (e.g. button loading state)
if isLoading {
    ProgressView().tint(accent)
} else {
    Button("Sync") { sync() }
}

// Error — reuse EmptyState with a retry CTA
if let error {
    EmptyState(
        systemImage: "exclamationmark.triangle",
        title: "Couldn't load.",
        message: "Check your connection.",
        action: ("Try again", { retry() })
    )
}
```

---

### Toast / confirmation

iOS has no native toast. Use a floating pill anchored above the tab bar, auto-dismissed after 2 s.

```swift
struct Toast: View {
    let message: String
    @ScaledMetric(relativeTo: .body) private var hPad: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var vPad: CGFloat = 10

    var body: some View {
        Text(message)
            .font(.appSubhead).fontWeight(.medium)
            .padding(.horizontal, hPad).padding(.vertical, vPad)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}

// Attach to root view; overlay above tab bar safe area
.overlay(alignment: .bottom) {
    if showToast {
        Toast(message: "Saved")
            .padding(.bottom, 90)        // above floating tab bar
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.spring(response: 0.35, dampingFraction: 0.8), value: showToast)
// Dismiss: DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
```

---

## Haptics

Fire haptics at meaningful moments — never decoratively.

```swift
// Selection change (tab switch, row tap, toggle)
UISelectionFeedbackGenerator().selectionChanged()

// Action success (habit checked off, item saved)
UINotificationFeedbackGenerator().notificationOccurred(.success)

// Action warning (can't delete last item)
UINotificationFeedbackGenerator().notificationOccurred(.warning)

// Action failure / error
UINotificationFeedbackGenerator().notificationOccurred(.error)

// Physical impact (delete swipe, sheet snap)
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
// .light for subtle (reorder row), .rigid for sharp (timer start)
```

Wrap in a helper and gate on the "Haptics" user preference:
```swift
func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    guard prefs.haptics else { return }
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
```

---

## Accessibility

### Contrast
Check every accent against both backgrounds before shipping. Minimum ratios (WCAG AA):
- Body text on background: **4.5 : 1**
- Large text (≥18pt bold or ≥24pt): **3 : 1**
- UI components / icons: **3 : 1**

Amber `rgb(255,149,10)` passes on dark (#000) but **fails on white** — use a darker light-mode variant (`rgb(185,105,0)`) in the Asset Catalog pair.

### VoiceOver essentials

```swift
// Custom component — describe what it IS and what it DOES
ProgressRing(value: 0.6)
    .accessibilityLabel("Progress ring")
    .accessibilityValue("60 percent complete")

// Icon chip button — label the action, not the icon name
IconChip(systemName: "bell.fill", color: .orange)
    .accessibilityLabel("Morning routine reminder")
    .accessibilityAddTraits(.isButton)

// Decorative elements — hide from VoiceOver
Image(systemName: "chevron.right")
    .accessibilityHidden(true)

// Group a row's text so VoiceOver reads it as one element
VStack { Text(title); Text(subtitle) }
    .accessibilityElement(children: .combine)
```

### Minimum targets
All interactive elements: `frame(minWidth: 44, minHeight: 44)`. SwiftUI system controls handle this automatically; custom views must do it explicitly.

---

## App icon

Each Hearth app's icon should be:
- **Simple SF Symbol** (or close derivative) centered on a solid colored background
- Background = the app's accent color (gives instant visual identity in a grid of apps)
- Use Apple's **1024×1024 source** in Assets.xcassets → AppIcon; Xcode generates all sizes
- Corner radius is applied by the OS — don't pre-round the source asset
- The symbol should be **white, no shadow**, at ~40% of the icon canvas width
- Test at 60×60 (Home Screen) and 120×120 (@2x) — must read at small size

```
// Rough layout: accent bg + white SF Symbol centered, symbol ~400px on 1024px canvas
// Keep it cleaner than you think is necessary — complexity disappears at small sizes
```

---

## iPad

On iPad, `TabView` becomes a sidebar automatically (iOS 18+). Support it with `.tabViewStyle(.sidebarAdaptable)`:

```swift
TabView(selection: $tab) { /* same as iPhone */ }
    .tabViewStyle(.sidebarAdaptable)
    .tint(accent)
```

For layout-adaptive views, use `@Environment(\.horizontalSizeClass)`:
```swift
@Environment(\.horizontalSizeClass) var hSizeClass

var body: some View {
    if hSizeClass == .regular {
        // iPad: two-column or wider layout
    } else {
        // iPhone: single column
    }
}
```

Pointer hover (iPad with trackpad/mouse): SwiftUI handles most hover states automatically with `.buttonStyle(.bordered)` etc. For custom rows add `.hoverEffect(.highlight)`.

---

## What NOT to do

- ❌ Decorative gradients on backgrounds (flat system colors only)
- ❌ Photographic hero imagery in app UI
- ❌ Shadows on flat page content (only floating UI gets shadows)
- ❌ Colored borders around cards
- ❌ Materials on static page cards (glass = floating elements only)
- ❌ More than one `.borderedProminent` button per screen
- ❌ Using the accent as a background fill or decoration — spotlight use only
- ❌ Custom PNGs for standard UI glyphs; emoji as UI icons
- ❌ Title Case on buttons or menu items
- ❌ Hardcoded hex/rgb for backgrounds or labels — use semantic system colors
- ❌ `.custom("Satoshi-Variable", size: N)` without `relativeTo:` — won't respond to accessibility text size
- ❌ `.font(.system(size: N))` on symbols next to text — use a text style
- ❌ Hardcoded `width`/`height` on layout-tied elements without `@ScaledMetric`
- ❌ Hardcoded `Color(red:green:blue:)` for accents without checking light-mode contrast
- ❌ Haptics on every tap — only at meaningful moments
- ❌ Custom views without `.accessibilityLabel` — VoiceOver users can't use unlabelled controls

---

## Quick-start checklist

When starting a new Hearth app:

1. Add `Satoshi-Variable.ttf` + `Satoshi-VariableItalic.ttf` to bundle; declare in `Info.plist`
2. Add accent as Asset Catalog color pair (light + dark); check contrast on both backgrounds
3. Define `AppAccentKey` environment key; inject at root; read via `@Environment(\.appAccent)`
4. `TabView` + `.tint(accent)` — add `.tabViewStyle(.sidebarAdaptable)` for iPad support
5. `List` → `.listStyle(.insetGrouped)`; add `.swipeActions` for delete/secondary actions
6. Navigation → `.navigationBarTitleDisplayMode(.large)`; `.tracking(-0.4)` on Large Title text
7. Sheets → `.presentationBackground(.thickMaterial)` + `.presentationDetents`
8. Fonts → always `Font.custom("Satoshi-Variable", size: N, relativeTo: .textStyle)`; `.monospacedDigit()` for live numbers
9. Sizes → `@ScaledMetric(relativeTo: .body)` for chip/button/ring frames; plain constants for margins and radii
10. Symbols → `.font(.headline)` / `.font(.body)` etc. — never `.font(.system(size: N))`
11. Shadows → only on floating elements (tab bar, sheets, popovers)
12. Empty screens → `EmptyState`; errors → `EmptyState` with retry CTA
13. Feedback → `Toast` for confirmations; `UINotificationFeedbackGenerator` for success/error; gate on user haptics pref
14. Accessibility → `.accessibilityLabel` on all custom controls; `.accessibilityElement(children: .combine)` on compound rows
