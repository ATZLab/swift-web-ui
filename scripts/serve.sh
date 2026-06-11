#!/usr/bin/env bash
# scripts/serve.sh
# One-shot dev workflow for SwiftWebUI. From a clean clone, this is
# the only command a contributor needs to remember. It:
#   1. Runs `swift build` + `swift test` on the host triple.
#   2. Tries `swift build --triple wasm32-unknown-wasi`. If the
#      wasm32 SDK is not installed, prints a clear message and
#      continues (the script still exits 0 in that case).
#   3. Serves `web/` over `python3 -m http.server` on port 8000.
#      The browser opens index.html; the JS shim logs a placeholder.
#
# Usage:
#   scripts/serve.sh
#   PORT=9000 scripts/serve.sh    # override port
#   WASM_SKIP=1 scripts/serve.sh  # skip the wasm build attempt
#
# Owner: swiftwebui-tooling. Stop condition (per AGENTS.md tooling
# scope): this script exists, is executable, runs on a clean clone,
# builds the host matrix, and serves the dev page on
# http://localhost:8000.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

log()  { printf '\033[1;34m[serve]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[serve]\033[0m %s\n' "$*" >&2; }
fail() { printf '\033[1;31m[serve]\033[0m %s\n' "$*" >&2; exit 1; }

PORT="${PORT:-8000}"
WASM_SKIP="${WASM_SKIP:-0}"

# --- 1. Host build + test -------------------------------------------------

log "1/3  host build (swift build)"
if ! swift build; then
    fail "host build failed. See output above."
fi

log "2/3  host test (swift test)"
if ! swift test; then
    fail "host tests failed. See output above."
fi

# --- 2. wasm32 build (best-effort) ----------------------------------------

if [[ "$WASM_SKIP" == "1" ]]; then
    warn "3/3  wasm32 build skipped (WASM_SKIP=1)"
else
    log "3/3  wasm32 build (swift build --triple wasm32-unknown-wasi)"
    if swift build --triple wasm32-unknown-wasi 2>wasm-build.log; then
        rm -f wasm-build.log
        log "    wasm32 build OK"
    else
        warn "    wasm32 SDK not installed; skipping wasm build."
        warn "    (install with: swift sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-macos.artifactbundle.tar.gz)"
        warn "    full error saved to wasm-build.log for inspection."
    fi
fi

# --- 3. Serve web/ --------------------------------------------------------

if [[ ! -d web ]]; then
    fail "web/ directory missing at $repo_root/web"
fi

if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 is required to serve web/ (it is the dev HTTP server)."
fi

log "ready. Serving web/ on http://localhost:${PORT}/  (Ctrl-C to stop)"
exec python3 -m http.server "$PORT" --directory web
