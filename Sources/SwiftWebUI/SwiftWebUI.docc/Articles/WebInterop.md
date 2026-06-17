# Web interop

> Status: stable for 0.2.0. The JavaScriptKit interop surface,
> the `JSClosure` retain policy, the Swift ↔ JS value
> converters, the `await` / Promise helpers, and the typed
> external-binding DSL land in 0.2.0 as `@_spi(SwiftWebUI)` SPI
> in the `SwiftWebUIBridge` module. The 0.3.0 work that promotes
> the bridge's user-facing pieces to the stable public API is a
> non-breaking change and does not alter this article.

## Overview

SwiftWebUI renders to the DOM through JavaScriptKit, the
project's only allowed JS-bridge dependency. The
`SwiftWebUIBridge` module owns the interop surface: the
`JSClosure` lifetime, the primitive and collection value
converters, the `await` helpers for Promise-returning JS
APIs, and the typed wrappers for the browser globals that
user code calls most often.

The bridge is a thin layer. The shape of the public API
the rest of SwiftWebUI exposes is unchanged by the bridge;
the bridge is the seam that turns a `JSClosure` (the
value the JavaScriptKit runtime hands Swift) into a value
with predictable, value-type lifetime. Every other module
in SwiftWebUI reaches the bridge through the
`@_spi(SwiftWebUI)` import.

## Topics

- <doc:GettingStarted>
- <doc:ViewFundamentals>
- <doc:Modifiers>

## The closure retain policy

A `JSClosure` produced by JavaScriptKit is a reference
type the runtime hands to Swift. A Swift view that hands a
`JSClosure` to the DOM must keep a strong reference to it
for as long as the JS side is allowed to call back. The
bridge models that lifetime as a value type.

`JSClosureRegistry` is a per-renderer map from a positive
integer handle to a `JSClosure`. The registry owns the
storage; the renderer hands the handle to the JS side.
When the renderer decides the closure is dead — a
graph-diff pass drops the node, the renderer deinits, the
user navigates away — the renderer calls `release(_:)`
on the handle and the registry frees the entry.

`BridgedClosure` is the value-type wrapper around a
registered handle. The wrapper is `~Copyable` so a single
handle has exactly one owner; the wrapper's deinit calls
the registry's `release(_:)`. A Swift view that stores a
`BridgedClosure` as a property therefore cannot leak the
underlying `JSClosure`: the moment the view is
deallocated, the handle is released.

The release contract is idempotent. A renderer that calls
`release(_:)` twice for the same handle, or that
explicitly releases a handle before the `BridgedClosure`
goes out of scope, sees the second call resolve to a
silent no-op. The `BridgedClosure` deinit observes the
already-empty slot and returns.

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

`Values` is the namespace of pure functions that wrap
`JSValue`'s static constructors and accessors. The
namespace exists so renderer and user code have a single,
discoverable place to convert between Swift and JS
values, rather than reaching for the untyped
`value.jsValue` and `value.string` property accessors
scattered across the framework.

Primitive encoders and decoders are available on every
host. The collection encoders and decoders — array and
object — are gated to the wasm32 host because they
allocate a `JSObject` on the JS side, which links the
JavaScriptKit C runtime that is not present on macOS.

The `Int` encoder routes through `Double` to bypass
JavaScriptKit's `Int.bitWidth == 32` assertion. The
canonical `Int` on `wasm32-unknown-wasi` is 32 bits; the
bridge's host triple is 64 bits, where the assertion
fires on every call. The resulting `JSValue` is a number
that decodes back to the original `Int` for any value
that fits in `Int32` without precision loss.

| Swift | → `JSValue` | ← `JSValue` |
| --- | --- | --- |
| `String` | `Values.toJSValue(_:)` | `Values.string(from:)` |
| `Bool` | `Values.toJSValue(_:)` | `Values.bool(from:)` |
| `Int` | `Values.toJSValue(_:)` | `Values.int(from:)` |
| `Double` | `Values.toJSValue(_:)` | `Values.double(from:)` |
| `[T]` | `Values.toJSValue(_:)` (wasm32) | `Values.array(of:from:)` (wasm32) |
| `[String: T]` | `Values.toJSValue(_:)` (wasm32) | `Values.object(of:from:)` (wasm32) |

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

## Async helpers

Promise-returning JS APIs are the only category of
JavaScriptKit call that is not synchronous. The bridge
exposes a single async helper to `await` such calls:
`JSObject.callAsPromise(_:)`. The helper takes the
target's argument list, internally constructs a
`new Promise((resolve, reject) => { ... })` wrapper
around the synchronous call, and resumes the Swift
continuation on resolution or rejection.

The contract is the simpler Promise shape: the JS
function must return a Promise that resolves with the
result. Node-style two-argument callbacks are wrapped
inside the helper. On resolution, the awaited value is
the Promise's resolution. On rejection, the call throws
a `JSException` carrying the rejection value.

## Example

```swift
import SwiftWebUIBridge

// `fetch` is exposed by Bridge.fetch as a JSObject
// (the wrapper returns the function as a JSObject
// because fetch is one of many Promise-returning
// browser APIs; the call site usually wants to await
// multiple of them concurrently).
let urlValue = Values.toJSValue("https://example.com/api")
let response = try await Bridge.fetch.function!(
    arguments: [urlValue]
).callAsPromise([])

// `response` is a JSValue wrapping the Response
// object. Decode the body as a Swift dictionary.
let body = Values.object(of: String.self, from: response)
```

## External JS API bindings

`Bridge` is the typed surface the user-facing API exposes
for the browser globals that user code is most likely to
call. The list is short — `alert`, `consoleLog`, `fetch`
— and is meant to be the reference examples for
developers who want to bind more. The bridge's
`README.md` documents the binding DSL.

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

## Example

```swift
import SwiftWebUIBridge

// Synchronous browser calls
Bridge.consoleLog("started")
Bridge.alert("clicked!")

// Promise-returning browser API
let urlValue = Values.toJSValue("https://example.com")
let response = try await Bridge.fetch.function!(
    arguments: [urlValue]
).callAsPromise([])
```

## See also

The <doc:GettingStarted> article walks through the 0.1.0
State and Environment family; the 0.2.0 update adds a
`Build a JS interop call` section that exercises
`BridgedClosure` retain and `Values` round-trip. The
property-wrapper family (`State`, `Binding`,
`Environment`) that the bridge retain policy supports is
documented in <doc:ViewFundamentals>. The 0.2.0 modifier
set lives in <doc:Modifiers>; the bridge SPI is not a
modifier target. The cross-cutting interop rules the
bridge module implements (the `JSClosure` retain policy,
the async model, the external-binding DSL, and the
banned alternatives) are in
`.harness/docs/js-bridge.md`. The per-symbol catalog of
the 0.2.0 surface lives in
`.harness/docs/swift-ui-surface.md`, owned by the
architect.
