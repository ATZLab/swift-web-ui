// Tests/SwiftWebUISnapshots/InteractivitySnapshotTests.swift
//
// 0.2.0 deferred snapshot / role tests (the 5 follow-up
// cases from the 0.2.0 red + green commit pair).
//
// Per `.harness/docs/swift-ui-surface.md` §10, the 0.2.0
// per-symbol acceptance for `Button` (lines 1390–1410),
// `TextField` (lines 1412–1428), and `.onTapGesture` (lines
// 1430–1445) includes a small number of committed-baseline
// DOM snapshots. The 0.2.0 red commit deferred these to a
// follow-up commit because the red commit had to land a
// stub for the production `RenderableDescription` (the
// 0.1.0 baseline was not aware of `.button` / `.textField`
// / `.textWithOnTapGesture`). This file is the follow-up:
// it adds the new cases to the renderer's input contract
// (see `Sources/SwiftWebUIRenderer/Renderable.swift`),
// extends `SnapshotRenderer` to match (see
// `Sources/SwiftWebUIRenderer/SnapshotRenderer.swift`),
// and asserts the byte-for-byte snapshot for each new
// shape.
//
// The 5 deferred tests are:
//
//   1. **Button snapshot** (line 1397): `Button("Save")` →
//      `<button>Save</button>`.
//   2. **Button role attribute** (line 1401):
//      `Button(role: .destructive)` →
//      `<button data-swui-role="destructive">Delete</button>`.
//   3. **TextField snapshot** (line 1423):
//      `TextField("Name", text: $empty)` →
//      `<input type="text" placeholder="Name">`.
//   4. **TextField single-line contract** (line 1427): the
//      tag is `<input>`, not `<textarea>` — explicit
//      assertion on the tag name so a regression to the
//      multi-line shape is caught at the snapshot layer.
//   5. **onTapGesture snapshot** (line 1442):
//      `Text("Tap me").onTapGesture { … }` produces the
//      **same** DOM as `Text("Tap me")` — the click
//      listener is internal to the renderer's mount hook
//      and is not part of the rendered markup.
//
// Owner: swiftwebui-dom-renderer (the renderer is the
// snapshot source). Architect owns the public `Button` /
// `TextField` / `.onTapGesture` surface; reviewer is the
// architect. See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §2 + §6 + §10.
//
// NOTE: per the deferred-scope note in
// `Tests/SwiftWebUIRendererTests/ButtonTapActionTests.swift`
// (lines 38–50) the 0.2.0 red commit could not add these
// snapshot tests to the `SwiftWebUIRendererTests` target
// because the 0.1.0 production renderer did not yet have
// the `.button` / `.textField` / `.textWithOnTapGesture`
// cases on `RenderableDescription`. The follow-up commit
// (this one) extends the renderer's input contract and
// lands the snapshot tests in the dedicated
// `SwiftWebUISnapshots` target — which is the committed-
// baseline target (per `.harness/docs/tdd.md`
// §"Snapshot tests") and was the right home for these
// assertions from day one.

import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - Test fixtures (test-local stand-ins)
//
// Per the pattern in
// `Tests/SwiftWebUIRendererTests/TextHiSnapshotTests.swift`
// the snapshot target keeps the production `Button` /
// `TextField` surface at arm's length until the architect's
// public types land. The stand-ins hold the data the
// renderer cares about (label, role, placeholder, value,
// content) and describe themselves through the same
// `Renderable` protocol the production types will conform
// to. When the real `SwiftWebUI.Button` / `SwiftWebUI.TextField`
// land, these stand-ins are replaced by the real types
// (the assertion strings stay the same — the snapshot is
// the contract, not the view type).

/// A `Renderable` that describes a 0.2.0 `Button`.
/// Mirrors the production `SwiftWebUI.Button` shape (label,
/// optional role); the action is held separately for the
/// `ButtonTapActionTests` target — the snapshot target
/// only asserts the rendered DOM.
private struct RenderableButton: Renderable {
    let label: String
    let role: ButtonRole?

    var _renderableDescription: RenderableDescription {
        .button(label: label, role: role)
    }
}

