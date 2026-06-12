// Sources/SwiftWebUI/State/DynamicProperty.swift
//
// The `DynamicProperty` protocol that `@State`, `@Binding`, and
// `@Environment` conform to. It is the hook the framework uses
// to give a property wrapper a chance to re-resolve its
// dependencies (e.g. a parent binding's storage) immediately
// before a view's `body` runs.
//
// In 0.1.0 the framework does not yet call `update()` — there
// is no re-render wiring, so the default no-op implementation
// is the only behaviour the wrappers need. The protocol is
// public (matching SwiftUI) so the three property wrappers can
// publicly conform; the call-site contract is the 0.2.0 work
// that wires re-render notifications, and that does not change
// the public shape of the protocol.
//
// Tightly-coupled companion of `State.swift`, `Binding.swift`,
// and `Environment.swift`; lives next to them per the
// "tightly-coupled companions may share a file" rule in
// `.harness/docs/repo-layout.md` — and is split out here
// because the three conformers all need it, and the file
// documents the protocol's contract in one place.
//
// Owner: swiftwebui-architect. Implementation: stub for 0.1.0 close-out.
//

/// A property wrapper that the framework updates before
/// rendering.
///
/// `DynamicProperty` is the hook SwiftWebUI uses to give a
/// property wrapper a chance to re-resolve its dependencies
/// immediately before the owning view's `body` is read. The
/// framework calls `update()` on every property-wrapper
/// instance declared on a view, in declaration order, before
/// the first read of `body`.
///
/// ## Overview
///
/// The default implementation is a no-op. The SwiftWebUI
/// property wrappers (`State`, `Binding`, `Environment`) rely
/// on the default in 0.1.0 because the framework does not yet
/// drive a re-render. The 0.2.0 work that wires re-render
/// notifications will use `update()` to refresh the
/// per-render bindings a wrapper holds; the public shape of
/// the protocol does not change in that work.
public protocol DynamicProperty {
    /// Refresh the wrapper's per-render state.
    ///
    /// Called by the framework on every property-wrapper
    /// instance declared on a view, in declaration order,
    /// immediately before the first read of `body`. The
    /// default implementation is a no-op.
    mutating func update()
}

extension DynamicProperty {
    /// The default no-op implementation. Wrappers in 0.1.0
    /// inherit this; 0.2.0 wrappers may override it to
    /// re-resolve bindings.
    public mutating func update() {}
}
