// Sources/SwiftWebUIRenderer/DOMNode.swift
//
// The output tree the renderer produces. v0.1.0 is intentionally
// minimal: one element case (with a tag name and children) and one
// text case. That is enough to express `<div>hi</div>` for the
// `Text("hi")` stop condition; the full graph (attributes,
// namespaces, identity) is gated under SPI and lands with the
// v0.2.0 work on identity-stable diffing.
//
// 0.2.0 additions: the `element` case gains an `attributes`
// parameter so `TextField` (`<input type="text" placeholder="…">`)
// and `Button(role:)` (`<button data-swui-role="…">`) can
// round-trip through the renderer. Attributes are kept as a
// `[String: String]` map (sorted on serialization for stable
// snapshot output) — the 0.3.0 work will narrow this to a
// typed attribute model when the diff/patch engine is
// extended to handle attribute-level changes.
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
/// - `element(tag:attributes:children:)` describes an HTML
///   element with a tag name, an attribute map, and an
///   ordered list of children. The tag name is intentionally
///   a `String` (not an enum) so the renderer stays open to
///   user-defined HTML element names; the public API will
///   narrow this when the SwiftUI surface lands. The
///   `attributes` map is empty for elements that have no
///   attributes (e.g. `<div>…</div>`).
/// - `text(_:)` describes a text leaf (no children, no
///   attributes). This is the v0.1.0 carrier of `Text("...")`
///   content.
public enum DOMNode: Equatable {
    /// An element with a tag name, an attribute map, and an
    /// ordered list of children.
    ///
    /// The `attributes` map is sorted on serialization for
    /// stable snapshot output (a `[String: String]` is not
    /// order-stable on its own). The 0.2.0 snapshot tests
    /// assert exact byte equality, so the sort order is part
    /// of the contract — see `SnapshotRenderer.swift` for
    /// the attribute order used in each case.
    case element(tag: String, attributes: [String: String], children: [DOMNode])
    /// A text leaf.
    case text(String)
}

extension DOMNode {
    /// Convenience initialiser for elements with no
    /// attributes. The 0.1.0 shape (the `Text("hi")` snapshot
    /// is `<div>hi</div>` with no attributes) is expressed
    /// through this initialiser.
    public static func element(tag: String, children: [DOMNode]) -> DOMNode {
        .element(tag: tag, attributes: [:], children: children)
    }
}

extension DOMNode: CustomStringConvertible {
    /// HTML-ish serialization used by `SnapshotRenderer` and the
    /// v0.1.0 snapshot tests. Intentionally minimal — no
    /// whitespace, no escaping (the snapshot test asserts exact
    /// byte equality, so the shape is part of the contract).
    ///
    /// Attribute serialization: keys are sorted lexicographically
    /// so a `[String: String]` map round-trips to a stable byte
    /// string (a `Dictionary` is not order-stable on its own).
    /// Values are emitted bare (no escaping) — the 0.2.0
    /// snapshot fixtures use ASCII-only values, so the
    /// no-escape contract is the right simplicity. The 0.3.0
    /// work that adds user-visible content will introduce
    /// proper escaping; the snapshot test for that will be a
    /// new fixture.
    ///
    /// Void elements: `<input>`, `<br>`, `<hr>`, `<meta>`,
    /// `<img>`, `<link>` are HTML void elements — they have
    /// no closing tag and no children. The serializer
    /// recognises them and emits the self-closing form
    /// (e.g. `<input type="text" placeholder="Name">`),
    /// matching the spec's snapshot for `TextField` (line
    /// 1423). Children on a void element are silently
    /// dropped — the renderer never produces a void element
    /// with children.
    public var description: String {
        switch self {
        case .text(let s):
            return s
        case .element(let tag, let attributes, let children):
            let attrString: String = {
                guard !attributes.isEmpty else { return "" }
                let sortedKeys = attributes.keys.sorted()
                let pairs = sortedKeys.map { key in
                    "\(key)=\"\(attributes[key] ?? "")\""
                }
                return " " + pairs.joined(separator: " ")
            }()
            if Self.isVoidElement(tag) {
                // Void elements never have children; emit
                // the self-closing form.
                return "<\(tag)\(attrString)>"
            }
            let inner = children.map(String.init(describing:)).joined()
            return "<\(tag)\(attrString)>\(inner)</\(tag)>"
        }
    }

    /// The set of HTML void elements — elements that have no
    /// closing tag and no children. The list matches the
    /// WHATWG HTML living standard (the `input`, `br`,
    /// `hr`, `meta`, `img`, `link`, and a few others are
    /// void; `<button>`, `<div>`, `<span>`, `<textarea>`
    /// are not). The 0.2.0 surface only emits `<input>`
    /// (the `TextField` shape); the others are listed for
    /// future-proofing — the renderer will not silently
    /// emit a closing tag on a void element if a future
    /// view description (e.g. `.image(...)`) lands.
    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    ]

    /// Whether `tag` is an HTML void element (no closing
    /// tag, no children). Used by the serializer to decide
    /// between the self-closing and the open/close form.
    private static func isVoidElement(_ tag: String) -> Bool {
        voidElements.contains(tag)
    }
}
