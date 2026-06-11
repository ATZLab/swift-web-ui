// Sources/SwiftWebUIRenderer/SnapshotRenderer.swift
//
// The v0.1.0 renderer. Walks a `Renderable`'s
// `_renderableDescription` and produces a `DOMNode` tree. The
// snapshot tests serialize the tree to a string and compare
// byte-for-byte (no whitespace, no escaping — the snapshot is
// the contract).
//
// Owner: swiftwebui-dom-renderer.

/// In-memory renderer used by snapshot tests.
///
/// Conforms to `Renderer` with `Output == DOMNode`. The
/// exhaustive switch over `RenderableDescription` is the
/// safety net that forces a new view kind to land with a new
/// render case on day one.
public struct SnapshotRenderer: Renderer {
    /// Creates a renderer. No configuration in v0.1.0.
    public init() {}

    /// Render `view` to a `DOMNode`.
    public func render<V: Renderable>(_ view: V) -> DOMNode {
        // v0.1.0: the only shape is `.text`. The exhaustive
        // switch is the safety net that catches missing
        // shapes at compile time (the test names the missing
        // case in its own `RenderableText`).
        switch view._renderableDescription {
        case .text(let content):
            return .element(tag: "div", children: [.text(content)])
        }
    }
}
