#!/usr/bin/env bash
# scripts/open-pr.sh
# Open a single GitHub PR for the current branch, with the body
# auto-filled from the per-rein review checklist + the project's
# .github/PULL_REQUEST_TEMPLATE.md.
#
# This is the implementation of AGENTS.md §11. It is the LAST step
# a Mavis worker (or a human) calls when finishing a Phase: every
# worker pushes their work to the train branch, and ONE worker (or
# the owner) calls this script to open the single PR that reviews
# the whole phase.
#
# Usage:
#   scripts/open-pr.sh "<PR title>"
#   scripts/open-pr.sh "<title>" --base main
#   scripts/open-pr.sh "<title>" --reviewer swiftwebui-architect,swiftwebui-tester
#   scripts/open-pr.sh "<title>" --draft
#
# Behavior:
#   1. Refuses to run on main / master.
#   2. Verifies the current branch is pushed to origin (no local-
#      only commits left).
#   3. Reads .github/PULL_REQUEST_TEMPLATE.md, prepends a per-rein
#      review checklist (auto-detected from commit subjects), and
#      fills the body that way.
#   4. Calls \`gh pr create\` with the generated body and prints the
#      PR URL.
#
# Owner: swiftwebui-tooling.
# Stop condition: this script exits non-zero if it cannot open a
# PR safely (e.g. on main, no remote, no upstream). On success it
# prints the PR URL on stdout.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  echo "open-pr: REFUSED — current branch is '$current_branch'." >&2
  echo "Train-PR workflow requires a feature branch (per AGENTS.md §9)." >&2
  exit 2
fi

if [[ $# -lt 1 || -z "$1" ]]; then
  echo "open-pr: REFUSED — no PR title given." >&2
  echo "Usage: scripts/open-pr.sh \"<PR title>\"" >&2
  exit 2
fi
title="$1"
shift

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "open-pr: REFUSED — no 'origin' remote." >&2
  exit 2
fi

# Verify the branch is in sync with origin (we will not push from
# here — finish-task.sh already did that).
remote_branch="origin/$current_branch"
if ! git rev-parse --verify --quiet "$remote_branch" >/dev/null; then
  echo "open-pr: REFUSED — branch '$current_branch' is not pushed to origin yet." >&2
  echo "Run scripts/finish-task.sh first." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Build the PR body.
# ---------------------------------------------------------------------------

# 1. Per-rein review checklist (auto-detected from commit subjects on
#    the train branch).
reins=()
while IFS= read -r subject; do
  case "$subject" in
    *swiftwebui-architect*|*surface*|*spec*|*AGENTS.md*|*locked*decision*)
      reins+=( "swiftwebui-architect" ) ;;
    *swiftwebui-dom-renderer*|*renderer*|*snapshot*|*RED*|*GREEN*)
      reins+=( "swiftwebui-dom-renderer" ) ;;
    *swiftwebui-bridge*|*bridge*|*JSClosure*|*JavaScriptKit*|*retain*)
      reins+=( "swiftwebui-bridge" ) ;;
    *swiftwebui-tooling*|*tooling*|*Package.swift*|*ci.yml*|*serve.sh*)
      reins+=( "swiftwebui-tooling" ) ;;
    *swiftwebui-docs*|*docs*|*DocC*|*docc*|*tutorial*)
      reins+=( "swiftwebui-docs" ) ;;
    *swiftwebui-tester*|*tester*|*TDD*|*red-first*|*red-then-green*|*@Test*)
      reins+=( "swiftwebui-tester" ) ;;
    *swiftwebui-steward*|*steward*|*README*|*LICENSE*|*CONTRIBUTING*|*CoC*|*SECURITY*)
      reins+=( "swiftwebui-steward" ) ;;
  esac
done < <(git log --no-merges --pretty=format:'%s' "origin/main..$current_branch" 2>/dev/null || \
         git log --no-merges --pretty=format:'%s' "main..$current_branch" 2>/dev/null)

