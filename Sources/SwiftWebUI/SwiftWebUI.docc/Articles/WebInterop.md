# Calling JavaScript from SwiftWebUI

> Status: SPI for 0.2.0. The JavaScriptKit interop surface,
> the `JSClosure` retain policy, the Swift ↔ JS value
> converters, the `await` / Promise helpers, and the typed
> external-binding DSL land in 0.2.0 as `@_spi(SwiftWebUI)`
> SPI. The 0.3.0 work that promotes the bridge's user-facing
> pieces to the stable public API is a non-breaking change
> and does not alter this article.

## Overview

SwiftWebUI renders to the DOM through JavaScriptKit, the
project's only allowed JS-bridge dependency. The
`SwiftWebUIBridge` module owns the interop surface: the
`JSClosure` lifetime, the primitive and collection value
converters, the `await` helpers for Promise-returning JS
APIs, and the typed wrappers for the browser globals that
user code calls most often.

The bridge is a thin layer. The shape of the public API the
rest of SwiftWebUI exposes is unchanged by the bridge; the
bridge is the seam that turns a `JSClosure` (the value the
JavaScriptKit runtime hands Swift) into a value with
predictable, value-type lifetime. Every other module in
SwiftWebUI reaches the bridge through `@_spi(SwiftWebUI)`.

The four surface areas of the bridge, in the order a Swift
view reaches for them, are the `JSClosure` retain policy,
the `Values` Swift ↔ JS value converters, the `await`
helper for Promise-returning JS APIs, and the `Bridge`
typed entry points for browser globals. The sections
below cover each in turn.

## The closure retain policy

A `JSClosure` produced by JavaScriptKit is a reference type
the runtime hands to Swift. A Swift view that hands a
`JSClosure` to the DOM must keep a strong reference to it
for as long as the JS side is allowed to call back. The
bridge models that lifetime as a value type.

The **`JSClosureRegistry`** is a per-renderer map from a
positive integer handle to a `JSClosure`. The registry
owns the storage; the renderer hands the handle to the JS
side. When the renderer decides the closure is dead — a
graph-diff pass drops the node, the renderer deinits, the
user navigates away — the renderer calls `release(_:)` on
the handle and the registry frees the entry.

The **`BridgedClosure`** is the value-type wrapper around
a registered handle. The wrapper is `~Copyable` so a
single handle has exactly one owner; the wrapper's deinit
calls the registry's `release(_:)`. A Swift view that
stores a `BridgedClosure` as a property therefore cannot
leak the underlying `JSClosure`: the moment the view is
deallocated, the handle is released.

The release contract is idempotent. A renderer that calls
`release(_:)` twice for the same handle, or that
explicitly releases a handle before the `BridgedClosure`
goes out of scope, sees the second call resolve to a
silent no-op. The `BridgedClosure` deinit observes the
already-empty slot and returns.

The retain contract is locked in
[`.harness/docs/js-bridge.md`](../../../.harness/docs/js-bridge.md)
§"JSClosure retain policy" and exercised by the
`JSClosureRegistryTests` / `BridgedClosureTests` test
suites in `Tests/SwiftWebUIBridgeTests/`.

## Example

```swift
import SwiftWebUIBridge

let registry = JSClosureRegistry()

// 1. Wrap the JS callback. Register the closure and
//    build the value-type handle around the registry
//    entry.
let callback = JSClosure { (args: [JSValue]) in
    let name = Values.string(from: args.first) ?? ""
    Bridge.consoleLog("clicked: \(name)")
}
let bridged = BridgedClosure(
    handle: registry.register(callback),
    closure: callback,
    in: registry
)

// 2. Hand the integer handle to the DOM as a property
//    name. The renderer patches
//    `element.onclick = window.__swiftwebui_bridge[handle]`
//    and the JS side dispatches back into the Swift
//    closure.

// 3. Drop `bridged` (e.g. the owning view deinits) and
//    the registry releases the handle. The JS side
//    can no longer fire the callback.
```

## Value conversion

The **`Values`** namespace is the collection of pure
functions that wrap `JSValue`'s static constructors and
accessors. The namespace exists so renderer and user code
have a single, discoverable place to convert between
Swift and JS values, rather than reaching for the
untyped `value.jsValue` and `value.string` property
accessors scattered across the framework.

Primitive encoders and decoders are available on every
host. The collection encoders and decoders — array and
object — are gated to the wasm32 host because they
allocate a `JSObject` on the JS side, which links the
JavaScriptKit C runtime that is not present on macOS.

| Swift | → `JSValue` | ← `JSValue` |
| --- | --- | --- |
| `String` | `Values.toJSValue(_:)` | `Values.string(from:)` |
| `Bool`   | `Values.toJSValue(_:)` | `Values.bool(from:)` |
| `Int`    | `Values.toJSValue(_:)` | `Values.int(from:)` |
| `Double` | `Values.toJSValue(_:)` | `Values.double(from:)` |
| `[T]`    | `Values.toJSValue(_:)` (wasm32) | `Values.array(of:from:)` (wasm32) |
| `[String: T]` | `Values.toJSValue(_:)` (wasm32) | `Values.object(of:from:)` (wasm32) |

The `Int` encoder routes through `Double` to bypass
JavaScriptKit's `Int.bitWidth == 32` assertion. The
canonical `Int` on `wasm32-unknown-wasi` is 32 bits; the
bridge's host triple is 64 bits, where the assertion
fires on every call. The resulting `JSValue` is a number
that decodes back to the original `Int` for any value
that fits in `Int32` without precision loss.

