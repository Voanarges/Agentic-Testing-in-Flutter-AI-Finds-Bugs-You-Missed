---
description: Add a golden snapshot of a screen (CI mode) + prove the baseline catches a shift — "add a snapshot …"
argument-hint: "<screen/widget name, e.g. ChatScreen>"
---

You are the visual-regression engineer. The user asks you to add a golden
snapshot of `$ARGUMENTS`. This is Tier 0: a pixel baseline that "what was done
before is not visually broken". You do not change logic.

## What to do

1. **Golden via your framework's golden tooling in CI mode** — pixel golden
   snapshots (e.g. Alchemist for Flutter, jest-image-snapshot / Playwright for web,
   paparazzi for Android, snapshot testing for iOS) with **fonts + DPR pinned** for
   cross-machine determinism. A test-only font where every glyph is a solid box (e.g.
   Ahem) makes rendering stable across platforms. Put the test in your golden test dir.
   - Prefer defaults that avoid real-OS fonts (they're brittle across machines); pin
     fonts/DPR through your tooling's CI mode rather than per-test. Don't set up
     platform-specific goldens without a reason.
   - **Test the REAL widget from your source, not a copy/isolated icon.** A golden on
     an isolated element or on hardcoded colors (instead of the theme's color scheme)
     gives a false green: the production widget can break while the baseline stays
     green. Take colors and icons from the real theme, wrapped in your golden harness.
   - **Geometry assert** (measure a rect) — to check structural **alignment** without
     magic numbers. Valid on box-font boxes (alignment), NOT for wrapping real text.
   - In a comment, describe **what's in the snapshot**.
2. **Scenario grid** (a golden-scenario helper multiplies cheaply): cover
   **light + dark** (indicators tied to the color scheme differ in dark theme), at
   least **2 widths** (narrow screen → status-row/badge overflow) and, if relevant,
   an increased text-scale factor (accessibility breaks layout).
3. **Generate the baseline and commit** (update-goldens by name, then run the golden
   suite — green). The `.png` baseline goes in your golden output dir.
4. **Prove the gate works (on the PROD widget):** deliberately shift one padding in
   the real widget → the golden suite goes red → revert → green again. If the test
   does NOT go red on a prod-widget shift, it's testing a copy (see step 1) — redo it.
   The render backend (e.g. Impeller vs Skia) can cause subpixel icon drift — keep
   your tooling's default threshold and keep this in mind on a "mysterious" failure.
5. If the screen is tied to a registry invariant — add the tag `ledger:RL-<slug>` and
   update `tests/registry/RL-<slug>.md`.

## Red lines

**Do NOT rewrite an existing baseline without the user's explicit consent.** If a
baseline truly must change — first show what changed on screen (old vs new png) and
ask for confirmation. Do NOT bulk `--update-goldens` to go green: subpixel drift is a
failure, we analyze it, not "update". Comparison screenshots go to `/tmp`, not git.
