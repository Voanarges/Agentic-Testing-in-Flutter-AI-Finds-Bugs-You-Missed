# Test heuristics — the engine inside the AI tester roles

These are classic, framework-agnostic testing heuristics. Every AI tester role in this kit is a
thin wrapper around them. You can use them by hand just as well. They answer three different
questions — keep them separate:

- **Coverage** ("what did I try?") — SFDIPOT, Whittaker tours, Hendrickson attacks.
- **Oracle** ("is it a bug?") — FEW HICCUPPS.
- **Impact after a change** ("what else to re-check?") — RCRCRC.

A passed tour is not a found bug. A hypothesis is not a defect. Keep those distinct too.

---

## Session-based charters (do this first)

Before enumerating axes, write **3–5 charters**: "Explore <area> with <data/condition> to find
<class of risk>." Each charter is a time-box — go DEEP on one, not WIDE across all. Breadth
without depth is the known failure mode of an LLM tester: two charters to the bottom beat ten
skimmed. In the report, mark which charter was worked, which was cut short, and why.

---

## SFDIPOT — what is there to test at all

Walk the feature across seven dimensions and write down what each one has for THIS feature:

- **S**tructure — which files/components/modules it's made of (find them).
- **F**unctions — everything the feature DOES, and how its functions interact.
- **D**ata — inputs / outputs / stored: big/small, valid/invalid, ordered, noisy (length,
  emoji, RTL, markup in a text body, media, files at the size limit).
- **I**nterfaces — UI, API, event/message payloads, deep links, embedded web views.
- **P**latform — each OS/browser; OS version; update OVER an old build; a federated/remote
  counterpart; network (offline / flaky / power-save).
- **O**perations — how it's really used: roles/permissions, 1:1 vs group vs tenant, rare and
  extreme scenarios.
- **T**ime — timing/order: server-echo races, timeouts, timezone/date change, simultaneous edits
  from two sessions, lagging acknowledgements.

---

## Whittaker tours — angles of attack

Walk the feature through the relevant tours; for each, write concrete steps for YOUR product:

- **Guidebook** — exactly by the spec (does the doc match reality?).
- **Money** — the showcase/demo scenarios.
- **Landmark** — jumps between the feature's key screens.
- **FedEx** — carry data all the way through: sender → backend → echo → receiver → notification →
  tap → navigation.
- **After-Hours / Museum** — leave the app open for days; update over an old build; touch legacy
  code and stale records.
- **Obsessive-Compulsive** — repeat one action many times; undo/redo; send, delete, edit the same
  thing.
- **Defocused** — don't aim: do 5 UNRELATED actions (open, background, change timezone, send
  media, return) and watch ACCUMULATED state (badges, avatars, stuck indicators). State-
  accumulation bugs don't fall to a one-shot aimed test — this is how stuck badges, boot loops,
  and flickering indicators surface.
- **Saboteur / Antisocial** — try to break it: resource starvation, illegal data, actions in the
  wrong order, cancel mid-way.
- **Back-Alley / Couch-Potato** — the least-used features; everything on defaults.
- **Supermodel** — appearance only: layout, narrow/wide, render, transitions.

---

## Hendrickson heuristics + data-type attacks — hostile data

For each field/input, generate evil data:

- **Boundaries / Goldilocks** — at the edge and just past it: the narrowest container, the longest
  name, an attachment exactly at the limit and +1 byte.
- **Count 0 / 1 / many** — 0 items, 1, 10,000; 0/1/N participants; 0 unread.
- **Selection some / none / all** — some permissions, none, all.
- **Numbers** — 0, 2^15, 2^16, 2^31, negative, fractional, comma vs dot decimal.
- **Strings** — very long (255/256/1000/2048+), accents, CJK, emoji, whitespace, separators;
  markup/HTML in a text body; RTL.
- **Dates/Times** — Feb 30, Feb 29 of a non-leap year, DST change, different timezones, timeouts.
- **Injection & Nulls** — HTML/JS in text (XSS in a renderer); NULL / empty / missing field
  EVERYWHERE (an empty filename on save; an empty remote profile → a blanked avatar).
- **Interruptions / Starvation** — log out mid-operation, kill the process, drop the network,
  power-save, disk/memory full, interrupt a recording by leaving the screen.
- **Multi-User / Flood** — simultaneous edits from two accounts; the same account in two sessions;
  a burst of messages.

---

## FEW HICCUPPS — is it a bug? (the oracle, with discipline)

Coverage heuristics say *what I tried*; the oracle says *is it a bug*. Discipline:

1. First describe the **observation neutrally** (what is on screen / in the log).
2. Only THEN name the consistency oracle it violates:
   **F**amiliarity (known bugs), **E**xplainability, **W**orld — **H**istory (past versions),
   **I**mage (brand), **C**omparable products, **C**laims (spec/docs), **U**ser desires,
   **P**roduct (internal consistency), **P**urpose (explicit AND implicit uses), **S**tatutes.
3. If your only oracle is the subjective **User desires / Purpose** "when the spec is silent",
   you MUST cite a second independent oracle (History, Comparable, Product-consistency, or
   Claims). One subjective oracle alone is `severity = Question` (a risk/question), not a
   confirmed defect.

---

## RCRCRC — what to re-check after a change

Walk a diff across six axes; a fix often breaks a neighbour whose file isn't in the diff:

- **R**ecent — what this change just added (most fragile).
- **C**ore — critical functions it touches indirectly (delivery, login, acknowledgements, push).
- **R**isk — the riskiest zones nearby (encryption, federation, DB migrations, payments).
- **C**onfiguration — platform/environment dependence (each OS; prod vs local; user role).
- **R**epaired — recent fixes in the same area (they introduce regressions — cross-check
  `git log` and the ledger).
- **C**hronic — the perennially-flaky places in YOUR product (find them in the ledger by area).

---

## Red reproducer — the bug-fix discipline

A guard that was never red doesn't prove it catches the regression. Before fixing the product:

1. Find the **root cause** (not the symptom) and explain it plainly.
2. Write a test that **fails on the OLD code for the right reason** (red).
3. Then fix the product (green).
4. Record the red→green proof in the RL record ("reverting the fix turns the test red").

For pinning a *feature* (not a fix): prove the guard goes red when you temporarily break the
invariant, then restore it.

---

## Hypotheses are not defects

If you have no device / no live environment, you produce **case plans and risk hypotheses**, not
defects. Put them in a separate "Hypotheses (not reproduced)" section — never in the defect list,
never with a severity or an RL proposal. A hypothesis must name: (a) the exact code line that
grounds it, (b) the concrete input that would test it, (c) what you'd expect to see. "Probably
breaks / likely a bug" is banned — only "line X on input Y is grounds to check Z".
