// Sources/SwiftWebUIRenderer/DOMNode.swift
//
// The output tree the renderer produces. v0.1.0 is intentionally
// minimal: one element case (with a tag name and children) and one
// text case. That is enough to express `<div>hi</div>` for the
// `Text("hi")` stop condition; the full graph (attributes,
// namespaces, identity) is gated under SPI and lands with the
// v0.2.0 work on identity-stable diffing.
//
// Owner: swiftwebui-dom-renderer.

/// A node in the renderer's output DOM tree.
///
/// The enum is the *lowest common denominator* across all renderer
/// targets: every renderer (snapshot, live DOM, accessibility
/// tree) consumes this shape. Renderer-specific decoration
/// (live DOM nodes, ARIA attributes, etc.) is layered on top
/// downstream.
///
/// - `element(tag:children:)` describes an HTML element with a
///   tag name and an ordered list of children. The tag name is
///   intentionally a `String` (not an enum) so the renderer
///   stays open to user-defined HTML element names; the public
///   API will narrow this when the SwiftUI surface lands.
/// - `text(_:)` describes a text leaf (no children, no
///   attributes). This is the v0.1.0 carrier of `Text("...")`
///   content.
public enum DOMNode: Equatable {
    /// An element with a tag name and an ordered list of children.
    case element(tag: String, children: [DOMNode])
    /// A text leaf.
    case text(String)
}

extension DOMNode: CustomStringConvertible {
    /// HTML-ish serialization used by `SnapshotRenderer` and the
    /// v0.1.0 snapshot tests. Intentionally minimal — no
    /// whitespace, no escaping (the snapshot test asserts exact
    /// byte equality, so the shape is part of the contract).
    public var description: String {
        switch self {
        case .text(let s):
            return s
        case .element(let tag, let children):
            let inner = children.map(String.init(describing:)).joined()
            return "<\(tag)>\(inner)</\(tag)>"
        }
    }
}
