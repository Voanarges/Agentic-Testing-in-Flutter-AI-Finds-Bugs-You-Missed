---
id: RL-<slug>                 # stable, never renamed, a slug (NOT a counter)
area: <auth|checkout|search|media|notifications|billing|infra|…>   # your own vocabulary
created: <YYYY-MM-DD>
last_touched: <YYYY-MM-DD>
status: active                # active | retired
visual: <required|recommended|none>   # UI invariant → required (needs a captured baseline)
commits: []                   # SHAs, not branch names
guard:
  type: <auto|golden|unit|widget|primitive|manual|none>   # matches the guard's tier
  render: <real-widget|pure-function|device|none>   # REQUIRED for a UI invariant
  ref: ledger:RL-<slug>       # the tag in the guard test's name/comment; for manual — "see body"
supersedes: []
---

# <Short invariant name>

**Invariant (what must not break, and why):** …

**Gotchas / traps:** …

## Acceptance criteria (from requirements)

<!--
  REQUIRED for a UI/behavioural feature. Captured BEFORE marking anything "done".
  Rationale: prose ("Invariant" above) captures the requirement in words, but the tester
  still decides which asserts to write — a quantifier like "ALWAYS / in all cases"
  dissolves, and it's easy to cover 1 of N cases and call it "covered". That is exactly
  how an alignment bug can ship green: the requirement was in prose, but the guard checked
  a hand-built REPLICA of the layout, not the real widget.

  - Source: a VERBATIM quote of the requirement (block-quote) + session/date. A paraphrase
    loses the quantifier ("ALWAYS", "in every") and the coordinates — quote it.
  - Each item = one atomic MEASURABLE assertion (one quantity: coordinate / pixel / order /
    ∀ over the explicitly listed cases).
  - Each AC-N is bound to coverage: either an auto-assert on the REAL widget tagged
    `AC:RL-<slug>/N`, or a mandatory manual-checklist item.
  - "ALWAYS / in all cases" → a multi-case assert (list the cases explicitly), NOT one example.
-->

Source: <session/date>.
> "<verbatim quote of the user's requirement>"

- [ ] **AC-1** <atomic measurable assertion + cases {…}>. — guard: `<test>` `AC:RL-<slug>/1`
- [ ] **AC-2** <…>. — guard: **manual** (`last_manual_check: —`)

**Guard:** `<path::test name>` or `golden <file>` — contains the tag `ledger:RL-<slug>`.
For a UI invariant the guard MUST render the REAL production widget (`guard.render:
real-widget`/`device`), not a hand-built replica of the layout; an isolated primitive
(`guard.render: pure-function`) does NOT count as coverage without a captured `visual` baseline.

**Red-proof (mandatory for a bug fix):** how it was proven the guard catches the regression:
"the test failed on the code before fix <sha> / when the fix is reverted" (red→green).
For pinning a feature (not a fix) — "goes red when the invariant is broken by temporarily
changing <what you changed>".

<!-- For guard.type: manual — the manual steps + last_manual_check: <date/session> -->
