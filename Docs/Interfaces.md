# Interfaces

A record of `Artifact`, `Command`, and `Harness` as they exist today. Descriptive, not
prescriptive: where behavior is undefined, it is marked undefined rather than described
as it ought to be. Opinions are confined to the last two sections and can be deleted
without touching the record.

## Design intent

Recorded because it is not derivable from the code, and because the code is narrower
than the design in places noted below.

**Harnesses are meant to be fully flexible.** Before argument parsing was implemented, a
harness held direct values for structures, other interfaces, and any number of commands.
The intent is that one harness can compose itself, scripts it calls directly, other
harnesses, and multiple commands into a single service. The current
`Harness.command: Reference` is a single binding and is narrower than that.

**The parameter template is the no-code grammar.** A parameter's `type` is authored, not
compiled, and it is read by three consumers at once — argv rendering, the agent-readable
form, and the inspector UI. It is the foundation for an interface editor in which people
author their own commands and harnesses without writing code.

**Intents will carry an argument contract.** A meta protocol is planned: conforming to a
given intent will require a harness to declare a specific set of arguments, different per
intent. Nothing enforces this today.

## The shared shape

All three are `Functional`, which is `Composable`, which is `Resolvable`. Each follows
the same construction:

```swift
struct X: Functional {
    let ref: Reference
    let <dependencies>              // immutable, no arguments, no runtime state

    enum Parameter: Codable, Sendable, Equatable { … }   // Command, Harness

    init(_ ref: Reference = .init(Self.self))            // protocol conformance only
    init(_ ref: Reference, <dependencies>)               // real initializer

    var rendered: String                                 // agent-readable form
    func rendered(with values: [String: Value]) -> [String]   // argv, Command + Harness

    static func register(…) -> Reference                 // entry into the runtime
}
```

**Statelessness.** No interface stores arguments, values, or process state. Every stored
property is `let`, and every property is either identity (`ref`) or a reference to
another interface. Values arrive as parameters at call time and are discarded.

**Standalone and composed.** Each interface is complete on its own — an `Artifact`
resolves without a `Command`, a `Command` renders without a `Harness` — and each
composes upward: `Harness → Command → Artifact`.

**The single-argument initializer is a no-op.** `Composable` requires
`init(_ ref: Reference)`. It assigns `ref` to its own dependency fields
(`Command.artifact = ref`, `Harness.command = ref`) because the language requires all
stored properties to be initialized. It is not a usable object; objects enter the runtime
through their `static func register`.

**Access is never direct.** Instances are read and written through
`Type.with(ref) { … }` and `Type.update(ref) { … }`, which resolve through
`Library.shared.store(for:)`.

## Artifact

```swift
struct Artifact: Functional {
    let ref: Reference
    let handler: Handler
}
```

An artifact is a URL. It is a proxy for something outside the runtime, and a handler for
that thing once resolved — a meta-handler, not a wrapper around file contents.

### Handler

```swift
enum Handler: Codable, Sendable, Equatable {
    case app(URL?), bookmark(URL?), directory(URL?), executable(URL?)
    case file(URL?), image(URL?), script(URL?), skill(URL?)
}
```

| Member | Returns | Behavior |
| --- | --- | --- |
| `url` | `URL?` | The case's URL, standardized and symlink-resolved for file URLs; returned as-is otherwise |
| `type` | `String` | The case name; used as the descriptor tag at registration |
| `name` | `String` | `url.lastPathComponent`, empty when nil |
| `directory` | `Bool` | True only for `.directory` |
| `children` | `[Handler]` | Directory contents, each classified, sorted case-insensitively by path. Empty for non-directories. Reads the filesystem on every access |
| `resolvable` | `Bool` | File URL *and* executable per `FileManager` |
| `executable` | `String?` | `url.path(percentEncoded: false)` when `resolvable`, else nil |

`classify(_ url: URL?)` assigns the case, in order: nil → `.file(nil)`; non-file URL →
`.bookmark`; `.app` extension → `.app`; directory → `.directory`; `SKILL.md` →
`.skill`; known image extension → `.image`; `#!` in the first 128 bytes → `.script`;
executable non-directory → `.executable`; otherwise `.file`.

`children` recursing through `classify` is intentional — a directory artifact resolves
its contents as artifacts of their own kind.

### Members

| Member | Returns | Behavior |
| --- | --- | --- |
| `rendered` | `String` | File URLs → decoded path; others → `absoluteString`. Force-unwraps `handler.url` |
| `register(_ name:_ url:)` | `Reference` | Classifies the URL, creates a descriptor tagged with `handler.type`, adds to the `artifacts` store |

