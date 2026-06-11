#!/usr/bin/env bash
# scripts/lint-paths.sh
# Fail the build (or the pre-commit hook) if any tracked Markdown file
# in this repository contains an absolute filesystem path.
#
# Rationale: SwiftWebUI is open-source. A clone on a contributor's
# machine must read identically to a clone on the original author's.
# Absolute paths leak the author's home directory and break the
# moment the project moves. See AGENTS.md §10 (Locked Decision 10).
#
# Owner: swiftwebui-tooling
# Stop condition for the guard: this script returns non-zero on
# any tracked doc that contains a forbidden path pattern.

set -euo pipefail

# Resolve the repo root no matter where the script is invoked from.
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# Files we scan: tracked Markdown only. Untracked files (e.g. local
# scratch notes) are ignored on purpose — they aren't shipped.
files=$(git ls-files '*.md' '*.markdown')

if [[ -z "$files" ]]; then
  echo "lint-paths: no tracked markdown files; nothing to check."
  exit 0
fi

# Patterns we forbid. Each pattern is a Perl regex (grep -E compatible).
# - /Users/..., /home/...           : macOS / Linux absolute homes
# - C:\..., C:/...                 : Windows drive roots
# - ~/<segment>/...                : tilde-expanded user-relative paths
# - /tmp/..., /var/..., /opt/...    : other absolute system paths
patterns=(
  '/Users/[^[:space:])"]+'
  '/home/[^[:space:])"]+'
  '[A-Za-z]:[\\\\/][^[:space:])"]+'
  '~[a-zA-Z0-9_.-]+/[^[:space:])"]+'
  '/(tmp|var|opt|etc|usr/local)/[^[:space:])"]+'
)

violations=0
for pattern in "${patterns[@]}"; do
  # We strip fenced code blocks and inline backticks BEFORE running
  # grep, so the rule itself doesn't false-positive on its own
  # example patterns. Per file:
  #   1. awk: drop everything between ``` fences.
  #   2. sed: drop everything between backticks.
  # The result is prose-only; absolute paths in prose are what we
  # want to catch.
  matches=""
  for f in $files; do
    prose=$(awk '
      /^[[:space:]]*```/ { in_fence = !in_fence; next }
      in_fence { next }
      { print NR "\t" $0 }
    ' "$f" | sed -E 's/`[^`]*`//g')
    # Each surviving line still carries its original line number as
    # a leading "<n>\t". Grep with -n will give a fresh line number
    # within the post-processed stream; recover the original by
    # parsing the leading column.
    file_matches=$(printf '%s\n' "$prose" | awk -v pat="$pattern" -v file="$f" '
      {
        orig_line = $1 + 0
        $1 = ""
        sub(/^\t/, "")
        if (match($0, pat)) {
          printf "%s:%d: %s\n", file, orig_line, $0
        }
      }
    ')
    if [[ -n "$file_matches" ]]; then
      matches+="$file_matches"$'\n'
    fi
  done
  if [[ -n "$matches" ]]; then
    echo "lint-paths: forbidden absolute path pattern '$pattern' found:"
    echo "$matches" | sed 's/^/  /'
    echo
    violations=$((violations + 1))
  fi
done

if [[ $violations -gt 0 ]]; then
  echo "lint-paths: FAIL — $violations forbidden pattern(s) in tracked docs."
  echo "Replace with a repo-relative path (./foo, ../AGENTS.md, etc.)."
  echo "See AGENTS.md §10 for the full rule."
  exit 1
fi

echo "lint-paths: OK — all tracked docs use repo-relative paths."
