#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-test}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$PROJECT_DIR/.." && pwd)"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_UDID="${SIMULATOR_UDID:-}"
DESTINATION="${DESTINATION:-}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_DIR/.build}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$BUILD_DIR/derived-data}"
COMPILER_INDEX_STORE_ENABLE="${COMPILER_INDEX_STORE_ENABLE:-YES}"

usage() {
  echo "Usage: $0 [build|test|all|release|danger]"
  echo "  build   Build via Fastlane without distribution"
  echo "  test    Run the unified Fastlane ci lane (SwiftLint + build + XCTest)"
  echo "  all     Full local gate suite: SwiftLint + SwiftFormat + build + XCTest + Periphery + Danger"
  echo "  release Build a Release configuration via Fastlane without distribution"
  echo "  danger  Run the local Danger changeset-policy gate vs DANGER_BASE (default: main)"
}

fail() {
  echo "error: $*" >&2
  exit 65
}

# Detect and self-heal bad Ruby before any bundle/fastlane calls.
ruby_preflight() {
  local ruby_path ruby_major
  ruby_path="$(command -v ruby 2>/dev/null || true)"
  ruby_major=0
  [[ -n "$ruby_path" ]] && ruby_major="$(ruby -e 'puts RUBY_VERSION.split(".")[0]' 2>/dev/null || echo 0)"

  # Self-heal: macOS system Ruby or version < 3 — try prepending Homebrew Ruby
  if [[ "$ruby_path" == /usr/bin/ruby* || "$ruby_path" == /System/Library/Frameworks/Ruby.framework* ]] || (( ruby_major < 3 )); then
    if command -v brew >/dev/null 2>&1; then
      local brew_ruby_prefix brew_gems_bin
      brew_ruby_prefix="$(brew --prefix ruby 2>/dev/null || true)"
      if [[ -n "$brew_ruby_prefix" && -d "$brew_ruby_prefix/bin" ]]; then
        brew_gems_bin="$(ls -d "$(brew --prefix)/lib/ruby/gems/"*/bin 2>/dev/null | sort -V | tail -n 1 || true)"
        export PATH="$brew_ruby_prefix/bin${brew_gems_bin:+:$brew_gems_bin}:$PATH"
        ruby_path="$(command -v ruby 2>/dev/null || true)"
        ruby_major="$(ruby -e 'puts RUBY_VERSION.split(".")[0]' 2>/dev/null || echo 0)"
        echo "→ Ruby preflight: self-healed PATH to Homebrew Ruby at $ruby_path (v${ruby_major}.x)" >&2
      fi
    fi
  fi

  if [[ "$ruby_path" == /usr/bin/ruby* || "$ruby_path" == /System/Library/Frameworks/Ruby.framework* ]] || (( ruby_major < 3 )); then
    echo "error: Ruby >= 3 is required; active Ruby is '${ruby_path}' (v${ruby_major}.x)." >&2
    echo "  Apple's system Ruby (2.6) is read-only and unsupported." >&2
    echo "  Fix:" >&2
    echo "    1. brew install ruby" >&2
    echo '    2. Add to ~/.zshrc:  export PATH="$(brew --prefix ruby)/bin:$PATH"' >&2
    echo "    3. Restart your shell, then: cd app && bundle install" >&2
    echo "  See README.md → Fastlane setup → Ruby requirement" >&2
    exit 1
  fi

  if ! command -v bundle >/dev/null 2>&1; then
    echo "error: 'bundle' not found under Ruby at '${ruby_path}'." >&2
    echo "  Install Bundler:  gem install bundler" >&2
    echo "  Then:             cd app && bundle install" >&2
    exit 1
  fi
}

destination_value() {
  local key="$1"
  printf '%s\n' "$DESTINATION" |
    tr ',' '\n' |
    sed -n "s/^[[:space:]]*${key}=//p" |
    head -n 1
}

resolve_simulator_udid_by_name() {
  local name="$1"
  xcrun simctl list devices available "$name" |
    awk -F '[()]' '/^[[:space:]]+.*\([0-9A-F-]{36}\)/ { print $2; exit }'
}

resolve_simulator_name_by_udid() {
  local udid="$1"
  xcrun simctl list devices available |
    awk -F '[()]' -v udid="$udid" '$0 ~ udid { gsub(/^[[:space:]]+/, "", $1); gsub(/[[:space:]]+$/, "", $1); print $1; exit }'
}

