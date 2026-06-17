// Sources/SwiftWebUIRenderer/SnapshotRenderer.swift
//
// The v0.1.0 renderer. Walks a `Renderable`'s
// `_renderableDescription` and produces a `DOMNode` tree. The
// snapshot tests serialize the tree to a string and compare
// byte-for-byte (no whitespace, no escaping — the snapshot is
// the contract).
//
// 0.2.0 additions: the switch is extended for the
// `.button(label:role:)`, `.textField(placeholder:value:)`,
// and `.textWithOnTapGesture(content:)` cases added to
// `RenderableDescription`. The click / `input` event listeners
// are installed at mount time by the production renderer via
// `_RenderEventRegistry`; the snapshot renderer does not
// install listeners (it has no live DOM host) — the snapshot
// tests assert the rendered DOM only, and the listener
// semantics are covered by the renderer-tests target
// (`SwiftWebUIRendererTests/ButtonTapActionTests.swift` etc.).
//
// Owner: swiftwebui-dom-renderer.

/// In-memory renderer used by snapshot tests.
///
/// Conforms to `Renderer` with `Output == DOMNode`. The
/// exhaustive switch over `RenderableDescription` is the
/// safety net that forces a new view kind to land with a new
/// render case on day one.
public struct SnapshotRenderer: Renderer {
    /// Creates a renderer. No configuration in v0.2.0.
    public init() {}

    /// Render `view` to a `DOMNode`.
    public func render<V: Renderable>(_ view: V) -> DOMNode {
        // The exhaustive switch is the safety net that
        // catches missing shapes at compile time (a new case
        // on `RenderableDescription` without a matching
        // `case` here is a build error, not a runtime fall-
        // through).
        switch view._renderableDescription {
        case .text(let content):
            return .element(tag: "div", children: [.text(content)])

        case .button(let label, let role):
            // The 0.2.0 `Button("Save") { … }` snapshot
            // (per `.harness/docs/swift-ui-surface.md` §10
            // line 1397) is `<button>Save</button>`. A
            // `Button(role: .destructive)` (line 1401)
            // adds `data-swui-role="destructive"`; the
            // acceptance test asserts the attribute is
            // queryable from the DOM. The order of the
            // attributes is fixed by the `Dictionary` sort
            // (alphabetical) so the snapshot is stable.
            var attributes: [String: String] = [:]
            if let role {
                attributes["data-swui-role"] = role.rawValue
            }
            return .element(
                tag: "button",
                attributes: attributes,
                children: [.text(label)]
            )

        case .textField(let placeholder, let value):
            // The 0.2.0 `TextField("Name", text: $name)`
            // snapshot (per `.harness/docs/swift-ui-surface.md`
            // §10 line 1423) is
            // `<input type="text" placeholder="Name">` (when
            // the binding is empty) or
            // `<input type="text" placeholder="Name" value="…">`
            // (when the binding holds a value). The single-
            // line contract (line 1427) is that the tag is
            // `<input>`, not `<textarea>` — the test asserts
            // the tag name explicitly. The attribute order
            // is alphabetical: `placeholder`, `type`,
            // `value`.
            var attributes: [String: String] = [
                "type": "text"
            ]
            if !placeholder.isEmpty {
                attributes["placeholder"] = placeholder
            }
            if !value.isEmpty {
                attributes["value"] = value
            }
            return .element(
                tag: "input",
                attributes: attributes,
                children: []
            )

        case .textWithOnTapGesture(let content):
            // The 0.2.0 `.onTapGesture` snapshot (per
            // `.harness/docs/swift-ui-surface.md` §10 line
            // 1442) is the **same** DOM as `.text(content)`
            // — `<div>Tap me</div>`. The click listener is
            // internal to the production renderer's mount
            // hook (it installs through
            // `_RenderEventRegistry`) and is **not** part
            // of the rendered markup. The snapshot test
            // asserts the byte-for-byte equality with the
            // plain `Text("Tap me")` render.
            return .element(tag: "div", children: [.text(content)])
        }
    }
}
