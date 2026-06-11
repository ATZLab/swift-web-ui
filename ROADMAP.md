# SwiftWebUI — Roadmap

> Owner: `swiftwebui-steward` (release shape), `swiftwebui-architect` (scope
> shape). The roadmap is the **first thing a new contributor or user
> reads after the README** — it should be honest, ordered, and boring.
>
> See also: `AGENTS.md` (locked decisions), `.harness/docs/release.md`
> (release mechanics), `.harness/docs/swift-ui-surface.md` (0.1.0 surface).

## North star

> **A Swift engineer can read a SwiftWebUI file and not realize they're
> writing for the web.**

That means: SwiftUI's exact names where they apply, the same modifier
chains, the same state model, the same environment propagation. The web
shows up only at the `import` boundary and the `Web.*` extension points.

## Strategy: MVP-first, increment by increment

We do **not** ship "0.1.0 of everything" and "0.2.0 of everything" in
two big bangs. Each release is a **thin vertical slice** that is useful
on its own, fully tested, fully documented, and lives on the SwiftUI
side of the line. Underlying systems (renderer, bridge, tooling) grow
**just enough** to support the next slice — never ahead of it.

The shape of every release:

1. Pick the smallest user-visible behavior we want to be true.
2. Spec the SwiftUI surface for it (architect + docs).
3. Write the red tests first (tester).
4. Make the renderer / bridge do the minimum to pass (dom-renderer /
   bridge).
5. Wire it into a runnable `web/` example (tooling).
6. Document it (docs).
7. Tag a minor.

Anything that doesn't unblock the next slice goes in `@_spi(Experimental)`
or stays in a feature branch.

## Roadmap at a glance

```
v0.1.0  ▓▓▓▓░░░░░░░░░░░░░░░░  MVP — "Hello, web in Swift"
v0.2.0  ░░░░▓▓▓▓░░░░░░░░░░░░  Interactivity
v0.3.0  ░░░░░░░░▓▓▓▓░░░░░░░░  Animation & a11y
v0.4.0  ░░░░░░░░░░░░▓▓▓▓░░░░  Layout & shapes
v0.5.0  ░░░░░░░░░░░░░░░░▓▓▓▓  Lists, navigation, forms
v1.0.0  ░░░░░░░░░░░░░░░░░░▓▓  API freeze
```

Each row is a **named milestone**, not a date. We tag when CI is green
and the stop conditions are met — not on a calendar.

---

## v0.1.0 — MVP: "Hello, web in Swift"

> **What you can do after 0.1.0**: write `Text("hi")` in Swift, run a
> one-shot script, and see `<div>hi</div>` in a browser. Stack, group,
> and the bare state model are there. No interaction yet, no animation,
> no shape, no list. That is fine — 0.1.0 is the **proof of shape**,
> not the proof of feature.

### User-visible capability

```swift
import SwiftWebUI

struct Hello: View {
    var body: some View {
        VStack {
            Text("Hello, web.")
            Text("From Swift.")
                .foregroundStyle(.secondary)
            @State var count = 0
            Text("count = \(count)")  // static render only in 0.1.0
        }
    }
}
```

…renders to a VStack of two `<div>`s and one re-render of the count.
`@State` exists in the type system but the *re-render-on-change*
behavior is the very first thing 0.2.0 unlocks.

### Surface (architect-owned, full list in `docs/swift-ui-surface.md`)

- `View`, `body`, `some View`, `ViewBuilder`
- `Text`, `VStack`, `HStack`, `ZStack`, `Group`
- `Color`, `Spacer`, `Divider`
- `ForEach` (over `Range<Int>` only)
- `EmptyView`, `AnyView` (escape hatch)
- Modifier set: `.padding()`, `.foregroundStyle(_:)`, `.background(_:)`,
  `.frame(width:height:alignment:)`, `.font(_:)`, `.opacity(_:)`,
  `.onAppear { }` (callback, but no re-render wiring in 0.1.0)
- State types exist: `@State`, `@Binding`, `@Environment` — but only
  `@State` is wired to a (single, root) re-render in 0.1.0.

### Behind the scenes (kept as small as possible)

- **Renderer**: graph (`_Graph`, `_ViewOutputs`), single-pass diff,
  sequential DOM patch. No fine-grained reactivity. No batching yet.
- **Bridge**: JavaScriptKit only. `JSClosure` registry with
  retain-cycle test. One external JS call (`window.alert`) as a
  proof-of-shape.
- **Tooling**: `Package.swift` with `wasm32-unknown-wasi` + native
  matrix. `./scripts/serve.sh` builds, bundles, serves. README has
  a 5-line quickstart.
- **Tests**: `swift test` for the graph + diff. Playwright smoke for
  one rendered `Text("hi")` → `<div>hi</div>`.
- **Docs**: DocC catalog with `GettingStarted`, `ViewFundamentals`,
  `Modifiers`. No tutorial beyond "Hello, web".

### Stop conditions for 0.1.0

