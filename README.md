# iOS/SwiftUI + Fastlane Template

A reusable starter template for iOS apps built with SwiftUI and distributed via fastlane — GitLab-hosted, Squad AI–ready. One bootstrap command personalises the Xcode project, fastlane config, and Squad team to your app name and bundle ID.

---

## What's included

| Path | Purpose |
|------|---------|
| `app/app.xcodeproj` | Xcode project with app, unit test, and UI test targets |
| `app/__APP_NAME__/` | SwiftUI source skeleton (renamed by `bootstrap.sh`) |
| `app/__APP_NAME__Tests/` | Unit test target with sample XCTest |
| `app/__APP_NAME__UITests/` | UI test target with accessibility audit |
| `app/fastlane/Fastfile` | Full lane suite: `ci`, `build`, `test`, `certs`, `beta`, `release` |
| `app/fastlane/Appfile` | App identity placeholders (`app_identifier`, `apple_id`, `team_id`) |
| `app/fastlane/Matchfile` | Cert-sync placeholders (`git_url`, `username`) |
| `app/Gemfile` | Ruby gem manifest (fastlane + plugins) |
| `app/build.sh` | CLI wrapper for fastlane: `build`, `test`, `release` modes; `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` enforced |
| `app/run.sh` | Builds the app and launches it on an iOS Simulator |
| `docs/swift_coding_standards.md` | Google Swift Style Guide + project-specific rules |
| `docs/app-store-connect-privacy-setup.md` | App Store Connect API key & privacy manifest guide |
| `.squad/` | Squad AI team governance — empty roster, ready to cast |
| `.squad/skills/glab/SKILL.md` | GitLab CLI (`glab`) skill for Squad agents |
| `bootstrap.sh` | One-shot personalisation script — self-deletes after use |
| `loop.sh` | Squad work-loop driver |

### What is intentionally **not** included

- **SwiftLint config** (`.swiftlint.yml`) — project-specific; add your own. `build.sh` silently skips lint if `swiftlint` is not on PATH; the fastlane `ci` lane calls it directly (install it first or remove the call from the `ci` lane). See `docs/swift_coding_standards.md` for rule rationale.
- **CI pipeline files** — no `.gitlab-ci.yml` is bundled. The `ci`, `beta`, and `release` lanes are CI-ready; wire them up per your pipeline setup.

---

## Prerequisites

| Requirement | Install |
|-------------|---------|
| macOS 14+ | — |
| Xcode 16+ | Mac App Store or `xcode-select --install` |
| Ruby >= 3 (Homebrew) | `brew install ruby` then add `export PATH="$(brew --prefix ruby)/bin:$PATH"` to `~/.zshrc` — Apple's system Ruby 2.6 is **NOT** supported |
| Bundler | `gem install bundler` |
| fastlane (via Bundler) | `cd app && bundle install` *(do not install globally)* |
| `glab` CLI (GitLab) | `brew install glab` then `glab auth login` |
| `gh` CLI (GitHub) | `brew install gh` then `gh auth login` — used by `bootstrap.sh` to create the companion GitHub CI/CD repo (skippable via `--no-github`) |

> **SwiftLint** (optional): `brew install swiftlint`. Add a `.swiftlint.yml` to enforce project rules. `build.sh` logs a warning and continues if it is absent; the fastlane `ci` lane will error without it.

---

## Quick start

### 1. Create your repo from this template, then clone it

On GitLab: **Use this template** → create your project, then:

```bash
git clone git@gitlab.com:<your-org>/<your-repo>.git
cd <your-repo>
```

### 2. Run `bootstrap.sh`

```bash
./bootstrap.sh "<bundle.id>" [options]
```

| Argument / Option | Required | Description |
|-------------------|----------|-------------|
| `bundle.id` | ✅ | Reverse-DNS bundle identifier. e.g. `com.acme.myapp` |
| `-n`, `--app-name` | optional | Override the Xcode app/target/scheme name. Must be a valid Swift identifier. Use only if the auto-derived name is wrong. |
| `-b`, `--board` | optional | GitLab board URL used by `loop.sh`. e.g. `https://gitlab.com/acme/my-app` |
| `--no-github` | optional | Skip creating the companion public GitHub CI/CD repo. Equivalent to `SKIP_GITHUB=1 ./bootstrap.sh ...`. |

