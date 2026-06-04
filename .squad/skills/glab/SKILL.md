---
name: "glab"
description: "Use the GitLab CLI (glab) as the primary forge CLI for this GitLab-hosted project — the GitLab equivalent of gh for GitHub"
domain: "tooling, forge-cli, ci"
confidence: "medium"
source: "manual"
tools:
  - name: "bash"
    description: "Run glab commands in the shell"
    when: "Any time you interact with GitLab issues, MRs, pipelines, or the repo"
---

## Context

This project is hosted on GitLab. Anywhere the base `squad.agent.md` says to use `gh issue ...` or `gh pr ...`, use the `glab issue ...` / `glab mr ...` equivalents instead. The Squad workflow (issue labels, branch naming, routing) is identical — only the CLI changes.

## Patterns

### 0. Prerequisites

Always confirm `glab` is available and authenticated before issuing any forge commands:

```bash
glab --version           # e.g. glab version 1.47.0 (2024-xx-xx)
glab auth status         # shows current user + token scope
```

If not authenticated:

```bash
glab auth login          # interactive: choose gitlab.com, browser or token
```

---

### 1. Issues

```bash
# List open issues
glab issue list

# Filter by label (Squad routing model uses "squad" and "squad:{member}" labels)
glab issue list --label "squad"
glab issue list --label "squad:hopper"

# View a single issue
glab issue view 42

# Create an issue
glab issue create --title "Fix gauge math edge case" --description "Details here"

# Close an issue
glab issue close 42

# Add / update labels (route to a Squad member)
glab issue update 42 --label "squad:hopper"
glab issue update 42 --label "squad:ralph"

# Remove a label
glab issue update 42 --unlabel "squad:hopper"
```

Branch convention stays unchanged: `squad/{issue-number}-{slug}`, e.g. `squad/42-fix-gauge-math`.

---

### 2. Merge Requests (GitLab's equivalent of Pull Requests)

```bash
# Create an MR from current branch to main (--fill pulls title/body from commits)
glab mr create --fill --source-branch squad/42-fix-gauge-math --target-branch main

# List open MRs
glab mr list

# View an MR
glab mr view 7

# Check out an MR locally
glab mr checkout 7

# Approve an MR
glab mr approve 7

# Merge an MR (fast-forward or squash as appropriate)
glab mr merge 7
glab mr merge 7 --squash --remove-source-branch
```

**Review feedback → Ralph:** When you receive inline MR review comments, treat them exactly as you would GitHub PR review comments — log the feedback in the Ralph circuit-breaker doc and address each thread before re-requesting review.

---

### 3. CI / Pipelines

```bash
# Status of the pipeline on the current branch
glab ci status

# Interactive log view of the latest pipeline
glab ci view

# List recent pipelines for the repo
glab pipeline list

# Retry a failed pipeline
glab pipeline retry <pipeline-id>
```

A pipeline must be **passed** before merging — this is the merge gate. If `glab ci status` shows a failure, fix the issue before `glab mr merge`.

---

### 4. Repo

```bash
# Open repo in browser / show metadata
glab repo view

# Clone (HTTPS or SSH inferred from glab config)
glab repo clone yashas.gujjar/ios-swiftui-fastlane-template
```

---

### 5. Squad label mapping

| Action | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| List issues with Squad label | `gh issue list --label squad` | `glab issue list --label "squad"` |
| Route to member | `gh issue edit <id> --add-label "squad:hopper"` | `glab issue update <id> --label "squad:hopper"` |
| Create PR/MR | `gh pr create --fill` | `glab mr create --fill` |
| List PRs/MRs | `gh pr list` | `glab mr list` |
| Merge PR/MR | `gh pr merge <id>` | `glab mr merge <id>` |
| CI status | `gh run list` | `glab ci status` |

---

## Examples

**Full new-feature flow:**

```bash
# 1. Create issue
glab issue create --title "Add dark-mode gauge colours" --description "Track work for #55"

# 2. Branch
git checkout -b squad/55-dark-mode-gauge

# 3. ... do work, commit ...

# 4. Push and open MR
git push -u origin squad/55-dark-mode-gauge
glab mr create --fill --target-branch main

# 5. Check CI
glab ci status

# 6. Merge when green
glab mr merge 55 --squash --remove-source-branch
```

---

## Anti-Patterns

- **Don't mix `gh` and `glab` on the same repo.** This project is GitLab-only; `gh` commands will fail or silently target the wrong remote.
- **Don't merge before CI is green.** Always run `glab ci status` and wait for a passing pipeline.
- **Don't forget `--fill` on `glab mr create`.** Without it you'll get an empty MR title/description.

---

## Graceful Degradation

If `glab` is unavailable:

1. **GitLab Web UI** — https://gitlab.com/yashas.gujjar/ios-swiftui-fastlane-template — handles all of the above interactively.
2. **REST API via curl:**

```bash
# Example: list open issues
curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/projects/yashas.gujjar%2Fios-swiftui-fastlane-template/issues?state=opened"

# Example: create an MR
curl --silent --request POST \
     --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"source_branch":"squad/42-fix","target_branch":"main","title":"Fix gauge math"}' \
     "https://gitlab.com/api/v4/projects/yashas.gujjar%2Fios-swiftui-fastlane-template/merge_requests"
```

Set `GITLAB_TOKEN` to a personal access token with `api` scope.
