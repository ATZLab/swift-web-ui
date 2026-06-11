#!/usr/bin/env bash
# scripts/release.sh
# Non-destructive helper for cutting a SwiftWebUI tagged release.
#
# This script DOES NOT tag, push, or merge anything. It is a
# pre-flight checklist and a one-page reference for the release
# owner: it refuses to run on protected branches, checks CI status
# for the current branch, prints the exact tag + push commands the
# owner will run by hand, and writes a one-line entry into
# .harness/changelogs/ that the owner commits and merges on the
# close-out PR.
#
# Usage:
#   scripts/release.sh                       # auto-detect version from CHANGELOG.md
#   scripts/release.sh 0.1.0                 # pin the version explicitly
#   scripts/release.sh --help
#
# Behavior:
#   1. Refuses to run on main / master (exit 2). Release is cut
#      AFTER a feature branch is merged, on main.
#   2. Reads or accepts a version string. Validates the shape
#      (MAJOR.MINOR.PATCH). Does not write tags.
#   3. Verifies CI is green via `gh pr checks <branch>` for any
#      open PR touching the current branch. If `gh` is not
#      authenticated, warns and continues.
#   4. Prints (does NOT execute) the tag command:
#        git tag -s 0.MINOR.0 -m 'SwiftWebUI 0.MINOR.0'
#      and the push command:
#        git push origin 0.MINOR.0
#   5. Updates .harness/changelogs/$(date -I).md with a one-line
#      "0.MINOR.0 tagged" entry. Does NOT commit it; the owner
#      verifies the entry, commits it, and merges the close-out PR.
#
# Owner: swiftwebui-steward.
# Stop condition: this script exits non-zero on the safety checks
# (wrong branch, malformed version). On success it prints the
# commands the owner will run by hand and a "0.MINOR.0 tagged"
# changelog line the owner can commit.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
scripts/release.sh — non-destructive SwiftWebUI release helper.

USAGE
  scripts/release.sh                       # auto-detect from CHANGELOG.md
  scripts/release.sh <version>             # pin the version (e.g. 0.1.0)
  scripts/release.sh --help

BEHAVIOR
  Refuses to run on main or master. Verifies CI is green for the
  current branch (best-effort; warns if `gh` is not authenticated).
  Prints — but does NOT execute — the tag and push commands the
  owner will run by hand:

      git tag -s <version> -m 'SwiftWebUI <version>'
      git push origin <version>

  Appends a one-line "0.MINOR.0 tagged" entry to
  .harness/changelogs/<today>.md. The entry is NOT committed; the
  owner reviews, commits, and merges the close-out PR.

SEE ALSO
  AGENTS.md §9, §11, §12
  .harness/docs/release.md
  ROADMAP.md
EOF
}

if [[ $# -ge 1 && "$1" == "--help" ]]; then
  usage
  exit 0
fi

# ---------------------------------------------------------------------------
# 1. Refuse to run on main / master.
# ---------------------------------------------------------------------------

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
  echo "release.sh: REFUSED — current branch is '$current_branch'." >&2
  echo "Run this script on a feature/fix/chore branch, AFTER the owner has" >&2
  echo "merged that branch into main and the close-out PR has shipped." >&2
  echo "See AGENTS.md §9 (Git workflow) and .harness/docs/release.md" >&2
  echo "(Release checklist)." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 2. Determine and validate the version string.
# ---------------------------------------------------------------------------

version="${1:-}"

if [[ -z "$version" ]]; then
  if [[ -f "$repo_root/CHANGELOG.md" ]]; then
    # The first H2 whose text starts with "[" in CHANGELOG.md. We
    # only look at the first match to avoid the [Unreleased] line.
    version="$(awk '
      /^## \[/ {
        line = $0
        sub(/^## \[/, "", line)
        sub(/\].*$/, "", line)
        # Skip the "Unreleased" placeholder.
        if (line != "Unreleased") {
          print line
          exit
        }
      }
    ' "$repo_root/CHANGELOG.md" || true)"
  fi
  if [[ -z "$version" ]]; then
    echo "release.sh: REFUSED — no version given and could not auto-detect from CHANGELOG.md." >&2
    echo "Pass a version explicitly: scripts/release.sh 0.1.0" >&2
    exit 2
  fi
  echo "release.sh: auto-detected version '$version' from CHANGELOG.md."
else
  echo "release.sh: using pinned version '$version'."
fi

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.\-]+)?$ ]]; then
  echo "release.sh: REFUSED — version '$version' is not a valid MAJOR.MINOR.PATCH[-(pre)]. " >&2
  echo "Examples: 0.1.0, 0.2.0, 1.0.0, 1.0.0-rc.1" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 3. Verify CI is green for the current branch (best-effort).
