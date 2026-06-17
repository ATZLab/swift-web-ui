// Sources/SwiftWebUIRenderer/ReRenderObserver.swift
//
// The observer protocol the renderer (and the test
// fixtures) implements to receive commit notifications
// from `_ReRenderScheduler`.
//
// The scheduler invokes the observer once per
// microtask-batched commit, on the main actor, with the
// dedup'd subtree set the commit applies to. The
// renderer's observer walks the recorded subtrees and
// produces a fresh graph; the test fixtures record the
// commits to assert the batching / main-actor / subtree
// contracts in `.harness/docs/swift-ui-surface.md` §10.
//
// Owner: swiftwebui-dom-renderer.

/// A receiver of `_ReRenderScheduler` commit
/// notifications.
///
/// The renderer (and the test fixtures) installs a
/// concrete observer on
/// `_ReRenderScheduler.observer`. The scheduler
/// invokes `scheduler(didCommitFor:)` exactly once
/// per microtask-batched commit, on the main actor,
/// in a `Task { @MainActor in ... }` body. The
/// `subtrees` argument is the dedup'd set of
/// `_GraphIdentity` values the commit re-renders
/// (the renderer walks the recorded subtrees; the
/// test fixtures append the list to a recorder and
/// assert the count / contents).
///
/// ## Concurrency
///
/// Implementations are invoked on the main actor.
/// Production observers are typically
/// `@MainActor`-isolated; the test fixtures are
/// `final class` with a `@MainActor.assertIsolated()`
/// check inside the body to assert the actor
/// isolation (the cross-actor test relies on the
/// assertion to fail if the scheduler drops the
/// actor hop).
@_spi(SwiftWebUI)
public protocol ReRenderObserver {
    /// Called by `_ReRenderScheduler` once per
    /// commit, on the main actor. `subtrees` is
    /// the dedup'd set of view identities the
    /// commit re-renders.
    func scheduler(didCommitFor subtrees: [_GraphIdentity])
}
