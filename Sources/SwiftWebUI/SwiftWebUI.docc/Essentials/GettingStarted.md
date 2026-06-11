# Getting started

> Status: stub. A fully runnable version of this article lands in
> 0.2.0, when the renderer and bridge are wired end-to-end. The 0.1.0
> surface is documented in
> `.harness/docs/swift-ui-surface.md`; the milestone plan is in
> `ROADMAP.md`.

## What is SwiftWebUI

SwiftWebUI is an open-source, SwiftUI-style declarative UI framework
for the web. It targets `wasm32` and renders to the DOM through
JavaScriptKit. Where SwiftUI and SwiftWebUI overlap, the names and
shapes match exactly; the web shows up only at the `import` boundary
and the `Web.*` extension points.

The project is the spiritual successor to TokamakUI, which is
officially deprecated along with the Tokamak-era bundler.
SwiftWebUI replaces both with a single, actively-maintained
dependency: JavaScriptKit. The dependency policy is a locked
decision in `AGENTS.md` §5.

The 0.1.0 release is the **proof of shape**: a `Text` inside a
`VStack` inside a `View` compiles, runs in a browser, and renders
to the DOM through a single-pass graph diff. State, controls, and
animation arrive in 0.2.0 and later; the full sequence is in
`ROADMAP.md`.

## Hello, web in Swift

A first SwiftWebUI screen is a `View` whose `body` describes the
DOM to produce. The walkthrough below is the smallest end-to-end
shape the 0.1.0 release supports.

```swift
import SwiftWebUI

struct Hello: View {
    var body: some View {
        VStack {
            Text("Hello, web")
                .font(.title)
                .foregroundStyle(.blue)
        }
    }
}
```

The view renders to a `<div>` containing a single `<div>` with the
text `Hello, web`, painted in blue at the title size. There is no
`UIView`, no `UIViewController`, and no scene; the host page
mounts the root view into a DOM node, and the renderer patches the
tree from there.

To run it locally:

1. Add `SwiftWebUI` to a SwiftPM `Package.swift` as a dependency.
2. Build the `web` target with
   `swift build --triple wasm32-unknown-wasi`.
3. Run `./scripts/serve.sh` to bundle the wasm and the JS shim, and
   serve the host page on `localhost`.
4. Open the URL the script prints; the rendered DOM contains the
   `Hello, web` line.

## Where to go next

- `.harness/docs/swift-ui-surface.md` — the per-symbol catalog of
  the 0.1.0 surface, owned by the architect.
- `ROADMAP.md` — the 0.2.0 milestone plan and what each release
  unlocks.
- ``View`` and ``View/body`` — the protocol and the property every
  SwiftWebUI screen starts from.
- <doc:ViewFundamentals> — the long-form overview of the `View`
  protocol.
- <doc:Modifiers> — the 0.1.0 modifier set and how to chain it.
