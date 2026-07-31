---
description: FULL testing — the whole accumulated suite + regression-registry reconcile (before MR)
argument-hint: "[empty = all | golden | desktop | ios | android]"
---

You are the e2e-testing engineer. This is **full** testing: run EVERYTHING
accumulated (current + all previously done) + verify that **nothing was lost**. Run
it **before a MR**. For a fast run over the current branch — `/e2e-local`. The
`make e2e-*` targets are a suggested convention; the kit ships a config file, so
adapt the commands to your project.

ARGUMENT `$ARGUMENTS`: empty = the whole engine (`make e2e-all`); otherwise a single
phase (`golden`/`desktop`/`ios`/`android`).

## What "full" does (≠ "run every file")

1. **The whole suite in phases** — `make e2e-all`: golden → desktop → iOS → Android
   (increasing cost, RAM gate, teardown between phases, PASS/FAIL/SKIP statuses with
   reason codes). On a memory-constrained host, keep one mobile target at a time.
2. **Registry reconcile** (`scripts/regression/ledger-check.sh`, part of `e2e-all`) —
   reconciles `tests/registry/RL-<slug>.md` against tests via the grep tag
   `ledger:RL-<slug>`. Three outcomes:
   - **OK** — the record has a live guard tag;
   - **UNCOVERED** — record exists, no guard / it's `@Skip` / `guard:none` → **"possibly
     lost"**, the primary signal; UNCOVERED fails the full run;
   - **ORPHAN** — tag exists, no record → registry is stale, add an RL record.
   - If your product has server-driven feature signals (route/handler/command
     constants), extend the ledger's reverse-audit to enumerate them from code so a
     new feature without a guard shows up.
2b. **Visual reconcile** (`make e2e-visual`, part of `e2e-all`, Tier B) — reconciles
   reference baselines `tests/screenshots/<RL>/` against files and the registry, and
   prints a checklist "compare the current UI to the baseline BY EYE". Outcomes:
   PENDING (baseline not yet captured — for a UI record this is a signal to capture
   via `scripts/regression/snap-feature.sh`), MISSING/ORPHAN fails the run. Golden
   (Tier A) gives auto pixel-diff separately.
3. **MANUAL checklist** — for records with `guard.type: manual` print their steps
   (from the body of `RL-*.md`) as a mandatory manual gate. Full is **not green**
   until manuals are marked passed (set `last_manual_check` in the record).

## Red lines (violation = masking a regression)

- ❌ Do NOT bulk `--update-goldens` to go "green". Update a baseline only on a
  deliberate UI change, by name, with justification in the report; subpixel drift =
  a failure, not "update".
- ❌ Do NOT weaken asserts/timeouts, do NOT add `@Skip` without a link to an RL/issue.
- ❌ Do NOT pass UNCOVERED/SKIP off as PASS; a resource-driven SKIP ≠ bug, but also ≠ green.
- ❌ Do NOT commit/push/deploy; artifacts go only to `/tmp/e2e-*`.

## Triage

- Failure BEFORE the assert (stack/zombie/session/race/backend infra-flake) → fix and
  rerun once; mark infra-fail separately from a regression.
- Failure ON the assert (expected ≠ actual) → STOP, bug candidate, analyze hypotheses,
  escalate to the user. Do not patch blindly.
- UNCOVERED against a registry record → add/fix the guard test (or, if the feature was
  removed, `status: retired` + delete the tag/test). Do not leave a dead hole.

## Report (always)

1. Table phase × `PASS/FAIL/SKIP` × reason × duration.
2. **Reconcile:** lists OK / UNCOVERED / ORPHAN + MANUAL checklist with status.
3. Touched baselines/tests, each justified (none — say so).
4. **NOT covered** (always): background push, real devices, sound/jank,
   federation/auth — that's manual/device work.
5. **"Green" verdict** = no FAIL AND no UNCOVERED AND all MANUAL passed. Otherwise
   "partial/red" + what to do. Do not write "all verified" while there's SKIP/UNCOVERED.
