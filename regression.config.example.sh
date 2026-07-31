# Regression kit config — copy to `regression.config.sh` at your repo root and adapt.
# Sourced by ledger-check.sh, run-all.sh, and the pre-push hook. Plain bash.

# ── Ledger reconciliation (ledger-check.sh) ──────────────────────────────────
# Where RL-*.md records live.
LEDGER_DIR="tests/registry"
# Space-separated dirs scanned for `ledger:RL-<slug>` guard tags. Point these at wherever
# your tests live (client + server + e2e). node_modules / __pycache__ are excluded already.
TEST_DIRS="test tests integration_test src spec e2e"

# Optional reverse audit: a command that PRINTS one feature-signal slug per line (RL-<slug>).
# Any printed slug without a live guard tag is reported as UNPINNED (advisory). Leave unset to
# disable. Example: enumerate route constants from code and map them to expected RL slugs.
# REVERSE_AUDIT_CMD="bash scripts/regression/feature-signals.sh"

# ── Phase runner (run-all.sh) ────────────────────────────────────────────────
# Ordered phases, cheapest first. "name:command". Exit 0 = PASS, non-zero = FAIL.
# Use "name:SKIP:<reason>" to record an honest SKIP (e.g. no device attached).
# The `ledger` phase MUST call ledger-check.sh so a lost guard fails the whole run.
PHASES=(
  "golden:echo 'plug in your golden/pixel-snapshot command here'"      # e.g. npm run test:golden
  "integration:echo 'plug in your integration-test command here'"     # e.g. npm run test:e2e
  "ledger:bash scripts/regression/ledger-check.sh"
  # "ios:SKIP:no simulator on this machine"
)

# ── Push gate (githooks/pre-push) ────────────────────────────────────────────
MAINLINE_BRANCH="main"
# Phases that MUST be in the marker's pass[] before a gated push is allowed.
REQUIRED_PHASES="golden integration ledger"
# Branches whose diff (vs origin/MAINLINE) touches this path prefix are gated too.
GATED_PATHS="src/"
