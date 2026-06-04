# Copilot Instructions — iOS/SwiftUI + Fastlane Template

These instructions apply to any project generated from this template.

---

## Tokens & Bootstrap

Sources use `BakeryPricingCalculator` (Swift target name, scheme, directory) and `com.yashasg.bakery-pricing-calculator` (reverse-DNS bundle ID) until bootstrap runs:

```bash
./bootstrap.sh "<AppName>" "<bundle.id>" [gitlab-board-url]
```

`bootstrap.sh` self-deletes after use. Never hardcode app names or bundle IDs — use tokens in template files.

---

## Project Structure

```
ios-swiftui-fastlane-template/
├── app/
│   ├── app.xcodeproj/
│   ├── BakeryPricingCalculator/             # Main app target sources
│   │   ├── BakeryPricingCalculatorApp.swift # @main entry point; sets .satoshiBody as default font
│   │   ├── Components/           # Reusable UI (Font+Satoshi.swift, etc.)
│   │   ├── Views/                # Feature views
│   │   └── Assets.xcassets/
│   ├── BakeryPricingCalculatorTests/        # Unit tests (XCTest)
│   ├── BakeryPricingCalculatorUITests/      # UI tests (XCUIApplication)
│   ├── fastlane/                 # Fastfile, Appfile, Matchfile
│   ├── build.sh                  # ./build.sh [build|test|release]
│   ├── run.sh                    # ./run.sh — simulator run
│   └── Gemfile
├── docs/
│   ├── swift_coding_standards.md
│   ├── DesignSystem.md
│   └── app-store-connect-privacy-setup.md
└── bootstrap.sh
```

**File placement:**
- New Swift files → `app/BakeryPricingCalculator/` (or `Views/` / `Components/`)
- Unit tests → `app/BakeryPricingCalculatorTests/`
- UI tests → `app/BakeryPricingCalculatorUITests/`
- Docs → `docs/`

---

## Coding Standards

**Full rules:** `docs/swift_coding_standards.md` — read it. Non-negotiables:

- **Warnings are errors** — `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` (+ GCC/Clang equivalents) in `build.sh`. No suppressions without a named authorizing decision.
- **No network calls** — `URLSession` and third-party analytics SDKs are banned. MetricKit is permitted. Any network requirement needs a written decision in `.squad/decisions.md` first.
- **Force-unwrap discipline** — `!` on user-input–derived values is forbidden; `try!` is banned; use `guard let` / `do-catch`.
- **Concurrency** — no `Task { }` inside `View.body`; use `.task { }`; no `DispatchQueue.main.async` in SwiftUI views.
- **Determinism** — no `UUID()`, `Date()`, or `Double.random` in compute/domain paths.
- **SwiftLint** is NOT bundled. Add `.swiftlint.yml` per-project; `build.sh` skips lint if absent; the `ci` lane calls it directly and will fail without it.

---

## Design System

**Full reference:** `docs/DesignSystem.md`. Key rules:

- **Typeface is Satoshi** (variable, 300–900). Never substitute SF Pro.
- **Use Font+Satoshi.swift helpers only** — e.g. `.appBody`, `.appTitle2`, `.appHeadline`. Never `.font(.body)` / `.font(.title)`. Pass `relativeTo:` in custom sizes for Dynamic Type support.
- **Accent color** — each app injects its own via `@Environment(\.appAccent)`. Use sparingly: primary action, selected state, key glyphs.
- **SF Symbols** for all icons.
- **Dark-mode first** — color tokens are dark-mode first; light mode via SwiftUI semantic colors. No hardcoded colors or font sizes.

---

## Architecture

- `BakeryPricingCalculatorApp.swift` is `@main`, wraps a single `WindowGroup`, sets `.satoshiBody` as default font for all descendants.
- Decompose large views; reusable components in `Components/`, one-off views in `Views/`.
- State: `@State` / `@Binding` / `@StateObject`; prefer `@Observable` (iOS 17+) for complex state. No business logic in `View.body`.
- Prefer SwiftUI over UIKit.

---

## Testing

```bash
./app/build.sh test                    # unit tests
cd app && bundle exec fastlane ci      # SwiftLint + build + tests (CI gate)
bundle exec fastlane test ui:true      # UI tests only
```

- Unit tests in `app/BakeryPricingCalculatorTests/` (XCTestCase). Name: `test<Scenario>()`.
- UI tests in `app/BakeryPricingCalculatorUITests/` (XCUIApplication). Match elements via `accessibilityIdentifier`.
- **All interactive controls must have `accessibilityIdentifier` (kebab-case, e.g. `continue-button`) and `accessibilityLabel`.**
- All tests must compile warning-free.

