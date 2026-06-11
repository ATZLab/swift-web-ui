# Naming — Apple-like Swift naming for SwiftWebUI

> Owner: `swiftwebui-architect`. Doc owner: `swiftwebui-docs`.
> Every PR touching `Sources/SwiftWebUI/**` is checked against this file.

## Principle

If SwiftUI has a name for it, **use the same name**. If SwiftUI has
no analogue (because it's web-only), pick the shortest name an iOS
engineer would guess. Never rename a SwiftUI type.

## Rules

### 1. Use SwiftUI's exact names for compatible APIs

These names are **reserved and stable** in SwiftWebUI's public API:

| SwiftUI | SwiftWebUI | Notes |
|---|---|---|
| `protocol View { associatedtype Body; @ViewBuilder var body: Body { get } }` | identical | canonical |
| `@resultBuilder ViewBuilder` | identical | |
| `Text(_:)` | identical | String, not LocalizedStringKey, in 0.1.0 |
| `Image(_:)` | identical | web URL string |
| `Color` | identical | `.red` / `.blue` / `.hex(0xRRGGBB)` |
| `Spacer()` | identical | |
| `Divider()` | identical | |
| `VStack`, `HStack`, `ZStack` | identical | |
| `Group` | identical | |
| `ForEach(_:content:)` | identical | |
| `EnvironmentValues`, `EnvironmentKey` | identical | |
| `@State`, `@Binding`, `@Environment` | identical | property wrappers |
| `View` modifiers as View extensions | identical | `.padding()`, `.foregroundStyle(_:)`, … |
| `Alignment` | identical | `.center`, `.leading`, `.top`, … |
| `EdgeInsets` | identical | |
| `CGFloat` | identical | (Double-backed on wasm32) |

### 2. Modifiers are View extension methods

Mod chain in SwiftUI order:

```swift
Text("hi")
    .font(.title)
    .foregroundStyle(.red)
    .padding()
    .background(.yellow)
    .cornerRadius(8)
```

Modifiers return `some View`, never the original type — this is what
enables the chain.

### 3. Use typealiases over renaming

If a name is already taken in another module the user is likely to
import alongside SwiftWebUI (SwiftUI, Foundation, JavaScriptKit), use
a module-qualified alias and re-export the SwiftUI name when the
implementation allows.

```swift
// preferred
public typealias Color = SwiftWebUI.Color

// discouraged (breaks the chain)
public struct SwiftWebUIColor { … }
```

### 4. Parameter labels match SwiftUI

If SwiftUI has `.padding(_ length: CGFloat)`, we have
`.padding(_ length: CGFloat)`. If SwiftUI has
`.padding(.horizontal, 8)`, we have
`.padding(.horizontal, 8)`. Label-arity fidelity matters.

### 5. Avoid the second-person

- DocC tone: declarative, Apple guide style.
- Avoid "you can…", "this allows you to…". Use "calls the action
  closure when tapped", "lays out children in a vertical stack".
- See `docc.md` for the full comment template.

### 6. SPI for unstable surface

Unstable / in-progress public-but-not-final surface is gated:

```swift
@_spi(Experimental)
public struct GeometryReader<Content: View>: View { … }
```

The string inside `(_:)` is the SPI tag. Pick a single project-wide
tag (`Experimental`) for now. Once 0.2.0 stabilises, drop the SPI.

### 7. Disallowed public names

These are **banned** in the public surface:

- `Tokamak*` (anything starting with `Tokamak`)
- `*Compat` (e.g. `ColorCompat`, `ViewCompat`) — instead, fix the
  implementation to match SwiftUI.
- `*SwiftWebUI*` as a prefix on a SwiftUI-equivalent type name —
  use the SwiftUI name with our module qualifier.
- `JS*` (anything that leaks JavaScriptKit into the public API).
  JavaScriptKit types are internal to the bridge module.

## Cross-checks for PR review

The architect and docs agent run this checklist on every PR:

- [ ] All public symbol names match SwiftUI's name (or have a
      documented divergence in this file).
- [ ] All public modifiers are View extension methods returning
      `some View`.
- [ ] No `Tokamak*` or Tokamak-era bundler references in public
      surface.
- [ ] No JavaScriptKit types in public surface.
- [ ] All parameter labels match SwiftUI's labels for the same
      operation.
- [ ] Unstable surface is `@_spi(Experimental)`.
- [ ] DocC comments use Apple guide tone.