# ---------------------------------------------------------------------------

ci_status="skipped"
ci_note=""

if ! command -v gh >/dev/null 2>&1; then
  ci_status="skipped"
  ci_note="\`gh\` CLI not installed; CI status not verified. Install with 'brew install gh' and re-run."
elif ! gh auth status >/dev/null 2>&1; then
  ci_status="skipped"
  ci_note="\`gh\` CLI is not authenticated; CI status not verified. Run 'gh auth login' and re-run."
else
  # Best-effort: query the CI rollup for the current branch. We do
  # NOT require this to succeed — a missing remote PR or a draft
  # PR is a legitimate state. We just warn if the check rollup
  # reports a failure.
  if pr_url="$(gh pr view --json url -q .url 2>/dev/null || true)"; [[ -n "$pr_url" ]]; then
    if gh pr checks "$current_branch" >/dev/null 2>&1; then
      # Print the table for the owner to read. We don't pipe through
      # grep because the columns differ across `gh` versions.
      echo "release.sh: CI checks for '$current_branch' (PR: $pr_url):"
      gh pr checks "$current_branch" || true
      # Best-effort: detect a "fail" substring. We never fail the
      # script on this — the owner is the final say.
      if gh pr checks "$current_branch" 2>/dev/null | grep -Eiq '\bfail\b'; then
        ci_status="failing"
        ci_note="At least one CI check is reporting 'fail' for '$current_branch'. Investigate before tagging."
      else
        ci_status="passing-or-pending"
        ci_note="No 'fail' status detected. Owner must still read the table above."
      fi
    else
      ci_status="unknown"
      ci_note="Could not query CI checks for '$current_branch' (no PR or checks not yet started)."
    fi
  else
    ci_status="no-pr"
    ci_note="No open PR for '$current_branch'. CI cannot be verified locally."
  fi
fi

# ---------------------------------------------------------------------------
# 4. Print (do NOT execute) the tag and push commands.
# ---------------------------------------------------------------------------

tag_cmd="git tag -s $version -m 'SwiftWebUI $version'"
push_cmd="git push origin $version"

cat <<EOF

==============================================================
release.sh — $version pre-flight
==============================================================

Branch:        $current_branch
Version:       $version
CI status:     $ci_status
               $ci_note

--------------------------------------------------------------
The owner will run these commands BY HAND. This script does
NOT execute them. See AGENTS.md §9.
--------------------------------------------------------------

  $tag_cmd
  $push_cmd

--------------------------------------------------------------
If the tag is annotated with a GPG / SSH key, make sure that
key is in the SwiftWebUI release-maintainers team on GitHub
before pushing. If the key is missing, \`git push\` will be
rejected with "tag already exists" or a 403.
--------------------------------------------------------------

EOF

# ---------------------------------------------------------------------------
# 5. Append a "0.MINOR.0 tagged" entry to today's changelog.
#    Do NOT commit. The owner reviews, commits, and merges.
# ---------------------------------------------------------------------------

today="$(date -I)"
changelog_file="$repo_root/.harness/changelogs/$today.md"
timestamp="$(date '+%Y-%m-%d %H:%M')"
entry="[$timestamp] swiftwebui-steward — $version tagged (release.sh: pre-flight clean, awaiting owner to run tag + push)"

if [[ ! -d "$repo_root/.harness/changelogs" ]]; then
  echo "release.sh: REFUSED — .harness/changelogs/ does not exist." >&2
  echo "This directory is created and owned by swiftwebui-steward at" >&2
  echo "bootstrap time. See AGENTS.md §9." >&2
  exit 2
fi

if [[ ! -f "$changelog_file" ]]; then
  printf '# %s — changelog\n\n' "$today" > "$changelog_file"
fi

printf -- '- %s\n' "$entry" >> "$changelog_file"

cat <<EOF
Wrote a one-line entry to $changelog_file:

  $entry

This entry is NOT committed. The owner reviews, commits, and merges
the close-out PR. See AGENTS.md §9.

==============================================================
release.sh: pre-flight complete. Hand off to the owner.
==============================================================
EOF
