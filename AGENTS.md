# Working in Scint

Scint is a native macOS app over a reference-addressed runtime. Four targets share one
domain model: `Scint` (app), `ScintRuntime` (topology, context, persistence),
`ScintServer` (loopback MCP), `ScintService` (`scintd` XPC process supervision).

Read this before writing code. The rules below are not style preferences — they are the
contracts the codebase is built on, and violating them produces work that gets reverted.

---

## The rule behind every other rule

**When something you need doesn't exist, say so. Do not substitute something that compiles.**

This is the single failure mode that has cost this project the most time. Three real
examples, all from one week:

- A field was renamed `Composition.structure` → `Composition.space`. The call sites in
  `ContextServer` no longer compiled. They were **deleted**, along with the `tools/list`
  and `tools/call` routing — severing the app's entire MCP tool surface. The correct fix
  was a two-character rename.
- An Activity panel was specified with three groups: Working, Recent, Scheduled. No
  scheduled-run model exists in the runtime. Instead of reporting that, `state == .active`
  was picked because it type-checked, producing a permanently empty section that looks
  implemented.
- `TaskCard` used `Typography.prose` and `Style.Spacing.xs`. Both were **replaced** with
  `.font(.system(size: 14))` and a literal `1` to chase a visual, deleting token usage
  that already existed.

If a rename breaks a call site, fix the call site. If a spec needs a capability the
runtime lacks, build the capability or report the gap — do not fake the surface. If a
token doesn't produce the value you want, change the token or add one; never inline a
literal over it.

---

## Architecture: the app is a lens, not a copy

The UI holds no domain state. Views resolve runtime values through `Reference` on every
render. There is no view model mirroring the runtime.

### Data flow

```
Reference ──> Mapper ──> Params (presentation) + Controls (behavior) ──> Factory ──> Layouts
```

- **`Mapper`** (`Sources/Scint/Panels/Mappers/`) — the only place that reads the runtime
  for presentation. Implements `static func parameters(_:) -> Params` and
  `static func controls(_:) -> Controls`.
- **`Params`** (`Sources/Scint/Core/Params.swift`) — `Params` → `[SectionParams]` →
  `[ItemParams]`. Pure data: name, description, image, tint, count, ref, nested `items`.
- **`Controls`** (`Sources/Scint/Core/Controls.swift`) — closures: `onSelect`, `selected`,
  `onAction`, `itemAccessory`, `wrapSection`, `itemPalette`, drag/drop, and so on.
- **`Factory`** (`Sources/Scint/Core/Factory.swift`) — turns `Params` + `Controls` into
  views via `Layout` (`.list`, `.group`, `.grid`, `.table`) and `Nesting`
  (`.flat`, `.single`, `.recursive`).
- **`Panel`** — owns `PanelState` and routes its current surface to a mapper.
- **`Surface`** — renders. Its body should be exactly:

  ```swift
  var body: some View { render(self, panel.parameters(model), panel.controls(model)) }
  ```

  which is what `AnySurface` already does. **Most surfaces should not exist.** A panel case
  that maps cleanly returns `AnySurface(panel: self, model: model)`.

### The loop

```
Panel calls Mapper       ->  Mapper maps data to Params
Panel calls Factory      ->  Factory consumes Params, returns Views
View state changes       ->  Observation refreshes Panel  ->  repeat
```

### Where work goes

Two places, and together they should account for roughly ninety percent of all changes.

**Changing how something looks or behaves on screen is a View change.** Views are UI, and
composing them is the point. Layout, hierarchy, spacing, indicators, trailing controls,
hover, disclosure, empty states — all of it is view composition, and all of it belongs in
a view. Views carry no business logic and fetch no data, but inside presentation they are
where the work happens and where it should be pleasant to work.

**Changing what data appears is a Mapper change.** Mappers are pure data work: read,
filter, sort, format, structure, and hand back dimensional params. They make no UI
decisions.

