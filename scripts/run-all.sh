#!/usr/bin/env bash
# Framework-agnostic phase runner. Runs each configured test phase in order (cheapest first),
# tracks PASS/FAIL/SKIP, and — only on a clean run — writes the marker that the pre-push gate
# checks: test-results/e2e-pass.json = {sha, pass[], skip[]}.
#
# This is the ENGINE CONTRACT, not a full test framework: you plug YOUR real test commands in
# via regression.config.sh (or the PHASES env below). The value is the discipline around them —
# ordered phases, honest SKIP vs FAIL, and a tamper-resistant marker keyed to HEAD.
#
# Define phases as "name:command" pairs. A phase that exits 0 = PASS, non-zero = FAIL. A phase
# whose command is literally "SKIP:<reason>" is recorded as SKIP (e.g. no device available).
# Example (put in regression.config.sh at repo root):
#   PHASES=(
#     "golden:npm run test:golden"
#     "integration:npm run test:integration"
#     "ledger:bash scripts/regression/ledger-check.sh"
#   )
# The `ledger` phase should call ledger-check.sh so a lost guard fails the full run.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

[ -f regression.config.sh ] && . regression.config.sh

# Default phases if none configured — just the ledger reconciliation (always available).
# (${PHASES+x} is safe under set -u whether or not the array is defined.)
if [ -z "${PHASES+x}" ] || [ ${#PHASES[@]} -eq 0 ]; then
  PHASES=("ledger:bash $(dirname "$0")/ledger-check.sh")
fi

declare -a passed skipped failed
for entry in "${PHASES[@]}"; do
  name="${entry%%:*}"
  cmd="${entry#*:}"
  echo "──────── phase: $name ────────"
  case "$cmd" in
    SKIP:*)
      echo "SKIP ($name): ${cmd#SKIP:}"
      skipped+=("$name")
      ;;
    *)
      if eval "$cmd"; then
        echo "PASS ($name)"
        passed+=("$name")
      else
        echo "FAIL ($name)"
        failed+=("$name")
      fi
      ;;
  esac
done

echo
echo "════════ summary ════════"
printf 'PASS (%d): %s\n' "${#passed[@]}"  "${passed[*]:-—}"
printf 'SKIP (%d): %s\n' "${#skipped[@]}" "${skipped[*]:-—}"
printf 'FAIL (%d): %s\n' "${#failed[@]}"  "${failed[*]:-—}"

# Emit array elements as a JSON array body. Guarded so an empty array is safe under set -u
# on bash 3.2 (macOS default), where "${arr[@]}" on an empty array is an "unbound variable".
json_body() {
  local first=1 e
  for e in "$@"; do [ $first = 1 ] && first=0 || printf ', '; printf '"%s"' "$e"; done
}
write_marker() {
  local sha; sha="$(git rev-parse HEAD 2>/dev/null)" || sha="unknown"
  mkdir -p test-results
  {
    printf '{\n  "sha": "%s",\n  "pass": [' "$sha"
    [ ${#passed[@]} -gt 0 ] && json_body "${passed[@]}"
    printf '],\n  "skip": ['
    [ ${#skipped[@]} -gt 0 ] && json_body "${skipped[@]}"
    printf ']\n}\n'
  } > test-results/e2e-pass.json
  echo "e2e marker written: test-results/e2e-pass.json (sha=${sha:0:8})"
}

if [ ${#failed[@]} -eq 0 ]; then
  write_marker
  exit 0
else
  rm -f test-results/e2e-pass.json 2>/dev/null || true
  echo "→ FAIL present — marker NOT written (push gate stays closed)."
  exit 1
fi
