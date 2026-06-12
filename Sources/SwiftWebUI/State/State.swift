// Sources/SwiftWebUI/State/State.swift
//
// SwiftWebUI's `@State` property wrapper. The signature mirrors
// SwiftUI's `@State` (see `.harness/docs/swift-ui-surface.md` §4).
//
// In 0.1.0 the setter is wired to the renderer's
// `_RendererReRenderHook` (see
// `Sources/SwiftWebUIRenderer/RendererReRenderHook.swift`):
// every write to `wrappedValue` updates the per-instance
// storage and triggers a single, full re-render of the root
// view tree. The 0.2.0 work will replace this with a
// subtree-scoped, batched re-render driven by
// `DynamicProperty.update()`. The public shape of the
// wrapper does not change between 0.1.0 and 0.2.0.
//
// Owner: swiftwebui-architect (public surface, signature).
// The re-render seam itself is owned by
// `swiftwebui-dom-renderer` (Phase C2 of the 0.1.0
// close-out). The architect retains the surface; the
// renderer owns the notification path.
//

@_spi(SwiftWebUI) import SwiftWebUIRenderer


/// A value owned by the view.
///
/// `State` is the per-view mutable slot that survives across
/// re-renders of the view that declared it. The initial value is
/// captured at first render. Reading `wrappedValue` returns the
/// current value; writing it stores the new value in the same
/// per-instance storage so a subsequent read in the same view body
/// returns the new value.
///
/// ## Overview
///
/// In SwiftWebUI 0.1.0 mutating `wrappedValue` updates the backing
/// storage and **triggers a single, full re-render of the root
/// view tree**. The 0.2.0 work will replace this with a
/// subtree-scoped, batched re-render that only walks the views
/// that observed the change. The public shape (`State<Value>`,
/// `wrappedValue`, `projectedValue`) is identical to SwiftUI's
/// `@State`; the re-render granularity is the only difference, and
/// it is a renderer concern, not a surface concern.
///
/// The `projectedValue` is a `Binding<Value>` that re-targets
/// mutations back at the same storage, so a child view can take
/// `$count` and write through it without owning a `State` of its
/// own.
///
/// ## Example
///
/// ```swift
/// struct Counter: View {
///     @State var count = 0
///     var body: some View {
///         Text("count = \(count)")
///     }
/// }
/// ```
@propertyWrapper
public struct State<Value>: DynamicProperty {
    /// The box that holds the current value across re-renders.
    ///
    /// The reference type is required: the wrapper itself is value
    /// type and gets re-instantiated on every render, so a class
    /// inside it is what preserves the slot's identity.
    @_spi(SwiftWebUI)
    public final class Storage {
        /// The current value.
        public var value: Value
        /// Creates the storage seeded with the initial value.
        public init(_ value: Value) { self.value = value }
    }

    /// The per-instance storage. `nonmutating` so callers do not
    /// need `var` on the wrapper to read.
    @_spi(SwiftWebUI)
    public var storage: Storage

    /// Creates a `State` with the given initial value.
    ///
    /// Called automatically by the property-wrapper synthesis
    /// when a default is given (e.g. `@State var count = 0`).
    /// The same call shape is what `@State var count: Int` would
    /// receive from `_State.init(wrappedValue:)`.
    public init(wrappedValue: Value) {
        self.storage = Storage(wrappedValue)
    }

    /// The current value. Reading it returns the value stored by
    /// the most recent write to `wrappedValue` (or the initial
    /// value if nothing has been written yet).
    public var wrappedValue: Value {
        get {
            // Reading is a no-op (no schedule). The
            // 0.2.0 contract is that only writes schedule.
            storage.value
        }
        nonmutating set {
            // 0.2.0 contract (`.harness/docs/swift-ui-surface.md`
            // §4 + §8 + §10): mutating `wrappedValue` writes
            // the new value to the storage and schedules a
            // `Task { @MainActor in ... }` re-render via
            // `_ReRenderScheduler.schedule(_:)`. The
            // scheduler collapses N synchronous writes in the
            // same turn into a single commit; the commit
            // fires on the main actor regardless of the
            // calling actor.
            //
            // The 0.1.0 root-tree re-render is **also**
            // invoked for the 0.1.0 → 0.2.0 transition
            // window. The snapshot test target asserts the
            // hook fires once per write (the 0.1.0 contract);
            // the renderer test target asserts the scheduler
            // fires one commit per microtask-batched turn
            // (the 0.2.0 contract). The hook is
            // `@available(*, deprecated)` and is removed in
            // 0.3.0; the 0.2.0 line is the new contract.
            storage.value = newValue
            _ReRenderScheduler.schedule(
                _GraphIdentity("State<\(ObjectIdentifier(storage).hashValue)>")
            )
            // The deprecated 0.1.0 root-tree hook fires too.
            // See `RendererReRenderHook.swift` for the
            // deprecation note.
            _RendererReRenderHook.trigger()
        }
    }

    /// A `Binding<Value>` that re-targets writes back at the
    /// same storage. Use the `$` prefix in a view body to pass
    /// the binding to a child.
    public var projectedValue: Binding<Value> {
        // The binding holds a strong reference to the storage,
        // not to the `State` wrapper itself, so the slot survives
        // even if the parent view's `State` is re-instantiated.
        //
        // The setter goes through `wrappedValue =` (not
        // `storage.value =`) so the 0.2.0 chain holds:
        //
        //   Binding.wrappedValue = v
        //     → Binding.setter(v)
        //       → State.wrappedValue = v
        //         → _ReRenderScheduler.schedule(_:)
        //
        // A direct `storage.value = v` write would skip the
        // scheduler and break the per-key subtree
        // re-render contract (the 0.2.0 chain tests
        // assert the scheduler fires on a binding write).
        Binding(
            get: { self.storage.value },
            set: { newValue in self.wrappedValue = newValue }
        )
    }
}
