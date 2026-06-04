# Swift Coding Standards — BakeryPricingCalculator

**Status:** Binding on all Swift code in this repository.
**Owner:** Tesla (loop lead). Authored 2026-05-20 in response to GitLab issue #8.
**Audience:** Squad agents (Ada, Edison, Hopper, Curie, plus any human contributor).

## 1. Authoritative reference

The **Google Swift Style Guide** at <https://google.github.io/swift/> is the
normative external reference for this codebase. Treat it as the default style.
We do not vendor a copy here because:

- The canonical page is publicly hosted by Google and the URL has been stable
  since 2019.
- Bundling a snapshot in this repository creates a drift risk against the
  upstream document.
- The artefact attached to issue #8 (\<https://gitlab.com/[your-username]/BakeryPricingCalculator/uploads/abd2eeafc861cf5507274e7b6a1f4f0c/google_swift_coding_style.md\>)
  is behind Cloudflare bot protection and cannot be fetched from automation;
  the GitLab API resolves the same secret to 404. The canonical URL above is
  the equivalent material and is reachable.

When the Google guide and a project-specific rule below conflict, the
**project rule wins**. When the Google guide is silent on a topic, follow
[Apple's Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

## 2. Project-specific bindings

These rules supplement or override Google's guidance, scoped to this
codebase's product charter (offline, deterministic, single-purpose iOS app).

### 2.1 Warnings are errors

`xcodebuild` is invoked with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in
`app/build.sh`. The CI gate (`./app/build.sh test`) fails on **any** warning,
including deprecation warnings, unused-result warnings, and Swift 6 strict
concurrency diagnostics already adopted by the project. Suppression
(`// swiftlint:disable`, `@available`, `#warning` silencing) is not allowed
without an inline comment that names the issue or decision authorizing it.

### 2.2 Determinism in the math layer

`{DomainLogic}.swift` and its callers must be fully deterministic:

- No randomness (no `Double.random`, no `UUID()` in math paths).
- No clock reads in compute paths (no `Date()`, no `DispatchTime.now()` in
  `{DomainLogic}.compute` or anything it transitively calls).
- All formatting uses explicit `String(format:)` or the project's `fmtCm` /
  `fmtRows` / `fmtPct` helpers; never `NumberFormatter` with the user locale
  inside the math layer (UI surfaces may localise display strings, but the
  underlying numbers must be bit-identical across locales).

The math layer (`{DomainLogic}.swift`) MUST NOT import `MetricKit`, `os.signpost`, `os`, or any analytics framework. Verdict classification for analytics signposts lives in `{DomainLogic}Metrics.swift`, called by the view layer after `{DomainLogic}.compute(...)` returns. This is enforced by `MetricKitSubscriberTests.AC-3` (static file scan) and `AC-4` (runtime recording double).

### 2.3 No network, no analytics upload

The product charter (issue #1, mitigation 3) forbids network calls. Concretely:

- No `URLSession`, `Network` framework, `WKWebView` external loads, or
  third-party SDK that reaches a remote endpoint.
- No remote configuration. Feature flags are environment-driven launch
  arguments (`KGR_*` prefix) or compile-time constants.

User code MUST NOT open sockets, instantiate `URLSession` to telemetry endpoints, or link any third-party analytics SDK (Firebase, Amplitude, Mixpanel, Segment, GoogleAnalytics, Sentry, or equivalents). System frameworks (`MetricKit`) that conduct OS-mediated upload at Apple's schedule, with user opt-out under iOS Settings → Privacy & Security → Analytics & Improvements → Share With App Developers, are PERMITTED. Re-export of `MXMetricPayload` via a developer-owned HTTP endpoint requires a separate §2.3 amendment naming the endpoint URL and stating a retention policy; this is explicitly DEFERRED to V2 and is NOT in scope for V1.

If a future requirement needs network access, it must arrive as a written
decision in `.squad/decisions.md` first.

### 2.4 Force-unwrap discipline

- Force-unwrap (`!`) is forbidden on any value derived from user input.
- Force-unwrap on `Optional` literals (`Bundle.main.path(...)!`) is allowed
  only with an inline comment explaining why the unwrap cannot fail.
- Prefer `guard let`, `if let`, `??`, and `value.map { ... }` over force-
  unwraps. `try!` is banned; use `do/try/catch` with a graceful UI fallback.

### 2.5 Implicitly-unwrapped optionals (IUO)

Banned in new declarations. Outlets and storyboards do not apply (we are
SwiftUI-only). Existing IUO occurrences must be migrated to `Optional` or to
a non-optional `let` initialised by `init`.

### 2.6 Namespaces

Use a caseless `enum` (`enum {DomainLogic} { ... }`) rather than a `struct` with
a private `init` for pure-function namespaces. Already established in
`{DomainLogic}.swift`; new module-level utilities follow the same pattern.

### 2.7 Layout, indentation, and line length

- 4-space indentation. No tabs. (Matches existing `{DomainLogic}.swift` and
  `ContentView.swift`.) This is **stricter** than Google's 2-space default —
  the project rule wins.
- Maximum line length: **120 columns** (Google guide default is 100; we
  raise it because long SwiftUI view modifier chains and `String(format:)`
  spans dominate the codebase and re-wrapping them hurts readability more
  than it helps).
- Opening braces on the same line (`func foo() {`), one-statement-per-line.

### 2.8 SwiftUI specifics

- Views are `struct`s conforming to `View`. Reusable subviews live in the
  same file as their parent until they are used in three or more places,
  then they move to their own file (named `<ComponentName>.swift`).
- `@State` and `@Binding` are private. `@ObservedObject` / `@StateObject` are
  acceptable for shared models but not for pure-math result holders — use a
  computed property on the view instead.
- Accessibility is non-negotiable: every interactive control must declare an
  `accessibilityLabel`, `accessibilityHint` when behaviour is non-obvious,
  and an `accessibilityIdentifier` matching the convention used in UI tests
  (kebab-case, e.g. `verdict-help-button`).
- Identifiers used by UI tests are part of the **public contract** — renaming
  one is a behaviour change and requires a corresponding test update in the
  same commit.

### 2.9 Tests

- Unit tests live in `app/BakeryPricingCalculatorTests/` and use Apple's
  Swift Testing framework (`@Test`, `#expect`). XCTest is acceptable for UI
  tests only.
- UI tests run **serially** (per the 2026-05-20T06-25 decision) to avoid
  simulator races. Don't reintroduce `parallel: true`.
- A test that flakes more than once must be deleted or rewritten — see
  Curie's charter. Quarantine via `@Test(.disabled)` is not allowed.
- Every Jacquard-defined craft scenario sourced from Jacquard's charter and
  `.squad/decisions.md` has at least one matching Swift test. New gauge edge
  cases land as Swift tests first and, when they become team knowledge,
  should be recorded through Jacquard's charter or decision flow.

### 2.10 Concurrency

- Avoid `@MainActor` annotations on pure-value types and pure-math
  functions; reserve them for view models and UI sinks.
- No `Task { ... }` inside `View.body` — wrap in `.task { ... }` so the
  framework manages cancellation.
- No `DispatchQueue.main.async` inside SwiftUI views; use `withAnimation`,
  `.task`, or `.onChange` instead.

### 2.11 Comments and documentation

- Public types and functions in `{DomainLogic}.swift` carry a `///` doc comment
  describing the contract — what the function computes and what each
  parameter means in your app domain (e.g., use domain-meaningful names, not just
  "rows").
- `// MARK: -` is used to section large views (`ContentView.swift`).
- Avoid restating what the code says. Comment **why**, especially for any
  formula that diverges from the JS prototype or compensates for a real-
  domain-specific behaviour.

### 2.12 Logging

No log statements (`print`, `os_log`, `Logger`) in release builds outside of
a debug-flag-gated branch (`#if DEBUG` or env-var-gated). The math layer
must not log at all.

`MXMetricManagerSubscriber.didReceive(_:)` handlers that log payload contents (e.g., `jsonRepresentation()` via `print` or `os_log`) MUST be wrapped in `#if DEBUG`. In release builds, `didReceive(_:)` is a no-op — the data still flows to App Store Connect Analytics via Apple's auto-pipeline, but our process never emits the contents.

## 3. Tooling

- `xcodebuild` with `-quiet -warnings-as-errors` invoked by `app/build.sh`.
- `xcpretty` for human-readable test output (already wired by `build.sh`).
- **SwiftLint** is configured at `.swiftlint.yml` (repo root) and runs as part of `app/build.sh` before every xcodebuild invocation. It must also be wired as a pre-commit hook — see §3.1.

### 3.1 SwiftLint and pre-commit hook

`brew install swiftlint` (0.63.2+). The config at `.swiftlint.yml` encodes all rules below. To install as a pre-commit hook:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
if command -v swiftlint &>/dev/null; then
  swiftlint lint --config .swiftlint.yml --reporter xcode
fi
EOF
chmod +x .git/hooks/pre-commit
```

### 3.2 HIG compliance rules (SwiftLint custom_rules)

These rules catch Human Interface Guideline violations before review. All are encoded in `.swiftlint.yml` and are authoritative — do not suppress without an inline comment citing the HIG section:

| Rule ID | Severity | What it catches |
|---|---|---|
| `no_hardcoded_font_size` | error | `.font(.system(size:))` — use semantic styles for Dynamic Type (HIG §Typography) |
| `no_uppercased_in_code` | error | `Text(…).uppercased()` — use `.textCase(.uppercase)` so VoiceOver doesn't read as acronym (HIG §Accessibility) |
| `navigation_stack_in_sheet` | error | `NavigationStack` inside `.sheet` — competing gestures suppress swipe-to-dismiss (HIG §Navigation) |
| `color_literal_rgb` | error | `Color(red:green:blue:)` — use Color Assets for dark mode (HIG §Color) |
| `missing_min_touch_target` | error | `.padding(.vertical, N)` where N < 12 — may drop below 44 pt hit target (HIG §Buttons) |

Also enabled: `accessibility_label_for_image` (opt-in built-in rule).

## 4. Resolution rules

1. **Project rule above** beats Google guide.
2. **Google guide** beats Apple API design guidelines on Swift syntax-level
   matters (spacing, naming, formatting).
3. **Apple API design guidelines** beat both on Swift-Cocoa interop, naming
   for clarity (`makeIterator()`, `removeAll(where:)`), and protocol naming.
4. When in doubt and none of the three speaks to the question, prefer the
   convention already used in the file you're editing. Don't refactor an
   unrelated file just to enforce a style preference.

## 5. Pull-request expectations

Every MR/PR that touches Swift code must:

- Pass `./app/build.sh test` locally (warnings = 0, tests pass).
- Pass the GitLab CI mirror (the GitHub Actions `gitlab_mr` workflow).
- Not introduce force-unwraps on user input (§2.4).
- Not introduce network or analytics dependencies (§2.3) without a recorded
  decision in `.squad/decisions.md`.
- Update UI test identifiers and tests in the same commit when renaming a
  control (§2.8).

## 6. How agents use this document

Squad agents read `.squad/decisions.md` at spawn. A pointer to this guide
lives there. When this guide changes, the inbox-and-merge flow in
`.squad/decisions/inbox/` is the right surface for proposing the change.

If a rule here is wrong or has become obsolete, **don't** silently ignore
it in code review — file an inbox entry titled `tesla-swift-standard-amend-
<topic>.md` proposing the amendment. The next Scribe pass will merge it.

## 7. MetricKit

RESOLVED 2026-05-20. MetricKit consumption (via `MXMetricManagerSubscriber` and `MXSignpost(_:)`) is in scope. Re-export of payloads to a developer-owned endpoint is forbidden by default — see §2.3 carve-out. The current roster of `MXSignpost` names (9 total) is documented in `.squad/decisions.md`. Any new signpost name requires a Lead review and an addition to `decisions.md`.
