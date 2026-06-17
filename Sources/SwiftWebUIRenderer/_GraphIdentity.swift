// Sources/SwiftWebUIRenderer/_GraphIdentity.swift
//
// The per-view identity tag the renderer uses to decide which
// subtree a re-render applies to. The 0.2.0 contract (see
// `.harness/docs/swift-ui-surface.md` §8) is: a write to a
// `@State` owned by view `A` schedules a `Task { @MainActor in
// ... }` re-render whose `subtrees` is `{A, A.children}` and
// not `{root, root.subtree}`. The identity is the tag the
// scheduler logs with the commit so the renderer can decide
// which subtree to walk.
//
// ## Equality contract (0.2.0 — owner decision)
//
// Equality is **by `label` (a `String`)**. The label is a
// debug-friendly name (e.g. the view type name) the test
// author and the production code use as the identity tag.
// Two `_GraphIdentity` values with the same label compare
// equal and hash equal; the scheduler's `pending` set
// dedupes on this equality.
//
// This is a deliberate **structural identity** in 0.2.0, not
// a runtime-object identity. The 0.2.0 surface is a proof of
// subtree scope on the *simple* owner/sibling case; the
// identity is a tag the test passes in, not a handle the
// renderer tracks. The 0.3.0 work that introduces
// identity-stable diffing (and a per-render
// `ObjectIdentifier`-backed handle) will tighten this
// contract — see AGENTS.md §6 and the architect's note in
// `.harness/docs/swift-ui-surface.md` §11 self-critique.
//
// Owner: swiftwebui-dom-renderer.

/// A per-view identity tag used by `_ReRenderScheduler` to
/// route commits to the correct subtree.
///
/// The struct is the public, SPI-gated handle the renderer
/// passes to the scheduler when it wants to schedule a
/// re-render. The scheduler records the identity in its
/// pending-subtree set; on commit it forwards the set to
/// the installed `ReRenderObserver` so the observer (the
/// renderer) knows which subtrees to walk.
///
/// ## Equality
///
/// Two identities with the same `label` are equal. The
/// label is the only stored property; `Hashable` and
/// `Equatable` are auto-synthesised from it. In 0.2.0 this
/// is a structural equality (string-keyed) — two
/// `_GraphIdentity("Counter")` instances compare equal.
/// The 0.3.0 work will tighten this to a per-render handle
/// identity (see the file header for the rationale).
///
/// ## Example
///
/// ```swift
/// @_spi(SwiftWebUI) import SwiftWebUIRenderer
///
/// let counter = _GraphIdentity("Counter")
/// let sibling = _GraphIdentity("Sibling")
/// _ReRenderScheduler.schedule(counter)
/// ```
@_spi(SwiftWebUI)
public struct _GraphIdentity: Hashable, Sendable {
    /// The debug-friendly name the identity was constructed
    /// with. The only stored property; equality and
    /// hashing derive from this String.
    public let label: String

    /// Creates an identity with the given label.
    ///
    /// The label is the only property the equality contract
    /// sees; two identities with the same label compare
    /// equal.
    public init(_ label: String) {
        self.label = label
    }
}
