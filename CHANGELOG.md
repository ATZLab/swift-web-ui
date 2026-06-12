# Changelog

All notable changes to **SwiftWebUI** are recorded here. The format
follows **Keep a Changelog** 1.1.0, and this project adheres to
**Semantic Versioning** 2.0.0.

The entries inside each version are aggregated from the per-day
record under [`.harness/changelogs/`](./.harness/changelogs/) and are
reproduced verbatim. See [`.harness/docs/release.md`](./.harness/docs/release.md)
for the release checklist and [`.harness/docs/release.md`](./.harness/docs/release.md)
§"Banned / required language in release notes" for the language policy
that this changelog obeys.

## [Unreleased]

_Nothing yet. The next entry is 0.2.0._

## [0.1.0] - 2026-06-11

The first tagged release of SwiftWebUI. The MVP slice ships a
working render path from `Text("hi")` to `<div>hi</div>` in a browser,
backed by a graph-based renderer and the JavaScriptKit bridge. It is
the **proof of shape**, not the proof of feature: no interaction, no
animation, no shape primitives, no lists. See
[`ROADMAP.md`](./ROADMAP.md) §v0.1.0 for the user-visible capability
and the stop conditions this release was judged against.

### Aggregated per-day changelog

The entries below are reproduced verbatim from
[`.harness/changelogs/2026-06-11.md`](./.harness/changelogs/2026-06-11.md).

- `[2026-06-11 14:19] swiftwebui-architect` — wrote v0.1.0 surface spec in `docs/swift-ui-surface.md`; locked as `AGENTS.md` §11
- `[2026-06-11 14:20] swiftwebui-steward` — repo tree baseline (`README`, `LICENSE`, `CONTRIBUTING`, `CoC`, `SECURITY`, issue/PR templates, dependabot)
- `[2026-06-11 14:25] swiftwebui-tooling` — `Package.swift` (4 products), `scripts/serve.sh`, `.github/workflows/ci.yml` (lint-paths + swift build + swift test)
- `[2026-06-11 14:41] swiftwebui-docs` — DocC catalog stub (landing page, Getting Started tutorial, ViewFundamentals + Modifiers articles)

### Added

- Public SwiftUI-style API surface for 0.1.0, as enumerated in
  [`.harness/docs/swift-ui-surface.md`](./.harness/docs/swift-ui-surface.md):
  `View`, `body`, `some View`, `ViewBuilder`, `Text`, `VStack`,
  `HStack`, `ZStack`, `Group`, `Color`, `Spacer`, `Divider`,
  `ForEach` (over `Range<Int>` only), `EmptyView`, `AnyView`.
- Modifier set: `.padding()`, `.foregroundStyle(_:)`,
  `.background(_:)`, `.frame(width:height:alignment:)`,
  `.font(_:)`, `.opacity(_:)`, `.onAppear { }`.
- State types: `@State`, `@Binding`, `@Environment` (only `@State`
  is wired to a single, root re-render in 0.1.0).
- SwiftPM package `swift-web-ui` with four products — `SwiftWebUI`,
  `SwiftWebUIRenderer`, `SwiftWebUIBridge`, `SwiftWebUITooling` —
  declared in [`Package.swift`](./Package.swift).
- JavaScriptKit-only JS bridge: `JSClosure` registry with a
  retain-cycle test; one external JS call (`window.alert`) as a
  proof-of-shape.
- Renderer: graph (`_Graph`, `_ViewOutputs`), single-pass diff,
  sequential DOM patch. No fine-grained reactivity, no batching.
- Tooling: `scripts/serve.sh` builds, bundles, and serves the
  example locally; README has a 5-line quickstart.
- DocC catalog stub with `Getting Started` tutorial and the
  `ViewFundamentals` and `Modifiers` articles.
- OSS tree baseline: `README.md`, `LICENSE` (Apache-2.0),
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant
  v2.1), `SECURITY.md`, `.github/ISSUE_TEMPLATE/`, the
  `.github/PULL_REQUEST_TEMPLATE.md`, and Dependabot configuration.
- Path-hygiene guard [`scripts/lint-paths.sh`](./scripts/lint-paths.sh),
  wired into CI and a pre-PR sweep (enforces
  [`AGENTS.md`](./AGENTS.md) §10).

### Changed

_None. 0.1.0 is the first tagged release; there is no prior version
to compare against._

### Fixed

_None. 0.1.0 is the first tagged release._

### Docs

- Release meta for 0.1.0: this `CHANGELOG.md`,
  [`ReleaseNotes.md`](./ReleaseNotes.md), and
  [`scripts/release.sh`](./scripts/release.sh) (the non-destructive
  release helper that the owner runs by hand).
- [`ROADMAP.md`](./ROADMAP.md) v0.1.0 section is the source of truth
  for the stop conditions and the user-visible capability.

[Unreleased]: #unreleased
[0.1.0]: #010---2026-06-11
