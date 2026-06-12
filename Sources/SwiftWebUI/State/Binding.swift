// Sources/SwiftWebUI/State/Binding.swift
//
// SwiftWebUI's `@Binding` property wrapper. The signature mirrors
// SwiftUI's `@Binding` (see `.harness/docs/swift-ui-surface.md` §4).
//
// In 0.1.0 the getter and setter are stored and called; there is
// no notification back to the renderer on `wrappedValue` change.
// That notification path is the dom-renderer rein's job
// (Phase C2) and lands in the same minor release.
//
// Owner: swiftwebui-architect. Implementation: stub for 0.1.0 close-out.
//

/// A two-way reference to a value owned elsewhere.
///
/// `Binding` is the read/write handle that flows from a parent
/// view's `@State` to a child view. The child reads and writes
/// `wrappedValue` as if the value were its own, and the change
/// lands in the parent's storage.
///
/// ## Overview
///
/// In SwiftWebUI 0.1.0 the getter / setter functions are stored
/// and called on every read and write. The change is **not**
/// propagated to the renderer — the 0.2.0 work will wire the
/// notification path so that a child writing through a binding
/// triggers a re-render the same way a parent's `@State` write
/// does. In 0.1.0 the renderer reads the binding's current value
/// at every render and the snapshot tests are the contract.
///
/// `Binding.constant(_:)` produces a non-mutating binding whose
/// getter always returns the same value and whose setter is a
/// no-op. It is the right handle to pass to a child when the
/// child must take a binding for shape but the parent does not
/// want the child's writes to take effect — typical for
/// previews and for one-way data flow.
///
/// ## Example
///
/// ```swift
/// struct LabeledCounter: View {
///     @Binding var count: Int
///     var body: some View { Text("\(count)") }
/// }
///
/// struct Parent: View {
///     @State var n = 0
///     var body: some View { LabeledCounter(count: $n) }
/// }
/// ```
@propertyWrapper
public struct Binding<Value>: DynamicProperty {
    /// The closure called on every read. `nonmutating` so the
    /// `Binding` can be declared with `let` at the use site.
    @_spi(SwiftWebUI)
    public var getter: () -> Value

    /// The closure called on every write. `nonmutating` so the
    /// `Binding` can be declared with `let` at the use site.
    @_spi(SwiftWebUI)
    public var setter: (Value) -> Void

    /// Creates a `Binding` from a getter and a setter.
    ///
    /// Use this when the binding is read or written by a piece
    /// of code that does not own a `State` directly — for
    /// example, when adapting a foreign value (a `UserDefaults`
    /// read, a `localStorage` lookup) into SwiftWebUI's
    /// read/write shape.
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.getter = get
        self.setter = set
    }

    /// Creates a `Binding` that owns its value.
    ///
    /// This is the initializer that property-wrapper synthesis
    /// calls for `@Binding var x = 0` — the synthesized
    /// `_Binding.init(wrappedValue:)` is the property-wrapper
    /// hook. The default read returns the captured value; the
    /// default write mutates it in place. Because the captured
    /// value lives in a reference-typed box, the mutation is
    /// visible to subsequent reads of the same binding.
    public init(wrappedValue: Value) {
        // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
        // 0.1.0 behaviour: a self-referencing binding whose
        // getter returns the current value and whose setter
        // stores the new one. The reference box keeps the
        // identity stable across the wrapper's re-instantiation.
        let box = MutableBox(wrappedValue)
        self.init(
            get: { box.value },
            set: { box.value = $0 }
        )
    }

    /// The current value. Reading calls the stored getter.
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }

    /// A `Binding<Value>` re-targeted at the same getter and
    /// setter. Declared `nonmutating get` so the projected
    /// value is the binding itself, not a new wrapper.
    public var projectedValue: Binding<Value> { self }

    /// A non-mutating binding whose getter always returns
    /// `value` and whose setter is a no-op.
    ///
    /// Useful for previewing a view that takes a binding
    /// without driving state from the preview. See
    /// `Binding.constant(_:)` in SwiftUI for the same shape.
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
}

/// A reference-typed box used to keep a `Binding` stable across
/// re-instantiation of the surrounding struct.
///
/// Kept `@_spi(SwiftWebUI)` because the public API of `Binding`
/// hides it; renderer code may reach for it when wiring the
/// 0.2.0 change-notification path.
@_spi(SwiftWebUI)
public final class MutableBox<Value> {
    /// The current value.
    public var value: Value
    /// Creates a box seeded with the initial value.
    public init(_ value: Value) { self.value = value }
}
