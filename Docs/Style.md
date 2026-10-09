# Style

How code in this project is written. Follow it literally. When a rule and your training
disagree, the rule wins.

## The principle

Every line earns its keep. The thing to eliminate is *indirection*, not characters.

A twenty-line helper called once from the same file, wrapping logic that reads fine
inlined in three, is the worst outcome — it costs a name, a signature, a jump, and a
place to drift out of sync, and buys nothing. Abstraction is a debt paid against a
second caller. No second caller, no abstraction.

The declarative layer is exempt from brevity. A view body may run forty lines of
explicit modifiers and structure; that is the shape of the thing being described, not
indirection. Long bodies are fine. Hidden bodies are not.

## Deriving values

Derive with computed properties at the top of the type. Do not pass values in that the
type can read for itself, do not store what can be computed, and do not snapshot.

```swift
struct DocumentContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.selection.opened.document }
}
```

These are one line each, they read through to live state, and the body below reads as
prose. A computed property that fits on one line is not a "helper" — it's a name for a
path. Once it needs a body of its own with branching, it has to justify itself the same
as any function.

Correlated values come back as a labeled tuple rather than a struct or two parallel
properties:

```swift
var state: (label: String, tint: Color) {
    switch composition?.state {
        case .active: ("Active", Style.Tint.accent.bright)
        case .completed: ("Complete", Style.Tint.space.bright)
        case .inactive, .none: ("Ready", Style.Foreground.secondary)
    }
}
```

## Functions

Write a function when there is a second caller, when it satisfies a protocol, or when a
single call site genuinely needs the two halves separated (e.g. content built separately
so the toolbar chain reads cleanly on top of it). Otherwise inline it.

Never extract: a wrapper that renames one call; a "configure" step; a `makeX`/`buildX`
that returns a literal; a validation pass over data that cannot be invalid here.

First argument is unlabeled when it is the subject: `func surface(_ model: any Model)`,
`EditorView(ref, autofocus: true)`, `Space.with(ref, { $0.harness })`. Later arguments
are labeled.

Prefer existentials (`Model`, `any Panel`) to generics. Flat signatures over
parameterized ones.

## Types and files

Small types, one job each, grouped by feature in one file. One-type-per-file is wrong
here. `SpaceCanvas.swift` holds `CanvasZoom`, `CanvasPresentation`, `CanvasMap`,
`CanvasControl`, and `SpaceCanvas`; `SpaceContent.swift` holds `SpaceMenu`,
`SpaceHeader`, and `SpaceContent`.

The file is named for its principal type. Supporting pieces come first, smallest and
most-reused at the top, the composed type last. The file reads bottom-up: by the time
you reach the main type, its vocabulary is defined.

Enums live nested inside the type that owns them (`PanelSurface` inside each `Panel`),
not hoisted into a shared global. Each conformer declares its own cases.

## Naming

Domain noun first, role second: `SpaceCanvas`, `SpaceHeader`, `CanvasMap`, `CanvasZoom`,
`DocumentContent`, `ContentFrame`, `NavigatorPicker`. The name is the concept.

Banned suffixes: `Manager`, `Helper`, `Utils`, `Service`, `Provider`, `Coordinator`,
`ViewModel`, `Wrapper`, `Impl`. If a name needs one of those, the type has no idea what
it is.

Properties are nouns, not `get`-prefixed. Booleans read as states: `presented`, `pinned`,
`hovered`, `focused`.

## Protocol uniformity

`Surface` and `Panel` define the shape of app UI. A `Surface` carries exactly `panel` and
`model` and is always constructed `Foo(panel: panel, model: model)`. Defaults live in the
protocol extension so conformers stay empty. Do not invent a parallel initializer, an
extra dependency parameter, or a bespoke environment key to get something a surface can
already reach through `model`.

## Views

Modifier chains run one per line in declaration order. Do not extract a chain into a
`ViewModifier` or a `.custom()` extension — inline chains are the readable form, and a
tuned chain is load-bearing. Never reorder, consolidate, or "clean up" modifiers on a
view that already works; ordering changes behavior.

Bindings are built inline where used:

```swift
Toggle(isOn: .init(get: { axis == option }, set: { if $0 { axis = option } })) { ... }
```

State is `@State private var` on the view that owns it. Panel state lives on the panel
and is reached through `bindable`. There is no global selection.

Empty stubs stay. `Button { } label: { Image(systemName: "pause.fill") }` is
work-in-progress, not a defect — do not delete it, wire it up, or add a TODO.

## Absence

Absence is a normal state and renders nothing.

```swift
if let ref { SpaceHeader(ref: ref, panel: panel, model: model) }
```

No `else`, no placeholder, no error text, unless there is a designed empty state
(`NoReference`, `Text("No Matches")`). No `precondition`, `assert`, `fatalError`,
`try!`, or force unwrap in app, editor, or view code. Nothing throws upward from a view.

Guard when the failure is the point, with `else` on its own line once the condition
runs long:

```swift
guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
else { return nil }
return ref
```

## Values and tokens

Shared semantics go through tokens: `Style.Spacing.page`, `Style.Foreground.primary`,
`Style.Background.canvas`, `Typography.detail`, `Metrics.inspectorHoleRadius`.

One-off visual tuning stays a literal: `.padding([.trailing, .vertical], 9)`,
`.font(.system(size: 13.5, weight: .medium))`, `.frame(width: 260, height: 280)`. These
are measured by eye and are correct as written. Do not promote them to constants, round
them, or unify them across files — a literal appearing twice is a coincidence, not
duplication.

## Comments

There are none. Do not add them — not headers, not `// MARK:`, not doc comments, not a
line explaining what the next line does. If something needs explaining, the names are
wrong. Fix the names.

## Formatting

Two blank lines after the import block, one between types. Imports in order: `Foundation`,
`SwiftUI`, then project modules (`ScintRuntime`, `ScintComponents`, …).

`switch` cases indent one level inside the `switch`. Switch expressions and single-line
cases omit `return`:

```swift
var symbol: String {
    switch self {
        case .documents: "text.alignleft"
        case .transcripts: "text.bubble"
        case .settings: "switch.2"
    }
}
```

Short `if`/`else` pairs go on two lines, `else` leading:

```swift
if let _ = session.opened.document { DocumentContent(panel: self, model: model) }
else { LibraryContent(panel: self, model: model) }
```

Access control only where it means something: `private` for genuinely internal state and
functions. No `public`/`internal` on types that don't need it.

## Working here

Move in small, working steps. A stub that compiles beats a finished module that has to be
argued with. Leave existing types where they are; don't relocate, rename, or reorganize
as a side effect of another change.

Do what was asked. Don't audit adjacent code, don't list problems you noticed, don't
"while I was in there." Unfinished is not broken.