## Command

```swift
struct Command: Functional {
    let ref: Reference
    let artifact: Reference     // the executable
    let parameters: [Parameter]
}
```

A command binds an executable artifact to an argument shape.

### Parameter

| Case | Fields | Role |
| --- | --- | --- |
| `.argument` | `name`, `type: Value`, `required: Bool`, `default: Value?` | Caller-supplied, validated against `type` |
| `.fixed` | `Value` | Always emitted, never supplied |
| `.requirement` | `name`, `type: Value`, `value: Value` | Declared; emits nothing. Same shape as the harness case |

### Members

| Member | Returns | Behavior |
| --- | --- | --- |
| `rendered` | `String` | Name, description, and a `usage:` line built from the executable path and parameters |
| `rendered(with:)` | `[String]` | `.argument` → supplied value else default, rendered; `.fixed` → its value rendered; `.requirement` → nothing |
| `register(_ name:exec:params:)` | `Reference` | Creates a descriptor tagged `command`, adds to the `controls` store |

## Harness

```swift
struct Harness: Functional {
    let ref: Reference
    let intent: Intent          // compose, dispatch, observe, execute, search
    let command: Reference
    let parameters: [Parameter]
}
```

A harness binds a command to an intent and a second argument shape. `Harness.Intent`
declares *which* contextual behavior runs; the runtime's own `Intent` enum holds the
constructed instance of it.

### Parameter

| Case | Fields | Role |
| --- | --- | --- |
| `.argument` | `name`, `type: Value`, `required: Bool`, `default: Value?` | Caller-supplied, validated against `type` |
| `.command` | `content: String`, `value: Value?` | Literal argv content. `value == .bool(false)` emits nothing; `.bool(true)` or nil emits `content` alone; any other value emits `content` followed by the value |
| `.requirement` | `name`, `type: Value`, `value: Value` | Parsed with a fixed value; emits nothing |
| `.target` | `name`, `type: Value`, `default: Value?` | Parsed; emits nothing |

### Members

| Member | Returns | Behavior |
| --- | --- | --- |
| `rendered` | `String` | Name, description, intent, command name, and one line per parameter with flag, choices, and default |
| `rendered(with:)` | `[String]` | `.argument` → supplied else default; `.command` → per the rules above; `.requirement` and `.target` → nothing |
| `register(_ name:command:intent:parameters:)` | `Reference` | Creates a descriptor tagged `harness`, adds to the `services` store |

## Registration

All three follow the same four steps:

1. Mint a reference — `Reference(Self.self)`, which generates one UUID used for `id`,
   `descriptorId`, `contextId`, and `storageId`.
2. Build the instance with its dependencies.
3. `Descriptor.new(ref, name:, tags:)` — writes into `Catalog`.
4. `Library.shared.store(for: ref)?.add(ref, instance)` — routes by type through
   `Interfaces` to `artifacts`, `controls`, or `services`, then calls `changed(ref)`,
   which schedules a debounced save through `Coordinator`.

Nothing validates uniqueness of name. `SampleInterfaces` de-duplicates by scanning
`Runtime.shared.all(as:)` for a matching descriptor name before registering.

## Parameter values

A parameter's `type` is a `Value` used as a template. It carries both the flag and the
accepted shape.

| Template | Accepts | Notes |
| --- | --- | --- |
| `.string("")` | any `.string`; `.bool`/`.integer`/`.decimal` from parseable strings | Non-empty payload is a placeholder label |
| `.bool` / `.integer` / `.decimal` | same case, or a `.string` that parses | `.integer` is **not** accepted for `.decimal` |
| `.reference(T)` | a `.reference` whose `typeId` matches | |
| `.sequence([])` | any `.reference` | `Value.anyReference` |
| `.sequence([one])` | a `.sequence`, each element constructed against `one` | |
| `.sequence([a, b, …])` | intended as an enumeration of allowed values | See Deviations |
| `.collection([k: v])` | a `.collection` with exactly matching keys, or any scalar — which is wrapped as `[k: scalar]` | The key is the flag |

Rendering (`Value.rendered`): scalars render as one element; `.sequence` flattens;
`.collection` emits one `key=value` element per key, keys sorted, multiple values
comma-joined; `.reference` renders through `Runtime.shared.rendered(_:)`.

## The three consumers of a template

Any change to the template grammar lands in all three at once.

**1. argv** — `Value.rendered`, described above.

**2. The agent-readable form** — `Value.described`, via `Command.rendered` and
`Harness.rendered`.

