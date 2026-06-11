# SwiftWebUI

SwiftWebUI is a SwiftUI-style declarative UI framework for the web.
It targets `wasm32` and renders to the DOM through JavaScriptKit. The
public surface mirrors SwiftUI's names and shapes wherever the two
overlap, so a view written against SwiftWebUI reads as a SwiftUI view
with a `Web` import swapped in.

## Overview

SwiftWebUI ships as four SwiftPM products. `SwiftWebUI` is the
opinionated, user-facing module; `SwiftWebUIRenderer` owns the
graph and DOM patching; `SwiftWebUIBridge` owns the JavaScriptKit
interop and `JSClosure` lifetimes; `SwiftWebUITooling` carries the
dev-server and build glue. JavaScriptKit is the only allowed
JS-bridge dependency. The Tokamak stack and the Tokamak-era bundler
are not used.

The 0.1.0 release is the proof of shape: a `Text` inside a `VStack`
inside a `View` compiles, runs in a browser, and renders to the DOM
through a single-pass graph diff. Interactivity, animation, lists,
and navigation are sequenced in 0.2.0 and later; the full plan is in
`ROADMAP.md`.

## Topics

### Essentials

- <doc:GettingStarted> — install, first `Text("Hello, web")`, the
  one-screen walkthrough.
- ``View`` — the protocol every UI node conforms to.
- ``ViewBuilder`` — the result builder that turns a block of
  declarations into a single `body`.
- ``View/body`` — the `@ViewBuilder` property that describes a
  view's content.

### Views

- ``Text`` — a single line of read-only text.
- ``Image`` — a web image referenced by URL.
- ``Color`` — a flat color, named or hex.
- ``Spacer`` — an expanding, transparent layout slot.
- ``Divider`` — a thin horizontal or vertical rule.
- ``VStack`` — a container that lays out children in a vertical
  line.
- ``HStack`` — a container that lays out children in a horizontal
  line.
- ``ZStack`` — a container that overlays children back-to-front.
- ``Group`` — a type-erasing container that returns one child
  unchanged.
- ``ForEach`` — a container that produces one child per element in
  a range or `Identifiable` collection.
- ``EmptyView`` — a view that renders nothing.
- ``AnyView`` — a type-erased view, used as an escape hatch.

### Modifiers

- ``View/padding(_:)`` — applies a uniform inset.
- ``View/padding()`` — applies a system-default inset.
- ``View/frame(width:height:alignment:)`` — proposes a width,
  height, and alignment for a view.
- ``View/foregroundStyle(_:)`` — paints a view's content with the
  given color or shape style.
- ``View/background(_:)`` — paints a backing surface behind a
  view.
- ``View/font(_:)`` — applies a font to text content.
- ``View/opacity(_:)`` — sets the view's opacity.
- ``View/onTapGesture(perform:)`` — attaches a tap handler to a
  view.
- ``View/onAppear(perform:)`` — runs a closure when the view first
  appears in the rendered tree.
- ``View/cornerRadius(_:)`` — rounds a view's corners.

### State and data flow

- ``State`` — a per-view mutable value backed by the runtime
  storage.
- ``Binding`` — a two-way reference into a `State` slot.
- ``Environment`` — a read-only view of an
  ``EnvironmentValues`` key.
- ``EnvironmentValues`` — the propagated collection of
  environment values.

### Tutorials

- <doc:Getting-Started-Tutorial> — three steps from `swift package`
  to `Text("Hello, web")` in a browser.

### Articles

- <doc:GettingStarted> — the long-form walkthrough.
- <doc:ViewFundamentals> — the `View` protocol and the `body`
  requirement.
- <doc:Modifiers> — chaining modifiers and the 0.1.0 modifier set.

## See also

- `ROADMAP.md` — the milestone plan and the 0.1.0 stop conditions.
- `.harness/docs/swift-ui-surface.md` — the per-symbol spec
  owned by the architect.
- `.harness/docs/docc.md` — the DocC contract this catalog
  follows.
