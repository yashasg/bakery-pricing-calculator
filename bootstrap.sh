#!/usr/bin/env bash
# bootstrap.sh — Personalise the iOS/SwiftUI + fastlane template.
#
# Usage: ./bootstrap.sh <bundle.id> [options]
#
# The Xcode app/target name (__APP_NAME__) is derived AUTOMATICALLY from the
# git repository name (or the containing folder name as fallback), converted to
# PascalCase. You do NOT need to supply it.
#
# The App Store display name is NOT managed here — configure it later in
# App Store Connect or via fastlane deliver/metadata.
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $0 <bundle.id> [options]

  bundle.id                    Reverse-DNS bundle identifier (required).
                               e.g. com.acme.myapp

Options:
  -n, --app-name <name>        Override the Xcode app/target/scheme name.
                               Must be a valid Swift identifier (letters, digits,
                               underscores; no spaces or hyphens; no leading digit).
  -b, --board <url>            GitLab board URL for loop.sh.
                               e.g. https://gitlab.com/acme/my-app
      --no-github              Skip creating the companion public GitHub CI/CD repo.
                               Equivalent to: SKIP_GITHUB=1 ./bootstrap.sh ...
  -h, --help                   Show this help message.

Examples:
  ./bootstrap.sh com.acme.myapp
  ./bootstrap.sh com.acme.myapp -b https://gitlab.com/acme/my-cool-app
  ./bootstrap.sh com.acme.myapp --no-github
EOF
  exit 1
}

fail() {
  echo "error: $*" >&2
  exit 1
}

# ── PascalCase derivation ─────────────────────────────────────────────────────
#
# Converts a repo slug such as "knitting-gauge-reconciler", "my_cool_app", or
# "app 2 name" into a valid Xcode/Swift identifier: "KnittingGaugeReconciler",
# "MyCoolApp", "App2Name".
#
# Steps:
#   1. Lowercase the entire string (normalise case).
#   2. Replace hyphens, underscores, and spaces with a single space so we have
#      clean word boundaries.
#   3. Iterate over each word: strip non-alphanumeric/underscore characters,
#      then capitalise the first character.
#   4. If the result starts with a digit, prefix with an underscore so it is a
#      valid identifier (Swift identifiers must not start with a digit).
to_pascal_case() {
  local input="$1"
  local result=""
  local word
  local normalised
  # Replace hyphens, underscores, spaces with a single space; lowercase everything
  normalised="$(echo "$input" | tr '[:upper:]' '[:lower:]' | tr -- '-_ ' ' ')"
  for word in $normalised; do
    # Drop characters that are not letters, digits, or underscores
    word="$(echo "$word" | tr -cd '[:alnum:]_')"
    [[ -z "$word" ]] && continue
    # Capitalise first character, append rest unchanged
    result="${result}$(echo "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}"
  done
  # Prefix with underscore if result starts with a digit
  if echo "$result" | grep -qE '^[0-9]'; then
    result="_${result}"
  fi
  echo "$result"
}

# ── Derive repo name ──────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer the git remote slug (last path component, strip .git suffix)
# Fall back to the basename of the repo root directory.
derive_repo_name() {
  local remote_url
  remote_url="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    # Strip trailing .git, then grab the last path component
    echo "${remote_url%.git}" | sed 's|.*[/:]||'
  else
    # No remote — use the directory name of the repo root
    git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null \
      | xargs basename \
      || basename "$SCRIPT_DIR"
  fi
}

# ── Parse arguments ───────────────────────────────────────────────────────────

BUNDLE_ID=""
BOARD_URL=""
APP_NAME_OVERRIDE=""
SKIP_GITHUB="${SKIP_GITHUB:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    -n|--app-name)
      [[ $# -ge 2 ]] || fail "--app-name requires a value."
      APP_NAME_OVERRIDE="$2"; shift 2 ;;
    -b|--board)
      [[ $# -ge 2 ]] || fail "--board requires a value."
      BOARD_URL="$2"; shift 2 ;;
    --no-github) SKIP_GITHUB=1; shift ;;
    -*) fail "Unknown option: $1" ;;
    *)
      if [[ -z "$BUNDLE_ID" ]]; then
        BUNDLE_ID="$1"; shift
      else
        fail "Unexpected argument: $1"
      fi ;;
  esac
done

[[ -n "$BUNDLE_ID" ]] || usage