acquire_build_lock() {
  mkdir -p "$BUILD_DIR"
  LOCK_DIR="$BUILD_DIR/build.lock"
  LOCK_WAIT_SECONDS="${LOCK_WAIT_SECONDS:-120}"
  LOCK_WAITED=0

  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [[ -f "$LOCK_DIR/pid" ]] && ! kill -0 "$(cat "$LOCK_DIR/pid")" 2>/dev/null; then
      rm -rf "$LOCK_DIR"
      continue
    fi
    if (( LOCK_WAITED >= LOCK_WAIT_SECONDS )); then
      fail "timed out waiting for another app/build.sh run to finish"
    fi
    sleep 2
    LOCK_WAITED=$((LOCK_WAITED + 2))
  done

  echo "$$" > "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

run_swiftlint() {
  if command -v swiftlint >/dev/null 2>&1; then
    echo "→ SwiftLint (HIG rules, --strict)..."
    # --strict promotes warnings to errors; the non-zero exit then fails this script
    # (set -e), matching the compiler warnings-as-errors policy. The guard above keeps
    # environments without swiftlint installed from hard-failing.
    if ! swiftlint lint --config "$REPO_ROOT/.swiftlint.yml" --strict --reporter xcode; then
      fail "SwiftLint reported violations (strict mode: warnings are failures)"
    fi
  else
    echo "⚠ SwiftLint not installed — skipping HIG lint (brew install swiftlint)"
  fi
}

run_swiftformat() {
  if command -v swiftformat >/dev/null 2>&1; then
    echo "→ SwiftFormat (--lint, fail on diff)..."
    if ! swiftformat --lint --config "$REPO_ROOT/.swiftformat" "$REPO_ROOT"; then
      fail "SwiftFormat found formatting violations (run: swiftformat . to auto-fix)"
    fi
  else
    echo "⚠ SwiftFormat not installed — skipping format lint (brew install swiftformat)"
  fi
}

run_periphery() {
  if command -v periphery >/dev/null 2>&1; then
    echo "→ Periphery (dead-code scan, FAIL on unused code)..."
    if ! periphery scan --config "$REPO_ROOT/.periphery.yml" --quiet; then
      fail "Periphery detected unused code (dead code must be removed before merge)"
    fi
  else
    echo "⚠ Periphery not installed — skipping dead-code scan (brew install peripheryapp/periphery/periphery)"
  fi
}

# Local-only Danger changeset-policy gate (Dangerfile.swift at repo root).
# Danger is NOT run in PR/CI here — `danger-swift local` evaluates the COMMITTED
# diff between HEAD and DANGER_BASE (default: main). That means it only has
# something to evaluate on a feature branch with commits ahead of the base; on the
# base branch itself, or with a clean tree, it is a deliberate no-op. We export
# DANGER_LOCAL_BASE so Dangerfile.swift's per-file diff uses the same base, and
# pass --failOnErrors so policy violations fail this script (and the gate).
run_danger() {
  local base="${DANGER_BASE:-main}"

  if ! command -v danger-swift >/dev/null 2>&1; then
    echo "⚠ danger-swift not installed — skipping changeset policy (brew install danger/tap/danger-swift)"
    return 0
  fi

  local current_branch
  current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
    echo "⚠ Danger: base branch '$base' not found — skipping (set DANGER_BASE to a valid branch)."
    return 0
  fi

  if [[ "$current_branch" == "$base" ]]; then
    echo "→ Danger: on base branch '$base' — no committed diff to evaluate, skipping."
    return 0
  fi

  echo "→ Danger (local changeset policy vs '$base')..."
  if ! DANGER_LOCAL_BASE="$base" danger-swift local --base "$base" --failOnErrors; then
    fail "Danger reported changeset-policy violations (see above)"
  fi
}

telemetry_preflight() {
  local pkg_resolved="$PROJECT_DIR/app.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  if [[ -f "$pkg_resolved" ]]; then
    local telemetry_pattern='swift-metrics|firebase|sentry-cocoa|datadog|amplitude|mixpanel|segment|braze|newrelic|instana|bugsnag'
    if grep -Eiq "$telemetry_pattern" "$pkg_resolved"; then
      fail "Package.resolved references a third-party telemetry SDK; only MetricKit (system framework) is permitted"
    fi
  fi
}

resolve_simulator_context() {
  local destination_udid=""
  local destination_name=""

  FASTLANE_TEST_DEVICE="$SIMULATOR_NAME"

  if [[ -n "$DESTINATION" ]]; then
    [[ "$DESTINATION" == *"platform=iOS Simulator"* ]] || \
      fail "DESTINATION must target an iOS Simulator for $MODE: $DESTINATION"

    destination_udid="$(destination_value id)"
    destination_name="$(destination_value name)"

    if [[ -n "$destination_udid" ]]; then
      SIMULATOR_UDID="$destination_udid"
      FASTLANE_TEST_DEVICE="$(resolve_simulator_name_by_udid "$SIMULATOR_UDID")"
    elif [[ -n "$destination_name" ]]; then
      SIMULATOR_NAME="$destination_name"
      FASTLANE_TEST_DEVICE="$destination_name"
      SIMULATOR_UDID="$(resolve_simulator_udid_by_name "$destination_name")"
      [[ -n "$SIMULATOR_UDID" ]] || fail "no available simulator named '$destination_name'"
    fi
  fi

  if [[ -z "$DESTINATION" ]]; then
    if [[ -z "$SIMULATOR_UDID" ]]; then
      SIMULATOR_UDID="$(resolve_simulator_udid_by_name "$SIMULATOR_NAME")"
    fi
    # Fall back to any available iPhone if the preferred name is not present.
    if [[ -z "$SIMULATOR_UDID" ]]; then
      echo "⚠ no simulator named '${SIMULATOR_NAME}'; picking best available iPhone..." >&2
      SIMULATOR_UDID="$(pick_best_available_iphone_udid)"
      if [[ -n "$SIMULATOR_UDID" ]]; then
        FASTLANE_TEST_DEVICE="$(resolve_simulator_name_by_udid "$SIMULATOR_UDID")"
      fi
    fi
    [[ -n "$SIMULATOR_UDID" ]] || fail "no available iOS Simulator found (check: xcrun simctl list devices available)"
    DESTINATION="platform=iOS Simulator,id=${SIMULATOR_UDID}"
  fi

  if [[ -z "$FASTLANE_TEST_DEVICE" && -n "$SIMULATOR_UDID" ]]; then
    FASTLANE_TEST_DEVICE="$(resolve_simulator_name_by_udid "$SIMULATOR_UDID")"
  fi
  FASTLANE_TEST_DEVICE="${FASTLANE_TEST_DEVICE:-$SIMULATOR_NAME}"
}

foreign_app_preflight() {
  [[ -n "$SIMULATOR_UDID" ]] || return 0

  local listapps_raw foreign_bundle_ids
  listapps_raw="$(xcrun simctl listapps "$SIMULATOR_UDID" 2>/dev/null || true)"
  [[ -n "$listapps_raw" ]] || return 0

  foreign_bundle_ids="$(
    printf '%s' "$listapps_raw" \
      | /usr/bin/awk -F '"' '/CFBundleIdentifier =/ { print $2 }' \
      | grep -E "^${BUNDLE_ID_PREFIX:-com\.example}\." \
      | grep -v "^${BUNDLE_ID:-__BUNDLE_ID__}$" \
      || true
  )"
  [[ -n "$foreign_bundle_ids" ]] || return 0

  while IFS= read -r bundle_id; do
    [[ -n "$bundle_id" ]] || continue
    echo "→ foreign-app preflight: uninstall $bundle_id" >&2
    xcrun simctl uninstall "$SIMULATOR_UDID" "$bundle_id" >/dev/null 2>&1 || true
  done <<< "$foreign_bundle_ids"
}

