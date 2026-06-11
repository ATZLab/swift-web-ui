# SwiftUI surface — v0.1.0 public API

> Owner: `swiftwebui-architect` (gate for any public API change).
> Test owner: `swiftwebui-tester`.
> Doc owner: `swiftwebui-docs`.
> Source of truth: this file is the **canonical v0.1.0 surface**;
> any symbol not listed here is **not** a 0.1.0 goal. Locked as
> `AGENTS.md` §11 — changes require an architect PR.

This document is the per-symbol catalog that `swiftwebui-docs` will
turn into DocC articles and that the SwiftWebUI maintainers will
copy into `///` doc comments on the source files. Signatures are
Swift declarations with **no body**; Discussion paragraphs follow
the Apple guide tone rules in `.harness/docs/docc.md`
(declarative, no second person, no marketing copy); the
**Mirrors SwiftUI** field names the SwiftUI counterpart (or
states that there is no SwiftUI equivalent and the symbol is
SwiftWebUI-only); the **Example** field is a single working
Swift snippet.

The 0.1.0 surface is the **proof of shape**, not the proof of
feature. It is what the first `Hello, web in Swift` example
exercises. Renderer is graph-based (VDOM-style); state changes
do not yet re-render. That is 0.2.0's job. The full stop
conditions for 0.1.0 live in `ROADMAP.md` §"v0.1.0".

---

## How to read this document

Each entry has the same shape:

```
### `SymbolName`

```swift
public declaration
```

Discussion paragraph (1-3 sentences, Apple guide tone).

**Mirrors SwiftUI:** SwiftUI equivalent or "no SwiftUI
equivalent; SwiftWebUI-only".

**Example:**

```swift
// one-line Swift snippet
```

Symbols are grouped by role: **Core protocol and combinators**,
**Leaf views**, **Container views**, **State and binding**,
**Environment**, **Modifiers**, and **Escape hatches**.

The **SPI in 0.1.0** subsection lists everything that is
`@_spi(Experimental)` and therefore not part of the stable
0.1.0 contract.

---

## 1. Core protocol and combinators

The protocol a user implements to produce a view, the
`@ViewBuilder` that turns a block into a tuple of children, and
the result types for empty / single-child / ten-child content.

### `View`

```swift
public protocol View {
    associatedtype Body: View
    @ViewBuilder var body: Self.Body { get }
}
```

The unit of declarative UI. A type conforms to `View` by
declaring a `body` that returns a tree of other `View`s. The
framework walks the tree to produce a renderer graph; users
never see the graph directly.

**Mirrors SwiftUI:** identical to SwiftUI's `View` protocol.
SwiftUI's `View` is wider (e.g. default `body` requirement for
*never*-modifying leaves is provided by extensions), but the
core associated-type + property shape is the same.

**Example:**

```swift
struct Hello: View {
    var body: some View { Text("hi") }
}
```

### `ViewBuilder`

```swift
@resultBuilder
public struct ViewBuilder {
    public static func buildBlock<C0: View>(_ c0: C0) -> some View
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> some View
    // … overloads through buildBlock<C0, …, C9>
    public static func buildIf<Content: View>(_ content: Content?) -> some View
    public static func buildEither<True: View, False: View>(first: True) -> _ConditionalContent<True, False>
    public static func buildEither<True: View, False: View>(second: False) -> _ConditionalContent<True, False>
}
```

The result builder that turns the children of a container
(`VStack { … }`, `Group { … }`, the `body` getter) into a single
value. Supports up to ten unconditioned children, an `if`
without an `else` (via `buildIf`), and an `if` / `else`
(via `buildEither`).

**Mirrors SwiftUI:** identical to SwiftUI's `ViewBuilder`. The
0.1.0 overload set is intentionally minimal — the same set
SwiftUI ships in its public surface for 10-or-fewer children.

**Example:**

```swift
VStack {
    Text("one")
    Text("two")
    if isLoggedIn { Text("secret") }
}
```

### `_ConditionalContent`

```swift
@_spi(SwiftWebUI)
public struct _ConditionalContent<True: View, False: View>: View {
    public var body: Never { get }
}
```

The erased representation of an `if` / `else` inside a
`@ViewBuilder` block. Users see the value as `some View`; the
concrete type leaks only into the graph and the renderer
implementation.

**Mirrors SwiftUI:** SwiftUI has the same `_ConditionalContent`
internal type; its surface is `@_spi` and identical in shape.

**Example:** not user-writable. Produced by `buildEither`.

### `TupleView`

```swift
@_spi(SwiftWebUI)
public struct TupleView<Tuple: View>: View { … }
```

Holds a tuple of up to ten children produced by `ViewBuilder`
overloads. The renderer pattern-matches on `TupleView` to walk
its children.

**Mirrors SwiftUI:** SwiftUI ships the same `TupleView` shape
internally; the public API of SwiftWebUI keeps it SPI for
now and will demote it to internal when the graph is private.

**Example:** not user-writable. Produced by `buildBlock`.

---

## 2. Leaf views

Views that render exactly one DOM node (or one inert node in
the case of `EmptyView`).

### `Text`

```swift
public struct Text: View {
    public init(_ content: String)
    public init(verbatim content: String)
    public var body: some View { /* never */ }
}
```

A read-only line of UTF-8 text. `Text("hi")` renders to a
`<div>` whose `textContent` is `hi`. `Text(verbatim:)` treats
its content as a literal — there is no `LocalizedStringKey` in
0.1.0.

**Mirrors SwiftUI:** SwiftUI's `Text` initializer signature
differs (`Text(_ content: some StringProtocol)`,
`Text(_ key: LocalizedStringKey)`, `Text(verbatim:)`). The
0.1.0 SwiftWebUI surface accepts `String` only; `verbatim:` is
shipped for parity with SwiftUI's verbatim form but is
behaviourally identical to `init(_ content: String)` in 0.1.0
(no `LocalizedStringKey` semantics yet).

**Example:**

```swift
Text("Hello, web.")
```

### `Image`

```swift
public struct Image: View {
    public init(_ src: String)
    public var body: some View { /* never */ }
}
```

A web image referenced by URL string. `Image("/cat.png")`
renders to `<img src="/cat.png" alt="">` with an empty `alt`
attribute in 0.1.0 (a11y is a 0.3.0 concern).

**Mirrors SwiftUI:** SwiftUI's `Image` takes a `String` for
system-image names or an `Image` asset reference. SwiftWebUI's
`Image` takes a URL string — closer to HTML's `<img src=…>`
than to UIKit's `UIImage(named:)`.

**Example:**

```swift
Image("/cat.png")
```

### `Color`

```swift
public struct Color: View, Hashable, Sendable {
    public static let red: Color
    public static let blue: Color
    public static let green: Color
    public static let black: Color
    public static let white: Color
    public static let gray: Color
    public static let clear: Color
    public static let primary: Color
    public static let secondary: Color

