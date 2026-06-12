# SwiftUI surface — v0.2.0 public API

> Owner: `swiftwebui-architect` (gate for any public API change).
> Test owner: `swiftwebui-tester`.
> Doc owner: `swiftwebui-docs`.
> Source of truth: this file is the **canonical v0.2.0 surface**;
> any symbol not listed here is **not** a 0.2.0 goal. Locked as
> `AGENTS.md` §11 — changes require an architect PR.
>
> v0.1.0 entries are preserved verbatim where their public shape
> is unchanged. v0.2.0 deltas are marked **`(v0.2.0)`** in the
> per-symbol section header and noted in the per-symbol
> Discussion paragraph.

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

The 0.2.0 surface is the **proof of interactivity**, on top of
the 0.1.0 **proof of shape**. State changes re-render the
**subtree** that observed the change (not the full root tree,
as 0.1.0 did). Re-renders are **batched** — one render per
microtask, not per setter. The microtask primitive is pinned
to `Task { @MainActor in ... }` on the Swift concurrency
runtime (see §4 and §8 `_ReRenderScheduler`). `Button`,
`.onTapGesture`, and `TextField` (single-line) are the
user-visible interactive primitives; the underlying
event-delegation path lives in `Sources/SwiftWebUIRenderer/`
and the `JSClosure` lifetime policy lives in
`Sources/SwiftWebUIBridge/`. The full stop conditions for
0.2.0 live in `ROADMAP.md` §"v0.2.0".

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

The **SPI in 0.2.0** subsection (§8) lists everything that is
`@_spi(Experimental)` (public-API-in-waiting) and
`@_spi(SwiftWebUI)` (project-internal) and therefore not part
of the stable 0.2.0 contract.

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

### `Button` **`(v0.2.0)`**

```swift
public struct Button<Label: View>: View {
    public init(_ titleKey: LocalizedStringKey, action: @escaping () -> Void)
    public init<S: StringProtocol>(_ title: S, action: @escaping () -> Void)
    public init(role: ButtonRole?, action: @escaping () -> Void, @ViewBuilder label: () -> Label)
    public init(action: @escaping () -> Void, @ViewBuilder label: () -> Label)
    public var body: some View { /* never */ }
}

public enum ButtonRole: Hashable, Sendable {
    case destructive
    case cancel
}
```

A tappable control. The `(_:action:)` overloads take a string
label and an action; the `(action:label:)` overloads take an
action and a `@ViewBuilder` label. The `role:` parameter
mirrors SwiftUI's role-aware button — `.destructive` and
`.cancel` affect only the accessible name and traits in
0.2.0; visual styling of the role is 0.3.0+.

Tapping the button calls `action()` once per tap. The action
runs on the same microtask that scheduled the tap; mutating
`@State` inside the action triggers the 0.2.0 subtree-scoped
re-render of the view that owns the state. The renderer's
`_RenderEventRegistry` (SPI) installs the DOM `click` listener
on mount and removes it on teardown; `JSClosure` retention is
the 0.2.0 `JSClosure` lifetime contract.

**Mirrors SwiftUI:** identical signature shape to SwiftUI's
`Button`. SwiftUI's `Button` also ships a
`ButtonStyleConfiguration` for styled buttons; the equivalent
in SwiftWebUI is the `ButtonStyle` protocol (SPI in 0.2.0, see
§8). The `LocalizedStringKey` overload is shipped for parity
but the runtime behaviour of localisation is 0.3.0+.

**Example:**

```swift
Button("Save") { save() }
Button(role: .destructive) { delete() } label: { Text("Delete") }
```

### `TextField` **`(v0.2.0)`**

```swift
public struct TextField: View {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>)
    public init<S: StringProtocol>(_ title: S, text: Binding<String>)
    public var body: some View { /* never */ }
}
```

A single-line text input. The `(_:text:)` overloads take a
placeholder string and a `Binding<String>` whose `wrappedValue`
is the field's text. Renders to `<input type="text">`; the
placeholder is set as the HTML `placeholder` attribute. Typing
in the field writes the new value through the binding; the
binding's setter is the same `@Binding` setter from §4, so
the 0.2.0 subtree-scoped re-render of the view that declared
the binding fires on every keystroke.

In 0.2.0 the field is **single-line**; pressing `Enter` does
not commit, the value is written on every `input` event. There
is no `onSubmit(of:_:)`, no `formatter`, no
`TextFieldStyle`. Multi-line input (`TextEditor`) is **not**
a 0.2.0 goal — see §9.