# Returns the UDID of the best available iPhone simulator — fallback when the
# preferred SIMULATOR_NAME is not present (e.g. fresh machine, different Xcode).
pick_best_available_iphone_udid() {
  xcrun simctl list devices available \
    | grep -E '^\s+iPhone' \
    | awk -F'[()]' '/\([0-9A-F-]{36}\)/ { print $2 }' \
    | head -n 1
}

run_fastlane() {
  local lane="$1"
  shift
  # Prefer 'bundle exec fastlane' so gem versions from Gemfile.lock are honoured.
  if command -v bundle >/dev/null 2>&1; then
    (cd "$PROJECT_DIR" && bundle exec fastlane "$lane" "$@")
  elif command -v fastlane >/dev/null 2>&1; then
    echo "⚠ bundle not found; using bare fastlane (gem versions may differ from Gemfile.lock)" >&2
    (cd "$PROJECT_DIR" && fastlane "$lane" "$@")
  else
    fail "fastlane not found; install via: cd app && bundle install  (requires Ruby + Bundler)"
  fi
}

# The `danger` subcommand is a standalone local gate — it needs neither Ruby,
# Fastlane, nor a simulator, so handle it before the heavyweight preflights.
if [[ "$MODE" == "danger" ]]; then
  run_danger
  exit 0
fi

ruby_preflight

