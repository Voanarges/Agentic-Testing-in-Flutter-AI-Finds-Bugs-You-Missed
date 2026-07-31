---
description: Pin a finished feature with a guard (e2e test + golden if it has a screen + registry record) — "pin the feature …"
argument-hint: "<feature/invariant name, e.g. sendMessage>"
---

You are the e2e-testing engineer. The user asks you to **pin** the finished
feature `$ARGUMENTS`: previously done work must not get lost. You do NOT change the
feature's logic — you only add a guard. See `tests/registry/README.md`.

**This is an authoring command** (it creates a guard), NOT a suite run. After it —
`/e2e-local` (confirm the new guard is green), before a MR — `/e2e-full`.

## What to do

1. **End-to-end test for the main user path.** File —
   `<your integration-test dir>/<slug>_test.<ext>` (slug = the same one used in the
   RL record; next to the other integration tests).
   - The second user is NOT a second GUI — drive collaborator/second-user accounts
     **programmatically through your app's own API (HTTP/SDK)** instead of spinning
     up a second GUI: the app is its own sync bus. Log in, send events, read
     receipts, wait for events over the API.
   - If your product has login/anti-abuse guards, satisfy them in the test harness
     (e.g. a required device-name/header) — note this as a project-specific gotcha
     to fill in, or the login gets rejected.
   - Waits — a `waitUntil` poll loop (e.g. `pump(100ms)`), NOT `pumpAndSettle`
     (it hangs on infinite animations in a live binding).
   - Main path = "opened → did the action → saw the result in the UI" for one side.
     Do not cover rare branches — that's `/pin-feature`, not the full suite.
   - **Isolation:** a unique room/context per run (a shared local backend accumulates
     state — otherwise flake). Teardown must NOT swallow exceptions silently (e.g. a
     forbidden leave failing the next case) — log it.
   - **Platform caveat:** receiving an event may be identical across the four
     platforms, but SENDING a state marker (e.g. a read receipt) can be
     platform-dependent (desktop takes one branch, iOS sends only when `resumed`).
     "One code = four platforms" holds for receive, not always for send.
2. **Stable identifier.** If the feature has an interactive/verifiable element —
   set a stable key (e.g. `ValueKey('<slug>_...')` or a semantics identifier).
   Without it, native inspectors (Tier B: mobile-mcp/FlaUI) don't see canvas-rendered
   widgets and finders are brittle. It also improves accessibility.
3. **If the feature has a noticeable screen — a golden snapshot baseline** (Tier A,
   auto pixel-diff): `/add-golden <Screen>` or by hand via your framework's golden
   tooling (e.g. Alchemist for Flutter, jest-image-snapshot / Playwright for web,
   paparazzi for Android, snapshot testing for iOS) with fonts + DPR pinned. If there
   is no screen or it's trivial — skip and say so explicitly.
3b. **If the task is about REAL UI — a reference screenshot (Tier B):** once the
   feature is verified in the interface at MR stage — capture a screenshot of the
   successful UI and register the baseline:
   `bash scripts/regression/snap-feature.sh <slug> <name> <png> "<desc>" [platform] [build]`.
   It lands in `tests/screenshots/<slug>/` (committed — it's a baseline, not /tmp).
   Mark the RL `visual: required`. Reconciled by eye on `/e2e-full` (`make e2e-visual`).
4. **Registry record** `tests/registry/RL-<slug>.md` per `_TEMPLATE.md`: the
   invariant ("what must not break and why"), gotchas, guards. Add the grep tag
   `ledger:RL-<slug>` to the guard test(s) (test name or comment). The slug is not a
   counter. Group by risk zone (one invariant = one record with history).
5. **Run** the added test (`make e2e-local` or the specific test file directly),
   show it green. **Prove the guard catches a regression**: temporarily break the
   invariant → the test goes RED → revert → green (same as `/add-golden`; "in your
   head" is not enough). Put the result in the RL record as a **Red-proof** section.
   `scripts/regression/ledger-check.sh` — the record must land in OK.
6. **Commit** the test + snapshot + RL record with a clear message. **Do not touch
   existing tests/baselines.** Explain in words what the test verifies.

## Red lines

Do NOT weaken asserts to go green; do NOT `git add -A` (stage only your own files);
run artifacts go to `/tmp`. If the test fails because of real behavior — STOP,
analyze hypotheses, escalate to the user (do not patch blindly).
