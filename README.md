# Scint

Scint is an agent workspace for macOS. You don't open a thread, you create a space.
The space is the focal point of context for a piece of work: it holds the documents,
commands and record for that work, and it stays. What happens in a space splits by
intent into a hierarchy of transcripts that is never compacted, and each request is
classified by TypeSafe's Jev to decide which mapping over that record the agent sees.
Spaces nest, so delegated work becomes a sub-space you can open, not a summary you
can't.

This repository is the native app. It sits on top of
[ScintRuntime](../ScintRuntime), which owns the graph, the execution path, the MCP
server and the process daemon, and [ScintComponents](../ScintComponents), the design
system. The case study and architecture notes at
[scintapp.github.io](http://scintapp.github.io) describe the whole project.


## How the pieces fit

| Module | Role |
| --- | --- |
| `Scint` (this repo) | The SwiftUI app: navigator, content and inspector over the runtime's graph. |
| `ScintRuntime` | Identity, spaces, documents, transcripts, the catalog, and the Broker → Composer → Handler path that runs work. |
| `ScintServer` | The localhost MCP server and `scint://` callback handling. The app starts it on launch. |
| `ScintService` | `scintd`, the XPC process daemon. Built here as the `scintd` target and registered by the app through `SMAppService`. |
| `ScintComponents` | Tokens (`Style`, `Typography`, `Iconography`), controls, block views and markdown rendering. |

The app is a client. It holds no copy of any runtime object, keeps no cache, and
validates nothing the runtime already owns. Every view reads the graph as it is at the
moment it draws.


## The graph the app is built on

### References

Every object in Scint has exactly one `Reference`, and everything that uses the
object holds that reference. A space points to its documents by reference; a document
embeds another document by reference; a transcript points to the nested transcript
behind a reply by reference.

A reference carries five identities: the object, its type (a stable hash of the type
name), its descriptor in the catalog, the context (space) it belongs to, and its
storage. So a bare `Reference` already knows what it is, what it's called, and where it
lives:

```swift
ref.type          // Space.self, Document.self, Transcript.self, …
ref.descriptor    // name, description, tags, created/updated, published
ref.context       // the live Context for its space
ref.url           // scint://document/8f2c61d0-…
```

A reference leaves the app as a `scint://` link and comes back as the same object,
whether it travelled through a document, a command's arguments, an agent's reply or
another application.

### Reading through

There is one way to touch an object: by reference, with its type's own methods.

```swift
Space.with(ref, { $0.documents })
Document.update(input) { $0.header.argument(value, key, for: command) }
Transcript.with(ref, { $0.entries })
```

The runtime's stores are `@Observable`, so a view that reads through `with` re-renders
when the object changes, including when an agent changes it. When an agent edits a
document someone has open, they watch it change, because there is only one document.
The app's own code is computed properties over these paths, one line each, with
nothing snapshotted:

```swift
var ref: Reference? { model.session.selection.opened.document }
var input: Reference? { space.flatMap { Space.with($0, { $0.input }) } }
```

### Spaces, closures and bridges

A `Space` has an origin (its parent), child spaces, bridges to other spaces, an
interface, a closure and a broker. The closure is what the space works with: its
documents, artifacts, commands and transcripts, all by reference. Containment says
where a space belongs; bridges say which spaces work together, and they cross the
hierarchy freely. A document can sit in any number of spaces and still be one
document.

### Transcripts

A space's root transcript is the shared conversation. Each intent (Compose, Process,
Evaluate, Observe, Search) records into its own nested transcript, linked from the
root by a `.transcript` entry. Entries are messages, invocations, signals and nested
transcripts. A space's state (active, working, completed, failed) is derived from the
signals in its transcript and its live handlers, never stored beside them.


## App structure

### Roots

The runtime seeds one model space with three children, and the app is organized
around them:

```
App
├── Agenda      scheduled tasks
├── Library     documents (with Files and Skills)
└── Spaces      the user's spaces
```

`DataModel` resolves these three references once. `Selection.root` walks a selection's
origin chain up to one of them, and that root decides what every frame shows: the
content frame picks `AgendaContent`, `LibraryContent` or `ProjectContent`, and the
inspector picks the matching outline and settings mappers.

### Session and selection

`Session` is the app's state for one window or panel host: focus, selection and
navigation history. There is no global selection.

- `Selection` is hierarchical along three axes: structure (a space), interface (a
  command or interface) and content (a document, artifact or transcript), plus what is
  opened. Selecting a space clears interface and content below it; selecting content
  clears what was opened. The model drives open and close; views never close
  themselves.
- `Focus` is what the keyboard and inspector are pointed at, derived from the
  reference's type.
- `Navigation` keeps back/forward history as a list of selections and derives the
  path bar by walking origins.

`ScintModel` owns two `Model`s that each carry a `Session`: `AppModel` for the main
window and `PanelModel` for floating panels and anchored menus (search, actions,
choices, settings).

### Frames, surfaces and mappers

`AppView` is a `NavigationSplitView` with three frames: `Navigator`, `ContentFrame` and
`Inspector`. Every presenter of UI is a `Host`, which owns a `StateContainer` and
optionally supplies `Controls` and `Params`. `Frame`s render into the window; `Panel`s
and `Menu`s render through `PanelModel` into an `NSPanel`.

