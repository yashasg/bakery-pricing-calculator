---
configured: false
interval: 1
timeout: 30
description: "BakeryPricingCalculator — iOS app build loop"
---

# Squad Work Loop — BakeryPricingCalculator iOS

## Model defaults

Default all Squad agent model selections to `claude-sonnet-4.6`. Exception: Ralph and Scribe must not inherit or use this default (they stay on `claude-haiku-4.5` — cheap mechanical ops).

## Goals (define and check off to exit)

1. **Working app** — `./app/build.sh test` exits 0, iPhone simulator, zero crashes.
2. **UI/UX approved** — Designer signs off on SwiftUI screens.
3. **User scenarios captured** — Researcher confirms scenarios are covered by tests.
4. **Expert approved** — Domain expert signs off on business logic correctness.
5. **Code tested and validated** — Tester runs `./app/build.sh test`; all tests pass, zero warnings.

## Each cycle

1. Check `.squad/decisions/inbox/` and `.squad/log/` for open items.
2. Pick the top open work item; assign to the right member (see roster below).
3. Make the change on a feature branch, then run `./app/build.sh test`. **A warning = a failure. Fix before moving on.**
4. Once the feature is complete and tests pass locally, push the branch and wait for CI/CD to pass. Do not merge until the pipeline is green. Then merge the branch into `main`.
5. Re-evaluate all goals.
   - Any goal ❌ or new drift found → **open an issue** with member name, goal #, and one-line description. Add to work items. Keep looping.
   - All ✅ → proceed to final review.

## Roster

| Member | Owns |
|--------|------|
| **Lead** | Architecture, blockers, handoffs |
| **{Dev}** | Feature implementation |
| **{Tester}** | All tests — unit + UI |
| **{Designer}** | UX review |

## Work items (priority order)

1. **Lead** — Define project goals and scaffold work items.
2. **{Dev}** — Implement core features.
3. **{Tester}** — Write tests.
4. **{Designer}** — Review UI.
5. **{Tester}** — Final test run: `./app/build.sh test` green, zero warnings.

## Final review (parallel — only when work items are empty)

All members review simultaneously against their area. Any new issue or drift found → **open an issue** and resume looping. All pass → log in `.squad/log/`, hand off.
