#!/usr/bin/env bash
set -euo pipefail

BASELINE="${BASELINE:-.github/sizes.json}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
GROWTH_PCT="${GROWTH_PCT:-20}"
OVERRIDE="${SIZE_OVERRIDE:-}"

CLOUD_TOOLS="aws gcloud az"

commit="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

build() {
  target="$1"
  tag="$2"
  cloud="${3:-}"
  docker build \
    --build-arg "IMAGE_VERSION=size" \
    --build-arg "SOURCE_COMMIT=${commit}" \
    --build-arg "BUILD_DATE=${date}" \
    --build-arg "CLOUD_CLIS=${cloud}" \
    --build-arg "CODING_AGENTS=" \
    --target "$target" -t "$tag" . >/dev/null 2>&1
}

size_bytes() {
  docker image inspect "$1" --format '{{.Size}}'
}

human() {
  awk -v b="$1" 'BEGIN{ split("B KB MB GB TB",u," "); i=1; while(b>=1024 && i<5){b/=1024;i++} printf "%.0f%s", b, u[i] }'
}

baseline_get() {
  key="$1"
  [ -f "$BASELINE" ] || {
    echo ""
    return
  }
  python3 - "$BASELINE" "$key" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    print(data.get(sys.argv[2], ""))
except Exception:
    print("")
PY
}

echo "Building base..." >&2
build base fenix-size:base ""
base_bytes="$(size_bytes fenix-size:base)"

declare -A tool_bytes
for t in $CLOUD_TOOLS; do
  echo "Building cloud-ops with $t..." >&2
  build cloud-ops "fenix-size:$t" "$t"
  full="$(size_bytes "fenix-size:$t")"
  delta=$((full - base_bytes))
  [ "$delta" -lt 0 ] && delta=0
  tool_bytes["$t"]="$delta"
  docker image rm "fenix-size:$t" >/dev/null 2>&1 || true
done

echo "Building all-in targets..." >&2
build cloud-ops fenix-size:cloud-ops-all "$CLOUD_TOOLS"
cloudall_bytes="$(size_bytes fenix-size:cloud-ops-all)"
build mise fenix-size:mise ""
mise_bytes="$(size_bytes fenix-size:mise)"

{
  echo "## Image size report"
  echo
  echo "Commit \`${commit}\`."
  echo
  echo "### Per-tool layer size (cloud-ops)"
  echo
  echo "| Tool | Size added | Baseline | Growth |"
  echo "|---|---|---|---|"
} >>"$SUMMARY"

fail=0
for t in $CLOUD_TOOLS; do
  cur="${tool_bytes[$t]}"
  base_val="$(baseline_get "tool.$t")"
  if [ -n "$base_val" ] && [ "$base_val" -gt 0 ] 2>/dev/null; then
    pct="$(awk -v c="$cur" -v b="$base_val" 'BEGIN{printf "%.0f", (c-b)*100.0/b}')"
    growth="${pct}%"
    if [ "$pct" -gt "$GROWTH_PCT" ] 2>/dev/null; then
      if [ -n "$OVERRIDE" ]; then
        growth="${pct}% (override)"
      else
        growth="${pct}% ⚠ FAIL"
        fail=1
      fi
    fi
  else
    growth="(no baseline)"
  fi
  echo "| $t | $(human "$cur") | $([ -n "$base_val" ] && human "$base_val" || echo -) | $growth |" >>"$SUMMARY"
done

{
  echo
  echo "### Per-target total size"
  echo
  echo "| Target | Size |"
  echo "|---|---|"
  echo "| base | $(human "$base_bytes") |"
  echo "| cloud-ops (aws gcloud az) | $(human "$cloudall_bytes") |"
  echo "| mise | $(human "$mise_bytes") |"
} >>"$SUMMARY"

docker image rm fenix-size:cloud-ops-all fenix-size:mise fenix-size:base >/dev/null 2>&1 || true

if [ "$fail" -ne 0 ]; then
  echo "size-report: a tool grew more than ${GROWTH_PCT}% vs baseline without an override label" >&2
  exit 1
fi
echo "size-report: OK" >&2
