#!/usr/bin/env bash
# Regression-ledger reconciliation — reconcile tests/registry/RL-*.md against the test
# suite (see docs/regression-ledger.md).
#
# Source of truth for a guard's PRESENCE is a grep of the tag `ledger:RL-<slug>` in the
# tests, NOT markdown parsing. GREENNESS is proven by an actual run (/e2e-full) — here we
# only detect presence/loss.
#
# Buckets:
#   OK        — the record has a guard tag (auto/golden), present and not @Skip/skipped.
#   UNCOVERED — record exists, no guard / it is skipped / a `manual` guard isn't marked done
#               → "possibly lost" (the main signal).
#   ORPHAN    — a tag exists in tests, but no record → the ledger is behind the code.
# Acceptance-criteria buckets (AC-N granularity):
#   AC_OK / AC_MANUAL / AC_UNASSERTED  (AC_UNASSERTED BLOCKS the run).
#   MOCK_ONLY — a UI record whose guard is not a real widget (advisory).
#
# Exit != 0 on any UNCOVERED or AC_UNASSERTED (manual items go to a checklist, they don't
# fail the grep-level check).
#
# Config (override via env or an optional regression.config.sh at repo root):
#   LEDGER_DIR   default: tests/registry
#   TEST_DIRS    default: test tests integration_test src spec
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

# Optional project config (repo-root file, gitignored or committed — your call).
[ -f regression.config.sh ] && . regression.config.sh

LEDGER_DIR="${LEDGER_DIR:-tests/registry}"
# Directories scanned for guard tags. Guards can live anywhere — client, server, e2e.
TEST_DIRS="${TEST_DIRS:-test tests integration_test src spec e2e}"

[ -d "$LEDGER_DIR" ] || { echo "No $LEDGER_DIR — ledger not initialized"; exit 0; }

# The ledger records themselves contain `ledger:` / `AC:` tag text in their bodies. If a
# TEST_DIR overlaps LEDGER_DIR, those would self-satisfy the scan → false OK. So every scan
# below drops hits located under LEDGER_DIR.
not_in_ledger() { grep -v "^${LEDGER_DIR}/"; }

# Tags actually present in tests: ledger:RL-<slug>  (filenames kept, then ledger dir filtered)
present_tags=$(grep -rHoE -I --exclude-dir=node_modules --exclude-dir=__pycache__ \
  'ledger:RL-[a-z0-9-]+' $TEST_DIRS 2>/dev/null | not_in_ledger \
  | sed -E 's/.*(ledger:RL-[a-z0-9-]+)$/\1/; s/^ledger://' | sort -u)