case "$MODE" in
  build)
    LANE="build"
    CONFIGURATION="${CONFIGURATION:-Debug}"
    SDK="${SDK:-iphonesimulator}"
    ;;
  test)
    LANE="ci"
    CONFIGURATION="${CONFIGURATION:-Debug}"
    SDK="${SDK:-iphonesimulator}"
    ;;
  all)
    # Full local pre-merge gate suite. Runs the same lean ci lane as `test`
    # (SwiftLint + build + XCTest) and additionally layers SwiftFormat, Periphery,
    # and Danger around it. Strict superset of `test`/`ci` — never equivalent.
    LANE="ci"
    CONFIGURATION="${CONFIGURATION:-Debug}"
    SDK="${SDK:-iphonesimulator}"
    ;;
  release)
    LANE="build"
    CONFIGURATION="${CONFIGURATION:-Release}"
    SDK="${SDK:-iphoneos}"
    DESTINATION="${DESTINATION:-generic/platform=iOS}"
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

acquire_build_lock
telemetry_preflight
# SwiftLint runs at script level only for modes that bypass the ci lane
# (build/release use the `build` lane). test/all receive SwiftLint from the ci lane.
if [[ "$MODE" == "build" || "$MODE" == "release" ]]; then
  run_swiftlint
fi
# SwiftFormat is part of the full local gate suite (`all`) and pre-build hygiene
# for build/release. It is intentionally NOT run for test/ci — the CI runner
# installs SwiftLint only (see .squad decision: gate tiering).
if [[ "$MODE" == "build" || "$MODE" == "release" || "$MODE" == "all" ]]; then
  run_swiftformat
fi

if [[ "$MODE" != "release" ]]; then
  resolve_simulator_context
fi

if [[ "$MODE" == "test" || "$MODE" == "all" ]]; then
  foreign_app_preflight
fi

xcargs=(
  "COMPILER_INDEX_STORE_ENABLE=${COMPILER_INDEX_STORE_ENABLE}"
  "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"
  "GCC_TREAT_WARNINGS_AS_ERRORS=YES"
  "CLANG_TREAT_WARNINGS_AS_ERRORS=YES"
  "OTHER_SWIFT_FLAGS=-warnings-as-errors"
)

# The fastlane `xcodebuild` action (build/release lanes) does NOT honor its
# derived_data_path option — it is silently dropped and xcodebuild falls back to
# the global ~/Library/Developer/Xcode/DerivedData. Pass -derivedDataPath
# explicitly so the build product actually lands in DERIVED_DATA_PATH (which
# run.sh reads from). Skip this for test/all: the ci lane's run_tests (scan)
# already injects -derivedDataPath natively, and xcodebuild rejects it twice.
if [[ "$MODE" != "test" && "$MODE" != "all" ]]; then
  xcargs+=("-derivedDataPath ${DERIVED_DATA_PATH}")
fi

if [[ "$MODE" != "release" ]]; then
  xcargs=("CODE_SIGNING_ALLOWED=NO" "${xcargs[@]}")
fi

if [[ "$MODE" == "test" || "$MODE" == "all" ]]; then
  xcargs+=(
    "-parallel-testing-enabled NO"
    "-retry-tests-on-failure"
    "-test-iterations 2"
    "-test-repetition-relaunch-enabled YES"
  )
fi

fastlane_args=(
  "configuration:${CONFIGURATION}"
  "derived_data_path:${DERIVED_DATA_PATH}"
  "xcargs:${xcargs[*]}"
)

if [[ "$LANE" == "build" || "$LANE" == "ci" ]]; then
  fastlane_args+=(
    "sdk:${SDK}"
    "destination:${DESTINATION}"
  )
  if [[ "$MODE" == "release" ]]; then
    fastlane_args+=("allow_codesigning:true")
  fi
fi

if [[ "$MODE" == "test" || "$MODE" == "all" ]]; then
  fastlane_args+=(
    "device:${FASTLANE_TEST_DEVICE}"
    "output_directory:${BUILD_DIR}"
  )
fi

run_fastlane "$LANE" "${fastlane_args[@]}"

# Periphery and Danger are part of the FULL local gate suite only (`all`).
# They are deliberately excluded from test/ci: the CI runner installs SwiftLint
# only (see .squad decision: gate tiering). `all` is a strict superset of `test`.
if [[ "$MODE" == "all" ]]; then
  # Periphery runs after the build/test succeeds (needs index store).
  run_periphery
  # Local changeset-policy gate. Self-skips on the base branch or a clean tree,
  # so this is a no-op on `main` and only enforces on feature branches with a
  # committed diff vs DANGER_BASE. Run it standalone anytime via: app/build.sh danger
  run_danger
fi
