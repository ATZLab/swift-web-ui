// Sources/SwiftWebUIRenderer/Placeholder.swift
//
// Empty target placeholder. Real renderer code (graph protocol,
// diff/patch engine, DOM event delegation) lands via
// swiftwebui-dom-renderer. See:
//   - AGENTS.md §6 (renderer model)
//   - .harness/docs/swift-ui-surface.md (graph surface)
//   - .harness/docs/tdd.md (TDD red-first requirement)
//
// Owner: swiftwebui-dom-renderer. TDD note: do not add public
// surface here without a failing test in Tests/SwiftWebUIRendererTests/
// landing first.
//
// This file exists solely so SwiftPM does not error with
// "target has no source files".

internal enum _SwiftWebUIRendererPlaceholder {}
