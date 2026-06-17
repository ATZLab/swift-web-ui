# SwiftWebUI

SwiftWebUI is a SwiftUI-style declarative UI framework for the web.
It targets `wasm32` and renders to the DOM through JavaScriptKit. The
public surface mirrors SwiftUI's names and shapes wherever the two
overlap, so a view written against SwiftWebUI reads as a SwiftUI view
with a `Web` import swapped in.

## Overview

SwiftWebUI ships as four SwiftPM products. `SwiftWebUI` is the
opinionated, user-facing module; `SwiftWebUIRenderer` owns the graph
and DOM patching; `SwiftWebUIBridge` owns the JavaScriptKit interop
and `JSClosure` lifetimes; `SwiftWebUITooling` carries the dev-server
and build glue. JavaScriptKit is the only allowed JS-bridge
dependency. The Tokamak stack and the Tokamak-era bundler are not
used.

The 0.1.0 release is the **proof of shape**, not the proof of
feature. The shipping public surface in 0.1.0 is the State and
Environment family: the property wrappers that the future
`View` / `Text` / `VStack` surface will plug into, plus the
`EnvironmentValues` bag those wrappers read from. The full
SwiftUI-style catalog — leaf views, containers, modifiers — lands
in 0.2.0 and later; the milestone plan is in `ROADMAP.md`.

The 0.2.0 release adds the `SwiftWebUIBridge` module — the only
JavaScriptKit interop path, with the `JSClosure` lifetime contract
and the `Bridge` typed entry points (see <doc:WebInterop>).

## Topics

### State and data flow

- ``State``
- ``Binding``
- ``Environment``
- ``DynamicProperty``

### Environment

- ``EnvironmentValues``
- ``EnvironmentKey``

### Bridge (SPI)

- <doc:WebInterop>

### Essentials

- <doc:GettingStarted>

### Articles

- <doc:ViewFundamentals>
- <doc:Modifiers>
- <doc:WebInterop>
