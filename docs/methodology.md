# Methodology — how the whole thing fits together

This kit is a **testing discipline**, not a test framework. It plugs your real test commands
into a structure that answers one question honestly: *"is this actually verified, or does it
just have green somewhere?"*

It rests on **three pillars**, and no pillar replaces another:

1. **Run tiers** (§2) — the machine that runs scenarios across platforms.
2. **The regression ledger** (§3) — memory that "what was built before must not be lost", with
   guard tests.
3. **Acceptance by eye on real data** (§4) — the final check on production-like data that an
   automated test cannot reproduce.

Plus two cross-cutting mechanisms: a **push gate** (§5) that won't let unverified code into the
mainline, and **AI tester roles** (§6) — a generator of cases nobody wrote down. The discipline
that keeps it all from rotting is in §7.

---

## 2. Run tiers — the engine

There is no single "one tool for everything". A run is **four tiers**; ideally one test body
runs across your platforms (mobile / desktop / web).

| Tier | What it checks | How it's realized |
|---|---|---|
| **0. Golden** | "visually, what was built didn't break" — pixel baselines of components | Your framework's golden tooling (e.g. Alchemist for Flutter, jest-image-snapshot / Playwright for web, paparazzi for Android, snapshot testing for iOS). **Pin fonts + DPR** for cross-machine determinism, else render drift. |
| **A. Scripted regression** | ~90% of delivery / read / state scenarios on every platform | Your official integration-test runner. **A second user is NOT a second GUI — drive collaborator accounts programmatically through your app's own API (HTTP/SDK) directly in the test.** Deterministic; one device instead of two. |
| **B. Interactive exploration** | debugging and scenarios hard to script | Live drivers: UI-inspection / device-automation tooling + CLI. This is where the human (or an AI tester role) pokes at the running app. |
| **C. Native scenarios** | push, banners, permission dialogs, the notification shade — things an in-process integration test physically cannot see | OS-level tools: `simctl push` (iOS), `am` / `dumpsys notification` (Android), desktop UI automation (macOS/Windows). |

**Why Tier A can't see push:** an integration test runs *inside* the app process and is blind
to native OS UI. That's a tool limitation, not a method limitation — push is covered by Tier C.
The full production push path (server → gateway → APNs/FCM → device, and any notification-service
logic) is outside the cheap local loop (needs sandbox APNs / a real distribution build) and is
marked `manual`.

**The key pattern (as upstream messaging clients do it):** drive the counterpart account
programmatically via your backend's events — the app is its own sync bus, no separate test
coordinator needed. If your product has login / anti-abuse guards, satisfy them in the harness
(e.g. a required device name / header) — note that as a project-specific gotcha to fill in.

Two entry points, deliberately different names so you never confuse "ran the current thing"
with "ran everything":

- **`/e2e-local`** — the current session/branch's functionality (fast; scope = diff + guards of
  affected areas).
- **`/e2e-full`** — the whole accumulated suite + ledger reconciliation (the pre-MR ritual).

The kit ships a framework-agnostic runner (`scripts/run-all.sh`) that executes your configured
phases in order, records PASS/SKIP/FAIL, and — only on a clean run — writes the marker the push
gate checks.

---

## 3. The regression ledger — "what was built isn't lost"

The ledger stores **invariants**: "X was built here; a future change must not break Y, because
Z; the guard is this test." Not a duplicate of git history, not a diary — *why-it-is* +
*what-not-to-break* + a link to a guard test. Full spec — [`regression-ledger.md`](regression-ledger.md).

Mechanics in one breath: one file per invariant `tests/registry/RL-<slug>.md`; the guard test
carries a grep tag `ledger:RL-<slug>`; `scripts/ledger-check.sh` greps the tags and reports
**OK** (guard present) / **UNCOVERED** (record exists, guard missing or skipped → *possibly
lost*, the main signal) / **ORPHAN** (tag exists, record missing → ledger is behind). Presence
is proven by grep; **greenness only by a run** — so reconcile *after* `/e2e-full`, never as a
static check.

**Acceptance criteria at assertion granularity.** Prose captures a requirement in words, but the
tester still picks the asserts — a quantifier like "ALWAYS / in all cases" dissolves, and it's
easy to cover 1 of N cases and call it covered. So an explicit requirement becomes a
`## Acceptance criteria` section: a verbatim quote + atomic `AC-N` items, each tagged
`AC:RL-<slug>/N` on an assert against the **real** widget (or marked `manual`). The reconciler
adds `AC_OK` / `AC_MANUAL` / `AC_UNASSERTED`, and **`AC_UNASSERTED` blocks the run**. It also
flags `MOCK_ONLY`: a UI guard that tests a replica/primitive instead of the real render — the
exact class where a mock stays green while the real render is broken.

---

## 4. Acceptance by eye on real data

Green automated tests ≠ the feature works: they run on a local seed account without real
conversations, groups, tenants, or federated participants. A whole class of bugs (mass-missing
avatars, a misplaced indicator, broken layout) is visible **only by eye on real data**.

- **Final acceptance before an MR is on a production-like account with real data.** Develop
  locally; do the final check on real data.
- **Never write test messages into real/working data** — keep dedicated test conversations /
  fixtures. Read-only checks (scroll, layout comparison) on real data are fine.
- Visual review follows a **UI inventory** — a map of every screen/zone with its coverage status
  (`unit` / `golden` / `visual` / `—`). Every zone of a touched screen is checked, not only the
  part you changed (a bug often lands on a neighbouring zone).
