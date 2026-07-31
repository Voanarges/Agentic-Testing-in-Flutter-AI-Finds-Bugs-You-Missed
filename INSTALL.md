# Install & adopt

Adopting the kit is copying a handful of files into your repo, wiring one config, and enabling
one git hook. Nothing here is framework-specific until *you* fill in the test commands.

## 1. Copy the pieces into your repo

From this kit into your project:

```bash
# from your project root, with the kit checked out alongside (adjust KIT=…)
KIT=../regression-testing-kit

mkdir -p tests/registry scripts/regression githooks .claude/agents .claude/commands

cp -r "$KIT"/registry/*                tests/registry/
cp     "$KIT"/scripts/*.sh             scripts/regression/
cp     "$KIT"/githooks/pre-push        githooks/pre-push
cp -r "$KIT"/claude/agents/*           .claude/agents/
cp -r "$KIT"/claude/commands/*         .claude/commands/
cp     "$KIT"/regression.config.example.sh   regression.config.sh

chmod +x scripts/regression/*.sh githooks/pre-push
```

> Directory names are a convention, not a hard requirement. If you use different paths, set them
> in `regression.config.sh` (the scripts and the hook read it) and update the paths referenced in
> the slash commands.

## 2. Configure `regression.config.sh`

Open it and set four things (details inline in the file):

- **`TEST_DIRS`** — where your tests live, so `ledger-check.sh` can grep for `ledger:RL-<slug>`
  tags (client + server + e2e — list them all).
- **`PHASES`** — your ordered test commands as `"name:command"` (cheapest first). Keep the
  `ledger` phase pointing at `ledger-check.sh`. Use `"name:SKIP:<reason>"` for an honest skip.
- **`REQUIRED_PHASES`** — which phases must be green before a gated push is allowed.
- **`MAINLINE_BRANCH`** / **`GATED_PATHS`** — your mainline branch, and the source path prefix
  whose feature branches should also be gated.

## 3. Enable the push gate (once per clone)

```bash
git config core.hooksPath githooks
```

Now a push to your mainline (or a feature branch touching `GATED_PATHS`) is blocked unless a
fresh marker `test-results/e2e-pass.json` exists for the current HEAD with the required phases
passed. The marker is written **only** by a clean `scripts/regression/run-all.sh`. Emergency
bypass when infrastructure is down (not a test failure): `SKIP_E2E_GATE=1 git push …`.

## 4. Gitignore the generated artifacts

Add to your project's `.gitignore`:

```
test-results/
tests/registry/INDEX.md
```

(`INDEX.md` is a generated reconciliation snapshot; `test-results/` holds the gate marker.)

## 5. Try it

```bash
# reconcile the ledger (ships with one example record → expect it in UNCOVERED until you
# add a guard test tagged  ledger:RL-example-checkout-total )
bash scripts/regression/ledger-check.sh

# run your phases and write the marker (once PHASES point at real commands)
bash scripts/regression/run-all.sh
```

Delete `tests/registry/RL-example-checkout-total.md` once you've written your first real record.

## 6. Using the Claude Code assets

The 10 tester roles and 5 commands live under `.claude/`. In Claude Code:

- **Slash commands** — `/e2e-local`, `/e2e-full`, `/pin-feature`, `/add-golden`, `/fix-test`.
- **Subagent roles** — invoked by name via the agent tool, or orchestrated by
  `qa-lead-orchestrator`. Start with `exploratory-qa-tester` (finds unrequested defects) and
  `adversarial-verifier` (tries to refute a claimed fix).

Read [`docs/methodology.md`](docs/methodology.md) for how the roles feed the ledger, and
[`docs/heuristics.md`](docs/heuristics.md) for the QA engine inside each role — those work by
hand too, no agent required.

## Adapting to your stack — checklist

- [ ] Golden tier: pick your pixel-snapshot tool and **pin fonts + DPR** for determinism.
- [ ] Scripted tier: decide how a test drives a *second* user — **programmatically via your API**,
      not a second GUI.
- [ ] If your product has a login / anti-abuse guard, satisfy it in the harness (device name /
      header) and note it in your project docs.
- [ ] Native tier (push/permissions): wire `simctl` / `adb` / desktop UI automation as needed, or
      mark those `manual` in the ledger.
- [ ] Reverse audit (optional): if you have server-driven feature signals, set `REVERSE_AUDIT_CMD`.
