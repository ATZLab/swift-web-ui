# SwiftWebUIBridge

> **JavaScriptKit interop for SwiftWebUI.** Owns the
> `JSClosure` retain policy, the Swift ↔ JS value
> conversion, the `await` / Promise helpers, and the typed
> external-binding DSL that user code reaches for when it
> needs to call a browser API from Swift.

The bridge is the **only** module in the SwiftWebUI
source tree that may `import JavaScriptKit`. Every other
module consumes the bridge through the
`@_spi(SwiftWebUI)` surface documented below.

The cross-cutting interop rules — banned alternatives,
the public-API-exposure rule, and the bridge's test
harness — are in
[`../../.harness/docs/js-bridge.md`](../../.harness/docs/js-bridge.md).
This README is the **module-internal handbook** for the
bridge: the ownership rules, the async helpers, and the
binding DSL.

## Modules

| File | Surface | When to use |
| --- | --- | --- |
| `JSClosureRegistry.swift` | `JSClosureRegistry`, `BridgedClosure` | Every `JSClosure` your code hands to the DOM or to a JS API. |
| `Values.swift` | `Values.toJSValue(_:)`, `Values.string(from:)`, etc. | Convert a Swift primitive to / from a `JSValue`. |
| `Promise.swift` | `JSObject.callAsPromise(_:)` (wasm32-only) | `await` a JS function that returns a Promise. |
| `ExternalJSAPI.swift` | `Bridge.alert(_:)`, `Bridge.consoleLog(_:)`, `Bridge.fetch` (wasm32-only) | Call a browser global from Swift. |

## Ownership rules

The bridge's retain policy has three contracts. Every
piece of code that hands a Swift closure into JS must
follow them.

### 1. Every `JSClosure` is registered

`JSClosureRegistry` is the single map from
`Int handle` to a `JSClosureProtocol` instance. The
renderer allocates one registry per `Renderer`
instance; user code that needs to hand a closure to JS
talks to the registry, not to `JSClosure.init` directly.

```swift
let registry: JSClosureRegistry = ... // from the renderer
let closure = JSClosure { args in
    // ...Swift body...
    return .undefined
}
let bridged = BridgedClosure(
    handle: registry.register(closure),
    closure: closure,
    in: registry
)
// Hand `bridged.handle` to JS. When `bridged` is
// dropped (or the registry's `release(_:)` is called),
// the entry is removed and `closure.release()` fires.
```

The renderer's graph diff calls `registry.release(handle)`
for every handle the diff determines has dropped. The
renderer's deinit calls `registry.releaseAll()`.

### 2. Releasing is idempotent

`registry.release(handle)` is a no-op on an unknown
handle. Callers may call it twice from two code paths
without trapping, which is what makes the
"diff drops node → release handle" path safe to
combine with the "view is dropped → deinit fires
another release" path.

### 3. The Swift side is the source of truth

The JS side keeps a `JSClosure` alive forever; the
Swift side keeps the closure (and its captures) alive
forever. The two failure modes cancel out only when
both sides release. The bridge's contract is: the
Swift side is the source of truth — a `BridgedClosure`
that drops **must** release the handle, and the
release **must** call `closure.release()` on the JS
side.

The struct's `deinit` is the policy. There is no
manual `release()` for user code to call.

## Async helpers

`JSObject.callAsPromise(_:)` (the function is
`JSObject`; `JSFunction` is a typealias for it in
modern JavaScriptKit) is the bridge's `await` shape.
The convention is the Node-style
`fn((resolve, reject) => { ... }, ...args)` shape used
by `fetch`, `crypto.subtle`, `WebSocket.send`, and
most third-party Promise-returning APIs.

```swift
let fetch = Bridge.fetch  // JSObject (Promise-returning)
let response = try await fetch.callAsPromise([urlValue])
```

The helper internally constructs a `new Promise((resolve,
reject) => { try { resolve(targetFn(...args)); } catch
(e) { reject(e); } })` and awaits it via
`withCheckedThrowingContinuation`. The Swift call site
sees a single resolution with either the function's
return value or a `JSException` carrying the rejection.

> The `callAsPromise` extension is **wasm32-only** —
> the implementation calls the JavaScriptKit C runtime,
> which is wasi-only. The host (macOS) build links the
> type so the test target compiles; the runtime call
> paths are `#if os(WASI)`-gated.

## External-binding DSL

The bridge's `Bridge` namespace is the **reference
example** for binding browser globals. The list is
intentionally short — `alert`, `consoleLog`, `fetch` —
but the *pattern* is what user code copies when it
needs to bind more.

```swift
@_spi(SwiftWebUI)
public enum Bridge {
    public static func alert(_ message: String) {
        guard let alert = JSObject.global.alert.function else {
            return
        }
        _ = alert(arguments: [message.jsValue])
    }
    // ... consoleLog, fetch ...
}
```

The DSL is:

1. **Look up the global on `JSObject.global`.** The
   `@dynamicMemberLookup` projection turns
   `JSObject.global.alert` into a typed lookup of the
   `alert` property.
2. **Unwrap the optional `.function`.** The runtime
   may not have an `alert` (a non-browser wasm host);
   the `guard let` makes the call site safe.
3. **Call with `[message.jsValue]`.** The Swift → JS
   conversion is the bridge's job, not the call site's.
4. **Discard the `JSValue` return.** The wrapper's
   return type is `Void`; the JS function's return
   value is not part of the Swift surface.

To bind a new API, copy the pattern. The
`Tests/SwiftWebUIBridgeTests/ExternalJSAPIWrapperTests.swift`
file is the canonical test fixture for a new binding.

## SPI gating

The bridge's public symbols are gated:

- `@_spi(SwiftWebUI)` — internal SPI for the
  renderer / user API. Stable across the 0.2.x
  release line.
- `@_spi(Experimental)` — surface that is being
  trialled. May change between minor versions without
  the locked-decision process. Reserved for 0.3.0
  surface; not used in 0.2.0.

`JavaScriptKit` is **not** re-exported. A consumer of
the bridge sees Swift types only; the underlying
`JSValue`, `JSObject`, and `JSClosure` are sealed
behind the `Values` / `Bridge` / `JSClosureRegistry`
surface.

## Testing

`Tests/SwiftWebUIBridgeTests/` is the bridge's test
target. The split:

- **Host-runnable** (macOS): `JSClosureRegistryTests`,
  `BridgedClosureTests`, `ValuesPrimitiveRoundTripTests`.
  These exercise the registry's map semantics and the
  primitive round-trip via a `MockJSClosure` that
  conforms to `JSClosureProtocol` without touching the
  JavaScriptKit runtime. 16 tests.
- **Wasm32-only** (`#if os(WASI)`):
  `ValuesCollectionRoundTripTests`, `PromiseTests`,
  `WindowAlertWrapperTests`, `ConsoleLogWrapperTests`.
  These call into the JavaScriptKit C ABI; the host
  build compiles the call sites but the runtime path
  is wasm32-only. 7 tests.

Total: 16 native + 7 wasm32 = 23 tests, complementing
the renderer's 31.

## Cross-references

- [`.harness/docs/js-bridge.md`](../../.harness/docs/js-bridge.md)
  — the interop rules this module implements.
- [`.harness/docs/tdd.md`](../../.harness/docs/tdd.md)
  — the red → green contract every change to this
  module follows.
- [`.harness/docs/docc.md`](../../.harness/docs/docc.md)
  — the DocC comment style every public symbol here
  follows.
