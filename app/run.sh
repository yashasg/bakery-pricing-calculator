#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$PROJECT_DIR/build.sh"
BUILD_ROOT_DIR="${BUILD_DIR:-$PROJECT_DIR/.build}"
RUN_BUILD_DIR="${RUN_BUILD_DIR:-$BUILD_ROOT_DIR/run-build}"
DERIVED_DATA_DIR="$RUN_BUILD_DIR/derived-data"
PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_UDID="${SIMULATOR_UDID:-}"
DESTINATION="${DESTINATION:-}"

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

resolve_simulator() {
  local destination_udid=""
  local destination_name=""

  if [[ -n "$DESTINATION" ]]; then
    [[ "$DESTINATION" == *"platform=iOS Simulator"* ]] || \
      fail "DESTINATION must target an iOS Simulator to run the app: $DESTINATION"

    destination_udid="$(destination_value id)"
    destination_name="$(destination_value name)"

    if [[ -n "$destination_udid" ]]; then
      SIMULATOR_UDID="$destination_udid"
    elif [[ -n "$destination_name" ]]; then
      SIMULATOR_UDID="$(resolve_simulator_udid_by_name "$destination_name")"
      [[ -n "$SIMULATOR_UDID" ]] || fail "no available simulator named '$destination_name'"
    fi
  fi

  if [[ -z "$SIMULATOR_UDID" ]]; then
    SIMULATOR_UDID="$(resolve_simulator_udid_by_name "$SIMULATOR_NAME")"
  fi

  # Fall back to any available iPhone if the preferred name is not present.
  if [[ -z "$SIMULATOR_UDID" ]]; then
    echo "⚠ no simulator named '${SIMULATOR_NAME}'; picking best available iPhone..." >&2
    SIMULATOR_UDID="$(xcrun simctl list devices available \
      | grep -E '^\s+iPhone' \
      | awk -F'[()]' '/\([0-9A-F-]{36}\)/ { print $2 }' \
      | head -n 1)"
  fi

  [[ -n "$SIMULATOR_UDID" ]] || fail "no available iOS Simulator found (check: xcrun simctl list devices available)"
}

find_app_bundle() {
  [[ -d "$PRODUCTS_DIR" ]] || fail "build products directory not found: $PRODUCTS_DIR"

  find "$PRODUCTS_DIR" -maxdepth 1 -type d -name '*.app' ! -name '*-Runner.app' -print |
    sort |
    head -n 1
}

bundle_identifier() {
  local app_bundle="$1"
  local info_plist="$app_bundle/Info.plist"
  [[ -f "$info_plist" ]] || fail "Info.plist not found in built app: $app_bundle"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist"
}

simulator_state() {
  xcrun simctl list devices "$SIMULATOR_UDID" |
    awk -F '[()]' -v udid="$SIMULATOR_UDID" '$0 ~ udid { print $(NF - 1); exit }'
}

ruby_preflight

resolve_simulator

BUILD_DESTINATION="$DESTINATION"
if [[ -z "$BUILD_DESTINATION" ]]; then
  BUILD_DESTINATION="platform=iOS Simulator,id=${SIMULATOR_UDID}"
fi

# Clean the run-build derived data before every run. Incremental xcodebuild does
# not reliably recompile the asset catalog when colorsets are renamed or image
# assets are deleted, so a reused Products/*.app keeps stale resources (e.g. an
# old accent colorset or a removed image). run.sh exists to show the *current*
# source on the simulator, so we trade incremental speed for a guaranteed-fresh
# product. (build.sh / the ci lane keep their own incremental derived data.)
echo "→ run.sh: cleaning run-build derived data for a fresh product: $DERIVED_DATA_DIR" >&2
rm -rf "$DERIVED_DATA_DIR"

BUILD_START_MARKER="$RUN_BUILD_DIR/.build-start"
mkdir -p "$RUN_BUILD_DIR"
: > "$BUILD_START_MARKER"

if ! BUILD_DIR="$RUN_BUILD_DIR" COMPILER_INDEX_STORE_ENABLE=NO DESTINATION="$BUILD_DESTINATION" "$BUILD_SCRIPT" build; then
  fail "build failed"
fi

APP_BUNDLE="$(find_app_bundle)"
[[ -n "$APP_BUNDLE" ]] || fail "no built .app product found in $PRODUCTS_DIR"

# Fail fast if the .app was not produced by this build (defends against a silent
# no-op build leaving a stale product behind).
if [[ ! "$APP_BUNDLE" -nt "$BUILD_START_MARKER" ]]; then
  fail "built app is not newer than this build started — refusing to install a stale binary: $APP_BUNDLE"
fi

STAGED_DIR="$BUILD_ROOT_DIR/run"
STAGED_APP="$STAGED_DIR/$(basename "$APP_BUNDLE")"
rm -rf "$STAGED_DIR"
mkdir -p "$STAGED_DIR"
ditto "$APP_BUNDLE" "$STAGED_APP"

BUNDLE_ID="$(bundle_identifier "$STAGED_APP")"
[[ -n "$BUNDLE_ID" ]] || fail "could not determine bundle identifier from $STAGED_APP"

open -a Simulator >/dev/null 2>&1 || true
if [[ "$(simulator_state)" != "Booted" ]]; then
  xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
fi
xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null
# Uninstall any prior copy so the simulator's installed container cannot retain
# resources that were removed from the bundle (simctl install overlays files).
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIMULATOR_UDID" "$STAGED_APP"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID"
