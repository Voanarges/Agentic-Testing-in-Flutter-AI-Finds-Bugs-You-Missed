---
description: Fix a failing test without forcing it green (iron rule) — "fix the test …"
argument-hint: "<failing test name, e.g. chat_screen_test>"
---

You are the e2e engineer. `$ARGUMENTS` failed. Iron rule: NEVER force it green.

## Order (strict)

1. **Find the cause** and explain in plain words what broke and why. Classify:
   - **infra-fail** (fix and rerun ONCE): stack/zombie process/stuck session/backend
     race/simulator `Cannot allocate memory`/keychain-CA — things that are NOT about
     app logic.
   - **regression candidate** (STOP): a deterministic assert-fail.
   - ⚠️ **Timeout waiting for a UI element** (`waitUntil`/`waitForEvent` never got the
     widget) — do NOT auto-file it as infra and do NOT retry blindly: "the element
     stopped appearing" is often a real regression. Treat it as an assert. You may
     retry only a network/sync timeout with proof the backend genuinely didn't deliver
     the event.
2. **Real regression → STOP.** Work through 2–4 cause hypotheses with trade-offs,
   propose a fix to the PRODUCT (not the test) and wait for "ok". Do not patch blindly.
   Root-cause before the fix.
3. **Red reproducer (if you're fixing a BUG, not just a green test).** Before touching
   the product — make sure there's a test that fails on the OLD code for the right
   reason. No such test for this bug → write it first (red), then fix (green). A
   bug-fix without a prior red reproducer is not accepted. Put the red→green proof in
   the RL record as a **Red-proof** section (reverting the fix fails the test).
4. **After the fix** run `/e2e-full` and show the rest is green.

## Forbidden (this is masking a breakage)

- ❌ Edit the test itself / weaken an assert / raise a timeout to make it pass.
- ❌ `--update-goldens` to make the baseline "accept" the new look without analysis.
- ❌ `@Skip`/`skip:` without a link to an RL record or issue.
- ❌ Mask a regression as an infra retry (loop until green).

If a baseline TRULY must change (deliberate UI change) — first show what changed on
screen, and ask for confirmation; update by name with justification. Artifacts go
only to `/tmp`, WITHOUT credentials (don't dump test-user passwords).
