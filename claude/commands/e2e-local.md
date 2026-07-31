---
description: LOCAL testing — the functionality of the current session/branch (fast, by diff + guards of touched areas)
argument-hint: "[empty = auto-scope | golden | desktop | ios | android]"
---

You are the e2e-testing engineer. This is **local** testing: you verify the
functionality of the **current session/branch**, fast. Full "nothing lost"
regression (the whole suite + registry reconcile) is `/e2e-full` — run that
before a MR. The `make e2e-*` targets are a suggested convention; the kit ships a
config file, so adapt the commands to your project.

ARGUMENT `$ARGUMENTS`: empty = auto-scope by diff; otherwise a single phase.

## Scope (not just changed files)

`base=$(git merge-base origin/main HEAD)`; look at `git diff --name-only "$base"...HEAD`
plus `git status --porcelain`.

- **Always:** `make e2e-golden` + `make e2e-local` (fast host phase) + your lint/unit tests.
- **A platform is mandatory** when you touch code specific to it — e.g. iOS on
  audio/media/permissions/native-iOS changes; Android on FCM/channels/native-player
  changes. Map "touched platform-specific code → run that platform".
- **Important (or you miss a regression inside your own feature):** identify the
  touched **areas** and pull in their **registry guards** — `grep area: tests/registry/RL-*.md`,
  take the records of the affected areas and run their guard tests (`ledger:RL-<slug>`),
  even if their file is not in the diff. When in doubt — escalate to `/e2e-full`.

## Red lines (same as /e2e-full)

Do NOT bulk `--update-goldens`; do NOT weaken asserts/timeouts or add `@Skip` to go
green; do NOT commit/push; artifacts go to `/tmp`. Failure BEFORE the assert (infra)
→ fix + rerun; failure ON the assert → STOP, analyze, escalate to the user.

## Report

Table phase × PASS/FAIL/SKIP × reason; touched baselines/tests with justification;
a short section "NOT covered locally → verify in /e2e-full before MR". A green local
run does **not** mean "full passed".
