// Sources/SwiftWebUIRenderer/RendererReRenderHook.swift
//
// The 0.1.0 root re-render notification seam — **deprecated**
// in 0.2.0 in favour of `_ReRenderScheduler` (see
// `Sources/SwiftWebUIRenderer/_ReRenderScheduler.swift`).
//
// The 0.1.0 contract (`.harness/docs/swift-ui-surface.md` §4)
// is that the trigger fires a *single, full re-render of the
// root view tree*. The 0.2.0 work replaces this with a
// subtree-scoped, microtask-batched re-render driven by
// `Task { @MainActor in ... }`; the production wiring is
// `_ReRenderScheduler.schedule(_:)`.
//
// ## Deprecation (0.2.0)
//
// The hook's public surface is annotated
// `@available(*, deprecated, message: "Use
// _ReRenderScheduler.schedule(_:) instead. The 0.1.0 root
// re-render contract is replaced by the 0.2.0
// subtree-scoped, microtask-batched re-render. This hook is
// removed in 0.3.0.")` on every entry point. The seam stays
// `@_spi(SwiftWebUI)` because it is renderer-internal, not
// a stable public API.
//
// The 0.1.0 root-tree re-render still runs (the
// `State.wrappedValue` setter calls both the old hook and
// the new scheduler for the duration of 0.2.0) — the
// snapshot test target asserts the hook fires once per
// write (the 0.1.0 contract) and the renderer test target
// asserts the scheduler fires one commit per
// microtask-batched turn (the 0.2.0 contract). The two
// assertions live side by side until the 0.3.0 deletion.
//
// Owner: swiftwebui-dom-renderer. Architect owns `@State`'s
// public shape; this file is renderer-side SPI that the
// architect's wrapper calls into.

/// The 0.1.0 root re-render notification seam — **deprecated**
/// in 0.2.0.
///
/// In 0.1.0 SwiftWebUI's `@State` setter called
/// `_RendererReRenderHook.trigger()` on every write, and the
/// renderer installed a closure at mount time that walked the
/// root view tree synchronously on the calling thread. The
/// 0.2.0 work replaces this with the subtree-scoped,
/// microtask-batched `_ReRenderScheduler`
/// (see `Sources/SwiftWebUIRenderer/_ReRenderScheduler.swift`).
///
/// Every entry point on this enum is annotated
/// `@available(*, deprecated, ...)` so any remaining 0.1.0
/// call sites (the `@State` setter's secondary trigger, the
/// snapshot test target's `install` / `uninstall` calls) get
/// a compiler warning. The 0.2.0 `State.wrappedValue` setter
/// calls **both** the deprecated hook and the new scheduler
/// for the duration of the minor — the 0.1.0 snapshot test
/// still asserts the hook fires once per write, and the 0.2.0
/// scheduler test asserts the new microtask-batched path
/// fires. The hook is removed in 0.3.0.
@_spi(SwiftWebUI)
@available(*, deprecated, message: "Use _ReRenderScheduler.schedule(_:) instead. The 0.1.0 root re-render contract is replaced by the 0.2.0 subtree-scoped, microtask-batched re-render. This hook is removed in 0.3.0.")
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
    @available(*, deprecated, message: "Use _ReRenderScheduler.schedule(_:) instead; removed in 0.3.0.")
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
    @available(*, deprecated, message: "Use _ReRenderScheduler.schedule(_:) instead; removed in 0.3.0.")
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
    @available(*, deprecated, message: "Use _ReRenderScheduler.schedule(_:) instead; removed in 0.3.0.")
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
    @available(*, deprecated, message: "Use _ReRenderScheduler.schedule(_:) instead; removed in 0.3.0.")
    public static func trigger() {
        current?()
    }
}
