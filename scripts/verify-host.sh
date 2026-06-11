#!/usr/bin/env bash
# scripts/verify-host.sh
# Verify the host-triple build + test matrix for SwiftWebUI. This is
# the "happy path" gate that every worker runs before pushing (wired
# into `scripts/finish-task.sh`). It is intentionally minimal: it
# exits 0 on success and exits non-zero on the first failure, with
# the failing step name printed to stderr.
#
# Sequence:
#   1. `bash scripts/lint-paths.sh` — AGENTS.md §10 path-hygiene guard.
#      The script refuses to proceed if lint-paths returns non-zero,
#      because pushing code that violates §10 is a violation of a
#      locked decision.
#   2. `swift build` — host-triple debug build.
#   3. `swift test`  — host-triple test run.
#
# Usage:
#   scripts/verify-host.sh
#   VERIFY_VERBOSE=1 scripts/verify-host.sh   # stream swift output
#
# Environment:
#   VERIFY_VERBOSE — if set to 1, swift's stdout is streamed (default:
#                    silent; only the step name is printed).
#   SWIFT — override the swift binary (useful for CI pinning).
#
# Owner: swiftwebui-tooling. Stop condition: this script exists, is
# executable, runs `lint-paths.sh` first, and exits 0 only when
# `swift build` and `swift test` both pass on the host triple.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

SWIFT="${SWIFT:-swift}"
VERBOSE="${VERIFY_VERBOSE:-0}"

log()  { printf '\033[1;34m[verify-host]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[verify-host]\033[0m %s\n' "$*" >&2; exit 1; }

# --- 1. Path-hygiene guard (AGENTS.md §10) ---------------------------------

log "1/3  path-hygiene guard (scripts/lint-paths.sh)"
if ! bash scripts/lint-paths.sh; then
  fail "step 1/3 failed: lint-paths.sh — fix the forbidden paths before pushing (AGENTS.md §10)."
fi

# --- 2. Host build ---------------------------------------------------------

log "2/3  host build ($SWIFT build)"
if [[ "$VERBOSE" == "1" ]]; then
  "$SWIFT" build || fail "step 2/3 failed: $SWIFT build (host triple)."
else
  if ! "$SWIFT" build >/tmp/verify-host-build.log 2>&1; then
    tail -n 80 /tmp/verify-host-build.log >&2 || true
    fail "step 2/3 failed: $SWIFT build (host triple). Full log: /tmp/verify-host-build.log"
  fi
  rm -f /tmp/verify-host-build.log
fi

# --- 3. Host test ----------------------------------------------------------

log "3/3  host test  ($SWIFT test)"
if [[ "$VERBOSE" == "1" ]]; then
  "$SWIFT" test || fail "step 3/3 failed: $SWIFT test (host triple)."
else
  if ! "$SWIFT" test >/tmp/verify-host-test.log 2>&1; then
    tail -n 120 /tmp/verify-host-test.log >&2 || true
    fail "step 3/3 failed: $SWIFT test (host triple). Full log: /tmp/verify-host-test.log"
  fi
  rm -f /tmp/verify-host-test.log
fi

log "OK — host build + test green."
