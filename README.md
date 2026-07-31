# Regression Testing Kit

A **testing discipline** for AI-assisted development — the kind where an agent ships code fast
and you need a structure that answers, honestly: *"is this actually verified, or does it just
have green somewhere?"*

It's not a test framework. It plugs **your** real test commands into a structure with three
pillars, a push gate, and a set of AI tester roles. Extracted and genericized from a production
messaging app; every product-specific and confidential detail has been stripped.

> If you got here from the article: this repo is the runnable version of what the article
> describes. Start with [`docs/methodology.md`](docs/methodology.md), then
> [`INSTALL.md`](INSTALL.md).

## The idea in one picture

```
Three pillars (no pillar replaces another):

  1. Run tiers        0 Golden · A Scripted · B Interactive · C Native
  2. Regression ledger   RL-<slug>.md  +  grep tag  ledger:RL-<slug>  +  reconcile
  3. Acceptance by eye   final check on real/production-like data

Two cross-cutting mechanisms:

  · Push gate       no fresh green e2e → not in the mainline (a versioned git hook)
  · AI tester roles  a generator of the cases nobody wrote down
```

## What's inside

```
regression-testing-kit/
├── docs/
│   ├── methodology.md          # the three pillars, four tiers, the end-to-end flow
│   ├── regression-ledger.md    # the ledger spec (the most portable, novel piece)
│   └── heuristics.md           # SFDIPOT · Whittaker tours · Hendrickson · FEW HICCUPPS · RCRCRC
├── claude/                     # Claude Code assets — copy into your repo's .claude/
│   ├── agents/                 # 10 AI tester roles (subagents)
│   └── commands/               # 5 slash commands: /e2e-local /e2e-full /pin-feature /add-golden /fix-test
├── registry/                   # the ledger — copy into your repo as tests/registry/
│   ├── _TEMPLATE.md            # copy this for each new invariant
│   ├── RL-example-checkout-total.md   # a worked example (delete once you have real ones)
│   └── README.md
├── scripts/                    # copy into your repo as scripts/regression/
│   ├── ledger-check.sh         # the reconciliation engine (OK / UNCOVERED / ORPHAN / AC_* / MOCK_ONLY)
│   ├── run-all.sh              # framework-agnostic phase runner; writes the push-gate marker
│   └── snap-feature.sh         # register an accepted visual baseline (Tier B)
├── githooks/
│   └── pre-push                # the push gate
├── regression.config.example.sh   # single config: your test dirs, phases, gated paths
└── INSTALL.md
```

## The two ideas most worth stealing

1. **The regression ledger.** One markdown file per invariant, linked to its guard test by a
   plain grep tag (`ledger:RL-<slug>`). A script reconciles records against tags and shouts
   **UNCOVERED** when an invariant lost its guard. No framework, no DB — just markdown + grep +
   bash. Works in any repo, any language. See [`docs/regression-ledger.md`](docs/regression-ledger.md).

2. **Acceptance criteria that can't dissolve.** An explicit requirement ("the total is ALWAYS
   recomputed") becomes atomic `AC-N` items, each tagged on an assert against the **real** widget.
   The reconciler **blocks** on any `AC_UNASSERTED` and flags `MOCK_ONLY` guards that test a
   replica instead of the real render — the exact class where a mock stays green while production
   is broken.

## Requirements

- **bash**, **git**, **python3** (the push gate parses the marker with python3; no `jq` needed).
- Any test stack — you supply the phase commands.
- The AI tester roles and slash commands assume **[Claude Code](https://claude.com/claude-code)**.
  The ledger, scripts, and push gate are plain bash and work with or without it.

## Where the ideas come from

Part of the discipline here grew out of **[Superpowers](https://github.com/obra/superpowers)**
(MIT), an open set of working habits for AI coding agents. Three of those habits shaped this kit:

- **Find the real cause before you fix anything.** We kept this as the hard rule for every bug fix.
- **Write a failing test first, then make it pass.** Superpowers asks you to do it; we made it
  count only when you can *prove* it — the test has to fail before the fix and pass after, and
  that proof is written down next to the invariant it protects.
- **Don't call work "done" until it's verified.** Superpowers leaves that to the agent's good
  intentions. We turned it into something a machine checks: a script that shouts when an
  invariant lost its test, and a git hook that refuses to push code that wasn't tested.

We also went further than Superpowers in one direction — instead of "just spin up a helper
agent", the kit ships a small team of specialized testing roles, each running a well-known
manual-testing technique, plus one role whose only job is to grade the others and throw out
made-up bugs.

And several pieces here have no Superpowers equivalent at all — they're this kit's own idea: the
**regression ledger** (a plain-text memory of "what must not break", tied to its test by a simple
tag), the way a requirement is broken into checkable claims so none quietly slips through, the
four levels of test runs, and the final check done by eye on real data. You don't need the
Superpowers plugin installed to use any of this.

## License

MIT — see [`LICENSE`](LICENSE).
