# Interfaces

**What each one does.** Both types do the same job:
1. declare some parameters;
2. read their values from a space's config;
3. resolve a parameter that references a `Command`;
4. build an argument list around a runner command;
5. execute it.

| | Harness | Automation |
|---|---|---|
| Its own parameters | `parameters` | `Automation.parameters` (`when`, `action`) |
| The command it wraps | a `command: .reference(Command)` argument, which `passthrough` resolves and whose parameters `parse` merges in | `action: .reference(Command)`, resolved by hand from config |
| Building the argument list | `Harness.arguments` expands a command reference into `[executable] + command.arguments(with: values)` | builds `[executable] + command.arguments(with: values)` itself |
| The runner | `self.command` (Exec, Codex, Schedule Job…) | Schedule Job and Remove Job, looked up by name |
| Where it runs | inside the runtime: `Process` → `Handler`, with `SCINT_CONTEXT`, the intent's rendered prompt as `input`, output parsed into the transcript, and exit codes as signals | outside it: none of that |

**The Observe harness already exists.** Its runner is Schedule Job and its intent is `.compose`, but its `params` is `[]`. Automation's parameters are the ones that belong there. Because Automation reimplements the harness outside the harness, the automations it runs get no context, no transcript and no way back. The type shouldn't exist. It should be the Observe harness with `when` and `action` as its parameters, and the action is just a command.

## Command relative to Harness

**Command** is an artifact plus a typed signature. Its parameters are fixed arguments and named arguments, each with a type, a default and a required flag.
- `parse` builds and checks values against those types.
- `arguments(with:)` turns values into command-line arguments.
- `run` starts the process.

It knows how to invoke one executable, and nothing about spaces, intents, contexts or transcripts.

**Harness** is an intent plus a runner command plus its own parameters. It's what puts a command into the runtime.
- `parse` merges three sets of parameters: the harness's own, those of any command passed in through a command reference, and the runner's. It sends the rendered prompt to whichever of them declares `input`.
- `run` builds the runner's arguments (minus the ones the harness owns) and adds the harness's own, with any passed-in command expanded in place.
- A `Handler` drives it with the context's environment. The intent decides how the prompt is mapped and how the transcript is structured.

**Why they work together.** Commands are raw, reusable capabilities: Codex, Claude Code, dew, `env`. Harnesses decide what role a capability plays in the runtime. The Exec pattern shows the payoff: Compose, Evaluate, Dispatch and Search all run on `env` and take a `command`. So any command can serve any intent, and you swap one side without touching the other. Parameters come from the command, and the process, context, transcript and signals come from the harness.

## Artifact

An `Artifact` is the concrete thing itself: an executable, a script, a file, a directory, an app, a bookmark or a skill. `Handler.classify` decides which from the URL.

It comes into play at two levels:
- **Under commands.** Every command's `executable` is its artifact's path, so the artifact is what actually runs.
- **As values.** Artifacts are also arguments: Codex's `-C` directory and `--add-dir` are `.reference(Artifact.self)` and marshal to paths.

## The three together

| Type | Role | Wraps |
|---|---|---|
| Artifact | the resource | — |
| Command | how to invoke it | an artifact |
| Harness | its role in the runtime | a command |

All three are `Functional`, addressed by refs, and addable to spaces as interfaces. Each can be swapped independently, and the harness is the only way into a process.

For automations that means scheduling is an Observe run in the Tasks space's process. Schedule Job is the runner, and each sheet's config supplies `when` and `action`. The sheet's command is the `action`, exactly like the `command` parameter on the other harnesses.