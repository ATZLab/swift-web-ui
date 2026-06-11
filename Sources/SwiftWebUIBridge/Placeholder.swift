// Sources/SwiftWebUIBridge/Placeholder.swift
//
// Empty target placeholder. Real bridge code (JSClosure retain
// policy, Swift↔JS value conversion, external JS API bindings)
// lands via swiftwebui-bridge. See:
//   - AGENTS.md §5 (JavaScriptKit is the only allowed JS-bridge dep)
//   - .harness/docs/js-bridge.md (interop rules)
//
// Owner: swiftwebui-bridge. TDD note: do not add public surface here
// without a failing test in Tests/SwiftWebUIBridgeTests/ landing
// first.
//
// This file exists solely so SwiftPM does not error with
// "target has no source files". The target DOES link against
// JavaScriptKit (see Package.swift) so the toolchain verifies the
// dependency graph at build time, even with no bridge code yet.

internal enum _SwiftWebUIBridgePlaceholder {}
