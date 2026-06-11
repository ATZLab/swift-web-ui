// Sources/SwiftWebUITooling/Placeholder.swift
//
// Empty target placeholder. The dev-server workflow
// (`scripts/serve.sh`) is currently a shell script; the Swift half
// of tooling (a build-tool plugin or an `Executable` target that
// orchestrates `swift build` + JS bundling) lands in a later
// iteration. See:
//   - AGENTS.md §6 (renderer model) and the `Sources/` tree
//   - the tooling scope: Package.swift matrix, JS bundle,
//     dev server, `scripts/serve.sh`, README Quickstart wiring
//
// Owner: swiftwebui-tooling. TDD note: do not add public surface
// here without a failing test landing first.
//
// This file exists solely so SwiftPM does not error with
// "target has no source files".

internal enum _SwiftWebUIToolingPlaceholder {}