# Same tags but in a skip context (guard disabled). Best-effort: files carrying a tag that
# also contain a skip marker (@Skip / skip: / it.skip / test.skip / xit / @pytest.mark.skip).
skipped_files=$(grep -rlE -I --exclude-dir=node_modules --exclude-dir=__pycache__ \
  'ledger:RL-[a-z0-9-]+' $TEST_DIRS 2>/dev/null | not_in_ledger | while read -r f; do
  grep -qE '@Skip|[^a-z]skip:[[:space:]]*(true|['\''"])|\.skip\(|(^|[^a-z])xit\(|@pytest\.mark\.skip' "$f" && echo "$f"; done)

# Acceptance-criteria asserts present in tests: AC:RL-<slug>/<N>.
present_ac=$(grep -rHoE -I --exclude-dir=node_modules --exclude-dir=__pycache__ \
  'AC:RL-[a-z0-9-]+/[0-9]+' $TEST_DIRS 2>/dev/null | not_in_ledger \
  | sed -E 's/.*(AC:RL-[a-z0-9-]+\/[0-9]+)$/\1/' | sort -u)

declare -a ok uncovered manual
for f in "$LEDGER_DIR"/RL-*.md; do
  [ -e "$f" ] || continue
  id=$(awk -F': *' '/^id:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
  gtype=$(awk '/^guard:/{g=1} g&&/^[[:space:]]+type:[[:space:]]/{sub(/.*type:[[:space:]]*/,"");print;exit}' "$f" | tr -d ' \r"'\''')
  status=$(awk -F': *' '/^status:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
  [ "$status" = "retired" ] && continue
  [ -z "$id" ] && continue

  case "$gtype" in
    manual) manual+=("$id") ;;
    none)   uncovered+=("$id (guard:none — no automated guard)") ;;
    auto|golden|unit|widget|primitive|*)
      if printf '%s\n' "$present_tags" | grep -qx "$id"; then
        if [ -n "$skipped_files" ] && grep -rlE -I --exclude-dir=node_modules --exclude-dir=__pycache__ "ledger:$id([^a-z0-9-]|$)" $TEST_DIRS 2>/dev/null | not_in_ledger | grep -qFf <(printf '%s\n' "$skipped_files"); then
          uncovered+=("$id (guard under @Skip/skip)")
        else
          ok+=("$id")
        fi
      else
        uncovered+=("$id (no guard tag in tests)")
      fi
      ;;
  esac
done

# Orphans: tags in tests with no ledger record.
ledger_ids=$(for f in "$LEDGER_DIR"/RL-*.md; do [ -e "$f" ] && awk -F': *' '/^id:[[:space:]]/{print $2;exit}' "$f" | tr -d ' \r"'\''' ; done | sort -u)
declare -a orphan
while IFS= read -r t; do
  [ -z "$t" ] && continue
  printf '%s\n' "$ledger_ids" | grep -qx "$t" || orphan+=("$t")
done <<< "$present_tags"

# ── ACCEPTANCE CRITERIA: is every declared AC-N covered? ──
# Coverage is measured at the granularity of the ASSERTION, not the file. For each record
# with a "## Acceptance criteria" section we parse "- [ ] **AC-N** …" items:
#   AC_OK         — item marked manual OR an assert tag AC:RL-<slug>/N exists in tests
#   AC_MANUAL     — item marked "manual" → mandatory manual checklist in /e2e-full
#   AC_UNASSERTED — declared, but neither assert nor manual → BLOCKS (assertion-level UNCOVERED)
declare -a ac_ok ac_manual ac_unasserted mock_only
for f in "$LEDGER_DIR"/RL-*.md; do
  [ -e "$f" ] || continue
  fid=$(awk -F': *' '/^id:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
  fstatus=$(awk -F': *' '/^status:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
  [ "$fstatus" = "retired" ] && continue
  [ -z "$fid" ] && continue
  # AC items may span multiple markdown lines, so glue each item's text up to the next AC /
  # section, otherwise "manual" on a wrapped line is missed. awk emits "N<US>full_item_text".
  while IFS= read -r item; do
    n=${item%%$'\x1f'*}
    text=${item#*$'\x1f'}
    [ -z "$n" ] && continue
    if printf '%s' "$text" | grep -qiE 'manual'; then
      ac_manual+=("$fid/AC-$n")
    elif printf '%s\n' "$present_ac" | grep -qx "AC:$fid/$n"; then
      ac_ok+=("$fid/AC-$n")
    else
      ac_unasserted+=("$fid/AC-$n (no assert AC:$fid/$n on a real widget)")
    fi
  done < <(awk '
    /^## Acceptance criteria/{inac=1; next}
    inac && /^## /{if(cur!="")print curN "\x1f" cur; inac=0; cur=""}
    inac && /- \[.\][[:space:]]*\*\*AC-[0-9]+\*\*/{
      if(cur!="")print curN "\x1f" cur;
      match($0,/AC-[0-9]+/); curN=substr($0,RSTART+3,RLENGTH-3); cur=$0; next
    }
    inac && cur!=""{cur=cur " " $0}
    END{if(cur!="")print curN "\x1f" cur}
  ' "$f")

  # MOCK_ONLY (advisory): a UI record (visual required/recommended) whose guard is not a
  # real widget (guard.render pure-function / unset). This is the class that burns you: the
  # mock replica is green while the real render is broken.
  vis=$(awk -F': *' '/^visual:[[:space:]]/{v=$2; sub(/[[:space:]]*#.*/,"",v); print v; exit}' "$f" | tr -d ' \r"'\''')
  render=$(awk '/^guard:/{g=1} g&&/^[[:space:]]+render:[[:space:]]/{sub(/.*render:[[:space:]]*/,"");sub(/[[:space:]]*#.*/,"");print;exit}' "$f" | tr -d ' \r"'\''')
  if [ "$vis" = "required" ] || [ "$vis" = "recommended" ]; then
    if [ "$render" = "pure-function" ] || [ -z "$render" ]; then
      mock_only+=("$fid (visual:$vis, guard.render:${render:-UNSET} — not a real render)")
    fi
  fi
done

# ── OPTIONAL: reverse audit of server-driven feature signals ──
# The ledger is one-directional by default ("does each record have a tag?"). It does NOT
# catch "does each feature have a record?" — a server feature shipped without a record shows
# a false "UNCOVERED 0". If your product has feature signals in code (route/handler/command
# constants), point REVERSE_AUDIT_CMD at a script that lists them; anything it prints that
# lacks a live guard tag is reported below. Advisory, never blocks.
declare -a unpinned_feat
if [ -n "${REVERSE_AUDIT_CMD:-}" ]; then
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    printf '%s\n' "$present_tags" | grep -qx "$slug" || unpinned_feat+=("$slug (feature signal without a live guard)")
  done < <($REVERSE_AUDIT_CMD 2>/dev/null | sort -u)
fi

# ── report ──
echo "════════ Regression-ledger reconciliation ════════"
printf 'OK (%d): %s\n'        "${#ok[@]}"        "${ok[*]:-—}"
printf 'MANUAL (%d): %s\n'    "${#manual[@]}"    "${manual[*]:-—}"
printf 'UNCOVERED (%d): %s\n' "${#uncovered[@]}" "${uncovered[*]:-—}"
printf 'ORPHAN (%d): %s\n'    "${#orphan[@]}"    "${orphan[*]:-—}"
printf 'AC_OK (%d): %s\n'         "${#ac_ok[@]}"         "${ac_ok[*]:-—}"
printf 'AC_MANUAL (%d): %s\n'     "${#ac_manual[@]}"     "${ac_manual[*]:-—}"
printf 'AC_UNASSERTED (%d): %s\n' "${#ac_unasserted[@]}" "${ac_unasserted[*]:-—}"
printf 'MOCK_ONLY (%d): %s\n'     "${#mock_only[@]}"     "${mock_only[*]:-—}"
[ -n "${REVERSE_AUDIT_CMD:-}" ] && printf 'UNPINNED_FEATURES (%d): %s\n' "${#unpinned_feat[@]}" "${unpinned_feat[*]:-—}"
[ ${#ac_unasserted[@]} -gt 0 ] && echo "→ AC_UNASSERTED: an acceptance criterion has no guard assert (AC:RL-…/N) — BLOCKS. Write an assert on the REAL widget, or mark the item manual."
[ ${#ac_manual[@]} -gt 0 ] && echo "→ AC_MANUAL: manual acceptance criteria — into the mandatory /e2e-full checklist (cannot be silently skipped)."
[ ${#mock_only[@]} -gt 0 ] && echo "→ MOCK_ONLY (advisory): UI record without guard.render:real-widget/device — the guard likely tests a replica/primitive, not the real render (see docs/regression-ledger.md)."
[ ${#manual[@]} -gt 0 ] && echo "→ MANUAL guards need a manual check (see the record bodies in $LEDGER_DIR)."
[ ${#orphan[@]} -gt 0 ] && echo "→ ORPHAN: add an RL record for these tags (the ledger is behind)."

# ── generated index (a snapshot of the last reconciliation, not a hand-maintained log) ──
# Bucket (OK/UNCOVERED/MANUAL) is computed by this run; dedup by slug. INDEX.md is gitignored
# (an aggregate file would reintroduce the merge conflicts the file-per-record format avoids).
bucket_of() {
  printf '%s\n' "${ok[*]:-}"     | tr ' ' '\n' | grep -qx "$1" && { echo OK; return; }
  printf '%s\n' "${manual[*]:-}" | tr ' ' '\n' | grep -qx "$1" && { echo MANUAL; return; }
  echo UNCOVERED
}
INDEX="$LEDGER_DIR/INDEX.md"
{
  echo "# Regression ledger — index (GENERATED, do not edit by hand)"
  echo
  echo "Snapshot of the last \`ledger-check.sh\` reconciliation. Source of truth for"
  echo "greenness is a run (\`/e2e-full\`), not this file. Spec — \`docs/regression-ledger.md\`."
  echo
  echo "| ID | Area | Guard | Ledger status | Invariant |"
  echo "|---|---|---|---|---|"
  esc() { printf '%s' "$1" | tr -d '\r' | sed 's/[|\\]/\\&/g'; }
  for f in "$LEDGER_DIR"/RL-*.md; do
    [ -e "$f" ] || continue
    id=$(awk -F': *' '/^id:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
    [ -z "$id" ] && { echo "⚠ $f has no id: — skipped in index" >&2; continue; }
    area=$(awk -F': *' '/^area:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
    gtype=$(awk '/^guard:/{g=1} g&&/^[[:space:]]+type:[[:space:]]/{sub(/.*type:[[:space:]]*/,"");print;exit}' "$f" | tr -d ' \r"'\''')
    status=$(awk -F': *' '/^status:[[:space:]]/{print $2; exit}' "$f" | tr -d ' \r"'\''')
    title=$(awk '/^# /{sub(/^# /,"");print;exit}' "$f")
    if [ "$status" = "retired" ]; then b="retired"; else b=$(bucket_of "$id"); fi
    echo "| \`$id\` | ${area:-—} | ${gtype:-—} | $b | $(esc "${title:-—}") |"
  done
} > "$INDEX"
echo "→ Index updated: $INDEX (gitignored, reconciliation snapshot)."

if [ ${#uncovered[@]} -eq 0 ] && [ ${#ac_unasserted[@]} -eq 0 ]; then
  echo "→ Every auto record has a live guard tag; all declared acceptance criteria are covered."
  exit 0
else
  [ ${#uncovered[@]} -gt 0 ] && echo "→ UNCOVERED: possibly lost — add/repair a guard."
  [ ${#ac_unasserted[@]} -gt 0 ] && echo "→ AC_UNASSERTED: acceptance criterion without coverage — assert on the real widget or mark manual."
  exit 1
fi