    public init(hex: UInt32)
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1)
    public var body: some View { /* never */ }
}
```

An sRGB colour. The named set is a **deliberately small,
declarative** subset of SwiftUI's `Color`: the eight CSS named
hues that survive a design-system audit, plus the two
hierarchical colours (`.primary`, `.secondary`) that mirror
SwiftUI's adaptive text colours and map to CSS
`color: CanvasText` / `color: GrayText` in 0.1.0. The `hex:`
and `rgb:` initialisers cover everything else.

`Color` conforms to `View` so it can stand alone in a
container: `VStack { Color.red }` produces a single `<div>`
filled red.

**Mirrors SwiftUI:** SwiftUI's `Color` has a much larger named
palette (`.indigo`, `.mint`, `.teal`, …). SwiftWebUI's 0.1.0
ships only the eight CSS named hues plus `.primary` and
`.secondary`. The full SwiftUI palette is a 0.2.0+ add; the
rationale is in `naming.md` §7 (no `*Compat` types).

**Example:**

```swift
Text("warning")
    .foregroundStyle(.red)
    .background(Color(hex: 0xFFEEAA))
```

### `Spacer`

```swift
public struct Spacer: View {
    public init(minLength: CGFloat? = nil)
    public var body: some View { /* never */ }
}
```

A flexible, transparent space that grows to fill the available
room along the parent stack's main axis. In 0.1.0 the
`minLength` parameter is accepted and stored; layout is
"stretch to fill" — there is no real flex algorithm yet (0.4.0
goal). A `Spacer` without a parent stack renders as an empty
invisible view.

**Mirrors SwiftUI:** identical to SwiftUI's `Spacer`.

**Example:**

```swift
HStack {
    Text("left")
    Spacer()
    Text("right")
}
```

### `Divider`

```swift
public struct Divider: View {
    public init()
    public var body: some View { /* never */ }
}
```

A thin horizontal line. Renders to `<div class="swui-divider"
role="separator">` in 0.1.0 — the CSS hook is provided by
the host page's default stylesheet (tooling's job, not
architect's).

**Mirrors SwiftUI:** identical to SwiftUI's `Divider`.

**Example:**

```swift
VStack {
    Text("above")
    Divider()
    Text("below")
}
```

### `EmptyView`

```swift
public struct EmptyView: View {
    public init()
    public var body: some View { /* never */ }
}
```

A view that renders nothing. Useful as a placeholder return
value for branches of `body` that have no meaningful content
(0.1.0 example: a `Group` whose `if` produces no children in
the false branch). The graph has no node for `EmptyView`; it
is collapsed at graph-build time.

**Mirrors SwiftUI:** identical to SwiftUI's `EmptyView`.

**Example:**

```swift
@ViewBuilder
func header() -> some View {
    if showTitle { Text(title) } else { EmptyView() }
}
```

---

## 3. Container views

Views that lay out zero or more children.

### `VStack`

```swift
public struct VStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)
    public var body: some View { /* never */ }
}
```

A vertical stack of children. `alignment` is the cross-axis
alignment (`.leading`, `.center`, `.trailing`); `spacing` is
the inter-child gap in CSS pixels (nil = the host page's
default, 8px in the default stylesheet shipped with
`./scripts/serve.sh`).

Renders to `<div class="swui-vstack">` with each child in a
child `<div>`. The CSS flex direction is `column`; alignment
maps to `align-items`.

**Mirrors SwiftUI:** identical signature to SwiftUI's `VStack`.
SwiftUI's spacing unit is the system point; SwiftWebUI uses
`CGFloat` (Double on wasm32), one CSS pixel per unit.

**Example:**

```swift
VStack(alignment: .leading, spacing: 12) {
    Text("title")
    Text("subtitle")
}
```

### `HStack`

```swift
public struct HStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content)
    public var body: some View { /* never */ }
}
```

A horizontal stack of children. `alignment` is the cross-axis
alignment (`.top`, `.center`, `.bottom`); `spacing` is the
inter-child gap in CSS pixels.

Renders to `<div class="swui-hstack">` with each child in a
child `<div>`. CSS flex direction is `row`; alignment maps to
`align-items`.

**Mirrors SwiftUI:** identical to SwiftUI's `HStack`.

**Example:**

```swift
HStack(spacing: 8) {
    Image("/logo.png")
    Text("Acme")
}
```

### `ZStack`

```swift
public struct ZStack<Content: View>: View {
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content)
    public var body: some View { /* never */ }
}
```

Overlaps children at the same origin. `alignment` is the
two-dimensional anchor (`.topLeading`, `.center`, `.bottom`,
…). In 0.1.0 the renderer places every child at the stack's
`alignment` and CSS `position: absolute` carries the rest.

**Mirrors SwiftUI:** identical to SwiftUI's `ZStack`.

**Example:**

```swift
ZStack(alignment: .bottomTrailing) {
    Image("/photo.jpg")
    Text("© 2026")
        .padding(8)
        .background(.black)
        .foregroundStyle(.white)
}
```

### `Group`

```swift
public struct Group<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
    public var body: some View { /* never */ }
}
```

A transparent container. `Group` introduces no DOM node of
its own; its children are flattened into the parent at
graph-build time. Useful for grouping children to satisfy a
`@ViewBuilder` arity limit (e.g. ten) without adding layout
structure.

**Mirrors SwiftUI:** identical to SwiftUI's `Group`.

**Example:**

```swift
Group {
    Text("a")
    Text("b")
    Text("c")
}
```

### `ForEach`

```swift
public struct ForEach<Data: View, ID: View>: View where /* see 0.1.0 constraint */ {
    public init(_ range: Range<Int>, @ViewBuilder content: @escaping (Int) -> Data)
}
```

Iterates over a `Range<Int>` and produces one child per
element, calling the content closure with the index. In 0.1.0
only the `Range<Int>` overload ships; the `Identifiable` and
`Hashable` ID-based overloads arrive in 0.2.0. The 0.1.0
renderer keys children by their index.

**Mirrors SwiftUI:** SwiftUI's `ForEach` has four overloads
(`Range<Int>`, `Data: RandomAccessCollection` with
`Data.Element: Identifiable`, `Data: RandomAccessCollection`
with explicit `id: KeyPath`, and the `enumerated()` form).
SwiftWebUI ships the `Range<Int>` form only in 0.1.0.

**Example:**

```swift
VStack {
    ForEach(0..<3) { i in
        Text("row \(i)")
    }
}
```

---

## 4. State and binding

Property wrappers that participate in the graph's re-render
cycle. In 0.1.0 **only `@State` is wired to a single, root
re-render**; `@Binding` and `@Environment` are present in the
type system so that 0.2.0 work can land without breaking
source, but they do not yet propagate changes. Calling
`wrappedValue` returns the current value; the setter exists
but is a no-op for re-render in 0.1.0.

### `@State`

```swift
@propertyWrapper
public struct State<Value>: DynamicProperty {
    public init(wrappedValue: Value)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }
}
```

A value owned by the view. The initial value is captured at
first render. In 0.1.0 mutating `wrappedValue` updates the
backing storage and **triggers a single, full re-render of the
root view tree** — the 0.2.0 work will turn this into a
subtree-scoped, batched re-render.

**Mirrors SwiftUI:** identical shape to SwiftUI's `@State`.
The "subtree-scoped, batched" re-render behaviour is a
SwiftWebUI 0.2.0 concern; SwiftUI gets that for free because
it owns the runtime.

**Example:**

```swift
struct Counter: View {
    @State var count = 0
    var body: some View {
        Text("count = \(count)")
    }
}
```

### `@Binding`

```swift
@propertyWrapper
public struct Binding<Value>: DynamicProperty {
    public init(wrappedValue: Value)
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void)
    public var wrappedValue: Value { get nonmutating set }
    public var projectedValue: Binding<Value> { get }
    public static func constant(_ value: Value) -> Binding<Value>
}
```

A two-way reference to a value owned elsewhere. In 0.1.0 the
getter / setter functions are stored and called; there is no
notification back to the renderer on `wrappedValue` change.
The `Binding.constant(_:)` initialiser produces a non-mutating
binding, useful for previewing a view that takes a binding
without owning state.

**Mirrors SwiftUI:** identical shape to SwiftUI's `@Binding`.

**Example:**

```swift
struct LabeledCounter: View {
    @Binding var count: Int
    var body: some View { Text("\(count)") }
}

