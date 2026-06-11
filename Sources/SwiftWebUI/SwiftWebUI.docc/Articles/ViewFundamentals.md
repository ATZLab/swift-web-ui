# State and environment fundamentals

> Status: stub. The full State and Environment article expands
> when the renderer installs an `EnvironmentValues` bag and
> the `View` / `body` requirement lands in 0.2.0. The 0.1.0
> surface is the property-wrapper family documented in
> `.harness/docs/swift-ui-surface.md` §4–§5.

## Overview

The 0.1.0 SwiftWebUI surface ships the property-wrapper
family that a SwiftUI-style view tree is composed from.
Three property wrappers (``State``, ``Binding``,
``Environment``) share a common protocol —
``DynamicProperty`` — that the framework uses to give each
wrapper a chance to re-resolve its dependencies before a
re-render. The leaf views, containers, and modifiers that
surround them land in 0.2.0; this article documents the
shape that ships today.

The full sequence is in `ROADMAP.md`.

## Topics

### Property wrappers

- ``State``
- ``Binding``
- ``Environment``

### Environment

- ``EnvironmentValues``
- ``EnvironmentKey``

### Pre-render hook

- ``DynamicProperty``

## See also

The full per-symbol spec of the 0.1.0 surface lives in
`.harness/docs/swift-ui-surface.md`. The end-to-end State
and Environment walkthrough is in <doc:GettingStarted>.
