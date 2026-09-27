# Scheduled space runs

Instructions for making a scheduled task start a space, as if a person were sitting in front of that space. Read `Docs/Interfaces.md` and `Docs/Style.md` first. They are binding. This document adds rules learned from a long design session; several exist because an earlier attempt broke them and was reverted.

Repositories:
- Runtime: `~/Developer/ScintRuntime` (Swift package: `swift build`, `swift test`)
- App: `~/Developer/Scint` (Xcode project, schemes `Scint` and `scintd`)

---

## 1. Goal

From Tasks, a person can automate the whole workspace. For example: "organize the Notes folder every other day", or "run the Consolidation space once a week".

When the task fires, it starts the target space with the task's input. That means:
- The target space runs in its own context, through its own harness, intent and transcript, with its own `SCINT_CONTEXT`.
- It is exactly what happens when someone types into that space's input and presses start.
- The task doesn't run Codex against a space URL. It activates the space, and the space's harness decides what runs.
- The target space is a default argument of the task: the Space chip in the task bar, stored as `data["space"]`.
- The task's command is a composed command, "Run Space". A variant, "Run Space with Command", can override the command the space's harness uses.

### Out of scope

- Dispatch as a top-level gateway space.
- The done predicate, retries, a History tab, and `dew edit` for rescheduling.

---

## 2. Composition comes first

The whole runtime is built on one idea: **commands are composable Unix commands, and commands take other commands as arguments.** Chains like this must work:

```swift
let chain = command(
    name: "Command Chain",
    description: "Run a series of commands consecutively.",
    artifact: env,
    params: [
        .argument(name: "commands", type: .sequence([.reference(Command.self)]), required: true)
    ]
)
```

Tim's original Task Action expressed the fire as composition. An earlier session replaced it with a bash script, and it must be restored in composed form. The original:

```swift
let action = command(
    name: "Task Action",
    description: "",
    artifact: env,
    params: [
        .fixed(.collection(["update": .reference(update)])),
        .argument(name: "action", type: .reference(Command.self), required: true),
    ]
)
```

It takes two commands: one is the callback that updates the originating (Tasks) context, the other is the action the user chose.

### Current state (verified)

A probe test built each shape with `Command.new` and `Harness.new`, then printed `Command.line(values)` or `Harness.method(.start, values)`. The results:

| Shape | Command line produced | Works? |
|---|---|---|
| Exec(A): a `.reference(Command)` argument, the pattern the default harnesses use | `/usr/bin/env /bin/echo a` | Yes |
| Outer(Exec(A)): a `.command` parameter wrapping Exec | `/usr/bin/env /usr/bin/env /bin/echo a` | Yes; nesting recurses with the same values |
| Command Chain over `[A, B]` (`.sequence([.reference(Command.self)])`) | `/usr/bin/env scint://command/… scint://command/…` | No; the list isn't expanded, and env tries to run URLs |
| Original Task Action (`.fixed(["update": Update Task])` + `action`) | `/usr/bin/env update=scint://command/… /bin/echo a` | Partly; the action runs, but `update` is only an environment variable holding a URL, and Update Task never runs |
| Harness with its own `.command` parameter that its runner doesn't declare | `/bin/echo a` | No; the harness's parameter is dropped (regression, see below) |

The default harnesses (Compose, Evaluate, Dispatch, Search) all run Exec with a `command` argument. That's the single-wrap case, and it works.

**Never worked (and wasn't broken this session):** `Functional.parse` has the same expansion logic as the pre-session `[Parameter].parse` (commit `bf3f463`). Only the named groups were removed.
- A single command reference expands recursively into that command's full command line. This covers both a `.command` parameter and an `.argument` whose constructed value is a single `.reference(Command)`.
- A list of command references, or a command reference inside a `.fixed` value, marshals to its `scint://` URL through `Parameter.marshal`.
- Nothing can run several programs one after another. `/usr/bin/env` executes exactly one.
- Hazard (already there): Exec whose `command` is Exec, with the same values, recurses forever. The inspector avoids it by filtering choices; parse doesn't guard against it.

**Regressions from the earlier session.** Restore these.
1. **Harness parameters no longer reach the command line.** `Harness.method` (`ScintRuntime/.../Interfaces/Harness.swift`) used to merge its own parse output over the runner's. It replaced entries with the same name and appended the rest, so a harness could add composed commands of its own. Now only the runner's command line is returned, and harness parameters only supply default values. Restore the append for names the runner doesn't declare, which is what Interfaces.md describes: "adds the harness's own". Do it by name. `parse` now returns a flat `[String]`, so this may need a way to parse per parameter. Keep that inside `Functional` and don't add new types.
2. **Direct command runs from outside are gone.**
   - Before: `scint://interface/run?ref=<command>` and MCP `interface run` ran any command through `Command.run`. That ran outside any context, which is itself a problem.
   - Now: `Command.run` is deleted, and `InterfaceTool.run` (`Scint/Sources/ScintHost/Tools/Core/InterfaceTool.swift`) only accepts a sheet, through `Runtime.run(sheet)`. Observe's `.callback` now carries the sheet, not the command.
   - Don't restore `Command.run`. Commands must run inside a context. If direct command runs are needed, route them through the facade into a context, and ask Tim how.
3. **Task Action was replaced with a bash script,** and Update Task with an osascript script.
   - The script does chain two commands: it expands `update` and `command` into command lines and runs them with a bespoke `::`-separated bash runner.
   - That's a task-specific runner, not composition. Replace it with the generic runner below, and restore the two-command shape.

### What's needed

1. **Expand command references wherever they appear:** in sequences, and inside `.fixed` values. Each command reference becomes that command's own command line, parsed with the same values, the way `expand` already does for a single reference. Do this inside `Functional.parse`'s existing switch. Don't create a new type.
2. **A generic runner for several commands.** `/usr/bin/env` runs one program; running several consecutively needs a runner.
   - Keep it Unix-shaped: expanded commands become argument segments separated by a fixed delimiter token.
   - Add one small generic artifact (a script) that runs the segments in order.
   - It must be generic, not task-specific. Any chain, and Task Action, are both just uses of it.
   - The only chain-level behavior is running in order and stopping on the first failure.
   - If passing one segment's output to the next is needed (as Task Action's update needs), make that one explicit, documented rule of the same runner. Don't bake task logic into it.