struct Parent: View {
    @State var n = 0
    var body: some View { LabeledCounter(count: $n) }
}
```

### `@Environment`

```swift
@propertyWrapper
public struct Environment<Value>: DynamicProperty {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>)
    public var wrappedValue: Value { get }
}
```

Reads a value from the `EnvironmentValues` carried down the
view tree. In 0.1.0 the lookup is performed at render time;
mutating the environment at the root of a re-render causes
children to see the new value on their next access. There is
no per-environment-key subscription in 0.1.0 — that is 0.2.0.

**Mirrors SwiftUI:** identical shape to SwiftUI's
`@Environment(_:)`.

**Example:** see `Environment` below.

---

## 5. Environment

The cross-tree, read-only value bag that `@Environment` reads
from.

### `EnvironmentValues`

```swift
public struct EnvironmentValues {
    public init()
    public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value { get set }
}
```

A bag of values keyed by `EnvironmentKey`. SwiftWebUI ships
the empty bag in 0.1.0; concrete keys (`.colorScheme`,
`.locale`, …) are 0.2.0+. The `subscript` API matches SwiftUI's
so adding a key later is non-breaking.

**Mirrors SwiftUI:** identical shape to SwiftUI's
`EnvironmentValues`.

**Example:**

```swift
@Environment(\.colorScheme) var scheme  // 0.2.0+
```

### `EnvironmentKey`

```swift
public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
```

The recipe for a new environment value. A new key in 0.1.0 is
SPI; promoting a key to public is the work of the minor that
ships the corresponding feature.

**Mirrors SwiftUI:** identical to SwiftUI's `EnvironmentKey`.

**Example:**

```swift
struct MyKey: EnvironmentKey {
    static let defaultValue: String = "hello"
}
```

### `Environment`

```swift
@frozen
public struct Environment<Value>: DynamicProperty {
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>)
    public var wrappedValue: Value { get }
}
```

The property wrapper. (Declared as `@frozen` so that the
key-path encoding of the key is stable across compiler
versions; this matches SwiftUI.)

**Mirrors SwiftUI:** identical to SwiftUI's
`@Environment(_:)`.

**Example:** see `@Environment` above.

---

## 6. Modifiers

View extension methods. Each returns `some View` (never the
original type) so chains compose. All modifiers in 0.1.0 are
**order-preserving**; the renderer applies them in chain order
at graph-build time.

### `.padding(_:)`

```swift
extension View {
    public func padding(_ insets: EdgeInsets) -> some View
}
```

Wraps the view in a `<div>` with the given CSS padding. The
result is `some View`; the padding wrapper introduces a single
DOM node. Use this overload when the four edges are
asymmetric.

**Mirrors SwiftUI:** identical to SwiftUI's
`.padding(_ insets: EdgeInsets)`.

**Example:**

```swift
Text("hi").padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
```

### `.padding()`

```swift
extension View {
    public func padding() -> some View
    public func padding(_ length: CGFloat) -> some View
    public func padding(_ edges: Edge.Set, _ length: CGFloat? = nil) -> some View
}
```

The no-argument form uses the host page's default inset (16px
on the default stylesheet). The single-argument form uses one
length on all four edges. The `(_ edges:, _ length:)` form
applies padding to a subset of edges (e.g. `.horizontal`,
`.top`).

**Mirrors SwiftUI:** identical to SwiftUI's `.padding()`
overloads.

**Example:**

```swift
Text("hi").padding()
Text("hi").padding(8)
Text("hi").padding(.horizontal, 12)
```

### `.foregroundStyle(_:)`

```swift
extension View {
    public func foregroundStyle(_ style: some ShapeStyle) -> some View
}
```

Sets the text colour for descendants. In 0.1.0 the only
accepted `ShapeStyle` is `Color`. The renderer writes the
resulting CSS color into the `style` attribute of the
descendant text `<div>`.

**Mirrors SwiftUI:** identical to SwiftUI's
`.foregroundStyle(_:)`.

**Example:**

```swift
Text("warning").foregroundStyle(.red)
```

### `.background(_:)`

```swift
extension View {
    public func background<S: ShapeStyle>(_ style: S) -> some View
    public func background<V: View>(_ view: V, alignment: Alignment = .center) -> some View
}
```

Two overloads. The first paints a solid colour (or
`HierarchicalShapeStyle`) behind the view. The second places
a `View` behind the receiver, aligned. In 0.1.0 the second
overload is wired to a real DOM `<div>` wrapper; a 0.2.0
follow-up will let it use a single `::before` pseudo-element
to avoid an extra wrapper.

**Mirrors SwiftUI:** identical to SwiftUI's `.background(_:)`
overloads.

**Example:**

```swift
Text("hi")
    .padding(8)
    .background(.yellow)
