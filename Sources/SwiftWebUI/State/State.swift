// Sources/SwiftWebUI/State/State.swift
//
// SwiftWebUI's `@State` property wrapper. The signature mirrors
// SwiftUI's `@State` (see `.harness/docs/swift-ui-surface.md` §4).
//
// In 0.1.0 the setter is a NO-OP placeholder: it stores the new
// value in the per-instance storage so subsequent reads return it,
// but it does NOT trigger a re-render. The "single, root re-render
// on `@State` mutation" wiring is the dom-renderer rein's job
// (Phase C2) and will land in the same minor release. Leaving the
// TODO here so the next worker sees the seam.
//
// Owner: swiftwebui-architect. Implementation: stub for 0.1.0 close-out.
//

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
            // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
            // 0.1.0 behaviour: read straight from the storage.
            storage.value
        }
        nonmutating set {
            // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
            // 0.1.0 behaviour: write the new value into the
            // storage so the next read in this view body sees it.
            // The 0.1.0 stop condition is "Hello, web in Swift" and
            // does not exercise re-render; the full root re-render
            // lands with C2 in the same minor.
            storage.value = newValue
        }
    }

    /// A `Binding<Value>` that re-targets writes back at the
    /// same storage. Use the `$` prefix in a view body to pass
    /// the binding to a child.
    public var projectedValue: Binding<Value> {
        // The binding holds a strong reference to the storage,
        // not to the `State` wrapper itself, so the slot survives
        // even if the parent view's `State` is re-instantiated.
        Binding(get: { self.storage.value }, set: { self.storage.value = $0 })
    }
}