**App/target name is auto-derived** from the git repository name (or folder name as fallback), converted to PascalCase — e.g. a repo named `my-cool-app` becomes the Xcode target `MyCoolApp`. You do not need to supply it.

**App Store display name is out of scope for bootstrap** — it is configured separately in App Store Connect or via fastlane (e.g. `deliver`/`metadata`). `CFBundleDisplayName` in `Info.plist` defaults to `$(PRODUCT_NAME)` (the Xcode target name).

What it does: renames all `__APP_NAME__` directories, files, and tokens; replaces `__BUNDLE_ID__`; sets the board URL in `loop.sh`; then **self-deletes**. Do not run it twice.

### 3. Install Ruby dependencies

```bash
cd app
bundle install
```

### 4. Open in Xcode or build from CLI

```bash
# Open in Xcode
open app/<AppName>.xcodeproj

# Or build + test from CLI
./app/build.sh test
```

---

## Building & testing

### `app/build.sh`

```bash
./app/build.sh [build|test|release]
```

| Mode | What it runs | Config / SDK |
|------|-------------|--------------|
| `build` *(default: `test`)* | `fastlane build` — debug build, no distribution | Debug / iphonesimulator |
| `test` | `fastlane ci` — SwiftLint + xcodebuild + XCTest suite | Debug / iphonesimulator |
| `release` | `fastlane build` — release archive, no distribution | Release / iphoneos |

`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` (plus `GCC_TREAT_WARNINGS_AS_ERRORS` and `CLANG_TREAT_WARNINGS_AS_ERRORS`) is passed as an `xcargs` override in every mode.

**Simulator override** — the default device is `iPhone 17 Pro`. Override via env vars:

```bash
SIMULATOR_NAME="iPhone 16" ./app/build.sh test
# or by UDID:
SIMULATOR_UDID="<udid>" ./app/build.sh test
```

### `app/run.sh`

Builds the app (debug, simulator) then installs and launches it:

```bash
./app/run.sh
# Override simulator the same way:
SIMULATOR_NAME="iPhone 16" ./app/run.sh
```

### Fastlane lanes (direct)

```bash
cd app
bundle exec fastlane test    # XCTest suite (UI tests excluded by default)
bundle exec fastlane build   # Debug build without distribution
bundle exec fastlane ci      # SwiftLint + xcodebuild + XCTest (CI gate)
```

> **UI tests** are excluded from `fastlane test` by default (`skip_testing: ["<AppName>UITests"]`). Remove `skip_testing` from the `test` lane in `app/fastlane/Fastfile` when you are ready to run them.

---

## Fastlane setup

Follow these steps once to get code signing and distribution working from scratch.

### Ruby requirement

This project requires **Ruby >= 3** (Gemfile.lock pins Bundler 4.x). Apple's built-in system Ruby (2.6, at `/usr/bin/ruby`) is read-only and **not supported** — gem installs will fail with a permissions error.

Install Homebrew Ruby and add it to your PATH **before** running `bundle install`:

```bash
brew install ruby
# Add to ~/.zshrc (then restart your shell):
export PATH="$(brew --prefix ruby)/bin:$PATH"
```

`build.sh` and `run.sh` will attempt to self-heal by prepending the Homebrew Ruby path automatically if system Ruby is detected; if Homebrew Ruby is not installed they will exit with a clear error.

### 1. Install Ruby dependencies

Xcode Command Line Tools must be installed:

```bash
xcode-select --install
```

Then install fastlane and its plugins via Bundler:

```bash
cd app
bundle install
```

### 2. Create the App ID and App Store Connect record

Fill in `app/fastlane/Appfile` with your real values:

```ruby
app_identifier("__BUNDLE_ID__")  # e.g. com.acme.myapp
apple_id("you@example.com")      # Apple ID for App Store Connect
team_id("XXXXXXXXXX")            # 10-character Apple Developer team ID
```

Then use `fastlane produce` to register the App ID in the Apple Developer Portal **and** create the App Store Connect app record in a single command:

