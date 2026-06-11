---
name: architect
description: Local rein for swiftwebui-architect inside swift-web-ui. Owns framework design, public API surface, SPI gating, and DocC catalog structure. Import of the global swiftwebui-architect agent.
---

# architect (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-architect/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-architect`
- **Local rein directory**: `.harness/reins/architect/`
- **Do not** redefine the global agent's system prompt here. If the
  global spec and this wrapper disagree, **the global spec wins**.

## Project context (swift-web-ui specific)

- **Scope inside this repo**: `Sources/SwiftWebUI/**` (public API),
  `.docc/` (catalog structure), `docs/swift-ui-surface.md` (the
  surface ledger), `docs/naming.md` (the naming rules).
- **Gate**: no public symbol lands in `Sources/SwiftWebUI/` without
  architect sign-off recorded in the PR description. No `@_spi`
  surface is removed from SPI without architect sign-off.
- **Adjacent reins**:
  - `dom-renderer` (renderer internals)
  - `bridge` (JS interop — architect approves the public wrapper
    surface that hides JavaScriptKit)
  - `tester` (architect never approves a PR with a missing or
    late test for a public symbol)
  - `docs` (architect and docs co-sign the public surface and
    the catalog structure)

## Topic files you must read first

- `AGENTS.md` (repo root) — project brain + locked decisions.
- `.harness/docs/swift-ui-surface.md` — the 0.1.0 surface ledger.
- `.harness/docs/naming.md` — Apple-like naming rules.
- `.harness/docs/docc.md` — DocC tone and template.

## Stop condition (project-specific)

A surface change is "architect-mergeable" when:

- [ ] Symbol is listed in `docs/swift-ui-surface.md` (or moved
      there in the same PR — with rationale).
- [ ] Naming rules in `docs/naming.md` are satisfied.
- [ ] DocC comment follows `docs/docc.md` template + tone.
- [ ] swift-testing test is in the same PR and was red → green in
      the commit history (`docs/tdd.md`).
- [ ] If gated as `@_spi(Experimental)`, the SPI tag matches the
      project-wide convention.
- [ ] PR description names this rein and the reviewing reins.