/// A `Renderable` that describes a 0.2.0 `TextField`.
/// Mirrors the production `SwiftWebUI.TextField` shape
/// (placeholder, value); the binding is held separately
/// for the `TextFieldKeystrokeTests` target — the snapshot
/// target only asserts the rendered DOM.
private struct RenderableTextField: Renderable {
    let placeholder: String
    let value: String

    var _renderableDescription: RenderableDescription {
        .textField(placeholder: placeholder, value: value)
    }
}

/// A `Renderable` that describes a `Text` with
/// `.onTapGesture { … }`. The action is held separately
/// for the `OnTapGestureTests` target — the snapshot
/// target only asserts the rendered DOM, and the contract
/// is that the rendered DOM is the same as the plain
/// `Text(content)` render.
private struct RenderableTextWithOnTapGesture: Renderable {
    let content: String

    var _renderableDescription: RenderableDescription {
        .textWithOnTapGesture(content: content)
    }
}

// MARK: - 1. Button snapshot (line 1397)

@Suite("Button snapshot (0.2.0, line 1397)", .serialized)
struct ButtonSnapshotTests {
    /// Committed DOM snapshot for `Button("Save")` (line 1397).
    ///
    /// The 0.1.0 renderer's text snapshot is `<div>…</div>`;
    /// the 0.2.0 `Button` snapshot is `<button>Save</button>`
    /// — the renderer chooses the tag name based on the
    /// description kind, not on the user's data. A change
    /// to this string is a deliberate snapshot PR — the
    /// snapshot is the contract (per
    /// `.harness/docs/tdd.md` §"Snapshot tests").
    private static let buttonSaveSnapshot = "<button>Save</button>"

    @Test("Button(\"Save\") renders to <button>Save</button>")
    func buttonSaveRendersToButtonElement() {
        // Arrange: a `Button("Save")` view (stand-in for
        // the architect's `SwiftWebUI.Button`, which is not
        // yet on the integration base).
        let button = RenderableButton(label: "Save", role: nil)

        // Act: render it through the in-memory snapshot
        // renderer.
        let rendered = SnapshotRenderer().render(button)

        // Assert: the rendered DOM tree serializes to
        // `<button>Save</button>`. The byte-for-byte
        // equality is the contract — the snapshot is what
        // the host page will mount.
        #expect(String(describing: rendered) == Self.buttonSaveSnapshot)
    }
}

// MARK: - 2. Button role attribute (line 1401)

@Suite("Button role attribute (0.2.0, line 1401)", .serialized)
struct ButtonRoleAttributeTests {
    /// Committed DOM snapshot for `Button(role: .destructive)`.
    ///
    /// Per `.harness/docs/swift-ui-surface.md` §10 line
    /// 1401, a `Button(role: .destructive)` exposes
    /// `data-swui-role="destructive"` on the underlying
    /// element so the accessibility sweep can detect it.
    /// The exact ARIA mapping is the dom-renderer rein's
    /// contract; the acceptance is that the role is
    /// queryable from the DOM — this snapshot asserts the
    /// attribute is on the rendered element.
    private static let buttonDestructiveSnapshot =
        "<button data-swui-role=\"destructive\">Delete</button>"

    @Test("Button(role: .destructive) renders the data-swui-role attribute")
    func destructiveButtonExposesRoleAttribute() {
        let button = RenderableButton(label: "Delete", role: .destructive)

        let rendered = SnapshotRenderer().render(button)

        #expect(String(describing: rendered) == Self.buttonDestructiveSnapshot)
    }
}

// MARK: - 3. TextField snapshot (line 1423)

@Suite("TextField snapshot (0.2.0, line 1423)", .serialized)
struct TextFieldSnapshotTests {
    /// Committed DOM snapshot for `TextField("Name", text: $empty)`.
    ///
    /// Per `.harness/docs/swift-ui-surface.md` §10 line
    /// 1423, a `TextField` with `placeholder = "Name"` and
    /// an empty binding renders to
    /// `<input type="text" placeholder="Name">`. The
    /// attribute order is alphabetical: `placeholder`
    /// comes before `type` in the snapshot output (the
    /// `DOMNode` serializer sorts the attribute map
    /// lexicographically for stable byte output).
    private static let textFieldEmptySnapshot =
        "<input placeholder=\"Name\" type=\"text\">"