**Mirrors SwiftUI:** subset of SwiftUI's `TextField` overloads.
SwiftUI's `TextField` also accepts `axis: Axis = .horizontal`
(multi-line, deferred) and an `onEditingChanged` /
`onCommit` callback (deferred). The 0.2.0 SwiftWebUI surface
is the simplest single-line form that exercises the
event-delegation path.

**Example:**

```swift
struct NameForm: View {
    @State var name = ""
    var body: some View {
        TextField("Your name", text: $name)
    }
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
cycle. **`(v0.2.0)`** In 0.2.0 `@State` and `@Binding` are
wired to a **subtree-scoped, microtask-batched** re-render:
every write to `wrappedValue` schedules a `Task { @MainActor
in ... }` on the Swift concurrency runtime that runs a
re-render of the **subtree rooted at the view that owns the
`State`**, and multiple writes inside the same synchronous
turn collapse into a single microtask-driven commit. The
microtask primitive is the Swift-on-wasm32 path; the
`@MainActor` isolation is the SwiftUI parity (see the
"Mirrors SwiftUI" line in each entry below). The 0.1.0
contract ("one full re-render of the root view tree per
setter, driven by `_RendererReRenderHook`") is replaced.

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
first render. **`(v0.2.0)`** Mutating `wrappedValue` updates
the backing storage and schedules a `Task { @MainActor in
... }` on the Swift concurrency runtime. The task runs a
re-render of the **subtree rooted at the view that owns the
`State`** and is deduplicated within a single microtask pass,
so multiple writes inside the same synchronous turn collapse
into a single re-render. The `Task` is enqueued via
`_ReRenderScheduler` (SPI); the actor isolation is the
contract — the setter may be called from any actor, but the
resulting re-render always runs on the main actor, matching
SwiftUI's `@MainActor` isolation. The 0.1.0 contract ("one
full re-render of the root view tree per setter") is
replaced.

**Mirrors SwiftUI:** identical shape to SwiftUI's `@State`,
including the `@MainActor` isolation that SwiftUI enforces on
its re-render path. The "subtree-scoped, batched" re-render
is the behaviour SwiftUI provides for free because it owns
the runtime; in SwiftWebUI it is the explicit contract of the
`_ReRenderScheduler` (SPI) the setter delegates to.

**Example:**

```swift
struct Counter: View {
    @State var count = 0
    var body: some View {
        Button("count = \(count)") { count += 1 }
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

A two-way reference to a value owned elsewhere. **`(v0.2.0)`**
The getter and setter functions are stored and called; a
write through the binding forwards to the parent `@State`
whose setter then schedules a `Task { @MainActor in ... }`
re-render of the parent subtree. The chain is:

```
Binding.wrappedValue = v
  → Binding.setter(v)
    → State.wrappedValue = v         (parent's storage)
      → Task { @MainActor in re-render(parent-subtree) }
```

Multiple binding writes inside the same synchronous turn
collapse into a single re-render through the same
microtask-batched path. In 0.1.0 the write reached the
parent's storage but did not trigger a re-render; that
behaviour is replaced.

The `Binding.constant(_:)` initialiser produces a non-mutating
binding, useful for previewing a view that takes a binding
without owning state. `Binding.constant` writes are
**never** a re-render trigger — the captured setter is a
no-op, so the parent storage is never touched and the
scheduler is never invoked.

**Mirrors SwiftUI:** identical shape to SwiftUI's `@Binding`,
including the re-render propagation that SwiftUI performs on
the main actor. SwiftUI's two-way data flow is implicit; in
SwiftWebUI the propagation is explicit because the `Binding`
wrapper holds the parent `State` as a strong reference (see
`Binding.Getter` / `Binding.Setter` in
`Sources/SwiftWebUI/State/Binding.swift`).

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
view tree. **`(v0.2.0)`** The lookup is performed at render
time against a per-key subscription: when an ancestor writes
a value through the `EnvironmentValues` subscript for a key
that a descendant reads with `@Environment`, the
`_ReRenderScheduler` schedules a `Task { @MainActor in ... }`
re-render of all descendants subscribed to that key, in the
same microtask-batched shape as `@State` and `@Binding`. The
actor isolation is the same `@MainActor` contract as
`@State` — the ancestor write may come from any actor, but
the re-render always runs on the main actor. In 0.1.0 the
same write reached the bag but did not trigger a re-render;
that behaviour is replaced.

**Mirrors SwiftUI:** identical shape to SwiftUI's
`@Environment(_:)`, including the main-actor re-render that
SwiftUI performs when a value in the environment changes.
SwiftUI tracks subscriptions implicitly through its
dependency graph; in SwiftWebUI the subscription is
maintained by `_EnvironmentAccessor` (SPI) on a
per-key granularity (a write to key `\.colorScheme` does not
trigger a re-render of a descendant that reads only
`\.locale`).

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

### `.onTapGesture(count:perform:)` **`(v0.2.0)`**

```swift
extension View {
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View
}
```

Attaches a tap recogniser to the view. `count` is the number
of consecutive taps required to fire `action`; the 0.2.0
surface accepts `count: Int = 1` only — `count == 1` is the
common case. A recogniser with `count > 1` defers firing
until the multi-tap timer elapses, so a `count: 2` recogniser
suppresses the `count: 1` recogniser that would otherwise
fire on the first tap.

The recogniser is implemented in the renderer against a DOM
`click` listener installed by `_RenderEventRegistry` (SPI);
the closure is wrapped in a `JSClosure` whose lifetime
follows the view's identity in the graph. Tapping calls
`action()` once per recognised gesture; mutating `@State`
inside `action` triggers the 0.2.0 subtree-scoped re-render
of the view that owns the state. There is no `gesture(_:)`,
no `SimultaneousGesture`, no `LongPressGesture` in 0.2.0 —
see §9.

**Mirrors SwiftUI:** identical signature to SwiftUI's
`.onTapGesture(count:perform:)`. SwiftUI also ships
`.onLongPressGesture`, `.gesture(_:)`, and the gesture
combinator DSL; those are 0.3.0+ (a11y / animation work)
because they depend on a frame-driven diff loop.

**Example:**

```swift
Text("Tap me")
    .onTapGesture { count += 1 }
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

## 8. SPI in 0.2.0

The following surface is gated in 0.2.0. **`@_spi(Experimental)`**
symbols are drafts — signatures may change, names may change,
semantics may change. **`@_spi(SwiftWebUI)`** symbols are
project-internal — they are not drafts, but they are not part
of the public surface either. **Do not** depend on either
flavour from outside the SwiftWebUI source tree. Promoting
a symbol to public requires an architect PR and a test.

### `@_spi(Experimental)` (public-API-in-waiting)

| Symbol | Reason for SPI in 0.2.0 |
|---|---|
| `Layout` protocol | Spec is still being aligned with SwiftUI's 0.5+ `Layout`; ship as SPI first. |
| `GeometryReader` | Depends on `Layout` and a real flex engine (0.4.0). |
| `Shape` protocol | Depends on a 2D path engine; `Rectangle` and `Circle` are 0.4.0. |
| `Path` 2D API | Same as `Shape`. |
| `ViewModifier` | Modifiers are shipped as View extensions in 0.2.0; the protocol lands when there is a need to bundle modifiers. |
| Animation primitives | 0.3.0 work — depends on a frame-driven diff loop. |
| Accessibility hooks | 0.3.0 work — depends on a stable renderer graph. |
| `ButtonStyle` | Protocol shape is locked for 0.2.0; concrete styles (`.bordered`, `.borderless`, …) are 0.3.0 work. The 0.2.0 renderer uses a `PlainButtonStyle` default. |

`Button` and `TextField` **moved from `@_spi(Experimental)` to
`public`** in 0.2.0 — see the v0.2.0 intro above.

### `@_spi(SwiftWebUI)` (project-internal, not for promotion)

The following types are part of the renderer's internal seam
between `Sources/SwiftWebUI/` and `Sources/SwiftWebUIRenderer/`.
They are not drafts and are not intended to become public.
Their public contract is documented in the per-symbol
Discussion above; the types themselves stay SPI so the
renderer is free to evolve without breaking source.

| Symbol | Public contract it implements |
|---|---|
| `_RendererReRenderHook` | The 0.1.0 root-tree re-render trigger, retained for the 0.1.0 → 0.2.0 transition. **Deprecated in 0.2.0** — `@State` and `@Binding` setters should call `_ReRenderScheduler.schedule(_:)` instead. The 0.2.0 deletion of this hook is 0.3.0 work. |
| `_ReRenderScheduler` | The re-render scheduler. **`(v0.2.0)`** The scheduler enqueues a `Task { @MainActor in ... }` on the Swift concurrency runtime; the body of the task performs the re-render of the scheduled subtree. `@State` and `@Binding` setters and `EnvironmentValues` writers all go through this. The `@MainActor` isolation is the contract — the body always runs on the main actor, even if the setter call came from another actor. |
| `_RenderEventRegistry` | The DOM event listener registry. `Button`, `TextField`, and `.onTapGesture` install their listeners here; the registry owns the `JSClosure` retain policy. |
| `_GraphIdentity` | The per-view identity tag the renderer uses to decide which subtree a re-render applies to. Stable across the 0.2.0 microtask-batched commits. |

`@_spi(Experimental)` symbols may ship tests in the same
commit as their implementation (the TDD red→green cycle is
encouraged but not enforced for SPI; see `.harness/docs/tdd.md`
§"What is not a TDD violation"). They MUST ship with DocC
comments and a test before they can be promoted to public.
`@_spi(SwiftWebUI)` symbols MUST ship with at least one test
(the renderer test target uses them directly) and SHOULD
ship with a `///` comment, but the public-API-style DocC
treatment is not required.

---

## 9. Disallowed public surface (locked, 0.2.0)

The following is **not** part of the 0.2.0 contract and MUST
NOT be added to the public API without an architect PR.
The general bans from v0.1.0 still apply; this section adds
the 0.2.0-specific carve-outs.

### General bans (unchanged from 0.1.0)

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

### 0.2.0-specific carve-outs

- **`TextEditor` (multi-line text input).** SwiftUI's
  `TextEditor` accepts an `axis: Axis` parameter; in 0.2.0
  `TextField` is single-line only. Adding a public
  `TextEditor` shape requires an architect PR that names
  the renderer strategy (CSS `contenteditable` vs. a hidden
  `<textarea>`) and the binding contract. The shape is
  deliberately **not** aliased to `TextField(axis: .vertical)`
  in 0.2.0 because the `input` event vs. the
  `beforeinput` / `input` event pair on `contenteditable` is
  a real difference that users will trip on.
- **`ButtonStyle` concrete styles.** The `ButtonStyle`
  protocol ships in 0.2.0 as `@_spi(Experimental)`; concrete
  styles (`.bordered`, `.borderless`, `.borderedProminent`,
  `.plain`) are 0.3.0. A 0.2.0 PR that adds a public
  concrete style is rejected.
- **Multi-tap, long-press, and gesture combinators.** The
  0.2.0 surface ships `.onTapGesture(count:perform:)` with
  `count: Int = 1` only. `.onLongPressGesture`,
  `LongPressGesture`, `DragGesture`, `MagnificationGesture`,
  `RotationGesture`, and the `gesture(_:)` / `simultaneousGesture(_:)`
  / `highPriorityGesture(_:)` modifier set are 0.3.0+ (they
  depend on the frame-driven diff loop, which is the
  animation work).
- **Text-field formatters and styles.** SwiftUI's
  `TextField` accepts a `formatter:` parameter, an
  `onEditingChanged:` callback, an `onCommit:` callback, and
  a `TextFieldStyle` (`PlainTextFieldStyle`,
  `RoundedBorderTextFieldStyle`, `SquareBorderTextFieldStyle`,
  `DefaultTextFieldStyle`). None of these are in 0.2.0. The
  0.2.0 surface is the simplest `(_:text:)` form that
  exercises the event-delegation path.
- **`SecureField`.** SwiftUI's `SecureField(_:text:)` is
  deliberately not in 0.2.0. The 0.2.0 `TextField` does
  **not** support `type="password"`; a public `SecureField`
  is a separate symbol and ships when the renderer has a
  tested path for `<input type="password">` and the
  `JSClosure` lifetime of a value-suppressing input.
- **`Toggle`, `Slider`, `Stepper`, `Picker`.** All 0.5.0
  forms. The 0.2.0 surface covers the
  gesture / event-delegation path with `Button` and
  `.onTapGesture`; the bound-control path lands in 0.5.0
  with `List` and `Form`.
- **`.buttonStyle(_:)` modifier.** The protocol is SPI; the
  modifier that consumes it is therefore also not in 0.2.0.
  Promoting the protocol to public lands with the first
  public concrete style in 0.3.0.
- **`.textFieldStyle(_:)` modifier.** Same reason — the
  protocol is not in 0.2.0 at all.

### 0.2.0 carry-over from 0.1.0

These were disallowed in 0.1.0 and remain disallowed in 0.2.0
because the 0.2.0 work did not add the renderer machinery to
support them:

- **`Image` system-image names** (e.g. `Image(systemName: "x")`).
  SwiftUI's `Image(systemName:)` resolves an SF Symbol; the
  0.2.0 `Image(_:)` is URL-string only (0.1.0 contract
  unchanged). SF Symbols require a web font mapping, which
  is 0.4.0+ (shapes work).
- **`Font.custom(_:size:)`** and `Font.Design`. The 0.1.0
  `Font` enum is unchanged in 0.2.0.
- **The full SwiftUI `Color` palette** (`.indigo`, `.mint`,
  `.teal`, …). The 0.1.0 set of eight named hues plus
  `.primary` and `.secondary` is the 0.2.0 set.

A PR that adds a banned symbol is rejected at review by the
architect; the steward reverts it on `main` if it lands.

---

## 10. Acceptance for 0.2.0 (per symbol)

Each public symbol in this document ships only when all five
are true. The 0.2.0 additions to this contract are noted
inline.

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

### 0.2.0 per-symbol test plan (additive)

The 0.2.0-specific symbols each require the following
acceptance, on top of the five general items above.

#### `@State` (re-render semantics change)

- **Subtree scope test** (Tests/SwiftWebUITests/): a
  `Parent` view that hosts a `State<Int>` and a `Sibling`
  view that does **not** observe that state; after a state
  write, only the subtree rooted at the `State` owner
  re-renders, not the `Sibling`. The test must observe the
  re-render count, not the resulting DOM (DOM equality is
  not a sufficient signal).
- **Batching test** (Tests/SwiftWebUITests/): three
  synchronous writes to the same `State` in the same
  synchronous turn produce **one** `Task { @MainActor in
  ... }` re-render, not three. The test installs a
  `ReRenderObserver` (SPI) on the scheduler and asserts the
  commit count.
- **Microtask timing test**: the `Task { @MainActor in ... }`
  fires **after** the synchronous turn returns, on the Swift
  concurrency runtime, not synchronously inside the setter.
  The test uses a `ReRenderObserver` and asserts the commit
  timestamp is later than the setter's return.
- **No-mutation-no-render test** (negative): reading
  `wrappedValue` without writing does not schedule a
  re-render. The test installs the `ReRenderObserver`,
  reads the state, and asserts the commit count stays at
  zero.
- **Cross-actor setter test**: a setter call from a
  non-`@MainActor` context (e.g. a `Task.detached { ... }`
  or a callback from a non-main-isolated API) is
  serialised through the `@MainActor` isolation of the
  resulting re-render task. The test fires a state write
  from a detached task, awaits the resulting re-render, and
  asserts the re-render ran on the main actor.
- **Snapshot test** (Tests/SwiftWebUISnapshots/): a
  `Counter` view at `count = 0` and at `count = 3` produces
  the expected two snapshots; the diff is a single
  `textContent` change in the `<div>`.
- **0.1.0 regression**: the existing `Test/SwiftWebUISnapshots/`
  baseline for the 0.1.0 root-tree re-render **does not**
  change in 0.2.0 (subtree scope is a new contract, the
  root-tree re-render was a 0.1.0 deliverable and is now
  deprecated; see §8 `_RendererReRenderHook`).

#### `@Binding` (re-render semantics change)

- **Through-binding trigger test**: a child view that holds
  `@Binding var count: Int` and writes to it; the parent's
  `@State` storage receives the write, the
  `_ReRenderScheduler` schedules a `Task { @MainActor in ... }`
  re-render of the parent's subtree, and the parent
  re-renders. The test uses the same `ReRenderObserver` as
  the `@State` batching test.
- **Cross-actor binding test**: a binding write from a
  non-`@MainActor` context is serialised through the
  `@MainActor` isolation of the resulting re-render task
  (the same contract as `@State`).
- **Constant binding is inert**: `Binding.constant(_:)`
  writes do **not** trigger a re-render (the assertion is
  negative — the commit count stays at zero; the
  `ReRenderObserver` is never invoked).

#### `@Environment` (per-key subscription change)

- **Ancestor-write-then-descendant-read test**: a parent
  view sets `\.colorScheme` to `.dark` through the
  `EnvironmentValues` subscript; the `_ReRenderScheduler`
  schedules a `Task { @MainActor in ... }` re-render of all
  descendants subscribed to that key; a child that reads
  `@Environment(\.colorScheme)` observes the new value on
  the same microtask-batched commit.
- **Unrelated-key test**: setting `\.colorScheme` on the
  ancestor does **not** cause a re-render of a descendant
  that does not read it (the per-key subscription
  granularity). The `ReRenderObserver` confirms no commit
  is scheduled for the unrelated descendant.
- **Cross-actor environment test**: a write to the
  `EnvironmentValues` subscript from a non-`@MainActor`
  context is serialised through the `@MainActor` isolation
  of the resulting re-render task.

#### `Button`

- **Tap-fires-action test** (Tests/SwiftWebUITests/): a
  `Button("Save") { counter += 1 }` whose action is
  invoked once on a synthetic click; the action receives
  the increment; the `@State` write triggers a subtree
  re-render.
- **Snapshot test** (Tests/SwiftWebUISnapshots/): a
  `Button` renders to `<button>Save</button>` (or the
  accessibility-correct equivalent); the snapshot file is
  committed.
- **`role:` accessibility test**: a `Button(role: .destructive)`
  exposes `aria-role="button"` plus a `data-swui-role="destructive"`
  attribute (or the renderer-equivalent marker the a11y
  sweep can detect). The exact ARIA mapping is the
  `swiftwebui-dom-renderer` agent's contract; the
  acceptance is that the role is queryable from the DOM.
- **Re-render pairing** with `@State` (already covered by
  the `@State` subtree-scope test); the test suite must
  include a `Button` that increments a `@State` and asserts
  the post-tap DOM.

#### `TextField`

- **Keystroke-writes-binding test**: a `TextField("Name",
  text: $name)` receives a synthetic `input` event with
  `value = "Hello"`; the binding's `wrappedValue` is
  `"Hello"` after the event.
- **Subtree re-render on keystroke**: the binding write
  triggers a subtree-scoped re-render (the `@Binding`
  acceptance covers this in the abstract; the
  `TextField`-specific test asserts the rendered DOM has
  the new value).
- **Snapshot test** (Tests/SwiftWebUISnapshots/): a
  `TextField` with `placeholder = "Name"` and an empty
  binding renders to `<input type="text" placeholder="Name">`;
  the snapshot is committed.
- **Single-line contract**: the DOM element is `<input>`
  (not `<textarea>`); the test asserts the tag name.

#### `.onTapGesture(count:perform:)`

- **Single-tap test**: a `Text` with `.onTapGesture { ... }`
  receives a synthetic `click` event; the action runs once.
- **Re-render pairing**: the same as `Button` — a tap that
  mutates `@State` triggers a subtree re-render; the test
  asserts the post-tap DOM.
- **No-event test**: a view that has `.onTapGesture`
  installed but never receives a click does not call the
  action and does not schedule a re-render. The
  `JSClosure` registry's retention test (existing in the
  renderer test target) covers the negative case.
- **Snapshot test** (Tests/SwiftWebUISnapshots/): a
  `Text("Tap me").onTapGesture { … }` produces the same
  DOM as `Text("Tap me")`; the click listener is internal
  and is not part of the rendered markup.

#### `ButtonStyle` (SPI in 0.2.0)

- **Compile-only acceptance**: the protocol compiles, the
  `PlainButtonStyle` default renders. No public symbol
  promise is made; the SPI contract is "a future minor
  promotes the protocol to public, with concrete styles,
  and the 0.2.0 protocol shape is part of that
  compatibility window". A test that asserts the
  `PlainButtonStyle` default is the renderer-selected
  style is **not** required in 0.2.0 — promoting the
  protocol to public is the work of 0.3.0.

#### `_ReRenderScheduler` (SPI)

- **Commit-count test**: synchronous N writes → 1 commit
  (batching contract). The 1 commit corresponds to 1
  `Task { @MainActor in ... }` body run, not N.
- **Primitive test**: the scheduler enqueues a
  `Task { @MainActor in ... }` on the Swift concurrency
  runtime, not a `DispatchQueue.main.async` or a custom
  microtask queue. The test uses a
  `MainActor.assumeIsolated { ... }` shim around the body
  to assert the actor context, and inspects the task's
  `Task` identity (`@MainActor`).
- **Microtask timing test**: the `Task { @MainActor in ... }`
  fires after the synchronous turn returns, on the Swift
  concurrency runtime, not synchronously inside the
  setter. The test uses a `ReRenderObserver` and asserts
  the commit timestamp is later than the setter's return.
- **Subtree identity test**: a write to a `@State` owned
  by view `A` schedules a commit whose re-render set is
  `{A, A.children}` and not `{root, root.subtree}`.

#### `_RenderEventRegistry` (SPI)

- **Install-on-mount / remove-on-teardown test**: a
  `Button` mounted in the DOM has a `click` listener
  registered; the listener is removed when the `Button`
  is torn down (the parent re-renders without it). The
  test uses a `MutationObserver` in the host page.
- **`JSClosure` retain-cycle test** (existing from 0.1.0):
  no regression — the registry's `JSClosure` policy
  remains the documented lifetime in
  `.harness/docs/js-bridge.md`.

---

## 11. Reference

- Naming rules and SwiftUI ↔ SwiftWebUI disambiguation:
  `.harness/docs/naming.md`.
- TDD contract (red → green, snapshot policy, CI matrix):
  `.harness/docs/tdd.md`.
- DocC contract (`///` + `## Discussion` + `## Example`,
  Apple-voice tone): `.harness/docs/docc.md`.
- Renderer model choice (graph-based / VDOM in 0.1.0; the
  0.2.0 work preserves the model and adds microtask
  batching): `AGENTS.md` §6.
- JavaScriptKit interop rules and the `JSClosure` lifetime
  policy: `.harness/docs/js-bridge.md`. **The 0.2.0
  `JSClosure` lifetime of `Button` / `.onTapGesture` /
  `TextField` event listeners is governed by
  `_RenderEventRegistry` (see §8); the bridge's retain-policy
  contract in `js-bridge.md` is the underlying mechanism.**
- Release mechanics and 0.x milestone plan: `.harness/docs/release.md`.
- v0.1.0 stop conditions: `ROADMAP.md` §"v0.1.0" (frozen;
  the 0.1.0 deliverable is on `main` as of the 0.1.0
  close-out merge).
- **v0.2.0 stop conditions**: `ROADMAP.md` §"v0.2.0". The
  five bullets in that section — `@State` toggle re-renders
  the affected subtree, `Button` tap fires the action,
  `TextField` typing updates the view, `onTapGesture` fires
  on tap, no `JSClosure` regression — are what the team is
  measured against.

### Self-critique status (transparency)

When this ledger was first committed (v0.2.0 phase 1, train
branch `feature/v0.2.0-interactivity`), the architect
flagged five self-critique items. Their status as of
v0.2.0 phase 2 (this commit) is:

- **(1) Microtask primitive not pinned.** **Resolved (owner
  decision, 2026-06-12).** The microtask is now pinned to
  `Task { @MainActor in ... }` on the Swift concurrency
  runtime. Every Discussion paragraph in §4, every relevant
  row in §8 (`_ReRenderScheduler`), and every acceptance
  test in §10 uses this exact token. The dom-renderer and
  bridge workers should implement against this primitive and
  no other (no `DispatchQueue.main.async`, no custom
  microtask queue).
- **(2) `LocalizedStringKey` overloads shipped before
  runtime localisation.** **Open.** Deferred to the
  0.2.x/0.3.0 release decision; the spec is unchanged. The
  owner has not yet decided whether to drop the
  `LocalizedStringKey` overloads from 0.2.0 or ship them
  with the existing 0.1.0 runtime fallback.
- **(3) Multi-tap / long-press deferred to 0.3.0.** **Open.**
  Awaiting the dom-renderer worker's gesture-recogniser
  shape (does the renderer want a `count: 1` only contract
  for 0.2.0, or does it want `count: 2` with a timer?).
- **(4) `_RendererReRenderHook` deprecation vs. deletion.**
  **Open.** The 0.2.0 spec marks the hook deprecated
  (deletion 0.3.0). The owner can promote to deletion in
  0.2.0 if the dom-renderer is ready to remove the global
  static on the same commit that adds `_ReRenderScheduler`.
- **(5) `ButtonStyle` SPI vs. public.** **Open.** The 0.2.0
  spec keeps the protocol as `@_spi(Experimental)`. The
  owner can promote to public if the dom-renderer ships a
  `PlainButtonStyle` default in 0.2.0.

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
