# DocC — Documentation contract

> Owner: `swiftwebui-docs`. Tone review: `swiftwebui-docs`.
> Builds: `swift package generate-documentation` must complete with
> zero warnings.

## DocC comment style

Every public symbol ships with a `///` DocC comment. Non-trivial
public types and functions add `## Discussion` and `## Example`
sections.

### Template (single line OK for trivial)

```swift
/// A control that performs an action when tapped.
///
/// Use `Button` to expose an action in response to user
/// interaction. The label is rendered as the button's children.
public struct Button<Label: View>: View { … }
```

### Template (full)

```swift
/// A control that performs an action when tapped.
///
/// `Button` renders as a `<button>` element and dispatches a
/// synthetic `click` event to the supplied closure.
///
/// ## Overview
///
/// Buttons present a tappable surface and a label. The label is
/// any `View`; the action closure is called when the user clicks
/// or activates the button.
///
/// ## Example
///
/// ```swift
/// Button("Save") {
///     store.save()
/// }
/// .padding()
/// ```
///
/// - Parameters:
///   - title: The button's visible label.
///   - action: The closure invoked on activation.
public init(_ title: String, action: @escaping () -> Void) { … }
```

## Tone rules (Apple guide style)

- **Declarative**, not imperative. Describe behaviour, not the
  reader. Avoid "you can…", "this allows you to…", "we…", "I…".
- **Third-person, present tense**. "Calls the action closure when
  tapped." not "When you tap, it calls the action closure."
- **No marketing fluff.** No "powerful", "lightning-fast",
  "intuitive", "next-generation".
- **No second person.** No "you", "your".
- **Specific over general.** "Lays out children in a vertical
  line" over "lays out children".
- **Short sentences.** Average ≤ 18 words.

## Catalog (`.docc/`)

The DocC catalog root lives in `.docc/SwiftWebUI.docc/`. Each
subdirectory is a tutorial or article. Required catalog entries
for 0.1.0:

- `GettingStarted.md` — install, first `Text("Hello")`, first
  `VStack`.
- `ViewFundamentals.md` — `View` protocol, `body`, `@ViewBuilder`.
- `Modifiers.md` — how to chain modifiers, the canonical list.
- `WebInterop.md` — how to call a JS API from Swift (forwarded to
  the bridge agent).
- `ReleaseNotes.md` — generated from `.harness/changelogs/`.

The `swiftwebui-docs` agent owns the catalog contents. The
`swiftwebui-steward` agent owns the GitHub Pages deploy workflow
that publishes the built site.

## DocC build

```bash
swift package generate-documentation \
    --target SwiftWebUI \
    --output-path .build/docs
```

CI fails on:

- A public symbol with no `///` comment.
- A DocC warning of any kind.
- A broken cross-reference (`<doc:…>` that doesn't resolve).

The `swiftwebui-docs` agent owns the warning list and triages
fixes.

## Tied to TDD

A new public symbol without a DocC comment fails the
`swiftwebui-tester` red-flag rule (`tdd.md`).

## Tied to naming

A DocC comment that mentions a non-Apple-style alternative name
(e.g. "this is like SwiftUI's `…` but called `…`") fails the
naming checklist in `naming.md`.
