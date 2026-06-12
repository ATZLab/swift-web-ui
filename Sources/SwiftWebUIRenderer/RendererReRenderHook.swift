// Sources/SwiftWebUIRenderer/RendererReRenderHook.swift
//
// The renderer's root re-render notification seam.
//
// SwiftWebUI's `@State` property wrapper triggers a "re-render"
// event when `wrappedValue` is set. The 0.1.0 contract
// (`.harness/docs/swift-ui-surface.md` §4) is that the trigger
// fires a *single, full re-render of the root view tree*. The
// 0.2.0 work will replace this with a subtree-scoped, batched
// re-render.
//
// The seam is shaped as a thread-local hook:
//   * The renderer installs a closure at mount time
//     (`install(_:)`).
//   * `@State`'s setter calls `trigger()` on every write.
//   * `trigger()` invokes the installed closure synchronously,
//     exactly once per write, on the calling thread. No
//     batching, no microtask queue, no `requestAnimationFrame` —
//     those are 0.2.0/0.3.0 concerns (see the locked spec at
//     `.harness/docs/swift-ui-surface.md` §4 and `AGENTS.md`
//     §6).
//
// The seam is `@_spi(SwiftWebUI)` because it is a
// renderer-internal protocol, not a stable public API. The
// 0.2.0 surface work will likely fold it into a more general
// `DynamicProperty.update()` call site and re-gate the
// remaining internal bits under `@_spi(Experimental)`.
//
// Owner: swiftwebui-dom-renderer. Architect owns `@State`'s
// public shape; this file is renderer-side SPI that the
// architect's wrapper calls into.

/// The renderer's root re-render notification seam.
///
/// SwiftWebUI's `@State` setter calls `trigger()` on every
/// write. The renderer installs a closure at mount time that
/// walks the view tree, re-evaluates the root body, diffs the
/// new graph against the previous graph, and applies the
/// patch. The 0.1.0 implementation invokes the closure
/// synchronously on the calling thread; the 0.2.0 work
/// introduces batching and a worker thread.
@_spi(SwiftWebUI)
public enum _RendererReRenderHook {
    /// The currently installed hook, or `nil` if no renderer
    /// is in scope.
    ///
    /// The slot is a single global because 0.1.0 is
    /// single-threaded. The 0.2.0 work that schedules
    /// re-renders on a worker will replace the slot with a
    /// `Synchronization.Mutex` (or equivalent) so the hook
    /// can be installed / uninstalled from any thread.
    @_spi(SwiftWebUI)
    public nonisolated(unsafe) static var current: (() -> Void)?

    /// Installs `hook` as the current root re-render callback.
    ///
    /// Returns the previous hook so the renderer can chain a
    /// stack of installs (e.g. nested coordinator contexts).
    /// The simple install / uninstall pair is what the
    /// snapshot tests use; the live renderer uses the chain.
    ///
    /// `@discardableResult` so call sites that do not need
    /// the previous hook do not have to bind it to `_`.
    @_spi(SwiftWebUI)
    @discardableResult
    public static func install(_ hook: @escaping () -> Void) -> (() -> Void)? {
        let previous = current
        current = hook
        return previous
    }

    /// Restores `nil` as the current hook.
    ///
    /// The renderer uses the explicit `install(previous)` form
    /// to chain; the tests use `uninstall()` for symmetry.
    @_spi(SwiftWebUI)
    public static func uninstall() {
        current = nil
    }

    /// Invokes the installed hook, if any.
    ///
    /// `@State`'s setter calls this. A nil hook is a no-op —
    /// the wrapper still updates its storage, the renderer
    /// just does not get a callback. That is the right
    /// behaviour outside a renderer context (e.g. a unit
    /// test that does not install a hook).
    @_spi(SwiftWebUI)
    public static func trigger() {
        current?()
    }
}