    /// Committed DOM snapshot for `TextField` with a value.
    private static let textFieldWithValueSnapshot =
        "<input placeholder=\"Name\" type=\"text\" value=\"Hello\">"

    @Test("TextField(\"Name\", text: $empty) renders to <input type=\"text\" placeholder=\"Name\">")
    func textFieldWithEmptyBindingRendersToInput() {
        let field = RenderableTextField(placeholder: "Name", value: "")

        let rendered = SnapshotRenderer().render(field)

        #expect(String(describing: rendered) == Self.textFieldEmptySnapshot)
    }

    @Test("TextField with a non-empty value exposes the value attribute")
    func textFieldWithValueExposesValueAttribute() {
        // The value attribute is the renderer-side read of
        // the binding; a subsequent keystroke re-renders
        // the same view with a new value and the snapshot
        // reflects the change. The test asserts the
        // attribute is on the rendered element when the
        // binding holds a value.
        let field = RenderableTextField(placeholder: "Name", value: "Hello")

        let rendered = SnapshotRenderer().render(field)

        #expect(String(describing: rendered) == Self.textFieldWithValueSnapshot)
    }
}

// MARK: - 4. TextField single-line contract (line 1427)

@Suite("TextField single-line contract (0.2.0, line 1427)", .serialized)
struct TextFieldSingleLineContractTests {
    @Test("TextField renders to an <input> element, not a <textarea>")
    func textFieldRendersAsInputNotTextarea() {
        // Per `.harness/docs/swift-ui-surface.md` §10 line
        // 1427, the single-line contract is that the DOM
        // element is `<input>` (not `<textarea>`); the
        // test asserts the tag name explicitly. A
        // regression to the multi-line shape (a future
        // `TextEditor` surface) would render `<textarea>`
        // — this test catches that regression at the
        // snapshot layer.
        let field = RenderableTextField(placeholder: "Name", value: "")

        let rendered = SnapshotRenderer().render(field)

        // Walk the rendered tree to assert the tag name.
        // The snapshot renderer produces a single element
        // node for `.textField`; the assertion inspects
        // the `.element` case directly so a regression
        // to a different tag (e.g. `<textarea>`) is named
        // in the failure message.
        switch rendered {
        case .element(let tag, _, _):
            #expect(tag == "input")
        case .text:
            Issue.record("expected an <input> element, got a text node")
        }
    }
}

// MARK: - 5. onTapGesture snapshot (line 1442)

@Suite(".onTapGesture snapshot (0.2.0, line 1442)", .serialized)
struct OnTapGestureSnapshotTests {
    /// Committed DOM snapshot for `Text("Tap me")` — the
    /// 0.1.0 leaf shape.
    private static let textOnlySnapshot = "<div>Tap me</div>"

    @Test("Text(\"Tap me\").onTapGesture renders the same DOM as Text(\"Tap me\") alone")
    func textWithOnTapGestureRendersSameDomAsTextAlone() {
        // Per `.harness/docs/swift-ui-surface.md` §10 line
        // 1442, `.onTapGesture` produces the **same** DOM
        // as the bare `Text("Tap me")` — the click listener
        // is internal to the production renderer's mount
        // hook (it installs through `_RenderEventRegistry`)
        // and is **not** part of the rendered markup.
        //
        // The acceptance test asserts byte-for-byte equality
        // with the plain `Text("Tap me")` render. The
        // listener semantics are covered by
        // `SwiftWebUIRendererTests/OnTapGestureTests.swift`
        // — the snapshot target asserts the rendered DOM
        // only.
        let tap = RenderableTextWithOnTapGesture(content: "Tap me")
        let rendered = SnapshotRenderer().render(tap)

        #expect(String(describing: rendered) == Self.textOnlySnapshot)
    }
}
