# The regression ledger — spec

So that as you improve things, **what was built before isn't lost** and is accounted for in
testing — a day ago or a month ago, doesn't matter.

## What it is, and what it is NOT

The ledger stores **invariants** — "X was built here; a future change must not break Y, because
Z; the guard is this test." It's *why-it-is* + *what-not-to-break* + a link to the guard test.

It does **not** duplicate:
- git history (what exactly changed lives there) — a record references a SHA, doesn't copy it;
- a dated work diary — ten diary notes distill into one ledger record;
- a bug tracker — the ledger links the anchor; the tracker keeps "bug ↔ case"; the ledger keeps
  "invariant ↔ guard".

**The source of truth about status is the test itself, not this file.** There is deliberately NO
"status: green" column — it goes stale and lies. Greenness / redness / loss is computed by a run
(`/e2e-full` → `ledger-check.sh`).

## Format: one file per record

A single big table degrades (unreadable + merge conflicts across parallel branches). So: **one
file per invariant**, `RL-<slug>.md` with YAML frontmatter. The index (`INDEX.md`) is generated
by `ledger-check.sh` (a snapshot with OK/MANUAL/UNCOVERED buckets, dedup by slug), never
hand-maintained, and **not committed** (`.gitignore`) — an aggregate file would reintroduce the
merge conflicts the file-per-record format exists to avoid.

- **IDs are slugs, not counters** (`RL-checkout-total`) so two parallel branches don't grab the
  same number and collide on merge.
- **Granularity is one invariant / risk zone, not one commit.** Group an area's regressions into
  one record with history. A feature with no fragility needs no record (the code/test describes
  it). A bug fix with a non-obvious cause needs one, always.

## Record ↔ test link (grep tag, not markdown parsing)

Reconciliation does not parse tables. The guard test's **name or a comment** carries the tag
`ledger:RL-<slug>`; the record's `guard.ref` holds the same id. `ledger-check.sh`:

1. collects ids from the frontmatter of all `RL-*.md`;
2. greps the tests for the tags actually present (`ledger:RL-…`);
3. prints **three sets**:
   - **OK** — the record has a guard tag (present, not skipped);
   - **UNCOVERED** — record exists, guard missing / skipped / a `manual` guard not marked done →
     "possibly lost" (the main signal);
   - **ORPHAN** — tag exists, record missing → the ledger is behind the code.

`grep` proves only presence. **Greenness comes from a run** — so reconcile AFTER `/e2e-full`, not
as a static check (otherwise it lies "covered" while a test is long-red or skipped).

## Frontmatter fields

```yaml
id: RL-checkout-total             # stable slug, never renamed
area: checkout                    # your own vocabulary (auth/search/media/billing/infra/…)
created: 2026-01-01               # when the invariant was pinned
last_touched: 2026-01-08          # last edit of the record
status: active                    # active | retired (feature removed → tag and test removed)
visual: recommended               # required | recommended | none (UI invariant → required)
commits: [3e1a90c]                # SHAs (immutable), NOT branch names
guard:
  type: golden                    # auto | golden | unit | widget | primitive | manual | none
  render: real-widget             # real-widget | device | pure-function | none (REQUIRED for UI)
  ref: ledger:RL-checkout-total   # for auto/golden — the tag; for manual — "see body"
supersedes: []                    # link to prior records of the same area
```

Body: the **invariant** (what must not break and why), gotchas, and for `manual` — the manual
steps + `last_manual_check: <date>`.

## Two testing modes

One engine, two entry points, distinct names so you never confuse "ran the current thing" with
"ran everything":

- **Local** — `/e2e-local`: the current branch's functionality. Scope = changed files **+ the
  guards of affected areas** (a fix can break the guard of its own feature, whose file isn't in
  the diff).
- **Full** — `/e2e-full`: the whole accumulated suite + **ledger reconciliation** + the `manual`
  checklist. Green only if no `FAIL`, no `UNCOVERED`, no `AC_UNASSERTED`, and all `manual` marked
  done. Run **before an MR**.

## Discipline (the minimum so it doesn't rot)

- Added a guard for a regression → add an RL record (and vice versa). A self-sustaining loop.
- **A bug fix is pinned by a red reproducer**: the test must have failed on the code BEFORE the
  fix (or when it's reverted) — recorded in the RL record's **Red-proof** section. A guard that
  was never red doesn't prove it catches the regression.
- `@Skip` only with a linked ticket; tests without an assertion are banned.
- A `manual` guard has a shelf life: stable for N runs → convert it to auto.
- Feature removed → `status: retired` + delete the tag and test (don't leave a dead hole).

## Acceptance criteria at assertion granularity

Prose captures a requirement in words, but the tester still decides which asserts to write — a
quantifier ("ALWAYS / in all cases") dissolves, and it's easy to cover 1 case of N and call it
"covered". That is exactly how an alignment bug can ship green: the requirement lived in prose,
but the guard checked a hand-built REPLICA of the layout, not the real widget.

**Format** (a `## Acceptance criteria` section in the record, see `../registry/_TEMPLATE.md`):
- **Source + a VERBATIM quote** of the requirement (block-quote) — not a paraphrase.
- Numbered atomic `AC-N`, each one MEASURABLE assertion (coordinate / pixel / order / ∀ over the
  EXPLICITLY listed cases).
- Coverage of each `AC-N`: either the tag **`AC:RL-<slug>/N`** in the name/comment of an auto
  assert (on the REAL widget), or an item marked **manual** → a checklist entry.

**Reconciliation** (`ledger-check.sh`, part of `/e2e-full`) adds buckets:
- `AC_OK` — the `AC-N` has an assert tag `AC:RL-<slug>/N` in the tests;
- `AC_MANUAL` — the item is marked manual → a mandatory manual checklist (can't be skipped);
- `AC_UNASSERTED` — declared, but neither an assert nor manual → **BLOCKS the run** (the
  assertion-level analogue of UNCOVERED — the core of the mechanism).

## A UI guard must render the REAL widget, not a replica

A guard of UI layout/render must satisfy one of:
1. **renders the REAL production widget** (the same type that ships; stub children are fine). A
   hand-built replica of the layout (a local widget that copies the production `build()`
   structure) does **NOT** count — it tests "how the author thinks it looks", not production.
2. **an isolated primitive** (`guard.render: pure-function`) — counts as coverage ONLY with a
   captured `visual` baseline (a host-golden on a box-glyph font like Ahem doesn't catch
   alignment / font-metrics).

`ledger-check.sh` flags a UI record without `real-widget`/`device` as `MOCK_ONLY` (advisory). If
the load-bearing logic is inline in a big `build()`, extract it into a presentational widget
first, then guard it (otherwise there's nothing to test but a replica).

## Optional: reverse audit of server-driven feature signals

By default the ledger is one-directional ("does each record have a tag?"). It does NOT catch
"does each feature have a record?" — a server feature shipped without a record shows a false
"UNCOVERED 0". If your product has feature signals in code (route/handler/command constants),
point `REVERSE_AUDIT_CMD` (in `regression.config.sh`) at a script that enumerates them from code;
any that lack a live guard tag are reported as `UNPINNED` (advisory). The source of truth is the
code, so a *new* feature signal enters the audit automatically.
