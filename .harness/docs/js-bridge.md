# JavaScriptKit bridge — interop rules

> Owner: `swiftwebui-bridge`. The bridge is the **only** place in the
> public source tree that may `import JavaScriptKit`.

## Locked decision

> **JavaScriptKit is the only allowed JS-bridge dependency.**
> The Tokamak stack (including the Tokamak-era bundler) and
> Tokamak interop are banned. The bridge agent enforces this.

## What the bridge owns

The bridge module (`Sources/SwiftWebUIBridge/`) is responsible for:

1. **JSClosure retain policy** — every `JSClosure` allocated on the
   Swift side MUST be registered in a per-instance `JSClosureRegistry`
   so that a long-lived Swift `@State` does not produce a
   retain-cycle through the JS object.
2. **Swift ↔ JS value conversion** — `JSValue` ↔ Swift primitive
   helpers (`string`, `bool`, `int`, `double`, `array`, `object`).
   Helpers live in `Sources/SwiftWebUIBridge/Values.swift`.
3. **Async / Promise helpers** — `await JSFunction.call(...)`,
   `JSFunction.promise(_:)` so that Swift code can `await` JS
   results.
4. **External JS API bindings** — small typed wrappers for the
   `window.alert`, `console.log`, and `fetch` APIs. They are the
   reference examples for users who want to bind more.

## JSClosure retain policy

A `JSClosure` is a JavaScript object that holds a reference back
to a Swift closure. If the Swift side drops its reference, the JS
side keeps the closure alive forever. If the Swift side keeps its
reference forever, the Swift closure (and the captured state it
holds) lives forever.

**Policy** (locked):

- Every `JSClosure` is wrapped in a `BridgedClosure` value type
  that **owns a single strong reference** plus an integer handle.
- The handle is registered in a per-renderer `JSClosureRegistry`
  (`var registry: [Int: JSClosure]`) on the `Renderer` instance.
- When the Swift view that produced the closure is **disposed**
  (graph diff drops the node), the bridge sends a
  `releaseClosure(handle)` to JS and removes the entry from the
  registry. The Swift closure is then free to be deallocated.
- A unit test (`JSClosureRegistryTests`) covers the round-trip
  and asserts the registry is empty after the view is dropped.

This is the **stop condition** of the `swiftwebui-bridge` agent.

## Banned APIs

The following are **explicitly banned** in the SwiftWebUI source
tree:

- `import Tokamak*` (any module whose name starts with `Tokamak`).
- `import` of the Tokamak-era bundler module (any spelling, in
  either case, regardless of capitalisation).
- `import JavaScriptCore` (the C bridge — JSKit is the modern
  replacement).
- Any direct `import` of a JS-binding module that is not
  `JavaScriptKit` or its transitive deps.

The bridge agent's `BridgetLint.swift` script (or equivalent
scripted check in CI) greps the source tree for these tokens and
fails the build on hit.

## Public API exposure rule

The bridge is **internal-only**. The public surface
(`Sources/SwiftWebUI/`) MUST NOT import `JavaScriptKit` and MUST
NOT expose `JSValue`, `JSClosure`, `JSFunction`, etc. in its
public symbols.

If a user-facing feature requires a JS interop call, the public
API exposes a **Swift-typed wrapper** defined in `Sources/SwiftWebUI/`
that calls into the bridge internally.

## Async model

JSKit's `JSFunction` is callable synchronously from Swift. For
asynchronous JS (e.g. `fetch` returning a `Promise`), the bridge
exposes:

```swift
public extension JSFunction {
    /// Calls the function and `await`s its Promise result.
    func callAsPromise(_ args: [JSValue]) async throws -> JSValue
}
```

The internal implementation uses `withCheckedThrowingContinuation`.
The function pointer is then called with a callback closure that
resolves the continuation.

## Tests for the bridge

- `JSClosureRegistryTests` — round-trip a closure, drop the Swift
  handle, assert registry empties and JS object releases.
- `window.alert` wrapper — fires a test alert in a headless
  Playwright session, asserts the alert text matches.
- `fetch` wrapper — `await`s a mock endpoint, decodes JSON, and
  returns a typed value to Swift.
- `console.log` wrapper — asserts a stringified argument reaches
  the browser console in the WebDriver test.

These are the **stop condition** of the `swiftwebui-bridge` agent.
