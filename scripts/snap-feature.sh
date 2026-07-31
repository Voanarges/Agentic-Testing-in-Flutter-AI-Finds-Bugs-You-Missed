#!/usr/bin/env bash
# Register a reference screenshot of real UI (Tier B visual baseline) against a ledger record.
# Called at MR time, once a UI feature has been verified by eye: "success is visible → pin the
# baseline". The shot goes to tests/screenshots/<RL-slug>/<name>.png and is recorded in the
# manifest tests/screenshots/<RL-slug>/baselines.md so the visual-check step can match the
# declared baseline to a file and to the ledger record.
#
# Tier A (deterministic pixel-diff) is golden testing via your framework's golden tooling — NOT
# this script. This is Tier B only: non-deterministic real UI, compared by eye via the manifest.
#
# Usage:
#   snap-feature.sh <RL-slug> <name> <source.png> "<description>" [platform] [build]
# Example:
#   snap-feature.sh checkout-total totals-with-discount /tmp/shot.png \
#     "order total with a percentage discount applied" web 1.4.2
set -euo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

slug="${1:-}"; name="${2:-}"; src="${3:-}"; desc="${4:-}"
platform="${5:-unknown}"; build="${6:-}"

if [ -z "$slug" ] || [ -z "$name" ] || [ -z "$src" ] || [ -z "$desc" ]; then
  echo "Usage: snap-feature.sh <RL-slug> <name> <source.png> \"<description>\" [platform] [build]" >&2
  exit 2
fi

rl="tests/registry/RL-${slug}.md"
if [ ! -f "$rl" ]; then
  echo "✗ No ledger record $rl — create the RL record first (/pin-feature)." >&2
  exit 1
fi
if [ ! -f "$src" ]; then
  echo "✗ Source screenshot not found: $src" >&2
  exit 1
fi

name="${name%.png}"
case "$name" in *[!a-zA-Z0-9_-]*) echo "✗ name must be [a-zA-Z0-9_-]" >&2; exit 2;; esac

dir="tests/screenshots/${slug}"
mkdir -p "$dir"
dest="${dir}/${name}.png"
cp "$src" "$dest"

manifest="${dir}/baselines.md"
if [ ! -f "$manifest" ]; then
  {
    echo "# Visual baselines (Tier B, real UI) — RL-${slug}"
    echo
    echo "Reference screenshots of successfully implemented UI. Compared BY EYE during"
    echo "\`/e2e-full\` (real UI is non-deterministic — deterministic pixel-diff is golden,"
    echo "see \`tests/registry/RL-${slug}.md\`). The machine-readable table below is written"
    echo "by \`snap-feature.sh\` — do not edit by hand."
    echo
    echo "| file | platform | build | captured | desc |"
    echo "|------|----------|-------|----------|------|"
  } > "$manifest"
fi

captured=$(date +%Y-%m-%d)
row="| ${name}.png | ${platform} | ${build:-—} | ${captured} | ${desc} |"
if grep -qE "^\| ${name}\.png \|" "$manifest"; then
  tmp=$(mktemp)
  sed "s#^| ${name}\.png |.*#${row}#" "$manifest" > "$tmp" && mv "$tmp" "$manifest"
  echo "↻ Updated baseline: $dest"
else
  printf '%s\n' "$row" >> "$manifest"
  echo "✓ Added baseline: $dest"
fi

echo "  manifest: $manifest"
echo "  ledger record: $rl"
echo "  → commit tests/screenshots/${slug}/ together with the fix (this is a baseline, not a /tmp artifact)."
