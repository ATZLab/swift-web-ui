// Sources/SwiftWebUIRenderer/Renderable.swift
//
// The renderer's input contract: a `Renderable` is anything the
// renderer knows how to turn into a `DOMNode`. For v0.1.0 the
// only producer is a test stand-in (see
// `Tests/SwiftWebUIRendererTests/TextHiSnapshotTests.swift`);
// the real `SwiftWebUI.View` and its `Text` will conform to
// `Renderable` once the public surface lands (see
// `.harness/docs/swift-ui-surface.md`).
//
// Design choice — `_renderableDescription` instead of a
// `toDOMNode()` visitor method: the renderer owns the mapping
// from view-kind to DOM-shape (it knows "a text description
// becomes a div-wrapped text node"). Views own their data and
// describe it; the renderer interprets the description. This
// keeps the renderer open to new shapes (e.g. `.vstack([...])`,
// `.hstack([...])`) without forcing every view to know about
// `DOMNode`.
//
// 0.2.0 additions: `Button`, `TextField`, and `.onTapGesture`
// descriptions land here as new cases. The renderer adds the
// matching `case` in the exhaustive switch (see
// `SnapshotRenderer.swift`). The 5 deferred snapshot / role
// tests in `Tests/SwiftWebUISnapshots/` exercise the new
// shapes end-to-end.
//
// Owner: swiftwebui-dom-renderer.

/// A view-shaped value the renderer can interpret.
///
/// The protocol is intentionally tiny: a single property that
/// yields a `RenderableDescription`. The description is the
/// *kind* of the view, not its concrete DOMNode — the renderer
/// picks the DOM shape. This split (view = data + kind, renderer
/// = kind → DOM) is the same split SwiftUI uses between `View`
/// and the graph builder.
public protocol Renderable {
    /// The kind of view, abstracted away from any specific
    /// renderer output. The renderer pattern-matches on this
    /// to produce a `DOMNode`.
    var _renderableDescription: RenderableDescription { get }
}

/// A button role marker (a11y-only, per
/// `.harness/docs/swift-ui-surface.md` §2 + §10).
///
/// The role is rendered as a `data-swui-role` attribute on the
/// underlying `<button>` element so the accessibility sweep can
/// detect it without an attribute-only marker (the marker is
/// the dom-renderer rein's contract for the a11y acceptance
/// test on line 1401 of the surface spec).
public enum ButtonRole: String, Hashable, Sendable, Equatable {
    /// A button whose action is destructive (e.g. "Delete").
    case destructive
    /// A button whose action cancels the current flow.
    case cancel
}

/// The closed set of view kinds the renderer understands.
///
/// New shapes (`VStack`, `HStack`, ...) land alongside their
/// view types; the renderer adds a `case` per shape. Keeping
/// the set closed (no `case other(...)`) is a deliberate
/// safety net — a view that does not match a known case fails
/// the renderer's exhaustive switch, so the test names the
/// missing shape on day one.
public enum RenderableDescription: Equatable {
    /// A leaf carrying a string. The renderer wraps it in a
    /// `<div>` because that is the v0.1.0 stop condition
    /// (`Text("hi")` → `<div>hi</div>`). When `Text` gains
    /// modifier support (0.2.0+) the wrapping rule will move
    /// out of this enum.
    case text(String)

    /// A button control. The renderer emits a `<button>`
    /// element whose text content is `label`; when `role` is
    /// non-`nil` the element also carries a
    /// `data-swui-role="<role>"` attribute. The click listener
    /// is installed through `_RenderEventRegistry` at mount
    /// time and is **not** part of the rendered markup.
    ///
    /// Added in 0.2.0 alongside `SwiftWebUI.Button`. See
    /// `.harness/docs/swift-ui-surface.md` §2 + §10 (lines
    /// 1390–1410).
    case button(label: String, role: ButtonRole?)

    /// A single-line text field. The renderer emits an
    /// `<input type="text">` element with a `placeholder`
    /// attribute (when non-empty) and a `value` attribute (when
    /// non-empty). The `input` event listener is installed
    /// through `_RenderEventRegistry` at mount time and is
    /// **not** part of the rendered markup.
    ///
    /// Added in 0.2.0 alongside `SwiftWebUI.TextField`. See
    /// `.harness/docs/swift-ui-surface.md` §2 + §10 (lines
    /// 1412–1428).
    case textField(placeholder: String, value: String)

    /// A text leaf with an attached tap gesture. The rendered
    /// DOM is identical to `.text(content)` — the click
    /// listener is installed through `_RenderEventRegistry` at
    /// mount time and is **not** part of the rendered markup.
    ///
    /// Added in 0.2.0 alongside `.onTapGesture(count:perform:)`.
    /// See `.harness/docs/swift-ui-surface.md` §6 + §10 (lines
    /// 1430–1445).
    case textWithOnTapGesture(content: String)
}
