// Sources/SwiftWebUI/State/Environment.swift
//
// SwiftWebUI's `@Environment` property wrapper. The signature
// mirrors SwiftUI's `@Environment` (see
// `.harness/docs/swift-ui-surface.md` §4 and §5).
//
// The lookup is performed at render time, against a
// thread-local `EnvironmentValues` that the renderer installs
// at the start of each commit. In 0.1.0 the renderer is
// graph-based and has no per-key subscription; the wrapper
// resolves the key on the current bag and returns the value.
// Concrete keys (`.colorScheme`, `.locale`, …) are 0.2.0+ —
// the wrapper is in the type system now so 0.2.0 work can
// land without breaking source.
//
// `@frozen` matches SwiftUI's `@Environment` so the key-path
// encoding of the key is stable across compiler versions.
//
// Owner: swiftwebui-architect. Implementation: stub for 0.1.0 close-out.
//

/// A read-only view of an `EnvironmentValues` key.
///
/// `Environment` resolves a `KeyPath<EnvironmentValues, Value>`
/// at render time against the current bag and returns the
/// value. The wrapper carries no state of its own.
///
/// ## Overview
///
/// In SwiftWebUI 0.1.0 the lookup is performed at render
/// time; mutating the environment at the root of a re-render
/// causes descendants to see the new value on their next
/// access. There is no per-environment-key subscription in
/// 0.1.0 — that is 0.2.0 work. The wrapper is declared
/// `@frozen` so the key-path encoding of the key is stable
/// across compiler versions; this matches SwiftUI.
///
/// Concrete environment keys (`.colorScheme`, `.locale`, …)
/// land in 0.2.0+. The wrapper is in the public API now so
/// that adding a key later is a non-breaking change.
///
/// ## Example
///
/// ```swift
/// struct Thumbnail: View {
///     @Environment(\.colorScheme) var scheme  // 0.2.0+
///     var body: some View {
///         Image("/cat.png")
///             .opacity(scheme == .dark ? 0.7 : 1.0)
///     }
/// }
/// ```
@frozen
@propertyWrapper
public struct Environment<Value>: DynamicProperty {
    /// The key-path the wrapper resolves. Stable across
    /// compiler versions thanks to `@frozen`.
    @usableFromInline
    let keyPath: KeyPath<EnvironmentValues, Value>

    /// Creates an `Environment` that reads the value at
    /// `keyPath` on the current `EnvironmentValues` bag.
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        self.keyPath = keyPath
    }

    /// The current value.
    ///
    /// Looks up the value in the thread-local
    /// `EnvironmentValues` that the renderer installs at
    /// the start of a commit. If no bag is installed
    /// (which is the 0.1.0 default for tests and for the
    /// pre-renderer build path) the lookup falls back to a
    /// fresh empty bag, which returns each key's
    /// `defaultValue`.
    public var wrappedValue: Value {
        // TODO(0.1.0): re-render wiring — see swiftwebui-dom-renderer C2.
        // 0.1.0 behaviour: thread-local lookup, falling back
        // to a fresh empty bag when no renderer is in scope.
        // The 0.2.0 renderer will install the current bag at
        // commit start and leave it in place for the
        // duration of the walk.
        let bag = _EnvironmentAccessor.current ?? EnvironmentValues()
        return bag[keyPath: keyPath]
    }
}

/// The thread-local storage for the renderer's current
/// `EnvironmentValues`.
///
/// The renderer (C2) calls `_EnvironmentAccessor.with(bag)`
/// around a commit walk; the `@Environment` wrapper reads
/// the installed bag from this accessor. In 0.1.0 the
/// renderer does not yet install a bag, so every
/// `@Environment` read falls back to a fresh empty bag and
/// returns each key's `defaultValue`. That is the
/// acknowledged 0.1.0 limitation — there are no concrete
/// keys to read in this minor release.
@_spi(SwiftWebUI)
public enum _EnvironmentAccessor {
    /// The current bag, or `nil` if the renderer has not
    /// installed one.
    ///
    /// Single-threaded in 0.1.0. The 0.2.0 work that
    /// schedules re-renders on a worker will replace the
    /// slot with a `Synchronization.Mutex` or equivalent.
    @_spi(SwiftWebUI)
    public nonisolated(unsafe) static var current: EnvironmentValues?

    /// Installs `bag` for the duration of `body`, restoring
    /// the previous value on exit. The renderer calls this
    /// around the commit walk.
    @_spi(SwiftWebUI)
    public static func with<R>(_ bag: EnvironmentValues, _ body: () -> R) -> R {
        let previous = _EnvironmentAccessor.current
        _EnvironmentAccessor.current = bag
        defer { _EnvironmentAccessor.current = previous }
        return body()
    }
}
