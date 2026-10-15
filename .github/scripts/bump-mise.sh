#!/usr/bin/env bash
# bump-mise.sh — keep the Dockerfile's MISE_VERSION pin current via a single,
# self-updating pull request.
#
# It compares the pinned `ARG MISE_VERSION=` against the latest mise GitHub
# release. When they differ it edits the Dockerfile, then force-updates one
# fixed branch (BUMP_BRANCH) and ensures exactly one open PR exists for it:
# a run that supersedes an unmerged bump simply rewrites that same branch/PR
# with the newer version, so a pile of stale PRs never accumulates.
#
# Idempotent: when already current (or when the fixed branch already carries
# the exact same bump) it makes no changes and opens no PR.
#
# Requirements: bash, git, curl, gh (authenticated). Intended for CI, but it is
# a plain script you can dry-run locally (CHECK_ONLY=1) to see the comparison.
#
# Environment:
#   BUMP_BRANCH   fixed branch name for the PR        (default: automation/bump-mise)
#   DEFAULT_BASE  base branch to target               (default: main)
#   CHECK_ONLY    "1" = print status and exit, no git (default: unset)
#   GH_TOKEN      consumed by gh / git over https (CI provides it)

set -euo pipefail

BUMP_BRANCH="${BUMP_BRANCH:-automation/bump-mise}"
DEFAULT_BASE="${DEFAULT_BASE:-main}"
CHECK_ONLY="${CHECK_ONLY:-}"

repo_root="$(git rev-parse --show-toplevel)"
dockerfile="${repo_root}/Dockerfile"

log() { printf '%s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[ -f "$dockerfile" ] || die "Dockerfile not found at $dockerfile"

# Current pin: the value of `ARG MISE_VERSION=` in the Dockerfile.
current="$(sed -n 's/^ARG MISE_VERSION=\(.*\)$/\1/p' "$dockerfile" | head -n1)"
[ -n "$current" ] || die "could not read ARG MISE_VERSION from Dockerfile"

# Latest mise release tag from the GitHub API (e.g. "v2026.10.9").
api="https://api.github.com/repos/jdx/mise/releases/latest"
auth=()
[ -n "${GH_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GH_TOKEN}")
latest="$(
  curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$api" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
)"
[ -n "$latest" ] || die "could not determine latest mise release from GitHub API"

log "current MISE_VERSION: ${current}"
log "latest mise release:  ${latest}"

if [ "$current" = "$latest" ]; then
  log "already current — nothing to do"
  exit 0
fi

log "update available: ${current} -> ${latest}"

if [ "$CHECK_ONLY" = "1" ]; then
  log "CHECK_ONLY=1 — not touching git"
  exit 0
fi

command -v gh >/dev/null 2>&1 || die "gh CLI is required"

title="chore(deps): bump mise ${current} -> ${latest}"
body="$(
  cat <<EOF
Automated bump of the pinned \`MISE_VERSION\` in the Dockerfile.

| | version |
|---|---|
| from | \`${current}\` |
| to | \`${latest}\` |

The checksum is fetched and verified from the release \`SHASUMS256.txt\` at
build time, so no checksum constant changes here.

Review the [mise release notes](https://github.com/jdx/mise/releases/tag/${latest})
before merging. This PR is maintained by \`.github/workflows/mise-version-check.yml\`:
if a newer release appears before it is merged, the same branch and PR are
updated in place rather than opening another one.

Refs #18.
EOF
)"

# Rebuild the fixed branch from the base each run so it always carries exactly
# one commit: the current -> latest bump on top of the latest base.
git fetch origin "$DEFAULT_BASE" --quiet
git switch --force-create "$BUMP_BRANCH" "origin/${DEFAULT_BASE}"

# Apply the bump.
sed -i "s/^ARG MISE_VERSION=.*/ARG MISE_VERSION=${latest}/" "$dockerfile"

if git diff --quiet -- "$dockerfile"; then
  die "expected a Dockerfile change but found none (pattern mismatch?)"
fi

git add "$dockerfile"
git -c user.name="github-actions[bot]" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit --quiet -m "$title"

# Force-push the fixed branch. If an open PR already tracks it, this updates
# that PR in place; otherwise we open one below.
git push --force-with-lease origin "$BUMP_BRANCH"

# One open PR per branch: update the existing one, or create it.
if gh pr view "$BUMP_BRANCH" --json state --jq '.state' 2>/dev/null | grep -qx OPEN; then
  log "updating existing open PR for ${BUMP_BRANCH}"
  gh pr edit "$BUMP_BRANCH" --title "$title" --body "$body"
else
  log "opening PR for ${BUMP_BRANCH}"
  gh pr create \
    --base "$DEFAULT_BASE" \
    --head "$BUMP_BRANCH" \
    --title "$title" \
    --body "$body"
fi

log "done"