- Capture screenshots **without stealing focus** from the user (by window id, in the background).
- **Accepted visual baselines** live under `tests/screenshots/<RL-slug>/` via
  `scripts/snap-feature.sh`, captured on real data once a feature is visually verified; compared
  by eye during `/e2e-full`. Ad-hoc comparison screenshots go to a temp dir and are never committed.

---

## 5. The push gate — "no fresh e2e → not in the mainline"

- A successful runner writes a marker `test-results/e2e-pass.json` (`{sha, pass[], skip[]}`).
- A **versioned `githooks/pre-push`** (enabled once via `git config core.hooksPath githooks`)
  **blocks** a push to the mainline if the marker is absent / its `sha ≠ HEAD` / the required
  phases aren't in `pass[]`. An echo-forged marker won't pass — it needs a real list of passed
  phases keyed to HEAD.
- The gate also covers **feature branches that touch guarded source paths** — those almost
  always land on the mainline via a server-side merge that local hooks can't see, so this push
  is the only interception point. Branches with no guarded changes (docs/config) are free.
- Emergency bypass **only when infrastructure fails** (not a test): `SKIP_E2E_GATE=1 git push …`.

**Why a git hook, not an editor/agent hook:** the git hook is versioned and fires for *every*
author on *every* clone. Editor/agent hooks are per-machine and don't gate a human in a terminal.

**Merged ≠ delivered.** For a client/UI change, merging to the mainline, a green CI, and a
closed MR change only the *sources* — the installed binary is unchanged (and a *revert* likewise
doesn't remove the feature from an already-installed build). A report on such a change must state
**delivery status** (is the fix in the slice of the last *released* build?
`git merge-base --is-ancestor <fix> <release-commit>`), not just "merged".

---

## 6. AI tester roles — a generator of cases nobody wrote down

Tiers (§2) and the ledger (§3) are strong at "what was built didn't break", but their cases come
from a human — only what someone thought of is covered. The missing layer is a **systematic
generator of cases that aren't in the task**: exercising a feature from angles the author of the
requirement never considered.

These are **subagents** (`claude/agents/*.md` — YAML frontmatter + a system prompt). Each role
has a QA engine built in: **SFDIPOT** (what to test at all), **Whittaker tours** (angles),
**Hendrickson heuristics + data-type attacks** (hostile data), **FEW HICCUPPS** (the "is it a
bug" oracle), **RCRCRC** (what to re-check after a change). Full reference —
[`heuristics.md`](heuristics.md). Roster:

- `exploratory-qa-tester` — the core; finds unrequested defects.
- `adversarial-verifier` — tries to *refute* a claimed invariant + checks delivery.
- `regression-scout` — RCRCRC over a diff (what to re-check nearby).
- `test-automator` — turns a confirmed defect into a guard + an RL record.
- `registry-coverage-analyst` — coverage holes, rated 1–10.
- `native-platform-specialist` — Tier C (push/permissions/shade).
- `prod-acceptance-visualizer` — visual acceptance on real data.
- `code-reviewer` — independent critical review of a diff.
- `qa-lead-orchestrator` — decomposes, delegates, synthesizes go/no-go.
- `qa-judge` — LLM-as-judge; scores a testing report, cuts hallucinated bugs.

**The roles don't replace the loop — they feed it.** An unrequested invariant they find is
closed the normal way: an RL record + a guard tagged `ledger:RL-<slug>` (+ a golden/baseline if
there's a screen), passes acceptance by eye (§4) and the *same* push gate (§5). No parallel
bookkeeping.

---

## 7. The flow, end to end

```
develop (locally, seed/test account)
      │
      ├─ as you go:  golden + local integration        (Tier 0 + A, scoped by diff)
      │              /e2e-local — current branch's functionality
      │
      ├─ (opt.) roles §6: exploratory / adversarial / regression-scout →
      │         unrequested cases → confirmed defect → test-automator
      │
      ├─ new invariant →  /pin-feature  (guard test + golden + RL record, ledger: tag)
      │
      ├─ before MR:  /e2e-full  (= full suite + ledger reconciliation + manual checklist)
      │              green ONLY if no FAIL, no UNCOVERED, no AC_UNASSERTED, all manual done
      │              → writes marker test-results/e2e-pass.json
      │
      ├─ acceptance by eye §4: review the UI inventory on real data
      │
      ├─ push feature branch → githooks/pre-push checks the marker §5
      │
      └─ MR to mainline → (client) ship a native build; "done" = the user can VERIFY it
```

---

## 8. Discipline — the minimum so the loop doesn't rot

- **Bug fix via a red reproducer.** Root cause first (not the symptom), then a test that fails on
  the OLD code for the right reason, then the product fix. Record the red→green proof.
- **Never force green.** Don't weaken asserts, don't bulk-update goldens, don't `@Skip` without a
  linked ticket. Tests without an assertion are banned.
- Added a guard for a regression → add an RL record (and vice versa). Pin it in the SAME MR as
  the feature (part of "done"), not "at the end".
- What a cheap auto test can't cover (push/NSE, real payments, media streaming, real IdP, real
  devices, sound/jank) → mark `guard.type: manual` with a checklist; never disguise it as auto,
  never count it "green".
- Comparison artifacts go to a temp dir, never committed (except accepted baselines under
  `tests/screenshots/<RL-slug>/`).
- Hooks warn; they don't block (except the versioned `pre-push`) — so follow the rules yourself.
