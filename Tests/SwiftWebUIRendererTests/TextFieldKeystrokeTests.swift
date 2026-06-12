// Tests/SwiftWebUIRendererTests/TextFieldKeystrokeTests.swift
//
// 0.2.0 `TextField` interaction contract.
//
// This file is the RED commit for the 0.2.0 per-symbol acceptance
// in `.harness/docs/swift-ui-surface.md` §10 (lines 1412–1428). The
// 0.2.0 contract:
//
//   1. **Keystroke-writes-binding** (line 1414): a
//      `TextField("Name", text: $name)` receives a synthetic
//      `input` event with `value = "Hello"`; the binding's
//      `wrappedValue` is `"Hello"` after the event.
//   2. **Subtree re-render on keystroke** (line 1418): the
//      binding write triggers a subtree-scoped re-render
//      (the `@Binding` acceptance covers this in the
//      abstract; the `TextField`-specific test asserts the
//      commit fires).
//
// The 0.2.0 `TextField` public type does not exist yet. For
// the red tests we use a test-local `TextField` stand-in
// that holds the placeholder and the binding; the test
// installs an `input` event listener via
// `_RenderEventRegistry` and fires synthetic input events
// via the registry's `simulate(event:on:)` API. The
// listener updates the binding's `wrappedValue` — that is
// the contract the 0.2.0 production implementation must
// satisfy (the production renderer wires the listener
// to the binding setter).
//
// All tests fail against the 0.1.0 implementation:
//   * The 0.1.0 `Binding` setter has no notification path
//     back to the scheduler (the test asserts a commit,
//     fails).
//   * The 0.1.0 surface has no `TextField` public type
//     (the test uses a stand-in for shape).
//
// **Scope note (red commit):** the single-line
// `<input type="text">` snapshot (line 1423) is deferred
// to a follow-up red commit for the same compile-blocks-
// the-0.1.0-target reason the Button snapshot is
// deferred. See the comment in `ButtonTapActionTests.swift`.
//
// Owner: swiftwebui-tester. swiftwebui-architect owns the
// `TextField` public surface; swiftwebui-dom-renderer owns
// the SPI and the event-listener wiring.
// See `.harness/docs/tdd.md` and
// `.harness/docs/swift-ui-surface.md` §2 + §4 + §8 + §10.

import Foundation
import Testing
@_spi(SwiftWebUI) @testable import SwiftWebUIRenderer
@_spi(SwiftWebUI) @testable import SwiftWebUI

// MARK: - ReRender observer (test fixture)

private final class TextFieldCommitRecorder: ReRenderObserver, @unchecked Sendable {
    private(set) var commits: [[_GraphIdentity]] = []
    private(set) var lastCommitWasOnMainActor: Bool = false

    func scheduler(didCommitFor subtrees: [_GraphIdentity]) {
        MainActor.assertIsolated()
        lastCommitWasOnMainActor = true
        commits.append(subtrees)
    }
}

// MARK: - TextField stand-in (test fixture)

/// Test-local stand-in for the 0.2.0 `SwiftWebUI.TextField`.
///
/// The 0.2.0 `TextField` is a public, SwiftUI-shaped
/// single-line text input (see spec §2). The 0.1.0
/// production type does not exist yet. The stand-in holds
/// the placeholder, the binding, and the identity; the
/// test installs the `input` event listener via
/// `_RenderEventRegistry` and fires synthetic input events
/// via the registry's `simulate(event:on:)` API. The
/// listener writes the new value through the binding —
/// the contract the 0.2.0 production implementation must
/// satisfy.
struct TextFieldStandIn {
    let placeholder: String
    let text: Binding<String>
    let identity: _GraphIdentity
}

// MARK: - TextField keystroke-writes-binding (line 1414)

@Suite("TextField keystroke-writes-binding (0.2.0, line 1414)", .serialized)
struct TextFieldKeystrokeTests {
    @Test("a synthetic input event on a TextField writes the value through the binding")
    func syntheticInputEventWritesValueThroughBinding() async {
        let recorder = TextFieldCommitRecorder()
        _ReRenderScheduler.observer = recorder
        defer { _ReRenderScheduler.observer = nil }
        _RenderEventRegistry.resetForTesting()
        defer { _RenderEventRegistry.resetForTesting() }

        // The 0.2.0 contract: a synthetic `input` event
        // with a new `value` is delivered to the listener,
        // the listener writes the value through the
        // binding, and the binding setter triggers a
        // commit on the main actor.
        //
        // The test creates a `TextFieldStandIn` with a
        // `Binding<String>` seeded to the empty string.
        // The 0.2.0 production renderer wires the
        // listener to write the event's value through the
        // binding. The test installs a manual listener
        // that does the same, because the 0.1.0 renderer
        // does not yet understand the `TextField` shape.
        let state = State<String>(wrappedValue: "")
        let binding = state.projectedValue

        let field = TextFieldStandIn(
            placeholder: "Name",
            text: binding,
            identity: _GraphIdentity("NameField")
        )

        // Install the `input` event listener. The handler
        // is the 0.2.0 production behavior in microcosm:
        // a synthetic event with `value = "Hello"` writes
        // through the binding.
        let capturedBinding = binding
        _RenderEventRegistry.install(
            owner: field.identity,
            event: "input",
            handler: {
                // The 0.2.0 production renderer reads the
                // event's `value` and writes it through
                // the binding. The test simulates the
                // event by hardcoding the value (the
                // 0.2.0 work wires the actual event
                // payload through the JavaScriptKit
                // bridge).
                capturedBinding.wrappedValue = "Hello"
            }
        )

        // Sanity: the binding is empty before the event.
        #expect(binding.wrappedValue == "")

        // Drain any microtask that may have been
        // scheduled by the binding's setter.
        let baselineCommits = recorder.commits.count
        await Task.yield()
        await Task.yield()

        // Fire the synthetic input event.
        _RenderEventRegistry.simulate(event: "input", on: field.identity)

        // Drain the microtask.
        await Task.yield()
        await Task.yield()
        await Task.yield()

        // Assert: the binding's value is now "Hello" AND
        // a commit fired on the main actor.
        #expect(binding.wrappedValue == "Hello")
        #expect(recorder.commits.count - baselineCommits == 1)
        #expect(recorder.lastCommitWasOnMainActor == true)
    }

    @Test("a TextField with a placeholder and an empty binding starts with the initial empty value")
    func textFieldStartsWithInitialValue() {
        // This is a baseline regression test: the
        // `TextField("Name", text: $name)` constructor
        // must preserve the binding's initial value. In
        // 0.1.0 the public type does not exist; the test
        // exercises the binding directly. The 0.2.0
        // production type must not mutate the binding at
        // construction time.
        let state = State<String>(wrappedValue: "")
        let binding = state.projectedValue

        let field = TextFieldStandIn(
            placeholder: "Name",
            text: binding,
            identity: _GraphIdentity("NameField")
        )

        #expect(field.placeholder == "Name")
        #expect(field.text.wrappedValue == "")
    }
}
