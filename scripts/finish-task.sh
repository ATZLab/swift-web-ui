#!/usr/bin/env bash
# scripts/finish-task.sh
# Finish a Mavis worker's task: commit on the current feature branch,
# push to origin, and report the PR URL. NEVER touches `main`.
#
# This is the implementation of AGENTS.md §9. A worker calls this
# at the end of every task instead of running git merge / git
# checkout main by hand.
#
# Usage:
#   scripts/finish-task.sh "<commit message>"
#
# Behavior:
#   1. Refuses to run if the current branch is `main` (or `master`).
#   2. Runs the pre-push verification gates (lint-paths,
#      verify-host, verify-wasm32, verify-docc). Any gate failure
#      refuses the push.
#   3. If there are unstaged / staged changes, `git add -A` and
#      commit with the provided message. (A clean tree = no new
#      commit.)
#   4. `git push -u origin <current-branch>`.
#   5. Print the PR URL:
#        https://github.com/<owner>/<repo>/pull/new/<branch>
#      so the owner can open the PR on github.com.
#
# Owner: swiftwebui-tooling.
# Stop condition: this script exits non-zero if it cannot finish
# the task safely (e.g. on main, no remote, mid-merge, mid-rebase).
# On success it prints the PR URL on stdout.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  echo "finish-task: REFUSED — current branch is '$current_branch'." >&2
  echo "Workers must do their work on a feature/fix/chore/... branch." >&2
  echo "Run: git checkout -b feature/<scope>-<short-desc>" >&2
  exit 2
fi

if [[ $# -lt 1 || -z "$1" ]]; then
  echo "finish-task: REFUSED — no commit message given." >&2
  echo "Usage: scripts/finish-task.sh \"<commit message>\"" >&2
  exit 2
fi
msg="$1"

if [[ -d "$repo_root/.git/MERGE_HEAD" ]]; then
  echo "finish-task: REFUSED — a merge is in progress." >&2
  exit 2
fi
if [[ -d "$repo_root/.git/REBASE_HEAD" || -d "$repo_root/.git/rebase-merge" || -d "$repo_root/.git/rebase-apply" ]]; then
  echo "finish-task: REFUSED — a rebase is in progress." >&2
  exit 2
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "finish-task: REFUSED — no 'origin' remote configured." >&2
  echo "Add one with: git remote add origin <url>" >&2
  exit 2
fi

# --- Pre-push verification gates (AGENTS.md §10, v0.1.0 close-out) -------
#
# These four gates run on every push. Any failure refuses the push;
# the worker must fix the underlying problem and re-invoke
# finish-task.sh. The gates match the 0.1.0 close-out stop
# conditions:
#   1. lint-paths    — AGENTS.md §10 path-hygiene guard.
#   2. verify-host   — swift build + swift test on the host triple.
#   3. verify-wasm32 — best-effort wasm32 build (exit 0 on missing
#                      SDK; 0.1.0 stop condition is best-effort).
#   4. verify-docc   — `swift package generate-documentation` with
#                      zero warnings (.harness/docs/docc.md contract).
#
# Each gate is run unconditionally. The wasm32 gate is allowed to
# pass with a missing SDK per AGENTS.md; the host and docc gates
# must be green. The verify scripts themselves print which step
# failed.

run_gate() {
  local label="$1"; shift
  echo
  echo "finish-task: gate — $label"
  if "$@"; then
    echo "finish-task: gate OK — $label"
  else
    local gate_exit=$?
    echo "finish-task: REFUSED — gate '$label' failed with exit $gate_exit." >&2
    echo "Fix the issue above and re-run: scripts/finish-task.sh \"$msg\"" >&2
    exit 1
  fi
}

run_gate "lint-paths"   bash scripts/lint-paths.sh
run_gate "verify-host"  bash scripts/verify-host.sh
run_gate "verify-wasm32" bash scripts/verify-wasm32.sh
run_gate "verify-docc"  bash scripts/verify-docc.sh

if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  echo "finish-task: staging and committing working tree changes on '$current_branch'."
  git add -A
  full_msg="$msg"$'\n\n'"Worker-finish: scripts/finish-task.sh on $current_branch"
  git commit -m "$full_msg"
else
  echo "finish-task: working tree clean — no new commit needed on '$current_branch'."
fi

echo "finish-task: pushing '$current_branch' to origin."
if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  git push origin "$current_branch"
else
  git push -u origin "$current_branch"
fi

origin_url="$(git remote get-url origin)"
case "$origin_url" in
  git@github.com:*)
    normalized="https://github.com/${origin_url#git@github.com:}"
    normalized="${normalized%.git}"
    ;;
  https://github.com/*)
    normalized="${origin_url%.git}"
    ;;
  *)
    normalized="$origin_url"
    ;;
esac

pr_url="${normalized}/pull/new/${current_branch}"
echo
echo "finish-task: OK — branch '$current_branch' is pushed."
echo "Open a PR at:"
echo "  $pr_url"
echo
echo "DO NOT merge locally. Review on github.com and merge there."
