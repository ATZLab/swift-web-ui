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

/// The closed set of view kinds the v0.1.0 renderer understands.
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
}