Most list-like UI goes through one pipeline:

```
Mapper  →  Params / Controls  →  Factory  →  ListLayout · GroupLayout · PanelLayout
```

A `Mapper` is a static pair of functions that reads the session and the graph and
returns plain values: `Params` (sections of `ItemParams`, each carrying a reference)
and `Controls` (callbacks for select, drop, toggle, value change and context menus).
`Factory` turns those into views. The navigator, the inspector's outline and settings
modes, search, actions and the reference panels are all mappers; they map the
graph, they don't own behavior.

Surfaces that are a designed screen rather than a list (the transcript, the library
grid, the agenda, the editor) are ordinary SwiftUI `Surface` views constructed with
the host and model, reading through the same session.

### Surfaces by root

**Spaces.** `ProjectContent` shows a space as its transcript, with the input editor
pinned at the bottom, or as a zoomable canvas of its space tree.
`TranscriptContent` flattens the root transcript and its nested intent transcripts
into one chronological thread; `TranscriptFactory` maps each entry to its view (input,
output, reasoning, tool calls, notices). The toolbar above the input exposes the
space's command and its typed arguments as pickers and ranges.

**Library.** `LibraryContent` lays documents out as cards in a masonry grid, each
card rendering the document's actual blocks scaled down. Opening one shows
`DocumentContent`, the block editor at reading width.

**Agenda.** `AgendaContent` shows the Agenda space's task documents as a grid or a
scoped list (today, upcoming, later, all). `TaskContent` edits one task: its
schedule, repeat, target space and command in the header, its instructions in the
editor below.

### The editor

`EditorView` is a block editor over a `Document`'s blocks, with live markdown styling
in TextKit. It is the same component everywhere a document appears: the library,
a task, and the input box at the bottom of a space. `EditorIO` reads and writes blocks
through `Document.update`; `EditorFocus` coordinates focus and caret movement between
blocks; blocks themselves own their behavior. References in a document are reference
blocks, not links in text.


## Starting work

Every interaction that starts work takes the same path: a document is added to a
space's input, and the space is composed.

```swift
Space.update(space, { $0.input(input) })
model.compose(space)
```

That is all the app does. The runtime's `Broker` queues the input and prepares the
next draft with the same header settings, the `Composer` creates a `Handler`, Jev
classifies the request, the intent's mapping renders the view, and `scintd` runs the
command. Output is parsed into records in the intent's nested transcript, and the
transcript view updates because it reads through.

A message typed into a space, a task dispatched from the agenda, an MCP compose call
and a `scint://` callback from another app all arrive the same way. The app has no
second path for any of them.

Requests are documents. The input editor's body carries instructions and embedded
references; its header carries execution settings (command, model, effort) keyed by
the command they configure. Tasks are documents in Agenda with a schedule and a target
space; when one comes due it dispatches to that space exactly like a typed message.


## Links, drag and drop

- `scint://` links open in the app through `ScintModel.openURL`, which hands them to
  the server's `CallbackHandler`. A link that names an object selects it; a link that
  names a tool runs it.
- `ReferenceTransfer` moves references between spaces by drag and drop, using exported
  types (`com.kaechle.scint.space`, `.document`, `.artifact`, …). Dropping attaches by
  reference; nothing is copied.
- `ActionProvider` derives the actions available on any reference for context menus
  and the actions panel. `ShortcutProvider` binds global keyboard shortcuts.


## Repository layout

```
Sources/Scint
├── Scint.swift, ScintModel.swift   app entry, runtime + MCP server startup, scintd registration
├── Model                           AppModel, PanelModel, DataModel, Session/Selection/Navigation, providers
├── Framework
│   ├── Core                        Host/Surface/Mapper protocols, Params, Mappers, Factories, Layouts
│   ├── Frames                      Navigator, ContentFrame, Inspector
│   ├── Editor                      block editor
│   ├── Panels, Menus               floating panels and anchored menus
│   └── Views                       shared app views
└── App
    ├── Projects                    space content, canvas, input toolbar, transcript
    ├── Library                     document grid and document view
    └── Tasks                       agenda grid/list and task view
Sources/ScintService                scintd entry point
Resources                           assets, entitlements, scintd launch agent plist
Tests                               regression suites with their run scripts
Docs/Style.md                       how code here is written
```


## Building

Scint requires macOS 26 and Xcode 26. `ScintRuntime` and `ScintComponents` are local
Swift packages and must be checked out beside this repository:

```
Developer/
├── Scint
├── ScintRuntime
└── ScintComponents
```

Open `Scint.xcodeproj` and build the `Scint` scheme; it embeds `scintd` as a launch
agent. On first launch the app registers `scintd` with `SMAppService`, which may need
approval in System Settings › Login Items.

Data lives in plain JSON under `~/.local/share/scint` (`spaces/` and `library/`),
following `XDG_DATA_HOME`. The regression suites in `Tests/` link against the Debug
build and run against a temporary data directory.

Read [Docs/Style.md](Docs/Style.md) before changing any Swift here.
