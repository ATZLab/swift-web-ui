// Sources/SwiftWebUI/EnvironmentValues.swift
//
// SwiftWebUI's environment-values bag. The signature mirrors
// SwiftUI's `EnvironmentValues` (see
// `.harness/docs/swift-ui-surface.md` §5).
//
// In 0.1.0 the bag ships EMPTY: there are no concrete
// `EnvironmentKey` types in the public surface, so every
// subscript access falls through to the key's `defaultValue`.
// Concrete keys (`.colorScheme`, `.locale`, …) land in 0.2.0+.
// The subscript API is stable so adding a key later is
// non-breaking.
//
// Owner: swiftwebui-architect. Implementation: stub for 0.1.0 close-out.
//

/// A bag of values keyed by `EnvironmentKey`.
///
/// `EnvironmentValues` is the cross-tree, read-only value bag
/// that `@Environment` reads from. The view tree carries a
/// single `EnvironmentValues` instance; every `@Environment`
/// wrapper looks up its key on that bag at render time.
///
/// ## Overview
///
/// SwiftWebUI ships the empty bag in 0.1.0. Adding a key in
/// 0.1.0 is `@_spi(Experimental)`; promoting a key to public
/// is the work of the minor that ships the corresponding
/// feature. The `subscript` API matches SwiftUI's
/// `EnvironmentValues` so adding a key later is non-breaking —
/// no user code needs to change.
///
/// The bag is mutated through the `subscript` setter; that
/// path is the bridge between an ancestor's
/// `.environment(\.key, value)` modifier (0.2.0) and a
/// descendant's `@Environment` read. In 0.1.0 the only write
/// the user can perform is a default read (every read returns
/// `Key.defaultValue`).
///
/// ## Example
///
/// ```swift
/// @Environment(\.colorScheme) var scheme  // 0.2.0+
/// ```
public struct EnvironmentValues {
    /// The concrete key/value storage.
    ///
    /// The bag is empty in 0.1.0. The storage is held in a
    /// class so the value-type `EnvironmentValues` can be
    /// copied cheaply across the tree without losing the
    /// entries the user has set.
    @_spi(SwiftWebUI)
    public final class Storage {
        /// The backing dictionary. Keyed by `ObjectIdentifier`
        /// of the `EnvironmentKey` metatype so the public
        /// API can stay key-typed (the user supplies a
        /// `Key.Type` and the runtime resolves it).
        public var entries: [ObjectIdentifier: Any]
        /// Creates an empty storage.
        public init() { self.entries = [:] }
    }

    /// The bag's storage. `nonmutating` on `let` sites so
    /// ancestor mutations to the bag flow down the tree.
    @_spi(SwiftWebUI)
    public var storage: Storage

    /// Creates an empty `EnvironmentValues`.
    public init() {
        self.storage = Storage()
    }

    /// Reads and writes a value by its `EnvironmentKey` type.
    ///
    /// Reading an unset key returns `Key.defaultValue`. Writing
    /// inserts the value into the bag; descendants that read
    /// the same key observe the written value.
    public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
        get {
            // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
            // 0.1.0 behaviour: an unset key returns its
            // `defaultValue`. Concrete keys are 0.2.0+.
            if let v = storage.entries[ObjectIdentifier(key)] as? Key.Value {
                return v
            }
            return Key.defaultValue
        }
        set {
            // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
            // 0.1.0 behaviour: a write stores the value. The
            // 0.2.0 work will trigger a re-render of any
            // descendant whose `@Environment` reads this key.
            storage.entries[ObjectIdentifier(key)] = newValue
        }
    }
}

/// A key in the `EnvironmentValues` bag.
///
/// A new key declares an `associatedtype Value` and a
/// `defaultValue`. SwiftWebUI ships no concrete keys in 0.1.0;
/// the protocol is in the public API so the bag's subscript has
/// a complete type to dispatch on. A new key in 0.1.0 should be
/// declared as `@_spi(Experimental)`; promoting a key to public
/// is the work of the minor that ships the corresponding
/// feature.
///
/// ## Example
///
/// ```swift
/// struct MyKey: EnvironmentKey {
///     static let defaultValue: String = "hello"
/// }
/// ```
public protocol EnvironmentKey {
    /// The type of value stored under this key.
    associatedtype Value
    /// The value returned by an `EnvironmentValues` subscript
    /// when no ancestor has written a value for the key.
    static var defaultValue: Value { get }
}
