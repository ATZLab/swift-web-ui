# View fundamentals

> Status: stub. The full article expands when the 0.1.0 surface
> lands in `Sources/SwiftWebUI/`.

## Overview

Every SwiftWebUI screen is a `View`. A `View` describes a node in
the rendered DOM tree; the runtime evaluates the view's `body`
on each pass and the renderer patches the DOM to match.

`body` is annotated with `@ViewBuilder`, a result builder that
turns a block of declarations into a single returned value. The
`some View` opaque return type keeps the implementation hidden
while preserving identity across renders, which the diff relies on
to avoid re-creating DOM nodes.

A screen typically composes existing views rather than subclassing
them: a `VStack` of a `Text` and an `Image` is a new view, not a
new type. Composition is the primary extension point; subclassing
is not used.

## Topics

- ``View`` — the protocol every UI node conforms to.
- ``ViewBuilder`` — the result builder that fuses a block of
  declarations into a single `body` value.
- ``View/body`` — the `@ViewBuilder` property that describes a
  view's content.
- ``EmptyView`` — a view that renders nothing.
- ``AnyView`` — a type-erased view, used as an escape hatch when
  a single concrete return type is impractical.

## See also

- <doc:GettingStarted> — the end-to-end walkthrough.
- <doc:Modifiers> — chaining modifiers and the 0.1.0 modifier
  set.
- `.harness/docs/swift-ui-surface.md` — the per-symbol spec
  owned by the architect.