## Example

```swift
import SwiftWebUIBridge

// Primitive round-trip
let js = Values.toJSValue("hello")
let back = Values.string(from: js)  // Optional("hello")

let count = Values.toJSValue(42)
let n = Values.int(from: count)     // Optional(42)

// Collection round-trip (wasm32 only)
let jsArray = Values.toJSValue([1, 2, 3])
let restored = Values.array(of: Int.self, from: jsArray)
// restored == [1, 2, 3]
```

## Awaiting a Promise

Promise-returning JS APIs are the only category of
JavaScriptKit call that is not synchronous. The bridge
extends `JSObject` with `callAsPromise(_:)` so Swift code
can `await` a Promise-returning function. The helper
internally constructs a
`new Promise((resolve, reject) => { ... })` wrapper
around the synchronous call and resumes the Swift
continuation on resolution or rejection.

The contract is the simpler Promise shape: the JS
function must return a Promise that resolves with the
result. Node-style two-argument callbacks are wrapped
inside the helper. On resolution, the awaited value is
the Promise's resolution. On rejection, the call throws
a `JSException` carrying the rejection value.

The `callAsPromise(_:)` extension is `os(WASI)`-gated.
The implementation calls the JavaScriptKit C runtime,
which is wasi-only. The host (macOS) build links the
type so the test target compiles; the runtime call paths
are `#if os(WASI)`-gated.

## Example

```swift
import SwiftWebUIBridge

// `Bridge.fetch` returns the `fetch` function as a
// `JSObject`. The call site `await`s it with
// `callAsPromise(_:)`, which is an extension on
// `JSObject` defined in `Sources/SwiftWebUIBridge/Promise.swift`.
let urlValue = Values.toJSValue("https://example.com/api")
let response = try await Bridge.fetch.callAsPromise([urlValue])

// `response` is a `JSValue` wrapping the Response
// object. Decode the body as a Swift dictionary.
let body = Values.object(of: String.self, from: response)
```

## External JS API bindings

The **`Bridge`** namespace is the typed surface the
user-facing API exposes for the browser globals that
user code is most likely to call. The list is short —
`alert`, `consoleLog`, `fetch` — and is meant to be the
reference examples for developers who want to bind more.
The bridge's `README.md` documents the binding DSL.

The wrappers look up the underlying JS function on
`JSObject.global` (the browser's `globalThis`). The
bridge owns the conversion between Swift primitives and
`JSValue`. `alert(_:)` and `consoleLog(_:)` take a
`String`; `fetch` is a getter that returns the
`JSObject` for the call site to `await`.

The `alert(_:)` and `consoleLog(_:)` wrappers are
synchronous. The call returns when the JS side has
acknowledged the message. `fetch` is a getter because
the call site composes it with `callAsPromise(_:)` to
`await` the result.

The `Bridge` surface is `os(WASI)`-gated. The wrappers
call into the JavaScriptKit runtime that is wasi-only.

## Example

```swift
import SwiftWebUIBridge

// Synchronous browser calls
Bridge.consoleLog("started")
Bridge.alert("clicked!")

// Promise-returning browser API
let urlValue = Values.toJSValue("https://example.com")
let response = try await Bridge.fetch.callAsPromise([urlValue])
```

## Adding a JS binding

The `Bridge` namespace is the **reference example** for
binding browser globals. The list is intentionally short
— `alert`, `consoleLog`, `fetch` — but the *pattern* is
what user code copies when it needs to bind more. The
DSL is:

1. **Look up the global on `JSObject.global`.** The
   `@dynamicMemberLookup` projection turns
   `JSObject.global.alert` into a typed lookup of the
   `alert` property.
2. **Unwrap the optional `.function`.** The runtime may
   not have an `alert` (a non-browser wasm host); the
   `guard let` makes the call site safe.
3. **Call with `[message.jsValue]`.** The Swift → JS
   conversion is the bridge's job, not the call site's.
4. **Discard the `JSValue` return.** The wrapper's
   return type is `Void`; the JS function's return value
   is not part of the Swift surface.

The full DSL is documented in
[`Sources/SwiftWebUIBridge/README.md`](../../../../SwiftWebUIBridge/README.md);
the test fixture
`Tests/SwiftWebUIBridgeTests/ExternalJSAPIWrapperTests.swift`
is the canonical example for a new binding.

## More

The State and Environment walkthrough is in
<doc:GettingStarted>; the 0.2.0 update adds a
`Calling JavaScript` section that exercises
`Bridge.consoleLog` from a Swift `Button` action. The
property-wrapper family (`State`, `Binding`,
`Environment`) that the bridge retain policy supports is
in <doc:ViewFundamentals>. The bridge SPI is not a
modifier target — see <doc:Modifiers> for the 0.2.0
modifier set.

The module-internal handbook — ownership rules, async
helpers, and the binding DSL — is in
[`Sources/SwiftWebUIBridge/README.md`](../../../../SwiftWebUIBridge/README.md).
The cross-cutting interop rules the bridge module
implements (the `JSClosure` retain policy, the async
model, the external-binding DSL, and the banned
alternatives) are in
[`.harness/docs/js-bridge.md`](../../../.harness/docs/js-bridge.md).
The per-symbol catalog of the 0.2.0 surface, owned by
the architect, is in
[`.harness/docs/swift-ui-surface.md`](../../../.harness/docs/swift-ui-surface.md).
