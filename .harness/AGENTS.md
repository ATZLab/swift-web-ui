# .harness/AGENTS.md — SwiftWebUI Project Orchestrator

> Mavis orchestrator for the **swift-web-ui** repository.
> This file is the orchestrator's routing brain: who handles what directly
> vs. who delegates. **The 7 reins listed below are imported from the
> global Mavis agent registry at runtime; the daemon injects the roster.
> Do not hand-edit the roster — update each rein's `description:` instead.**

## What this harness owns

This `.harness/` is the project-level team definition for SwiftWebUI
(see `AGENTS.md` at the repo root for the project brain and locked
decisions). It is committed to git and is the source of truth for:

- Routing from natural-language task descriptions to the right rein.
- Per-topic conventions in `.harness/docs/`.
- Shared memory and per-day changelogs.

## The 7 specialist reins

All reins are **imports** of global agents in `~/.mavis/agents/swiftwebui-*/`.
The local `.harness/reins/<name>/agent.md` files are project-side stubs
that:

1. Confirm the global agent is the canonical source.
2. Add project-specific acceptance criteria and topic-file references.
3. **Do not** redefine the global agent's system prompt.

| Reached for | Global agent | Local rein | Topic files (must read) |
|---|---|---|---|
| framework design / API surface / SPI gating | `swiftwebui-architect` | `.harness/reins/architect/` | `docs/swift-ui-surface.md`, `docs/naming.md` |
| `_Graph` → DOM, diff/patch, event delegation | `swiftwebui-dom-renderer` | `.harness/reins/dom-renderer/` | `docs/swift-ui-surface.md`, `docs/tdd.md` |
| JavaScriptKit interop, JSClosure lifetime | `swiftwebui-bridge` | `.harness/reins/bridge/` | `docs/js-bridge.md` |
| Package.swift, JS bundle, dev server, CI | `swiftwebui-tooling` | `.harness/reins/tooling/` | `docs/release.md` |
| DocC, guides, tone review | `swiftwebui-docs` | `.harness/reins/docs/` | `docs/docc.md`, `docs/naming.md` |
| TDD discipline, snapshots, WebDriver smoke | `swiftwebui-tester` | `.harness/reins/tester/` | `docs/tdd.md` |
| OSS health, releases, GitHub workflows | `swiftwebui-steward` | `.harness/reins/steward/` | `docs/release.md` |

## Routing rules (read this before dispatching)

1. **Framework surface, naming, SPI, DocC catalog structure** →
   `swiftwebui-architect`. Architect is the gate for any public API
   change. No type or modifier enters `Sources/SwiftWebUI/` without
   an architect sign-off recorded in the PR description.

2. **Renderer implementation** (`Sources/SwiftWebUIRenderer/`),
   diff/patch algorithms, DOM event delegation, browser-side runtime
   performance → `swiftwebui-dom-renderer`. Renderer code MUST ship
   with snapshot tests written first (`swiftwebui-tester` signs off
   on the test pair).

3. **JavaScriptKit interop** (`Sources/SwiftWebUIBridge/`),
   `JSClosure` retain policy, async helpers, external JS API bindings
   → `swiftwebui-bridge`. **The Tokamak stack (Tokamak interop and
   the Tokamak-era bundler) is banned — the bridge agent enforces
   that.**

4. **Package.swift matrix, `web/` JS bundle, dev server, CI shell
   glue** → `swiftwebui-tooling`. Tooling changes without a `swift test`
   pass on the matrix are rejected.

5. **Documentation (DocC + guides + tutorial catalog)** →
   `swiftwebui-docs`. Docs agent enforces the Apple guide tone
   (declarative, no second-person) and runs
   `swift package generate-documentation` with zero warnings.

6. **Test strategy, TDD enforcement, CI matrix, snapshot and
   WebDriver smoke** → `swiftwebui-tester`. Tester is the only
   agent that can green-light a PR's test matrix; tester ALSO
   red-flags PRs that landed implementation before tests.

7. **OSS health, README, CONTRIBUTING, CoC, semver, release notes,
   GitHub Actions (CI + Pages)** → `swiftwebui-steward`. Steward
   owns the first 0.1.0 release end-to-end.

## Cross-rein protocols