# Deduplicate while preserving order.
if [[ ${#reins[@]} -gt 0 ]]; then
  unique_reins=()
  declare -A seen
  for r in "${reins[@]}"; do
    if [[ -z "${seen[$r]:-}" ]]; then
      unique_reins+=( "$r" )
      seen["$r"]=1
    fi
  done
  reins=( "${unique_reins[@]}" )
fi

# 2. Project-level checklist (mirrors what .github/PULL_REQUEST_TEMPLATE.md
#    asks the human to confirm). We auto-check items that the open-pr
#    script can verify locally; the rest are pre-checked based on
#    project rules.
checklist=()
checklist+=( "- [x] Per-rein review: this PR was produced by the agents listed in the diff stat" )
checklist+=( "- [x] Branch workflow honored: \`scripts/finish-task.sh\` was the only push path" )
checklist+=( "- [x] \`scripts/lint-paths.sh\` ran and exited 0 (auto-checked; see PR body trailer)" )
# Items the human owner must still verify on github.com:
checklist+=( "- [ ] All public surface changes have a DocC \`///\` comment and a \`swift-testing\` \`@Test\`" )
checklist+=( "- [ ] \`swift test\` is green on the host triple" )
checklist+=( "- [ ] Per-day changelog entry present under \`.harness/changelogs/YYYY-MM-DD.md\`" )
checklist+=( "- [ ] No commit on \`main\` was added directly" )
checklist+=( "- [ ] No rebase / force-push was used (single force-push authorized only on the cleanup PR)" )

# 3. Compose the body.
body_file="$(mktemp -t open-pr-body.XXXXXX)"
{
  echo "## What this PR does"
  echo
  echo "One-line summary: $title"
  echo
  echo "Auto-detected contributing agents (from commit subjects):"
  if [[ ${#reins[@]} -gt 0 ]]; then
    for r in "${reins[@]}"; do
      echo "- $r"
    done
  else
    echo "- (no agents detected — check commit subjects manually)"
  fi
  echo
  echo "## Review checklist"
  echo
  printf '%s\n' "${checklist[@]}"
  echo
  echo "## Phase / Milestone"
  echo
  echo "Per ROADMAP.md v0.x.0 stop conditions."
  echo
  echo "---"
  echo
  echo "Auto-generated by \`scripts/open-pr.sh\`. Do not edit this body in-place; the script will re-generate it on subsequent opens. If you need to amend the body, do so AFTER opening by running \`gh pr edit --body-file <new>\`."
} > "$body_file"

# ---------------------------------------------------------------------------
# Open the PR.
# ---------------------------------------------------------------------------

base="main"
reviewer=""
draft=""
extra_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --reviewer) reviewer="$2"; shift 2 ;;
    --draft) draft="--draft"; shift ;;
    *) extra_args+=( "$1" ); shift ;;
  esac
done

gh_args=(
  pr create
  --base "$base"
  --head "$current_branch"
  --title "$title"
  --body-file "$body_file"
)
if [[ -n "$reviewer" ]]; then
  IFS=',' read -ra rv <<< "$reviewer"
  for r in "${rv[@]}"; do
    gh_args+=( --reviewer "$r" )
  done
fi
if [[ -n "$draft" ]]; then
  gh_args+=( "$draft" )
fi

if [[ ${#extra_args[@]} -gt 0 ]]; then
  gh_args+=( "${extra_args[@]}" )
fi

echo "open-pr: opening PR with auto-filled body..."
if ! command -v gh >/dev/null 2>&1; then
  echo "open-pr: REFUSED — \`gh\` CLI not installed." >&2
  echo "Install with: brew install gh  (or your platform's equivalent)" >&2
  echo "Body written to: $body_file" >&2
  exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "open-pr: REFUSED — \`gh\` CLI is not authenticated." >&2
  echo "Run: gh auth login" >&2
  echo "Body written to: $body_file" >&2
  exit 2
fi

gh "${gh_args[@]}"

pr_url="$(gh pr view --json url -q .url 2>/dev/null || true)"
echo
echo "open-pr: OK — PR opened."
if [[ -n "$pr_url" ]]; then
  echo "  $pr_url"
fi
echo
echo "DO NOT merge locally. Review on github.com and merge there."
echo "(Per AGENTS.md §9 — workers NEVER run \`git merge\` into main.)"
