---
name: dom-renderer
description: Local rein for swiftwebui-dom-renderer inside swift-web-ui. Owns Sources/SwiftWebUIRenderer/** (graph, diff/patch, event delegation). Import of the global swiftwebui-dom-renderer agent.
---

# dom-renderer (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-dom-renderer/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-dom-renderer`
- **Local rein directory**: `.harness/reins/dom-renderer/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**: `Sources/SwiftWebUIRenderer/**`
  (`_Graph`, `_ViewOutputs`, `_Diff`, `_Patch`,
  `_EventDelegation`, the `Renderer` protocol and its
  implementations).
- **Out of scope**:
  - Public API surface (`Sources/SwiftWebUI/**`) → `architect`.
  - JavaScriptKit interop internals (`Sources/SwiftWebUIBridge/**`)
    → `bridge`. The renderer consumes the bridge, never bypasses
    it.
- **Adjacent reins**:
  - `architect` (architect defines what the graph must represent;
    renderer defines how).
  - `bridge` (every JS call from the renderer goes through the
    bridge).
  - `tester` (every renderer change ships with a snapshot test
    and (for the 0.1.0 milestone) a WebDriver smoke).

## Topic files you must read first

- `.harness/docs/swift-ui-surface.md` — what the graph represents.
- `.harness/docs/tdd.md` — snapshot test contract.
- `.harness/docs/js-bridge.md` — the bridge interface the renderer
  uses.

## Stop condition (project-specific)

A renderer change is "renderer-mergeable" when:

- [ ] `swift test` is green on the host matrix.
- [ ] A snapshot test in `Tests/SwiftWebUISnapshots/` covers the
      new graph → patch path (red → green in history).
- [ ] For the 0.1.0 stop condition specifically: `Text("hi")`
      renders to a graph that, when applied to the live DOM,
      produces `<div>hi</div>` in a real browser. This is the
      WebDriver smoke in `Tests/SwiftWebUIWebDriver/`.
- [ ] No new dependency on JavaScriptKit outside the bridge
      module's public interface.
- [ ] No Tokamak stack or Tokamak-era bundler imports.