3. **Rebuild Task Action from those pieces** as the composition of an update command and an action command. Delete the bespoke bash script in `Harnesses.swift`, and any Update Task logic that exists only to serve it.
4. **Restore harness parameters on the command line** (regression 1 above).
5. **Add a test for each row of the table above.** Chain and Task Action must produce runnable command lines, and a harness-level command parameter must appear on the runner's command line. Follow the style of the existing tests in `ScintRuntime/Tests/ScintRuntimeTests/ScintRuntimeTests.swift`.

The daemon expands `$NAME` and `${NAME}` in every argument using the spawn environment. Keep shell variables in any runner script lowercase so they never collide with real environment variables.

---

## 3. How the task flow works today

Understand this before changing anything. Every step works end to end.

1. **Edit (app).** The components in `Scint/Sources/Scint/Studio/Tasks/Task/TaskBar.swift` read the sheet (`Sheet.with(ref)`) and write it (`Sheet.update(ref)`). `TaskSpace` stores `data["space"] = .reference(space)`.
2. **Schedule.** `model.observe(ref)` calls `Runtime.observe(sheet)`, which transmits `.start{ref: tasksSpace, document: sheet}`. `Process.compose(origin, with: sheet)` builds a Handler:
   - its arguments are `sheet.arguments` plus `input`, the Tasks intent's rendered prompt;
   - its harness is Observe.
3. **Handler.** It translates the signal through `Signature(signal)` (`.start` to start, `.update` to run, `.stop` to stop), then calls `harness.method(...)` and `Services.run(line, environment)`.
4. **Observe harness** (`ScintRuntime/.../Extensions/Harnesses.swift`):
   - start is Schedule Task: `dew add <sheet url> … --command "open 'scint://interface/run?ref=<sheet url>'"`.
   - run is Task Action.
   - stop is Cancel Task: `dew remove`.
5. **Fire.** dew opens the callback. `CallbackHandler` calls `InterfaceTool.run`, which calls `Runtime.run(sheet)` and transmits `.update`. Process composes a handler, and Handler runs Observe's `run`.
6. **Close.** Update Task writes back through `scint://content/write` callbacks.

`Sheet.arguments` (`ScintRuntime/.../Extensions/Materials.swift`) merges:
- the data block, including `space`;
- `name` (sheet URL), `action` (the sheet itself, used by Schedule Task's callback), `command`, `document`, `closed`;
- either `at` for one-shot tasks, or `date`, `time` and `repeat`.

---

## 4. How a space is started by hand, which Run Space must reproduce

- The composer writes blocks into the space's Input document.
- Submitting calls `Document.clear()`, which moves `blocks` into `buffer`.
- `Runtime.start(space)` transmits `.start`. The space's Process runs `compose(origin)`, which calls `Document.dump()` on the Input document to get the request, renders the space's own intent prompt, and starts a Handler on the space's harness.

The MCP/callback tool `compose` (`Scint/Sources/ScintHost/Tools/Intents/ComposeTool.swift`) already exposes `start` and `stop` for a space (`ref`). It starts the space but doesn't place any input first.

### Run Space

- **A command, "Run Space",** declares `space` (`.reference(Space.self)`, required) and the input.
  - The target is the sheet's `space`.
  - The input is the task's request: the sheet's document block, as text. It must *not* be the Tasks intent's rendered prompt in `args["input"]`, because the target space renders its own prompt.
  - Decide with Tim whether the sheet's document reference or its rendered text is passed.
- **When run,** it calls back into the host, where the target space receives the input exactly as typed input (Input document, then `clear()`) and is started through `Runtime.start(space)`.
  - The natural place is the `compose` tool's `start` verb, taking an optional input.
  - The host must go through the Runtime facade, and must reach the space by its URL.
- **"Run Space with Command"** is the same, plus a command argument. It sets the command the target space's harness uses for that run (the harness's `command` config).
- **The target space's run produces its own transcript.** The Tasks fire only records that it started the space. Update Task then closes the sheet as before; "output" is the fact the space was started, not the space's result.