- A change that touches ≥2 reins needs a **lead** assigned by the
  architect (or the orchestrator, for non-architect concerns). Lead
  is responsible for the final green and the PR description.
- Every PR description lists which reins reviewed which file.
- Memory: each rein appends a "**durable lesson**" entry to
  `.harness/memory/MEMORY.md` only when the lesson is project-wide
  and survives a code change. Per-task notes go in the rein's
  scratchpad, not in MEMORY.md.
- Daily changelog: every meaningful commit lands an entry in
  `.harness/changelogs/YYYY-MM-DD.md` in the format
  `HH:MM <rein> — <one-line summary>`.
- **Paths in tracked docs are repository-relative only.** No
  `/Users/…`, no `~/…`, no Windows drive roots. See repo-root
  `AGENTS.md` §10 for the full rule and the `lint-paths` guard
  (owned by `swiftwebui-tooling`).

## When the orchestrator handles directly (does NOT delegate)

- Pure read/research requests ("what does `_Graph` do today?").
- Renaming / reordering of `.harness/` files (mechanical).
- Resolving routing disagreements between reins (orchestrator is
  the final word unless the architect is asked to escalate).
- Branch hygiene / worktree setup for in-flight tasks.

## When the orchestrator MUST delegate (does NOT handle directly)

- Any change to `Sources/SwiftWebUI/**` → at minimum
  `swiftwebui-architect` and `swiftwebui-tester`.
- Any change to `Sources/SwiftWebUIBridge/**` →
  `swiftwebui-bridge` and `swiftwebui-tester`.
- Any change to `Sources/SwiftWebUIRenderer/**` →
  `swiftwebui-dom-renderer` and `swiftwebui-tester`.
- Any change to `Sources/SwiftWebUITooling/**` or CI → `swiftwebui-tooling`.
- Any change to `.docc/**` or public-facing guide text → `swiftwebui-docs`.
- Anything release-shaped (tag, changelog, version bump) →
  `swiftwebui-steward`.

## Topic files (deep-dive references)

- `.harness/docs/swift-ui-surface.md` — what the public surface looks
  like in 0.1.0 and what is gated as SPI.
- `.harness/docs/naming.md` — Apple-like naming rules and the
  SwiftUI disambiguation table.
- `.harness/docs/tdd.md` — TDD contract: red-first, snapshot policy,
  CI matrix.
- `.harness/docs/docc.md` — DocC comment template, tone rules,
  catalog layout.
- `.harness/docs/js-bridge.md` — JavaScriptKit interop rules,
  `JSClosure` lifetime, async helpers, banned alternatives (the
  Tokamak stack and its bundler).
- `.harness/docs/release.md` — version policy, milestone plan,
  release-note template.
- `.harness/docs/repo-layout.md` — what goes where in the tree.

## Verification protocol (per change)

1. The owning rein proposes a plan in its session.
2. Tester runs the relevant suite locally and reports
   red-then-green.
3. The owning rein opens the PR; PR description names the
   reviewing reins and links the test commit.
4. After CI green, the steward (if release-related) or
   the architect (if surface-related) merges.

## Onboarding a new contributor / agent

- Read `AGENTS.md` at the repo root first.
- Read this file second.
- Read the relevant `docs/<topic>.md` third.
- Do not start work without a stop condition written in the PR
  description.

## Out of scope (handled by the global agent, not the rein)

- Editing the global `swiftwebui-*/agent.md` files — those are
  authored by the `create-7-agents` track. The local reins are
  project-side wrappers, not the canonical definition.
- Changing Mavis itself — that's the `mavis` agent.

## Local tooling pointers

- `scripts/lint-paths.sh` — path-hygiene guard. Run before any PR.
  Owner: `swiftwebui-tooling`. See repo-root `AGENTS.md` §10.
- `scripts/finish-task.sh` — worker commit+push helper. Refuses
  to run on `main`. Owner: `swiftwebui-tooling`. See repo-root
  `AGENTS.md` §9.
- `scripts/open-pr.sh` — single PR opener with auto-filled body
  (per-rein review list + checklist). Refuses to run on `main`.
  Owner: `swiftwebui-tooling`. See repo-root `AGENTS.md` §11
  (one PR per phase) and §12 (PR body auto-fill).