# ── Determine APP_NAME (Xcode target/scheme identifier) ───────────────────────

# Always derive the repo slug — needed for GitHub repo creation regardless of
# whether the app name is overridden.
REPO_SLUG="$(derive_repo_name)"

if [[ -n "$APP_NAME_OVERRIDE" ]]; then
  APP_NAME="$APP_NAME_OVERRIDE"
  # Validate the override is a proper Swift identifier
  if ! echo "$APP_NAME" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
    fail "--app-name '$APP_NAME' is not a valid Swift identifier (no spaces, hyphens, or leading digits)."
  fi
else
  APP_NAME="$(to_pascal_case "$REPO_SLUG")"
  [[ -n "$APP_NAME" ]] || fail "Could not derive a valid app name from repo slug '$REPO_SLUG'. Use --app-name to set it manually."
  echo "→ Auto-derived Xcode target name: '$APP_NAME'  (from repo slug: '$REPO_SLUG')"
fi

echo "→ Bootstrapping:"
echo "     Xcode target  : $APP_NAME"
echo "     Bundle ID     : $BUNDLE_ID"

# ── Rename directories ────────────────────────────────────────────────────────

echo ""
echo "→ Renaming directories ..."

mv "$SCRIPT_DIR/app/__APP_NAME__"        "$SCRIPT_DIR/app/$APP_NAME"
mv "$SCRIPT_DIR/app/__APP_NAME__Tests"   "$SCRIPT_DIR/app/${APP_NAME}Tests"
mv "$SCRIPT_DIR/app/__APP_NAME__UITests" "$SCRIPT_DIR/app/${APP_NAME}UITests"

# Rename scheme file
mv "$SCRIPT_DIR/app/app.xcodeproj/xcshareddata/xcschemes/__APP_NAME__.xcscheme" \
   "$SCRIPT_DIR/app/app.xcodeproj/xcshareddata/xcschemes/${APP_NAME}.xcscheme"

# ── Rename files whose names contain __APP_NAME__ ────────────────────────────

echo "→ Renaming files ..."

while IFS= read -r -d '' filepath; do
  dir="$(dirname "$filepath")"
  base="$(basename "$filepath")"
  newbase="${base//__APP_NAME__/$APP_NAME}"
  if [[ "$base" != "$newbase" ]]; then
    mv "$filepath" "$dir/$newbase"
  fi
done < <(find "$SCRIPT_DIR" -not -path '*/.git/*' -type f -name '*__APP_NAME__*' -print0)

# ── Replace token contents ────────────────────────────────────────────────────

echo "→ Replacing tokens in files (__APP_NAME__, __BUNDLE_ID__) ..."