---

## SwiftLint Policy

This template enforces a **hardened `.swiftlint.yml`** at the repo root. **All contributions must lint clean.** Key policies:

- **No magic numbers** — use named constants or design-system tokens only.
- **Dynamic Type required** — all font sizes must use semantic styles (.body, .headline, etc.) or `@ScaledMetric`; no hardcoded point values.
- **Accessibility** — images, buttons, and interactive controls require `accessibilityLabel` and `accessibilityTrait`. Touch targets ≥44 pt.
- **Design-system colors & spacing** — use Asset Catalog colors (dark + light variants) or semantic system colors; use `Spacing.inner` / `Spacing.margin` constants, not raw numbers in `.padding()` / `.frame()`.
- **HIG-aligned** — violations in typography, color, and accessibility correctness are `:error`; layout heuristics are `:warning`.

SwiftLint runs in the `ci` lane and in `app/build.sh`. **Code must pass lint before commit.** The `prototype/` folder is excluded (consistent with "ignore prototype" below).

See `.swiftlint.yml` for the full rule set and `docs/swift_coding_standards.md` + `docs/DesignSystem.md` for rationale.

---

## Fastlane

Run from `app/` via Bundler: `cd app && bundle exec fastlane <lane>`

| Lane | Description |
|------|-------------|
| `ci` | SwiftLint + xcodebuild (debug) + XCTest — the CI gate |
| `build` | Debug or Release xcodebuild without distribution |
| `test` | XCTest only (UI tests excluded by default) |
| `certs` | Sync App Store certs/profiles via match |
| `beta` | Build signed `.ipa` → TestFlight |
| `release` | Build signed `.ipa` → App Store (no auto-review submission) |

`beta` / `release` accept `bump:patch|minor|major`. Build number auto-increments from latest TestFlight build.

**Signing prerequisites** — fill before any release lane:
- `app/fastlane/Appfile` — `app_identifier`, `apple_id`, `team_id`
- `app/fastlane/Matchfile` — `git_url`, `username`
- CI env vars: `MATCH_PASSWORD`, `MATCH_KEYCHAIN_PASSWORD`, `ASC_API_KEY_JSON`

See `docs/app-store-connect-privacy-setup.md` for ASC API key setup.

---

## Build & Run

```bash
./app/build.sh [build|test|release]
./app/run.sh                          # build debug + install + launch on simulator
SIMULATOR_NAME="iPhone 16" ./app/run.sh
```

| Mode | Fastlane lane | Config |
|------|---------------|--------|
| `build` | `fastlane build` | Debug / iphonesimulator |
| `test` | `fastlane ci` | Debug / iphonesimulator |
| `release` | `fastlane build` | Release / iphoneos |

Default simulator: `iPhone 17 Pro` (override with `SIMULATOR_NAME` or `SIMULATOR_UDID`).

---

## CI/CD Architecture

- **GitLab is the code repository** — source, MRs, Squad workflow (`glab`).
- **GitHub is the CI/CD runner** — pipelines run on GitHub Actions runners.
- **GitLab → GitHub webhook** — pushes trigger CI runs on GitHub. No native GitLab pipeline.
- **Do NOT create `.gitlab-ci.yml` or any GitLab CI/CD config.** GitLab is code-only here.

---

## Squad Workflow

Governed by `.github/agents/squad.agent.md`. `glab` skill: `.squad/skills/glab/SKILL.md`.

- Label `squad` for general routing; `squad:<member>` for a specific agent.
- MRs: `glab mr create --fill --target-branch main` / `glab mr merge <id>`
- Pipeline status: `glab ci status`

---

## Conventions (must-follow)

- **Tokens** — never hardcode app names or bundle IDs; use `BakeryPricingCalculator` / `com.yashasg.bakery-pricing-calculator` in template files.
- **No `.yml`/`.yaml` files** in template root or `.github/` unless explicitly requested.
- **No GitLab CI/CD files** — never add `.gitlab-ci.yml` or equivalent.
- **No new CI/CD pipeline files** unless explicitly asked; fastlane lanes are CI-ready.
- **File placement** — new Swift files under `app/BakeryPricingCalculator/`; tests under the right test target; docs under `docs/`.
- **SwiftLint** — do not add `.swiftlint.yml` to the template unless the task is specifically to add one.
- **Ignore `prototype/`** — exploratory scratch only; never read, modify, lint, test, or treat as production code.
