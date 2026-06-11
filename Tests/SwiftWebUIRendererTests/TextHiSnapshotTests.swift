// Tests/SwiftWebUIRendererTests/TextHiSnapshotTests.swift
//
// TDD red for the v0.1.0 minimal slice: `Text("hi")` rendered
// through the renderer must serialize to `<div>hi</div>`.
//
// Owner: swiftwebui-dom-renderer owns the renderer; tester reviews.
// See `.harness/docs/tdd.md` (the red-then-green cycle) and
// `.harness/docs/swift-ui-surface.md` (the `Text` symbol spec).
//
// NOTE: this test uses a test-local `RenderableText` stand-in for
// the architect's `SwiftWebUI.Text` (which lands via a separate
// surface PR). The stand-in is intentionally minimal — it is the
// *test's* description of the behaviour, not the production type.
// When the real `SwiftWebUI.Text` lands, this test is expected to
// be rewritten to use the real type (per `.harness/docs/tdd.md`
// the production `Text` will conform to the same renderer-input
// contract).
//
// RED state: at the time of this commit the `SnapshotRenderer`
// does not exist yet. The test therefore fails to COMPILE, which
// is the unambiguous red signal the TDD cycle expects. Commit 2
// introduces the smallest `SnapshotRenderer` that turns the
// compile error into a passing assertion.

import Testing
@testable import SwiftWebUIRenderer

/// Test-only stand-in for the architect's `SwiftWebUI.Text`.
///
/// Defined next to the test on purpose. It captures the *minimum*
/// behaviour this test exercises — a leaf node carrying a string —
/// and nothing more. It will be deleted once the real `Text` lands
/// in `SwiftWebUI` and the test is rewritten against the real type.
struct RenderableText {
    let content: String
}

@Suite("Text(\"hi\") snapshot")
struct TextHiSnapshotTests {
    @Test("Text(\"hi\") mounts to <div>hi</div>")
    func textHiMountsToDiv() {
        // Arrange: a `Text("hi")` view (stand-in for the architect's
        // `SwiftWebUI.Text`, which is not yet on the integration base).
        let text = RenderableText(content: "hi")

        // Act: render it through the in-memory snapshot renderer.
        // `SnapshotRenderer` and its `render(_:)` API do not exist
        // yet at the time of this commit — that is the RED signal.
        let rendered = SnapshotRenderer().render(text)

        // Assert: the rendered DOM tree serializes to `<div>hi</div>`.
        // This is the v0.1.0 "Hello, web in Swift" stop condition
        // (see `ROADMAP.md` v0.1.0 — "see <div>hi</div> in a
        // browser", and `.harness/docs/tdd.md` — the snapshot
        // policy).
        #expect(String(describing: rendered) == "<div>hi</div>")
    }
}