**`Params` and `Factory` should barely change at all.** They are the interface between
those two jobs, and their stability is precisely what keeps both jobs easy. Reaching for a
new param field or a new `Factory` branch to solve a *visual* problem is the signal that
the problem is being solved in the wrong module.

### The failure to avoid: UI reasoning inside a mapper

A mapper that resolves symbols, picks colors, or decides what an indicator looks like has
taken over the view's job. The usual next move — concluding that `Params` or the `Factory`
must grow to carry that resolved appearance — compounds it, and hardens the mistake into
the two modules that are supposed to stay still.

The mapper says **what a thing is**: a reference, a role, a state, a count. The view
decides **what that looks like**.

This has already happened once. `ActivityNavigator` resolved `Iconography` symbols and
`Style` tints into `ItemParams` rather than passing the intent along and letting the row
draw it — which then made a missing status indicator look like a `Factory` limitation
instead of a view that had not been composed yet.

Mappers still never contain views. That rule is unchanged, and it is not in tension with
any of the above: a mapper containing a view and a mapper making view decisions are the
same error wearing different clothes.

---

## Hard rules

### Runtime access

- **Surfaces and views never call `Runtime.shared`.** Mappers may. If a view body needs
  runtime data, it belongs in `Params`.
- Never call an expensive runtime query from a computed property used multiple times in
  one `body` — it re-runs per access.
- Read and mutate through the typed accessors only:
  `Space.with(ref) { $0.x }`, `Space.update(ref) { $0.x = y }`. Same for `Workspace`,
  `Material`, `Transcript`, `Artifact`, `Command`, `Harness`, `Closure`, `Bridge`.
- Never construct a `Reference` to address existing data. References come from the store.
  `Reference(SomeType.self)` creates a *new* identity.
- Mutation goes through `update`, which schedules persistence via `Coordinator`. Never
  write to a store directly.

### Design tokens

- Fonts: `Typography.*`. **No raw `.font(.system(size:))` in new code.**
- Spacing, color, shape, opacity, duration: `Style.Spacing`, `Style.Foreground`,
  `Style.Background`, `Style.Tint`, `Style.Shape`, `Style.Opacity`, `Style.Duration`.
- Icons: `Iconography.icon(for: ref)` / `Iconography.Icon`.
- No magic numbers for size, inset, or duration. If no token fits, add one to `Style`.
- Never replace existing token usage with a literal.

### State

- Expansion state uses `surface.isExpanded(id)` / `surface.setExpanded(id)`, which persist
  in `PanelState`. **Never `@State private var expanded`** — it is lost on redraw and
  diverges from the rest of the panel.
- `@State` is for transient view-local UI only (hover, in-flight text field).
- Session state (focus, selection, open material) lives in `Session`, reached via `model`.

### Scope

- Don't add types that are used once. Six single-use view structs in one file means the
  work belonged in a mapper.
- Don't duplicate an existing primitive. Check `Panels/Layouts/` (`ListLayout`, `ListLink`,
  `ListRow`, `RowLayout`, `GroupLayout`, `CardLayout`, `GridLayout`, `TableLayout`) and
  `Panels/Views/` first.
- Don't reformat, rename, or restructure code you were not asked to change.

---

## Building

`xcode-select` on this machine points at the CommandLineTools, where bare `xcodebuild`
fails **and exits 0**. An exit-code check is not a build check.

```
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Scint.xcodeproj -scheme Scint -destination 'platform=macOS' build
```

Verify by grepping for `BUILD SUCCEEDED` **and** evidence of `SwiftCompile` / `Ld` phases.
Touch the files you changed if you need to force a recompile. Targets are Swift 6,
macOS 27.0.

Do not run the app or drive the UI unless asked.

---

## Reporting

State what you did, what you did not do, and what you could not do. If part of a task was
impossible, say which part and why — a complete report of partial work is worth more than
a full-looking result with a hollow section in it.
