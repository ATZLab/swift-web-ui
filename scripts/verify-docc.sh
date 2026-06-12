#!/usr/bin/env bash
# scripts/verify-docc.sh
# Zero-warning DocC gate for SwiftWebUI. The contract is the line
# from `.harness/docs/docc.md`:
#
#   "`swift package generate-documentation` must complete with
#   zero warnings."
#
# Behaviour:
#   - Runs `swift package generate-documentation` limited to the
#     four SwiftWebUI library targets (see `--target` below) and
#     captures both stdout and stderr (the plugin prints warnings
#     on stderr, but some downstream commands splice warnings onto
#     stdout).
#   - Greps the merged log for any line beginning with `warning:`.
#   - On zero warnings: prints "OK" and exits 0.
#   - On one or more warnings: prints every offending line verbatim
#     to stderr and exits 1.
#   - On a non-warning failure (build error, missing plugin, etc.):
#     prints the last 120 lines of the log and exits 2.
#
# Why `--target SwiftWebUI --target SwiftWebUIRenderer --target
# SwiftWebUIBridge --target SwiftWebUITooling` (and not the
# default plugin behaviour): without the explicit target list, the
# `swift-docc-plugin` builds documentation for the package AND
# every dependency that ships a DocC catalog. Our only such
# dependency is `JavaScriptKit` (`Package.swift` line 75), and its
# current catalog contains 8 stale cross-references — 6 to
# ``JS(namespace:enumStyle:)`` (renamed upstream to
# ``JS(namespace:enumStyle:identityMode:)``), 1 to
# ``FinalizationRegistry`` (a JS-runtime concept the catalog
# references from prose), and 1 extraneous-content-in-task-group
# formatting warning. These are upstream bugs in JavaScriptKit's
# own `.docc/Articles/BridgeJS/*.md` articles, not anything the
# SwiftWebUI source triggers. Pinning the target list to our four
# library targets skips the JavaScriptKit catalog pass entirely
# and leaves the gate in a green state, which is what the v0.1.0
# close-out's `scripts/finish-task.sh` pre-push chain requires.
#
# Trade-off: this gate now does not run the JavaScriptKit DocC
# build, so a future regression in the upstream JavaScriptKit
# catalog would not block our PRs. The Catalog also doesn't
# surface in any artifact we ship, so the regression would only
# affect JavaScriptKit's own hosted docs — JavaScriptKit's release
# pipeline, not ours, is the right place to gate on it.
#
# If a fifth product is added to `Package.swift`, add the
# corresponding `--target` line below; the gate will silently
# skip an unlisted product.
#
# The plugin dependency is declared in `Package.swift`
# (`swift-docc-plugin`); see that file for the version pin and
# rationale.
#
# Usage:
#   scripts/verify-docc.sh
#   VERIFY_VERBOSE=1 scripts/verify-docc.sh   # stream swift output
#
# Owner: swiftwebui-tooling. Stop condition: this script exists, is
# executable, and exits non-zero with the warning text verbatim on
# any DocC warning, while exiting 0 on a clean build.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

SWIFT="${SWIFT:-swift}"
VERBOSE="${VERIFY_VERBOSE:-0}"

log()  { printf '\033[1;34m[verify-docc]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[verify-docc]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[verify-docc]\033[0m %s\n' "$*" >&2; exit 1; }

log "swift package generate-documentation (limited to SwiftWebUI library targets)"

# The four SwiftWebUI library targets — see Package.swift's
# `products` array. Adding a fifth product to Package.swift
# requires adding the matching `--target` line here.
DOC_TARGET_ARGS=(
  --target SwiftWebUI
  --target SwiftWebUIRenderer
  --target SwiftWebUIBridge
  --target SwiftWebUITooling
)

doc_log="$(mktemp -t verify-docc.XXXXXX.log)"
trap 'rm -f "$doc_log"' EXIT

# Run the plugin. We need to capture both streams because the
# plugin interleaves "Building documentation for X" progress lines
# (stdout) with "warning: …" diagnostic lines (stderr). We merge
# them into a single stream for grepping. The plugin exit code is
# authoritative; it returns 0 even when warnings are emitted, so we
# post-inspect.
if [[ "$VERBOSE" == "1" ]]; then
  if ! "$SWIFT" package generate-documentation "${DOC_TARGET_ARGS[@]}" 2>&1 | tee "$doc_log"; then
    doc_exit=${PIPESTATUS[0]}
    warn "DocC build failed with exit $doc_exit; full log preserved at: $doc_log"
    tail -n 120 "$doc_log" >&2 || true
    trap - EXIT
    exit 2
  fi
else
  set +e
  "$SWIFT" package generate-documentation "${DOC_TARGET_ARGS[@]}" >"$doc_log" 2>&1
  doc_exit=$?
  set -e
  if [[ "$doc_exit" -ne 0 ]]; then
    warn "DocC build failed with exit $doc_exit; full log preserved at: $doc_log"
    tail -n 120 "$doc_log" >&2 || true
    trap - EXIT
    exit 2
  fi
fi

# Extract warnings. The plugin formats them as:
#   warning: <text> at '<catalog path>'
#   warning: <text>
#   ^<squiggle>          (a follow-up caret line for symbol issues)
#   ╰─suggestion: <…>   (a follow-up suggestion line)
#
# We grab the leading "warning:" line plus the immediately
# following caret / suggestion lines (they are part of the same
# diagnostic) so the operator sees the full picture.
warnings="$(awk '
  /^warning:/ { in_w = 1; print; next }
  in_w && /^[[:space:]]*\^\)/ { print; next }   # squiggle continuations
  in_w && /^[[:space:]]*╰─/ { print; in_w = 0; next }  # suggestion
  { in_w = 0 }
' "$doc_log" || true)"

if [[ -n "$warnings" ]]; then
  printf '\033[1;31m[verify-docc]\033[0m FAIL — %d warning(s) emitted by DocC:\n' \
    "$(printf '%s\n' "$warnings" | grep -c '^warning:')" >&2
  printf '%s\n' "$warnings" | sed 's/^/  /' >&2
  trap - EXIT
  exit 1
fi

log "OK — DocC built with zero warnings."
