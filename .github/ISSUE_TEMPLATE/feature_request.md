---
name: Feature request
about: Propose a new SwiftWebUI type, modifier, or behaviour.
title: "[feature] "
labels: ["enhancement", "needs-triage"]
assignees: []
---

## Summary

One or two sentences. What is missing, and what user-visible behaviour
do you want to be true after it lands?

## Target version

Which release is this targeting? (Pick one. The full milestone plan is
in [`ROADMAP.md`](../../ROADMAP.md).)

- [ ] **0.1.0** — MVP "Hello, web in Swift" (Text, VStack, HStack,
      ZStack, Group, ForEach over `Range<Int>`, Color, Spacer, Divider,
      the 0.1.0 modifier set, `@State` re-render).
- [ ] **0.2.0** — Interactivity (Button, onTapGesture, GeometryReader
      SPI, Layout SPI, Path/Shape SPI, ViewModifier).
- [ ] **0.3.0** — Animation & a11y (`.animation(_:value:)`,
      `withAnimation { }`, accessibility traits, ARIA mapping).
- [ ] **0.4.0** — Layout & shapes (GeometryReader public, Layout public,
      Path / Shape public).
- [ ] **0.5.0** — Lists, navigation, forms (List, NavigationStack,
      NavigationLink, Form, Section, Picker, Toggle, Slider, Stepper).
- [ ] **SPI** — should land under `@_spi(Experimental)` first, then
      graduate.
- [ ] **Out of scope** — the roadmap in
      [`ROADMAP.md`](../../ROADMAP.md) explicitly excludes this (e.g.
      SSR, native iOS renderer, React interop). Open a Discussion
      instead.

## SwiftUI overlap

If this matches a SwiftUI type, modifier, or shape, name the SwiftUI
counterpart and link the Apple docs. SwiftWebUI matches SwiftUI names
exactly where they overlap — see
[`.harness/docs/naming.md`](../../.harness/docs/naming.md).

## Proposed API

A short usage example, in the SwiftUI style:

```swift
// What the call site should look like.
```

## Behind the scenes (optional)

If you have a sense of the renderer / bridge work it implies, link
the relevant topic file:

- Renderer (`_Graph`, diff/patch) —
  [`.harness/docs/swift-ui-surface.md`](../../.harness/docs/swift-ui-surface.md)
- JavaScriptKit interop (`JSClosure`, async) —
  [`.harness/docs/js-bridge.md`](../../.harness/docs/js-bridge.md)

## Test that proves it

TDD is mandatory — see
[`.harness/docs/tdd.md`](../../.harness/docs/tdd.md). Sketch the
failing test you would write first:

```swift
@Test
func ...() {
    // ...
}
```

## DocC

A `///` DocC comment with `## Discussion` and `## Example` is required
on every public symbol — see
[`.harness/docs/docc.md`](../../.harness/docs/docc.md). A draft
DocC comment for the new symbol is welcome but not required to open
the issue.
