# SwiftUI surface — public API shape

> Owner: `swiftwebui-architect` (gate for any public API change).
> Test owner: `swiftwebui-tester`.
> Doc owner: `swiftwebui-docs`.

## Goal

The public API of **SwiftWebUI** is a SwiftUI-compatible declarative UI
DSL for the web, running on `wasm32` and rendered to the DOM via
JavaScriptKit. Where SwiftUI and SwiftWebUI overlap, the names and
shapes match exactly. Where they diverge (web has no UIKit, no
`UIView`, no scene concept, no NavigationStack on the DOM), the
divergence is named and documented in `naming.md`.

## 0.1.0 minimum surface (locked)

This is what ships in the first tag. Anything not on this list is
**not** a 0.1.0 goal.

### Core protocol and combinators

```swift
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }
}

@resultBuilder
public struct ViewBuilder { /* … */ }
```

### Leaf views

- `Text(_ string: String)`
- `Image(_ src: String)`  // web image, not Asset Catalog
- `Color(.red | .blue | …)`  and `.hex(0xRRGGBB)`
- `Spacer()`
- `Divider()`

### Container views

- `VStack { … }`
- `HStack { … }`
- `ZStack { … }`
- `Group { … }`
- `ForEach(_:content:)` (over `Range<Int>` and `Identifiable`)

### Controls (Phase 1 follow-up; spec-only in 0.1.0)

- `Button(_:action:)` — render as `<button>`, delegate `click` to the
  closure.

### State and binding

- `@State` (wrapped property; backed by the runtime node)
- `@Binding` (a derived reference into a `@State` slot)
- `@Environment` and `EnvironmentValues` for cross-tree state.
- (Phase 1+: `@StateObject` if/when an `ObservableObject` shim lands.)

### Modifiers (0.1.0)

All modifiers are **View extension methods** with SwiftUI-style chain
semantics. They live in `Sources/SwiftWebUI/Modifiers/`.

- `.padding(_ insets: EdgeInsets = .init())`
- `.padding()`
- `.padding(_ length: CGFloat)`
- `.frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center)`
- `.background(_:)` (Color, View, HierarchicalShapeStyle)
- `.foregroundStyle(_:)`
- `.font(_:)` (a small `Font` enum in 0.1.0; full font system later)
- `.cornerRadius(_:)` (0.1.0 quick win; `.clipShape` in 0.2.0)
- `.onTapGesture { … }`
- `.opacity(_:)`

### SPI (gated, not 0.1.0-stable)

Anything below is marked `@_spi(Experimental)` until it stabilises:

- `Layout` protocol (custom layout containers)
- `GeometryReader`
- `Shape` and the `Path` 2D API
- `ViewModifier` (we ship modifiers as extensions first; ViewModifier
  lands in 0.2.0 if/when needed)
- Animation primitives

## Renderer model

- 0.1.0: **graph-based** (VDOM-style).
  - `View.body` produces a graph node.
  - The graph is diffed against the previous graph; a patch list is
    applied to the live DOM through JavaScriptKit.
  - The diff algorithm is owned by `swiftwebui-dom-renderer`.
- 0.3.0+ (optional): fine-grained reactivity. **Not a 0.1.0 goal.**

## Disallowed public surface (locked)

- Anything that exposes JavaScriptKit or DOM types in the public API.
- Anything that requires the user to import `JavaScriptKit` directly.
- Any type whose name does not match its SwiftUI counterpart when
  such a counterpart exists.
- Tokamak / Tokamak-era bundler imports or types in the public
  surface.

## Acceptance for 0.1.0 (per surface item)

1. Public symbol exists in `Sources/SwiftWebUI/`.
2. DocC comment is present (`///` + at least one `## Discussion` or
   `## Example` for non-trivial types).
3. At least one swift-testing unit test covers the type.
4. The corresponding snapshot test (if it produces DOM) lives in
   `Tests/SwiftWebUISnapshots/` and the PR history shows
   test-first red → green.
5. The architect has signed off the PR.

## Reference

- Naming rules and the SwiftUI ↔ SwiftWebUI disambiguation table:
  `naming.md`.
- TDD contract for the surface: `tdd.md`.
- DocC contract for the surface: `docc.md`.