- [ ] `swift test` green on the matrix.
- [ ] `swift build --triple wasm32-unknown-wasi` produces a binary.
- [ ] `./scripts/serve.sh` serves a working "Hello, web" example.
- [ ] Playwright smoke passes in CI.
- [ ] `swift package generate-documentation` 0 warnings.
- [ ] README, CONTRIBUTING, CoC, LICENSE exist.
- [ ] `CHANGELOG.md` and `ReleaseNotes.md` (0.1.0) exist.
- [ ] All public surface symbols have a DocC comment and a test.

---

## v0.2.0 — Interactivity

> **What unlocks**: state changes re-render. Buttons tap. Gestures fire.

### User-visible capability

- `@State` and `@Binding` actually re-render on `wrappedValue` change.
- `Button` action.
- `onTapGesture { }` on any view.
- `TextField` (one-line, single-line only).
- Re-render batching (one render per microtask, not per setter).

### Behind the scenes

- **Renderer**: microtask-batched patch path. Identity-stable `_Graph`
  nodes (so we don't re-create DOM on every state change).
- **Bridge**: DOM event listener registry bound to `JSClosure`s with
  documented lifetime.
- **Tests**: gesture / state-change snapshot tests.

### Stop conditions

- [ ] Toggling a `@State` Bool re-renders exactly the affected subtree.
- [ ] `Button` tap fires the action and updates the visible label.
- [ ] `TextField` typing updates `@State` and the view.
- [ ] `onTapGesture` fires on tap.
- [ ] `JSClosure` retain-cycle test still passes (no regression).

---

## v0.3.0 — Animation & a11y

> **What unlocks**: things move smoothly, and screen readers can see
> the view tree.

### User-visible capability

- `.animation(_:value:)` modifier.
- `withAnimation { }` block.
- Implicit animations on state changes (the ones SwiftUI handles
  implicitly).
- `accessibilityLabel(_:)`, `accessibilityValue(_:)`,
  `accessibilityAddTraits(_:)`.
- ARIA live region mapping.

### Behind the scenes

- **Renderer**: frame-driven diff loop, RAF batching.
- **Bridge**: a11y hooks into the DOM (we map to ARIA; we don't ship a
  full a11y tree — that's a 0.5.0+ problem).
- **Tests**: snapshot tests gated on stable time (fake clock).

### Stop conditions

- [ ] `.animation(.default, value: x)` animates a value change.
- [ ] `withAnimation { x.toggle() }` animates.
- [ ] VoiceOver reads `accessibilityLabel`.
- [ ] Lighthouse a11y score ≥ 95 on the example app.

---

## v0.4.0 — Layout & shapes

> **What unlocks**: GeometryReader (SPI), `ViewModifier`, `Layout`
> protocol (SPI), `Path` / `Shape` (SPI).

### User-visible capability

- `GeometryReader` (SPI at first, public in 0.5.0).
- `ViewModifier` for custom reusable modifier bundles.
- `Layout` protocol (SPI).
- `Path` and the shape protocols (SPI).

### Stop conditions

- [ ] A custom `ViewModifier` written against the public API works.
- [ ] A `Layout` (SPI) can compute a `ProposedViewSize` and place
      children.
- [ ] A `Rectangle` (default shape) renders.

---

## v0.5.0 — Lists, navigation, forms

> **What unlocks**: scrolling lists, basic forms, in-app navigation.

- `List`, `NavigationStack`, `NavigationLink`.
- `Form`, `Section`.
- Multi-line `TextEditor`.
- Picker, Toggle, Slider, Stepper.

---

## v1.0.0 — API freeze

> **What unlocks**: stable. The surface in `docs/swift-ui-surface.md`
> is final. No more `@_spi` in the stable product.

- All `@_spi` in `Sources/SwiftWebUI/**` is either promoted to public
  or removed.
- Every modifier has a DocC comment and a test.
- All SwiftUI-overlap names match exactly (no aliases left).
- A migration guide is published for the 0.5 → 1.0 transition.

---

## What is **not** on this roadmap (and why)

- **Server-side rendering (SSR).** SwiftWebUI is a client-side
  declarative UI framework. SSR is a different shape (Tokamak
  considered it; we explicitly do not).
- **Native iOS / macOS renderers.** SwiftWebUI is web-only. SwiftUI
  already covers native. The renderer-target abstraction exists
  *only* to make a future native renderer possible, not to ship one.
- **React interop.** `JSClosure` can call into any JS, but we won't
  ship a React-binding package. If the community wants one, it can
  live in a separate `SwiftWebUIReact` (out of core).
- **Native bindings to specific JS frameworks.** Out of core.

## How to read this document

- The **stop conditions** for each version are what the team is
  measured against — not dates, not features in a vacuum.
- A release can be split into multiple minors if the surface turns
  out to be larger than expected (e.g. 0.2.1 for the state batching
  before 0.3 ships animations).
- A release can be *cut* (released as-is, with the rest pushed to
  0.x+1) if the stop conditions are met and the user-visible story
  is coherent.
- Anything not on the roadmap is `@_spi(Experimental)` until it earns
  a row.
