# Modifiers

> Status: stub. The full article expands when the 0.1.0 surface
> lands in `Sources/SwiftWebUI/`.

## Overview

Modifiers in SwiftWebUI are `View` extension methods with
SwiftUI-style chain semantics. Each modifier returns a new view
that wraps the receiver and applies the requested effect; the
chain reads left-to-right and is the only ordering that affects
the result.

The 0.1.0 set covers layout, color, typography, and the most
common tap and appearance callbacks. Modifiers that need a custom
render path — for example, animation, transitions, or
`ViewModifier` bundles — land in 0.2.0 and later. The full
sequence is in `ROADMAP.md`.

## The 0.1.0 modifier set

Layout and insets:

- ``View/padding(_:)`` — applies a uniform inset.
- ``View/padding()`` — applies a system-default inset.
- ``View/frame(width:height:alignment:)`` — proposes a width,
  height, and alignment for a view.

Color and typography:

- ``View/foregroundStyle(_:)`` — paints a view's content with
  the given color or shape style.
- ``View/background(_:)`` — paints a backing surface behind a
  view.
- ``View/font(_:)`` — applies a font to text content.
- ``View/opacity(_:)`` — sets the view's opacity.
- ``View/cornerRadius(_:)`` — rounds a view's corners.

Interaction and appearance:

- ``View/onTapGesture(perform:)`` — attaches a tap handler to a
  view.
- ``View/onAppear(perform:)`` — runs a closure when the view
  first appears in the rendered tree.

## See also

- <doc:ViewFundamentals> — the `View` protocol and `body`.
- <doc:GettingStarted> — the end-to-end walkthrough.
- `.harness/docs/swift-ui-surface.md` — the per-symbol spec
  owned by the architect.