```bash
cd app
bundle exec fastlane produce -u <apple_id> -a <bundle_id> --app_name "<App Name>"
```

`-u` is your Apple ID, `-a` is your bundle identifier, and `produce` reads `team_id` from your `Appfile` automatically.

> **Interactive authentication required.** `produce` authenticates to the Apple Developer Portal and App Store Connect and will prompt for your Apple ID **password and 2FA code** on the first run. It **must be run in a real interactive Terminal** — not piped through a logging tool or launched from a non-interactive shell — or authentication will stall. This is a one-shot setup step; it does not belong in CI.

**Manual fallback** (if you prefer the web portals):

1. [developer.apple.com](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → Identifiers → **+** → register a new App ID with your bundle identifier.
2. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App** → select the bundle identifier you just registered.

### 3. Set up the App Store Connect API key

The release lanes authenticate to App Store Connect via an API key (not username/password).

See **[`docs/app-store-connect-privacy-setup.md`](docs/app-store-connect-privacy-setup.md)** for step-by-step instructions on generating the key. Place the resulting file at `app/fastlane/asc_api_key.json`, or export its contents as the `ASC_API_KEY_JSON` environment variable.

### 4. Configure match and sync certificates

Fill in `app/fastlane/Matchfile` pointing to a **private** Git repository that will store encrypted certificates:

```ruby
git_url("https://gitlab.com/your-org/match-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["__BUNDLE_ID__"])
username("you@example.com")
readonly(false)  # set true after first run
```

> **Important:** Fill in `username(...)` with your Apple ID email. match uses it to authenticate to the Apple Developer Portal when `readonly(false)` — if it is left blank the first run will fail. This is a per-project value; never commit a real address into the template.

Run the `certs` lane to create (first run) or sync (subsequent runs) certificates and provisioning profiles:

```bash
cd app
MATCH_PASSWORD=<your-passphrase> bundle exec fastlane certs
```

`MATCH_PASSWORD` is the passphrase match uses to encrypt the certs repository. On CI also set `MATCH_KEYCHAIN_PASSWORD` (used to create the temporary keychain).

> **First run is interactive.** The first execution of `fastlane certs` (which runs `match appstore --readonly false`) talks to the Apple Developer Portal to **create** the Distribution certificate and App Store provisioning profile. It will prompt for your Apple ID **password and 2FA code** — run it in a real interactive Terminal, not through a pipe or non-interactive shell, or it will stall waiting for input. After this first run, subsequent CI runs authenticate via the App Store Connect API key (Step 3) with `readonly(true)` and never prompt.

After the first run, set `readonly(true)` in `Matchfile` so the lane never overwrites existing certificates.

The full first-time ordering is: **produce** (Step 2, create app record) → **API key** (Step 3) → **configure Matchfile** (`git_url` + `username`) → **run `fastlane certs` interactively** → set `readonly(true)` → CI picks up from there.

### 5. Build and distribute

With steps 1–4 complete:

```bash
cd app

# Upload a signed build to TestFlight
bundle exec fastlane beta

# Upload a signed binary to App Store (does not auto-submit for review)
bundle exec fastlane release
```

Both lanes accept an optional `bump:` parameter to increment the marketing version before building:

```bash
bundle exec fastlane beta bump:patch     # 1.0.0 → 1.0.1
bundle exec fastlane beta bump:minor     # 1.0.0 → 1.1.0
bundle exec fastlane release bump:major  # 1.0.0 → 2.0.0
```

The build number is set automatically to `(latest TestFlight build for this version) + 1`.

### 6. CI/CD

These lanes run locally as described above. Automated CI/CD runs on **GitHub Actions** and is triggered via a GitLab→GitHub webhook — no pipeline YAML needs to be added to this GitLab repository.

> **Architecture:** GitLab is the code repository (`origin`). GitHub is the CI/CD runner, triggered by a GitLab→GitHub webhook. Bootstrap automatically creates the companion public GitHub repo (same name as this repo) and registers it as a remote named `github`.

**GitHub CI/CD repo (Actions runner):** `__GITHUB_CI_REPO_URL__`

To skip automatic repo creation: pass `--no-github` to `bootstrap.sh`, or set `SKIP_GITHUB=1` in the environment. Requires [`gh`](https://cli.github.com/) authenticated (`brew install gh && gh auth login`).

---

## Code signing (fastlane match)

The `Appfile` and `Matchfile` ship with blank placeholders. Fill them in before running any release lane.

**`app/fastlane/Appfile`**

```ruby
app_identifier("com.acme.myapp")   # your bundle ID
apple_id("you@example.com")        # Apple ID used for App Store Connect
team_id("XXXXXXXXXX")              # 10-character Apple Developer team ID
```

**`app/fastlane/Matchfile`**

```ruby
git_url("https://gitlab.com/your-org/match-certs.git")  # private certs repo
storage_mode("git")
type("appstore")
app_identifier(["com.acme.myapp"])
username("you@example.com")
readonly(true)
```

Then sync certificates and provisioning profiles:

```bash
cd app
bundle exec fastlane certs
```

---

## Release lanes

Both release lanes require:
- `Appfile` and `Matchfile` fully configured (see above).
- App Store Connect API key at `app/fastlane/asc_api_key.json` **or** exported as `ASC_API_KEY_JSON`. See `docs/app-store-connect-privacy-setup.md` for setup.
- On CI: `MATCH_PASSWORD` and `MATCH_KEYCHAIN_PASSWORD` env vars set.

| Lane | Command | What it does |
|------|---------|-------------|
| `beta` | `bundle exec fastlane beta` | Builds a signed `.ipa`, uploads to TestFlight |
| `release` | `bundle exec fastlane release` | Builds a signed `.ipa`, uploads to App Store (does not auto-submit for review) |

Both lanes accept an optional `bump:` parameter to increment the marketing version before building:

```bash
bundle exec fastlane beta bump:patch    # 1.0.0 → 1.0.1
bundle exec fastlane beta bump:minor    # 1.0.0 → 1.1.0
bundle exec fastlane release bump:major # 1.0.0 → 2.0.0
```

The build number is set automatically to `(latest TestFlight build for this version) + 1`.

---

## GitLab workflow (Squad + glab)

This template ships a **Squad AI team** (`.squad/`) with an empty roster — ready to cast your agents — and a `glab` skill so agents interact with GitLab natively.

- **Cast your team:** edit `.squad/team.md` and `.squad/routing.md`, then run `loop.sh` (requires `squad` CLI).
- **Issues** use `squad` / `squad:{member}` labels for routing (see `.squad/skills/glab/SKILL.md` for full patterns).
- **MRs** are created with `glab mr create --fill` and merged with `glab mr merge <id>`.

Quick reference:

```bash
glab issue list --label "squad"          # issues in the Squad queue
glab issue create --title "..."          # create a new issue
glab mr create --fill --target-branch main  # open an MR from current branch
glab ci status                           # pipeline status on current branch
```

Full command reference → `.squad/skills/glab/SKILL.md`.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `bootstrap.sh: No such file or directory` | It has already run and self-deleted. The project is already renamed — no action needed. |
| `bundler: command not found` | Run `gem install bundler`, then `cd app && bundle install`. |
| `error: no available simulator named 'iPhone 17 Pro'` | Either install that simulator in Xcode → Platforms, or override: `SIMULATOR_NAME="iPhone 16" ./app/build.sh test`. |
| `fastlane ci` fails on `swiftlint` | Install SwiftLint (`brew install swiftlint`) and add a `.swiftlint.yml`, or remove the `swiftlint(...)` call from the `ci` lane in `app/fastlane/Fastfile`. |
| `match` errors: `git_url is empty` | Fill in `git_url(...)` and `username(...)` in `app/fastlane/Matchfile` before running `fastlane certs` / `beta` / `release`. |
| `UI.user_error! Unable to read app_identifier` | `app/fastlane/Appfile` still has the `__BUNDLE_ID__` placeholder — run `bundle exec fastlane beta` only after bootstrap and filling in real values. |
| `ASC_API_KEY_JSON` not set | Place `asc_api_key.json` at `app/fastlane/asc_api_key.json` or export `ASC_API_KEY_JSON`. See `docs/app-store-connect-privacy-setup.md`. |