```

### `.frame(width:height:alignment:)`

```swift
extension View {
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View
}
```

Proposes a fixed width and / or height to the view. In 0.1.0
the renderer emits the values as inline CSS
(`width: <px>px; height: <px>px;`) and trusts the browser
layout. `nil` means "no proposal on that axis". Alignment is
stored but only affects children that opt in (a 0.4.0
`GeometryReader` concern).

**Mirrors SwiftUI:** identical to SwiftUI's
`.frame(width:height:alignment:)`.

**Example:**

```swift
Image("/logo.png").frame(width: 64, height: 64)
```

### `.font(_:)`

```swift
public enum Font: Hashable, Sendable {
    case largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2
    case system(size: CGFloat, weight: Font.Weight = .regular)
    public enum Weight: Hashable, Sendable { case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black }
}

extension View {
    public func font(_ font: Font?) -> some View
}
```

The 0.1.0 font system is a small SwiftUI-shaped enum
(`largeTitle`, `title`, …) plus a `system(size:weight:)`
escape hatch. The renderer maps the named cases to a host
stylesheet (shipped by tooling) that defines the CSS sizes;
the `system(size:weight:)` case emits an inline
`font-size: <px>px; font-weight: <n>;` style.

`font(_:)` accepts a `nil` to reset to the default; this
matches SwiftUI.

**Mirrors SwiftUI:** the shape is a subset of SwiftUI's
`Font`. SwiftUI's `Font` also supports `.custom(_:size:)`,
`Font.Design` (`.serif`, `.monospaced`), and dynamic-type
scaling. Those are 0.2.0+.

**Example:**

```swift
Text("title").font(.title)
Text("body").font(.system(size: 14, weight: .regular))
```

### `.opacity(_:)`

```swift
extension View {
    public func opacity(_ opacity: Double) -> some View
}
```

Sets the CSS `opacity` of the view. The argument is clamped
to `[0, 1]` at graph-build time.

**Mirrors SwiftUI:** identical to SwiftUI's `.opacity(_:)`.

**Example:**

```swift
Text("faded").opacity(0.5)
```

### `.onAppear(_:)`

```swift
extension View {
    public func onAppear(perform action: @escaping () -> Void) -> some View
}
```

Registers a closure to be invoked **once**, the first time
the view appears in the rendered DOM. In 0.1.0 the closure is
called after the first mount commit; subsequent re-renders
(of the same view identity at the same DOM node) do **not**
re-invoke it. There is no `onDisappear` in 0.1.0 — view
teardown is not observable from the Swift side.

**Mirrors SwiftUI:** identical to SwiftUI's
`.onAppear(perform:)`.

**Example:**

```swift
Text("ready").onAppear { print("mounted") }
```

---

## 7. Escape hatches

Type erasure and supporting types. Use sparingly — each is a
backpressure signal that the right generic is missing.

### `AnyView`

```swift
public struct AnyView: View {
    public init<V: View>(_ view: V)
    public var body: some View { /* never */ }
}
```

Type-erased view. Wraps any `View` in a box that hides its
concrete type. Use `AnyView` only when the type system cannot
express the return type — for example, a property on a
non-generic type that must return one of several view types
based on a stored value. In 0.1.0 the renderer pays an extra
hop on every `AnyView` mount; the 0.2.0 work will amortise
this.

**Mirrors SwiftUI:** identical to SwiftUI's `AnyView`.

**Example:**

```swift
struct Switcher: View {
    let useTitle: Bool
    var body: AnyView {
        if useTitle { AnyView(Text("title")) }
        else { AnyView(Image("/logo.png")) }
    }
}
```

> **Backpressure signal.** Whenever a PR adds an `AnyView`,
> the architect and the docs agent flag the use site and
> propose a generic (`some View` + a `ViewBuilder` function,
> or a discriminated `enum` with a `body` switch). `AnyView`
> in 0.1.0 is real but opt-in.

---

## 8. SPI in 0.1.0

The following surface is `@_spi(Experimental)` in 0.1.0.
Treat it as a draft — signatures may change, names may change,
semantics may change. **Do not** depend on SPI from outside
the SwiftWebUI source tree. Promoting a symbol to public
requires an architect PR and a test.

| Symbol | Reason for SPI in 0.1.0 |
|---|---|
| `Layout` protocol | Spec is still being aligned with SwiftUI's 0.5+ `Layout`; ship as SPI first. |
| `GeometryReader` | Depends on `Layout` and a real flex engine (0.4.0). |
| `Shape` protocol | Depends on a 2D path engine; `Rectangle` and `Circle` are 0.4.0. |
| `Path` 2D API | Same as `Shape`. |
| `ViewModifier` | Modifiers are shipped as View extensions in 0.1.0; the protocol lands when there is a need to bundle modifiers. |
| Animation primitives | 0.3.0 work — depends on a frame-driven diff loop. |
| Accessibility hooks | 0.3.0 work — depends on a stable renderer graph. |
| `Button`, `TextField` | 0.2.0 work — depend on a stable event-delegation path. |

`@_spi(Experimental)` symbols may ship tests in the same
commit as their implementation (the TDD red→green cycle is
encouraged but not enforced for SPI; see `.harness/docs/tdd.md`
§"What is not a TDD violation"). They MUST ship with DocC
comments and a test before they can be promoted to public.

---

## 9. Disallowed public surface (locked)

The following is **not** part of the 0.1.0 contract and MUST
NOT be added to the public API without an architect PR:

- Anything that exposes a `JavaScriptKit` type (`JSClosure`,
  `JSFunction`, `JSValue`, `JSObject`, …) in the public
  surface. Bridge types are `@_spi(SwiftWebUI)` and live in
  `Sources/SwiftWebUIBridge/`.
- Any type whose name does not match its SwiftUI counterpart
  when such a counterpart exists. The disambiguation table in
  `.harness/docs/naming.md` §7 is authoritative.
- `Tokamak*` imports or types, in any form, in the public
  surface. See `AGENTS.md` §5.
- `*Compat` suffixes (`ColorCompat`, `ViewCompat`, …). Fix
  the implementation to match SwiftUI instead.
- A second JS-bridge dependency. JavaScriptKit is the only
  allowed interop; see `AGENTS.md` §5 and
  `.harness/docs/js-bridge.md`.

A PR that adds a banned symbol is rejected at review by the
architect; the steward reverts it on `main` if it lands.

---

## 10. Acceptance for 0.1.0 (per symbol)

Each public symbol in this document ships only when all five
are true:

1. The symbol exists in `Sources/SwiftWebUI/` (or
   `Sources/SwiftWebUIRenderer/` for renderer-internal SPI,
   marked `@_spi(SwiftWebUI)`).
2. A DocC comment is present: `///` summary + a `## Discussion`
   paragraph for non-trivial types + an `## Example` snippet
   that compiles against the public surface.
