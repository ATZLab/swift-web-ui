# Modifiers

> Status: stub. The 0.1.0 surface ships no modifiers. The
> 0.2.0 set will mirror SwiftUI's modifier catalog —
> `.padding(_:)`, `.padding()`,
> `.foregroundStyle(_:)`, `.background(_:)`,
> `.frame(width:height:alignment:)`, `.font(_:)`,
> `.opacity(_:)`, `.onAppear(perform:)` — defined as
> `View` extension methods that return `some View`. The
> per-symbol spec is in
> `.harness/docs/swift-ui-surface.md` §6.

## Overview

Modifiers in SwiftWebUI are `View` extension methods with
SwiftUI-style chain semantics. Each modifier returns a new
view that wraps the receiver and applies the requested
effect; the chain reads left-to-right and is the only
ordering that affects the result.

The 0.1.0 release ships no `View` protocol, so no
`View`-extension modifiers exist yet. The renderer is
graph-based (VDOM-style); modifiers that need a custom
render path — for example, animation, transitions, or
`ViewModifier` bundles — land in 0.2.0 and later. The
full sequence is in `ROADMAP.md`.

## The 0.2.0 modifier set

Layout and insets: `.padding(_:)`, `.padding()`,
`.frame(width:height:alignment:)`. Color and typography:
`.foregroundStyle(_:)`, `.background(_:)`, `.font(_:)`,
`.opacity(_:)`. Interaction and appearance:
`.onAppear(perform:)`.

## See also

The full per-symbol spec of the 0.2.0 modifier catalog
lives in `.harness/docs/swift-ui-surface.md` §6. The
end-to-end State and Environment walkthrough is in
<doc:GettingStarted>.
