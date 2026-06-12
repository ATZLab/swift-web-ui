# Getting started

> Status: walkthrough. The 0.1.0 surface is the State and
> Environment family. The 0.1.0 release is the **proof of
> shape**, not the proof of feature — the `View` / `Text` /
> `VStack` catalog lands in 0.2.0. The full spec lives in
> `.harness/docs/swift-ui-surface.md`; the milestone plan is
> in `ROADMAP.md`.

## What is SwiftWebUI

SwiftWebUI is an open-source, SwiftUI-style declarative UI
framework for the web. It targets `wasm32` and renders to the
DOM through JavaScriptKit. Where SwiftUI and SwiftWebUI
overlap, the names and shapes match exactly; the web shows up
only at the `import` boundary and the `Web.*` extension
points.

The project is the spiritual successor to TokamakUI, which is
officially deprecated along with the Tokamak-era bundler.
SwiftWebUI replaces both with a single, actively-maintained
dependency: JavaScriptKit. The dependency policy is a locked
decision in `AGENTS.md` §5.

The 0.1.0 release ships the property wrappers and environment
bag that a SwiftUI-style view tree is composed from. The leaf
views, containers, and modifiers that surround them are
sequenced in 0.2.0 and later; the full plan is in `ROADMAP.md`.

## A first program

A 0.1.0 SwiftWebUI program declares a value with ``State``,
threads a reference into a child with ``Binding``, and reads
ambient values from ``EnvironmentValues`` through
``Environment``. The three wrappers share a common protocol —
``DynamicProperty`` — that the framework uses to give each
wrapper a chance to re-resolve its dependencies before a
re-render.

```swift
import SwiftWebUI

struct Counter {
    @State var count = 0

    // `count` reads and writes the slot.
    // `$count` hands a Binding<Int> to a child.
    mutating func bump() {
        count += 1
    }
}
```

``State`` is the per-view mutable slot that survives across
re-renders. The initial value is captured at first render;
the projected value is a ``Binding`` that re-targets writes
back at the same storage so a child can take `$count` and
write through it without owning a `State` of its own.

The environment half of 0.1.0:

```swift
import SwiftWebUI

struct ThemeKey: EnvironmentKey {
    static let defaultValue: String = "light"
}

extension EnvironmentValues {
    var theme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

struct Themed {
    @Environment(\.theme) var theme
    // theme == "light" until a renderer installs a bag
    // that overrides the key.
}
```

``EnvironmentValues`` is the propagated collection of
environment values. ``EnvironmentKey`` is the recipe for
declaring a new key. ``Environment`` is the property wrapper
that reads the key on the current bag. Concrete keys
(`.colorScheme`, `.locale`, …) are 0.2.0 work; the
``EnvironmentKey`` protocol and the `EnvironmentValues`
subscript API are in the public API now so adding a key
later is non-breaking.

## Where to go next

- ``EnvironmentValues`` — the propagated collection of
  environment values.
- ``EnvironmentKey`` — the recipe for declaring a new
  environment key.
- ``State`` — a per-view mutable value.
- ``Binding`` — a two-way reference into a `State` slot.
- ``Environment`` — a read-only view of an
  ``EnvironmentValues`` key.
- ``DynamicProperty`` — the protocol the wrappers conform
  to.
- `.harness/docs/swift-ui-surface.md` — the per-symbol
  catalog of the 0.1.0 surface, owned by the architect.
- `ROADMAP.md` — the 0.2.0 milestone plan and what each
  release unlocks.
