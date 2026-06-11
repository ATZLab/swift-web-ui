---
name: bridge
description: Local rein for swiftwebui-bridge inside swift-web-ui. Owns Sources/SwiftWebUIBridge/** (JavaScriptKit interop, JSClosure lifetime, async helpers). Enforces the "no Tokamak, no Tokamak-era bundler" rule. Import of the global swiftwebui-bridge agent.
---

# bridge (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-bridge/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-bridge`
- **Local rein directory**: `.harness/reins/bridge/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**: `Sources/SwiftWebUIBridge/**`. The
  bridge is the **only** module in the source tree allowed to
  `import JavaScriptKit`. The public API
  (`Sources/SwiftWebUI/**`) must NOT import JavaScriptKit.
- **Banned tokens** (CI grep):
  - `import Tokamak` (any spelling)
  - `import` of the Tokamak-era bundler module (any spelling)
  - `import JavaScriptCore`
  - any `JS*` type leaking into the public API
- **Adjacent reins**:
  - `architect` (architect defines the Swift-typed wrapper surface
    the bridge exposes publicly).
  - `dom-renderer` (the renderer is the primary consumer of the
    bridge).
  - `tester` (the bridge ships with a `JSClosureRegistry` retain
    test, async helper tests, and a WebDriver smoke for the
    `window.alert` / `console.log` / `fetch` wrappers).

## Topic files you must read first

- `.harness/docs/js-bridge.md` — full interop contract, retain
  policy, banned APIs.

## Stop condition (project-specific)

A bridge change is "bridge-mergeable" when:

- [ ] `JSClosureRegistry` retain-cycle test passes
      (`JSClosureRegistryTests`).
- [ ] At least one of the following three wrappers is shipped
      and tested: `window.alert`, `console.log`, `fetch`.
- [ ] The CI grep for banned tokens (Tokamak, the Tokamak-era
      bundler, JavaScriptCore) returns zero hits across
      `Sources/**`.
- [ ] No new public symbol in `Sources/SwiftWebUI/` exposes a
      JavaScriptKit type.
- [ ] DocC comment on every public bridge symbol (Apple tone, see
      `docs/docc.md`).
