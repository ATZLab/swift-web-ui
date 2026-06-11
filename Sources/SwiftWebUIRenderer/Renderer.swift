// Sources/SwiftWebUIRenderer/Renderer.swift
//
// The renderer's driving protocol. v0.1.0 ships with one
// implementation: `SnapshotRenderer` (string serialization for
// snapshot tests). The live DOM renderer that drives the
// browser lands in a later commit; it will conform to
// `Renderer` with a different `Output` (e.g. a JavaScriptKit
// `JSObject` reference).
//
// Owner: swiftwebui-dom-renderer.

/// A renderer turns a `Renderable` view into an `Output` tree.
///
/// The protocol is intentionally minimal: one method, one
/// associated type. Different renderer targets (snapshot, live
/// DOM, accessibility) conform with different `Output`s.
public protocol Renderer {
    /// The shape the renderer produces. `DOMNode` for snapshot
    /// and live DOM renderers; other types are possible
    /// (e.g. an a11y tree).
    associatedtype Output
    /// Render `view` to the renderer's output shape.
    func render<V: Renderable>(_ view: V) -> Output
}
