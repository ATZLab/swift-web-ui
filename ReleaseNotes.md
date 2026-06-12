# Release notes — 0.1.0

> **SwiftWebUI 0.1.0** — "Hello, web in Swift."
> Released 2026-06-11. See [`CHANGELOG.md`](./CHANGELOG.md) for the
> Keep-a-Changelog form, and [`ROADMAP.md`](./ROADMAP.md) §v0.1.0
> for the milestone this release was judged against.

## What is 0.1.0

0.1.0 is the **proof of shape** for SwiftWebUI. The product compiles
for `wasm32-unknown-wasi`, ships a graph-based renderer plus a
JavaScriptKit bridge, and renders a SwiftUI-style `View` to real DOM
nodes in a browser. The user-visible story is intentionally thin:
write `Text("hi")` in Swift, run a one-shot script, and see
`<div>hi</div>` in a tab. Stack, group, and the bare state model
exist; interaction, animation, lists, and shapes are queued for the
later minors.

0.1.0 is also the **first tagged release**. There is no prior version.
`Upgrade notes` below is kept as a heading for the 0.1.1 PR that
follows.

## User-visible capability

The snippet below is the v0.1.0 example from
[`ROADMAP.md`](./ROADMAP.md) §v0.1.0, reproduced verbatim.

```swift
import SwiftWebUI

struct Hello: View {
    var body: some View {
        VStack {
            Text("Hello, web.")
            Text("From Swift.")
                .foregroundStyle(.secondary)
            @State var count = 0
            Text("count = \(count)")  // static render only in 0.1.0
        }
    }
}
```

This compiles against the `swift-web-ui` SwiftPM package and renders
to a `VStack` of `<div>`s in the browser. `@State` exists in the type
system in 0.1.0; the *re-render-on-change* behavior is the very first
thing 0.2.0 unlocks (see [`ROADMAP.md`](./ROADMAP.md) §v0.2.0).

The full symbol list — signatures, DocC `Discussion` paragraphs, the
SwiftUI counterpart each symbol mirrors, and a working `Example`
snippet per symbol — is the locked v0.1.0 spec at
[`.harness/docs/swift-ui-surface.md`](./.harness/docs/swift-ui-surface.md).
That file is the single source of truth for what ships in 0.1.0;
anything not enumerated there is **not** a 0.1.0 goal. Items listed
as `@_spi(Experimental)` in the spec are SPI, not stable public
surface, and must not be relied on from outside the SwiftWebUI source
tree.

## Upgrade notes

There is no prior tagged version. This section is kept as a heading
so the 0.1.1 PR that follows has a stable anchor. Future 0.x.y
releases will fill it with: symbols renamed or removed, source
compatibility notes, and the migration path for any breaking change
(see [`.harness/docs/release.md`](./.harness/docs/release.md)
§"Banned / required language in release notes" for the policy).

For contributors and downstream consumers: 0.x.y allows
source-breaking changes in `MINOR` (see
[`AGENTS.md`](./AGENTS.md) §"Locked Decisions" §8 and
[`.harness/docs/release.md`](./.harness/docs/release.md) §"Versioning
policy"). Pin to a specific `0.MINOR.PATCH` rather than a minor
range.

## Stop conditions

0.1.0 was judged against the v0.1.0 stop conditions in
[`ROADMAP.md`](./ROADMAP.md) §v0.1.0:

- [x] `swift test` green on the matrix.
- [x] `swift build --triple wasm32-unknown-wasi` produces a binary.
- [x] `./scripts/serve.sh` serves a working "Hello, web" example.
- [x] Playwright smoke passes in CI.
- [x] `swift package generate-documentation` 0 warnings.
- [x] `README.md`, `CONTRIBUTING.md`, `CoC`, `LICENSE` exist.
- [x] `CHANGELOG.md` and `ReleaseNotes.md` (0.1.0) exist.
- [x] All public surface symbols have a DocC comment and a test.
- [x] `scripts/lint-paths.sh` (path-hygiene guard) is wired into
      CI and is green — see [`AGENTS.md`](./AGENTS.md) §10.

The verbatim list of stop conditions is the contract; the checkmarks
above reflect the state at tag time and are the basis on which the
release owner cuts the `0.1.0` tag via
[`scripts/release.sh`](./scripts/release.sh).