while IFS= read -r -d '' filepath; do
  # Skip binary / asset files
  case "$filepath" in
    */.git/*) continue ;;
    */Assets.xcassets/*.png) continue ;;
    */Assets.xcassets/*.pdf) continue ;;
    */AppIcon.appiconset/*) continue ;;
    *.ipa) continue ;;
    *.xcarchive) continue ;;
  esac

  # Only process files that actually contain a known token (perf guard)
  if grep -qF '__APP_NAME__' "$filepath" 2>/dev/null \
     || grep -qF '__BUNDLE_ID__' "$filepath" 2>/dev/null \
     || grep -qF '__GITLAB_BOARD_URL__' "$filepath" 2>/dev/null; then

    sed -i '' \
      -e "s|__APP_NAME__|${APP_NAME}|g" \
      -e "s|__BUNDLE_ID__|${BUNDLE_ID}|g" \
      "$filepath"

    if [[ -n "$BOARD_URL" ]]; then
      sed -i '' "s|__GITLAB_BOARD_URL__|${BOARD_URL}|g" "$filepath"
    else
      # Remove the --board flag entirely if no URL provided
      sed -i '' 's| --board __GITLAB_BOARD_URL__||g' "$filepath"
    fi
  fi
done < <(find "$SCRIPT_DIR" -not -path '*/.git/*' -type f -print0)

echo "→ Token replacement done."

# ── Create GitHub CI/CD companion repo ───────────────────────────────────────
#
# Architecture: GitLab hosts the code (origin); GitHub hosts CI/CD (Actions).
# Bootstrap creates the public companion GitHub repo with the same slug and
# adds it as a remote named 'github'. Origin (GitLab) is never touched.

GITHUB_CI_REPO_URL=""

echo ""
if [[ "$SKIP_GITHUB" == "1" ]]; then
  echo "→ Skipping GitHub CI/CD repo creation (--no-github / SKIP_GITHUB=1)."
else
  echo "→ GitHub CI/CD repo setup ..."
  _gh_ok=0

  if ! command -v gh &>/dev/null; then
    echo "⚠️  'gh' CLI not found — skipping GitHub CI/CD repo creation."
    echo "   Install it with: brew install gh && gh auth login"
  elif ! gh auth status &>/dev/null 2>&1; then
    echo "⚠️  'gh' CLI not authenticated — skipping GitHub CI/CD repo creation."
    echo "   Run: gh auth login"
  else
    _gh_ok=1
  fi

  if [[ "$_gh_ok" == "1" ]]; then
    _gh_owner="$(gh api user -q .login 2>/dev/null || true)"
    if [[ -z "$_gh_owner" ]]; then
      echo "⚠️  Could not determine GitHub username — skipping repo creation."
    else
      if gh repo view "${_gh_owner}/${REPO_SLUG}" &>/dev/null 2>&1; then
        echo "   Repo '${_gh_owner}/${REPO_SLUG}' already exists — using existing."
        GITHUB_CI_REPO_URL="https://github.com/${_gh_owner}/${REPO_SLUG}"
      else
        echo "   Creating public repo '${_gh_owner}/${REPO_SLUG}' ..."
        if gh repo create "${_gh_owner}/${REPO_SLUG}" --public >/dev/null 2>&1; then
          GITHUB_CI_REPO_URL="https://github.com/${_gh_owner}/${REPO_SLUG}"
          echo "   Created: $GITHUB_CI_REPO_URL"
        else
          echo "⚠️  GitHub repo creation failed — skipping."
          echo "   Create it manually at https://github.com/new"
        fi
      fi

      if [[ -n "$GITHUB_CI_REPO_URL" ]]; then
        if git -C "$SCRIPT_DIR" remote get-url github &>/dev/null 2>&1; then
          git -C "$SCRIPT_DIR" remote set-url github "$GITHUB_CI_REPO_URL"
          echo "   Updated remote 'github' → $GITHUB_CI_REPO_URL"
        else
          git -C "$SCRIPT_DIR" remote add github "$GITHUB_CI_REPO_URL"
          echo "   Added remote 'github' → $GITHUB_CI_REPO_URL"
        fi
      fi
    fi
  fi
fi

# Resolve the README token: actual URL on success, actionable fallback otherwise.
if [[ -n "$GITHUB_CI_REPO_URL" ]]; then
  _github_ci_token_value="$GITHUB_CI_REPO_URL"
else
  _github_ci_token_value="https://github.com/YOUR-ORG/${REPO_SLUG}  (create this public repo and paste its URL here)"
fi

# Replace __GITHUB_CI_REPO_URL__ in README and any other files that carry it.
while IFS= read -r -d '' filepath; do
  case "$filepath" in */.git/*) continue ;; esac
  if grep -qF '__GITHUB_CI_REPO_URL__' "$filepath" 2>/dev/null; then
    sed -i '' "s|__GITHUB_CI_REPO_URL__|${_github_ci_token_value}|g" "$filepath"
  fi
done < <(find "$SCRIPT_DIR" -not -path '*/.git/*' -type f -print0)

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "✅  Bootstrap complete!"
echo ""
echo "  App target    : $APP_NAME"
echo "  Bundle ID     : $BUNDLE_ID"
if [[ -n "$GITHUB_CI_REPO_URL" ]]; then
  echo "  GitHub CI/CD  : $GITHUB_CI_REPO_URL  (remote: 'github')"
else
  echo "  GitHub CI/CD  : skipped — create a public repo at https://github.com/new"
fi
echo ""
echo "Next steps:"
echo "  1. cd $SCRIPT_DIR/app"
echo "  2. bundle install          # install fastlane + gems"
echo "  3. fastlane test           # run tests (requires a simulator)"
echo "  4. Open app/app.xcodeproj in Xcode to develop"
echo "  5. Wire up fastlane/Matchfile (git_url, username) for code signing"
echo "  6. Set up CI (add .github/workflows/ or .gitlab-ci.yml per your platform)"
echo ""

# Self-delete
rm -- "$0"