3. At least one `swift-testing` `@Test` covers the symbol in
   `Tests/SwiftWebUITests/`. The PR history must show
   red → green for that test pair.
4. If the symbol produces DOM (Text, VStack, Image, etc.) a
   snapshot test lives in `Tests/SwiftWebUISnapshots/`. The
   snapshot file is committed; a snapshot diff is a deliberate
   PR with a "WHY" line in the description.
5. The architect (`swiftwebui-architect`) and the tester
   (`swiftwebui-tester`) have signed off on the PR.

The SwiftUI name parity check (rule 1 in `naming.md`) is
performed by the docs agent as a final pre-merge sweep.

---

## 11. Reference

- Naming rules and SwiftUI ↔ SwiftWebUI disambiguation:
  `.harness/docs/naming.md`.
- TDD contract (red → green, snapshot policy, CI matrix):
  `.harness/docs/tdd.md`.
- DocC contract (`///` + `## Discussion` + `## Example`,
  Apple-voice tone): `.harness/docs/docc.md`.
- Renderer model choice (graph-based / VDOM in 0.1.0):
  `AGENTS.md` §6.
- JavaScriptKit interop rules and the `JSClosure` lifetime
  policy: `.harness/docs/js-bridge.md`.
- Release mechanics and 0.x milestone plan: `.harness/docs/release.md`.
- v0.1.0 stop conditions: `ROADMAP.md` §"v0.1.0".

## 12. How to extend the surface (the architect's protocol)

1. **Open a design note** in `.harness/docs/architecture/`
   (or as a new file referenced from `AGENTS.md`). The note
   states: (a) the SwiftUI symbol you are copying, (b) any
   SwiftUI behaviour you are intentionally not copying in
   0.x, (c) the SPI gate (`@_spi(Experimental)` if the symbol
   is not stable enough to ship unannotated).
2. **Update this file** with a new entry in the appropriate
   section. Follow the same shape: signature, `## Discussion`,
   **Mirrors SwiftUI**, `## Example`.
3. **Open a PR** titled `feature/view-<symbol>-<short>` (or
   `feature/modifier-<symbol>`). The PR description links the
   design note and lists the reviewing reins
   (`swiftwebui-architect`, `swiftwebui-tester`, and
   `swiftwebui-dom-renderer` if it produces DOM).
4. **Get the test pair** in the PR history
   (red → green) before merging.
5. **Get the architect and tester sign-off** recorded in the
   PR description before the owner merges on github.com.

This is the only path for a new public symbol to enter
`Sources/SwiftWebUI/`.