**3. The inspector UI** — `SpaceGroup` in `StudioMappers` builds the Execution section
from `harness.parameters`:

- Only `.argument` cases appear. `.command`, `.requirement`, and `.target` render no
  control.
- Required arguments are excluded, as is any argument named `continuation`.
- `options(type)` unwraps single-key `.collection`s recursively; if it reaches a
  `.sequence` of more than one value, those become a **picker** with a leading
  "Default" entry. A configured value not present in the list is appended to it.
- Otherwise `leaf(type)` unwraps the same way and takes the first element of a
  `.sequence`: `.bool` → **toggle**, `.string`/`.integer`/`.decimal` → **field**,
  `.sequence`/`.collection`/`.reference` → no control.
- The selected value is `config[key].rendered.last`, and picking writes
  `.string(rendered)` back into the origin's closure config.

So `["--model": .sequence([…])]` yields a picker labelled "model", and
`["-c": ["model_reasoning_effort": .sequence([…])]]` yields one labelled
"reasoning Effort" — the flag and its nesting are invisible to the user, which is the
intent.

## Consumption

`Parser.parse(_ origin:for harness:)` produces the argv for a run:

1. Read `(config, rendered)` from the origin `Space` or `Workspace`.
2. For each harness parameter name, take `config[name]` — except `prompt`, which
   receives the origin's `rendered` text.
3. For each command `.argument` name, take `config[name]`.
4. Construct both sets against their templates — applying defaults, enforcing `required`,
   rejecting unexpected keys.
5. Return `command.rendered(with:) + harness.rendered(with:)`. Command argv precedes
   harness argv.

`Parser.parse(_ supplied:for ref:)` is the other entry: it resolves `ref` as a `Command`
or `Harness` and validates a supplied dictionary without touching an origin. Used by the
MCP server.

## Firing

Within a run: `Context.start` resolves the origin's harness, builds argv through
`Parser`, and constructs one of five contextual structs from `Harness.intent`. That
struct resolves `Harness.command → Command.artifact → Artifact.handler.executable`, sets
`SCINT_CONTEXT` in the environment, and calls `Runtime.shared.services.start`. Output is
registered per pid and arrives as `Signal`s.

Interfaces themselves are not called during a run beyond resolution and rendering. They
hold no process state; the pid lives in `Services`.

---

## Deviations from the pattern

Resolved 2026-08-11: `Command.dispatch` and `Harness.stop(pid:)` are gone — no interface
starts or stops a process. The MCP path in `ScintServer/HarnessTool.swift` now owns its
own launch. `Command.Parameter.requirement` gained the name and type its harness
counterpart already had. Both types register with a kind tag. `Command.register` lost
`@discardableResult`, so a new object's handle can no longer fall through silently.
`Handler.executable` no longer percent-encodes the path it hands to `process.executableURL`.

**`Harness.Parameter.command(content:value:)` is constructed nowhere.** No sample
interface uses it and no code path builds one; only `rendered(with:)` reads it. It is
either the composition slot described in Design intent, awaiting implementation, or
residue. `Command.Parameter.fixed(Value)` covers literal argv content for commands and is
used throughout.

**`.requirement` is constructed nowhere either**, on either type. `Parser` matches the
case; nothing creates one.

**Space and Workspace tags are inverted.** `Workspace.new` tags `space`, while `Space`
goes through `Structural.new`, which tags nothing. Structural, not interface — recorded
here because it affects the same search facets.

## Notes

**Enumerated values are not enforced.** `Value.construct` tests a `.sequence` of
alternatives with `alternatives.contains { (try? $0.construct(supplied)) != nil }`. Each
alternative is a `.string`, and `(.string, .string)` matches on case alone, so any string
satisfies any list. Every allowed-value list in `SampleInterfaces` currently accepts
anything.

**Rendering emits one joined element per flag.** `.collection` produces `--flag=value`
as a single argv element. Separated form (`-C /path`), repeated form (`--add-dir a
--add-dir b`), and nested form (`-c key=value` as two elements) are not expressible.

**`.requirement` and `.target` are constructed and reach nothing.** `Parser` validates
them; neither `rendered(with:)` emits them; no other consumer reads them. They are the
cases that carry references to structures and other interfaces, so they are where the
flexible composition described in Design intent would land — the declaration exists, the
delivery does not.

**`Harness.command` is a single reference.** Composing multiple commands, scripts, or
other harnesses into one service is not currently expressible; `Context` resolves exactly
one command per harness on the way to the executable.

**`Value.described`** (used by `Command.rendered` and `Harness.rendered` to print the
parameter grammar) was added 2026-08-11 and is not part of the original design.