---

## 5. Architecture rules (non-negotiable)

- **Process** is a root, like pid 1. It composes handlers on a signal and kills them on `.stop`, selected by the defining ref's id. It never interprets signals, picks transitions, calls Services, or mutates domain objects.
- **Handler** holds the harness and turns behavior defined as data into behavior. Don't add stored properties to it, or change `handle`.
- **Harness and Command** only produce arguments: `method`, `line`, `parse`. They never call Services.
- **Signature** is the grammar between Signal and Harness (`Signature(signal)`). Don't add Signal cases.
- **Runtime facade, Composer and the core singletons** (Workspaces, Library, Catalog, Coordinator): don't add, rename or re-sign anything. If a facade change looks necessary, stop and ask Tim.
- **The outside world** (MCP, callbacks) only ever has a URL. It enters through the Runtime facade, and the URL resolves to a context.
- **No state properties.** State is computed from existing data (see `Context.state`, `Sheet.scheduled`).
- **Persistence** belongs to the save coordinator. Never call `Runtime.shared.save` from views.
- **Services** is reached only by `Handler` through `Services.run(line, environment)`.
- **Views:** components take a `ref` and read and write the store directly. `@State` is only for short-lived UI state such as popovers and disclosure.
- **Don't touch** `GroupLayout`, `GroupRow`, `GroupDivider`, `Factory`, `ItemPicker`, `ItemRangePicker`, `LoadMenu`, or `HarnessGroup` styling.

---

## 6. Code style (from `Docs/Style.md`, enforced)

- **No comments:** no doc comments, no `// MARK:`. Fix names instead.
- **Derived values:** use computed properties at the top of a type. Correlated values come back as labeled tuples.
- **Functions:** extract only when there's a second caller. Never write single-use helpers, `make`/`build`/`configure` wrappers, or new "Invocation"/"Request" value types.
- **Naming:** domain noun first. The suffixes `Manager`, `Helper`, `Service`, `Provider`, `Coordinator`, `ViewModel` and `Wrapper` are banned.
- **Formatting:**
  - Two blank lines after imports.
  - `switch` cases indented one level.
  - `return` omitted in single-expression cases.
  - Short `if`/`else` on two lines, with `else` leading.
- **Scope:** do only what's asked. Don't reorganize or clean up neighboring code.

---

## 7. Steps

1. **Runtime, composition.** Make `Functional.parse` expand command references inside sequences and `.fixed` values. Add the generic multi-command runner artifact. Restore harness parameters on the command line. Add the composition tests.
2. **Runtime, harness data.** Rebuild Task Action from update plus action. Add `Command Chain`, Run Space, and Run Space with Command as data in `Harnesses.swift`.
3. **Host.** Make the `compose` tool's `start` take an input and place it in the target space the way typed input is placed, then start through the Runtime facade.
4. **App.** No task-bar changes are needed; the Space chip already sets `space`. Hide `space` from the Command setup rows in `TaskSetup` if Run Space declares it, so it isn't shown twice.
5. **Build and test:**
   - `cd ~/Developer/ScintRuntime && swift build && swift test`
   - `xcodebuild -project Scint.xcodeproj -scheme Scint build`
   - also build the `scintd` scheme.
6. **Manual check (Tim).** Schedule a task with command Run Space, target Notes, and input "organize this folder", 2+ minutes ahead. When it fires:
   - the Notes space's own transcript shows the request and its harness run;
   - the Tasks transcript shows the fire and its completion;
   - the task is closed.

---

## 8. Open decisions (ask Tim before implementing)

- **Input:** does Run Space pass the sheet's document reference, or its rendered text?
- **The `action` key.** It currently means "the sheet" in the argument set, for Schedule Task's callback. Tim's original Task Action uses `action` for the user's command. Which key should each use? Tim has said the scheduling and callback arguments are one set.
- **Output passing:** does the runner pass the previous segment's output to the next (a pipe), or run segments independently? Decide this before building Task Action from it.

---

## 9. Known pitfalls

- **First launch:** on a freshly seeded store, spaces have no context until the app is relaunched. `Composer.load` runs before `RuntimeModel.load()` creates the spaces. Don't fix this by composing inside a facade method.
- **dew:** `add` has no `--replace`. It rejects an `--at` time in the past, and removes `--at` jobs after they run.
- **Persisted definitions:** harness and command definitions are stored. Edits to `Harnesses.swift` take effect after Tim reseeds. Don't write migrations.
- **`SCINT_CONTEXT`** comes from `key.ref.contextId` (the origin), never `key.id`.
- **Logs:** use `/usr/bin/log stream --level debug --predicate 'subsystem == "com.kaechle.scint" OR process == "scintd"'`. zsh's `log` builtin shadows the real command.

---

## 10. When unsure

Stop and ask Tim if a step appears to need:
- a new method on Process, Handler, Composer, Runtime or a core type;
- a new Signal case;
- a change to a tuned layout component;
- a stored state property.

There's almost always a data-level route: parameters, harness command tables, or command composition.
