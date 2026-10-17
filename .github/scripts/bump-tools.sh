#!/usr/bin/env bash
# bump-tools.sh — keep pinned tool versions current via one self-updating pull
# request per tool.
#
# Each registered tool reports its current pin and the latest upstream version;
# when they differ the script edits the pin, then force-updates one fixed
# branch per tool (automation/bump-<tool>) and keeps exactly one open PR for it.
# A later run that supersedes an unmerged bump rewrites the same branch/PR, so
# stale bump PRs never pile up.
#
# It bumps ONLY version/checksum pins. It never edits a trust anchor (PGP
# fingerprints, apt signing-key fingerprints, embedded key blocks): key
# rotation is a human-reviewed change. The registry functions below touch
# nothing but version lines.
#
# Usage: bump-tools.sh [TOOL]   (TOOL defaults to "all"; or a single tool name)
#
# Environment:
#   DEFAULT_BASE  base branch to target               (default: main)
#   CHECK_ONLY    "1" = print comparisons, no git/PR   (default: unset)
#   GH_TOKEN      consumed by gh / git over https (CI provides it)

set -euo pipefail

DEFAULT_BASE="${DEFAULT_BASE:-main}"
CHECK_ONLY="${CHECK_ONLY:-}"

repo_root="$(git rev-parse --show-toplevel)"
dockerfile="${repo_root}/Dockerfile"

log() { printf '%s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

gh_api() {
  auth=()
  [ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GH_TOKEN}")
  curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" "$1"
}

latest_github_release() {
  gh_api "https://api.github.com/repos/$1/releases/latest" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

# --- registry -------------------------------------------------------------
# Each tool implements:
#   <tool>_current   -> prints the currently pinned version
#   <tool>_latest    -> prints the latest upstream version
#   <tool>_apply     -> edits the pin in place (version/checksum only)
#   <tool>_refs      -> prints an issue/notes reference line for the PR body

TOOLS="mise"

mise_current() {
  sed -n 's/^ARG MISE_VERSION=\(.*\)$/\1/p' "$dockerfile" | head -n1
}
mise_latest() {
  latest_github_release "jdx/mise"
}
mise_apply() {
  sed -i "s/^ARG MISE_VERSION=.*/ARG MISE_VERSION=$1/" "$dockerfile"
}
mise_refs() {
  printf 'Review the [mise release notes](https://github.com/jdx/mise/releases/tag/%s) before merging.\n\nRefs #18.' "$1"
}

# --------------------------------------------------------------------------

bump_one() {
  tool="$1"
  type "${tool}_current" >/dev/null 2>&1 || die "unknown tool '$tool'"

  current="$("${tool}_current")"
  [ -n "$current" ] || die "could not read current pin for '$tool'"
  latest="$("${tool}_latest")"
  [ -n "$latest" ] || die "could not determine latest version for '$tool'"

  log "[$tool] current: ${current}"
  log "[$tool] latest:  ${latest}"

  if [ "$current" = "$latest" ]; then
    log "[$tool] already current — nothing to do"
    return 0
  fi
  log "[$tool] update available: ${current} -> ${latest}"

  if [ "$CHECK_ONLY" = "1" ]; then
    log "[$tool] CHECK_ONLY=1 — not touching git"
    return 0
  fi

  command -v gh >/dev/null 2>&1 || die "gh CLI is required"

  branch="automation/bump-${tool}"
  title="chore(deps): bump ${tool} ${current} -> ${latest}"
  body="$(
    cat <<EOF
Automated bump of the pinned \`${tool}\` version.

| | version |
|---|---|
| from | \`${current}\` |
| to | \`${latest}\` |

Only the version/checksum pin changes; no trust anchor is touched.

$("${tool}_refs" "$latest")

This PR is maintained by \`.github/workflows/tool-version-check.yml\`: if a
newer version appears before it is merged, the same branch and PR are updated
in place rather than opening another one.
EOF
  )"

  git fetch origin "$DEFAULT_BASE" --quiet
  git switch --force-create "$branch" "origin/${DEFAULT_BASE}"

  "${tool}_apply" "$latest"

  if git diff --quiet; then
    die "[$tool] expected a change but found none (pattern mismatch?)"
  fi

  git add -A
  git -c user.name="github-actions[bot]" \
    -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
    commit --quiet -m "$title"
  git push --force-with-lease origin "$branch"

  if gh pr view "$branch" --json state --jq '.state' 2>/dev/null | grep -qx OPEN; then
    log "[$tool] updating existing open PR"
    gh pr edit "$branch" --title "$title" --body "$body"
  else
    log "[$tool] opening PR"
    gh pr create --base "$DEFAULT_BASE" --head "$branch" --title "$title" --body "$body"
  fi
}

[ -f "$dockerfile" ] || die "Dockerfile not found at $dockerfile"

selection="${1:-all}"
if [ "$selection" = "all" ]; then
  for t in $TOOLS; do bump_one "$t"; done
else
  bump_one "$selection"
fi

log "done"
