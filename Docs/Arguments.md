# Argument controls

How a settable argument moves from a UI control to argv, and which of Apple's HIG
components can supply each kind of argument. Component list taken from the
[HIG components index](https://developer.apple.com/design/human-interface-guidelines/components)
(64 components across 8 groups, fetched 2026-09-14).

## Pipeline

```
Parameter declaration        Harness.Parameter / Command.Parameter  (.argument name, type: Value, required, default)
        │
UI item                      HarnessGroup.parameters → ItemParams(trailingKind:)
        │
Configured value             HarnessGroup.controls → Space.configure(Value?, for: key)
        │
Validation                   Command.parse / Harness.parse → Value.construct(supplied, name:)
        │
argv                         Command.arguments / Harness.arguments → Arguments.marshal(Value)
```

- `.fixed(Value)` never reaches the UI. It is always marshaled.
- `.argument(required: true)` is skipped by `HarnessGroup` and supplied at run time (for example Codex `input`).
- An optional argument with no configured value and no default adds no elements to argv.

## Value shapes and their argv

From `Arguments.marshal` (`Sources/ScintRuntime/Core/Arguments.swift`).

| Declared type | Configured value | argv |
| --- | --- | --- |
| `.bool` | `.bool(true)` | `true` |
| `.integer` | `.integer(3)` | `3` |
| `.decimal` | `.decimal(0.5)` | `0.5` |
| `.string` | `.string("~/Desktop")` | `~/Desktop` |
| `.date` | `.date(…)` | `2026-09-14T09:00:00Z` (ISO 8601) |
| `.reference(Artifact.self)` | an artifact ref | the artifact's path |
| `.reference(Command.self)` | a command ref | executable followed by its argv |
| `.reference(<other>)` | any other ref | its `scint://` URL |
| `.sequence([a, b, …])` (2+ choices) | one of the choices | that choice |
| `.sequence([])` | any Space ref | its URL |
| `.sequence(.reference(T))` (1 template) | `.sequence([...])` | each element marshaled |
| `.range([ordered…])` | a member, or an integer index | that member |
| `.collection(["--flag": T])` | a value of T | `--flag=<value>` |
| `.collection(["-c": .collection(["key": T])])` | nested | `-c=key=<value>` |
| `.collection(["--flag": .sequence(.reference(T))])` | several refs | `--flag=a --flag=b` |

## What `HarnessGroup` renders today

| Shape detected (after unwrapping a single-key collection) | `TrailingKind` | Control | Example |
| --- | --- | --- | --- |
| `.reference(Command)` or `.sequence([])` | `.load` | Pop-up list of refs with icons, plus Default | Scheduled Observer `command` |
| `.range` | `.range` | Stepped slider | Codex `reasoningEffort` |
| `.sequence` with 2+ choices | `.picker` | Pop-up with Default | Codex `model`, `sandbox`; Scheduled Observer `repeat`; Directory Observer `event` |
| `.bool` | `.toggle` | Switch | — |
| `.date`, key contains "time" | `.time` | Gating toggle, then time picker | Scheduled Observer `time` |
| `.date` | `.date` | Gating toggle, then date picker | Scheduled Observer `date` |
| `.string`, key contains dir/folder/path | `.action` | Choose button opening `NSOpenPanel` | Directory Observer `directory` |
| `.string` / `.integer` / `.decimal` | `.field` | Text field | — |
| Leaf `.sequence` (one template), `.collection`, other `.reference` | not rendered | — | Codex `directory`, `additionalDirectories` (intentionally hidden; directories come from artifacts) |

## Component inventory

Every HIG component is listed once and sorted by what it can do for arguments.
"n/a" means it doesn't supply argument values on macOS. Links use
`https://developer.apple.com/design/human-interface-guidelines/<slug>`.

### 1. Value controls: set one argument

| Component | Value shape | argv example | Use when | Don't use when | macOS API |
| --- | --- | --- | --- | --- | --- |
| [Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles): switch | `.bool` | `--verbose=true` | On/off setting in an inspector row | The CLI wants a bare flag (see Gaps) | `Toggle` `.switch` |
| Toggles: checkbox | `.bool`, or one item of a multi-select | `--event=Created` | Dense forms, lists of independent options | Only one setting in the row | `Toggle` `.checkbox` |
| Toggles: radio buttons | `.sequence` 2–5 choices | `--sandbox=read-only` | Choices benefit from being visible with explanations | Space is tight | `Picker` `.radioGroup` |
| [Segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls) | `.sequence` 2–5 short choices, or small `.range` | `--every=daily` | Short labels, frequently switched | Long labels or more than about 5 choices | `Picker` `.segmented` |
| [Pop-up buttons](https://developer.apple.com/design/human-interface-guidelines/pop-up-buttons) | `.sequence` (any count), `.reference` choices | `--model=gpt-5.5` | Mutually exclusive choice where the current value should show | Choices trigger actions | `Picker` `.menu` |
| [Combo boxes](https://developer.apple.com/design/human-interface-guidelines/combo-boxes) | `.sequence` suggestions plus free `.string` | `--model=my-finetune` | Known values exist but the tool accepts others | The value must be one of the list | `NSComboBox` |
| [Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders) | `.range` (ticks) or bounded `.decimal` | `-c=model_reasoning_effort=high`, `--latency=0.5` | Ordered scale where relative position matters | The exact number matters more than position | `Slider(step:)` with tick marks |
| [Steppers](https://developer.apple.com/design/human-interface-guidelines/steppers) | `.integer` with step | `--retries=3` | Small integers adjusted by one | Large ranges | `Stepper` paired with a field |
| [Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields) | `.string`, `.integer`, `.decimal` | `--timeout=30` | Free-form short values | Value comes from a known set | `TextField(value:format:)` |
| Text fields: secure | secret `.string` | env var, never argv | Tokens, passwords | Always use env, since argv is visible in `ps` | `SecureField` |
| [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields) | query `.string` | `--query=invoice` | The argument is a search term | Anything else | `NSSearchField` / `.searchable` |
| [Token fields](https://developer.apple.com/design/human-interface-guidelines/token-fields) | `.sequence(.string)` or `.sequence(.reference)` | `--add-dir=/a --add-dir=/b` | Repeated flag or multi-value list | Single value | `NSTokenField` |
| [Pickers](https://developer.apple.com/design/human-interface-guidelines/pickers): date | `.date` | `--date=2026-09-15T00:00:00Z` | Calendar date | Relative durations (use a stepper and units) | `DatePicker` `.compact` / `.graphical` |
| Pickers: time | `.date` (time part) | `--time=…T09:00:00Z` | Wall-clock time | — | `DatePicker(displayedComponents: .hourAndMinute)` |
| Pickers: date and time | `.date` | one ISO value | A single moment is one argument | The tool takes date and time separately | `DatePicker` `.field` / `.stepperField` |
| [Color wells](https://developer.apple.com/design/human-interface-guidelines/color-wells) | `.string` hex | `--color=#B8514F` | The tool accepts a color | — | `ColorPicker` / `NSColorWell` |
| [Image wells](https://developer.apple.com/design/human-interface-guidelines/image-wells) | `.reference(Artifact)` image | `/path/to/image.png` | Drag and drop an image input | Non-image files (use a path control) | `NSImageView` `isEditable` |
| [Path controls](https://developer.apple.com/design/human-interface-guidelines/path-controls) | `.reference(Artifact)`, path `.string` | `-C /Users/…/Scint` | File or folder argument that needs its location visible | — | `NSPathControl` with `.popUp` style |
| [Rating indicators](https://developer.apple.com/design/human-interface-guidelines/rating-indicators) | `.integer` 0–5 | `--min-rating=4` | A threshold people think of as stars | Other numbers | `NSLevelIndicator` `.rating`, editable |
| [Digit entry views](https://developer.apple.com/design/human-interface-guidelines/digit-entry-views) | n/a | — | tvOS only | — | — |
| [Virtual keyboards](https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards) | n/a | — | iOS/iPadOS keyboard types | — | — |

### 2. Structure: compose several arguments

| Component | Shape it organizes | Use for | macOS API |
| --- | --- | --- | --- |
| [Boxes](https://developer.apple.com/design/human-interface-guidelines/boxes) | Several arguments in one section | "Harness Settings" style groups | `GroupBox`, `Form` `Section` |
| [Disclosure controls](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls) | Optional or advanced arguments; read-only view of `.fixed` | Hide `--skip-git-repo-check` and similar until asked | `DisclosureGroup` |
| [Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) | `.sequence(.collection)`, repeated pairs | Headers `-H "K: V"`, env vars, add-dir lists with +/- | `Table`, `List` with edit buttons |
| [Outline views](https://developer.apple.com/design/human-interface-guidelines/outline-views) | Nested `.collection` | `-c` config trees (`mcp_servers.scint.url`) | `OutlineGroup`, `List(children:)` |
| [Collections](https://developer.apple.com/design/human-interface-guidelines/collections) | `.reference` chosen visually | Pick a space or artifact from a grid | `LazyVGrid` |
| [Column views](https://developer.apple.com/design/human-interface-guidelines/column-views) | `.reference` in a hierarchy | Pick a space deep in a tree | `NSBrowser` |
| [Tab views](https://developer.apple.com/design/human-interface-guidelines/tab-views) | Mutually exclusive parameter sets | Subcommand modes (`exec` vs `review`), each with its own arguments | `TabView` |
| [Labels](https://developer.apple.com/design/human-interface-guidelines/labels) | Read-only values | Show `.fixed` args, required run-time inputs, argv preview | `LabeledContent`, `Text` |
| [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) | n/a | Layout only | — |
| [Lockups](https://developer.apple.com/design/human-interface-guidelines/lockups) | n/a | tvOS | — |

### 3. Presentation: where a complex argument is edited

| Component | Use for arguments | macOS API |
| --- | --- | --- |
| [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers) | Edit one row's complex value in place (graphical date, token list, nested collection) | `.popover` |
| [Documents](https://developer.apple.com/design/human-interface-guidelines/sheets) | Scoped multi-argument tasks, such as defining a command's parameters in "Add Command…" | `.sheet` |
| [Panels](https://developer.apple.com/design/human-interface-guidelines/panels) | File and folder choosing (`NSOpenPanel`, as in `HarnessGroup.choose`), the inspector itself | `.fileImporter`, `NSOpenPanel`, `.inspector` |
| [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | Confirm a dangerous value before it's saved (`danger-full-access`) | `.alert` |
| [Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets) | Pick between a few consequential options at run time | `.confirmationDialog` |
| [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views), [Page controls](https://developer.apple.com/design/human-interface-guidelines/page-controls) | n/a | — |

### 4. Actions: start things without setting values

| Component | Relationship to arguments | macOS API |
| --- | --- | --- |
| [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons) | Run with current arguments; open a chooser (`.action` "Choose") | `Button` |
| [Pull-down buttons](https://developer.apple.com/design/human-interface-guidelines/pull-down-buttons) | Actions about an argument list ("Add Command…"). Never for selecting a value | `Menu` |
| [Menus](https://developer.apple.com/design/human-interface-guidelines/menus) | Multi-select with checkmarks via toggles in a menu, for repeated flags | `Menu` containing `Toggle` |
| [Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus) | Per-argument: Reset to Default, Copy argv, Make Fixed | `.contextMenu` |
| [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar), [Dock menus](https://developer.apple.com/design/human-interface-guidelines/dock-menus) | Run or rerun with saved arguments | `.toolbar`, `.commands` |
| [Edit menus](https://developer.apple.com/design/human-interface-guidelines/edit-menus) | Copy and paste values between fields | system |
| [Activity views](https://developer.apple.com/design/human-interface-guidelines/activity-views) | Share a command and its argv | `ShareLink` |
| [Home Screen quick actions](https://developer.apple.com/design/human-interface-guidelines/home-screen-quick-actions), [Ornaments](https://developer.apple.com/design/human-interface-guidelines/ornaments) | n/a on macOS | — |

### 5. Content

| Component | Use for arguments | macOS API |
| --- | --- | --- |
| [Text views](https://developer.apple.com/design/human-interface-guidelines/text-views) | Long `.string`: prompts, script bodies. Prefer stdin or a file over argv for large text | `ScintEditor` |
| [Charts](https://developer.apple.com/design/human-interface-guidelines/charts), [Image views](https://developer.apple.com/design/human-interface-guidelines/image-views), [Web views](https://developer.apple.com/design/human-interface-guidelines/web-views) | n/a, display only | — |

### 6. Status: display results, not inputs

[Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators),
[Gauges](https://developer.apple.com/design/human-interface-guidelines/gauges),
[Activity rings](https://developer.apple.com/design/human-interface-guidelines/activity-rings).
A gauge can show where a `.range` value sits read-only. (Rating indicators are in section 1 because they're editable on macOS.)

### 7. System experiences: argument sources outside the app

| Component | Relationship to arguments |
| --- | --- |
| [App Shortcuts](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts) | `AppIntent` `@Parameter` maps directly to `Value`: `Bool`, `Int`, `Double`, `String`, `Date`, `IntentFile`/`URL` for artifacts, `AppEntity` for references, `AppEnum` for sequences. Shortcuts becomes a second no-code front end. |
| [Controls](https://developer.apple.com/design/human-interface-guidelines/controls) | Control Center toggle or button bound to one `.bool` or a run |
| [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) | Configurable intent parameters, same mapping as App Shortcuts |
| [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) | Action buttons or text reply supply a value at run time |
| [Snippets](https://developer.apple.com/design/human-interface-guidelines/snippets) | Confirm arguments before an intent runs |
| [Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities), [Complications](https://developer.apple.com/design/human-interface-guidelines/complications), [Status bars](https://developer.apple.com/design/human-interface-guidelines/status-bars), [Top Shelf](https://developer.apple.com/design/human-interface-guidelines/top-shelf), [Watch faces](https://developer.apple.com/design/human-interface-guidelines/watch-faces) | n/a |

## Choosing a control from a shape

Checked in order, first match wins.

| # | Shape | Control |
| --- | --- | --- |
| 1 | `.reference(Artifact)` that is a folder or file | Path control plus Choose (open panel); image well for images |
| 2 | `.reference(Command/Space/…)`, `.sequence([])` | Pop-up with icons; collection or column view once lists get long |
| 3 | `.sequence(.reference(T))` | Token field, or table with +/- |
| 4 | `.sequence(.string)` (one template, free values) | Token field |
| 5 | `.sequence` 2–5 short choices | Segmented control (or radio group when labels need explaining) |
| 6 | `.sequence` 6+ choices | Pop-up button |
| 7 | `.sequence` choices where other values are allowed | Combo box |
| 8 | `.range` with 7 or fewer ordered members | Slider with tick marks (today's `.range`) |
| 9 | `.range` with more members | Pop-up button |
| 10 | `.bool` | Switch in inspector rows, checkbox in dense forms |
| 11 | `.integer` | Stepper with field; slider when bounded |
| 12 | `.decimal` | Formatted text field; slider when bounded |
| 13 | `.date` | Date, time, or date-and-time picker; gating toggle when optional |
| 14 | `.string` short | Text field; search field for queries; color well for colors |
| 15 | `.string` long | Text view in a popover or sheet |
| 16 | `.collection` with several keys | Box or section of child controls |
| 17 | Nested `.collection` | Outline view |
| Optional | — | "Default" item in menus; gating toggle for pickers |
| Required | — | Label marking it as supplied at run time |

## CLI argument patterns

General CLIs use argv patterns beyond what the harnesses needed. Examples come from tools on this machine.

| Pattern | Example | Expressible today | Control |
| --- | --- | --- | --- |
| Flag with value | `dew add --every 6h` | `.collection(["--every": .string("")])`, joined as `--every=6h` | Text field |
| Flag with fixed choices | `codex exec --sandbox read-only` | `.collection(["--sandbox": .sequence([...])])` | Segmented control or pop-up |
| Repeated flag | `dew add --env A=1 --env B=2` | `.collection(["--env": .sequence(.string(""))])` | Token field |
| File or folder value | `codex exec --cd <dir>` | `.collection(["--cd": .reference(Artifact.self)])` | Path control |
| Positional | `dew show <name>` | `.argument(name:type:required:)`, in declaration order | Text field |
| Subcommand | `dew add` | `.fixed(.string("add"))` | Tab view, or one command per subcommand |
| Bare flag | `dew list --enabled` | No | Toggle |
| Negatable flag | `dew add --run-on-load` / `--no-run-on-load` | No | Toggle with Default (three states) |
| Counted flag | `ssh -vvv` | No | Stepper |
| Flag and value as two elements | `curl -o out.txt` | No (always joined with `=`) | — |
| Multi-select from a fixed set | `fswatch --event Created --event Updated` | No | Menu with checkmarks, token field |
| Mutually exclusive group | `dew add` needs exactly one of `--cron`, `--every`, `--at` | No | Segmented control choosing which field shows |
| Separator | `git log -- <path>` | Only as `.fixed(.string("--"))` | — |
| stdin or file input | `curl --data @-` | No | Text view, path control |

### Drafting declarations from completions

`script/draft-parameters.py` reads a fish completion script and prints draft
`command(...)` declarations. Each argument is commented with the control from the
table above, and unsupported patterns are left as comments.

```bash
dew --generate-completion-script fish | script/draft-parameters.py dew --usage
script/draft-parameters.py codex ~/.config/fish/completions/codex.fish --path "codex exec" --usage
script/draft-parameters.py rg /opt/homebrew/share/fish/vendor_completions.d/rg.fish
```

What completions provide: flag names, whether a flag takes a value (`-r`/`-x`),
literal choices (`-a`), file and directory values (`-F`, `__fish_complete_directories`),
subcommands, and, for swift-argument-parser, which options are repeatable.
What they don't provide: positionals (`--usage` reads them from each subcommand's
`--help` USAGE line, which runs the tool), numeric types, bounds, and mutually
exclusive groups. Folder arguments with no `-F` are guessed from descriptions
mentioning "directory" or "folder", and marked as guessed.

Sources: swift-argument-parser (`--generate-completion-script fish`), clap and cobra
(`<tool> completion fish`), `/opt/homebrew/share/fish/{completions,vendor_completions.d}`
(about 1,080 files here), `~/.config/fish/completions`.

## Gaps in today's shapes

These are places where no existing shape can express what a control needs. They're listed here, not changed.

1. **Bare flags.** A `.bool` marshals to `true`, or `--flag=true` inside a collection. CLIs like Codex want `--json` present or absent, which is why those arguments are `.fixed`. A toggle bound to a bare flag needs its own shape.
2. **Multi-select from a fixed set.** `construct` accepts exactly one alternative from a `.sequence` of choices. fswatch accepts `--event` repeatedly, but Directory Observer's `event` can only be a single-choice picker. Checkbox menus and token fields need a "many of these" shape.
3. **Numeric bounds and step.** `.integer` and `.decimal` carry no min, max, or step, so a stepper or slider can never be picked from the shape alone.
4. **Controls chosen by key name.** `directory(_:)`, `clock(_:)` and `symbol(_:)` in `GroupMapper.swift` infer the control and icon from the key text. A no-code builder lets people type keys, so the control will need to come from the shape or an explicit hint.
5. **Unexposed arguments are intentional.** Only arguments people generally understand appear in the inspector. Directories come from the space's artifacts, so Codex `directory` and `additionalDirectories` stay hidden. Rows 1, 3 and 16 above apply only if one of these is ever exposed.
6. **Two-element flags.** The `-c` and `--flag` pairs are joined as `flag=value`. The existing comment in `Arguments.marshal` already notes that parsers other than GNU- or clap-style need two elements. The nested form (`-c=model_reasoning_effort=high`) is the case most worth checking against Codex.
7. **Secrets in argv.** A secure field's value shouldn't be marshaled, because argv is visible to `ps`. `bearer_token_env_var=SCINT_CONTEXT` shows the pattern: secrets go in the environment and argv only names the variable.
8. **Large strings.** macOS caps argv plus environment at `ARG_MAX` (1 MB). Text-view arguments such as prompts are safer through stdin or a file.
