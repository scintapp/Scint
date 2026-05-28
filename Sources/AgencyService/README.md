# AgencyHarness

### What it does

This is a **macOS background daemon** (`agencyd`) that acts as a process-supervision and service-management broker. It launches, tracks, supervises, and communicates with arbitrary child processes on behalf of clients, and it exposes that capability over an **XPC interface** under the Mach service name `com.kaechle.agencyd`. In your framing — the "meta service provider for the runtime" — this is the thing that actually *owns* the OS processes that the rest of the ecosystem wants to run. Everything above it talks to it rather than spawning processes directly.

There are two conceptual layers it manages:

- **Ad-hoc processes** — fire-and-forget commands started by PID, tracked while alive.
- **Registered services** — named, persistent definitions (`id`, command, args, restart policy) that can be started/stopped/restarted by stable ID rather than by ephemeral PID.

### What it handles / supports

The capability surface, drawn from the XPC interface and the `request` dispatcher:

- **Process lifecycle** — `start`, `stop`, `restart`, with PID as the handle.
- **Bidirectional I/O** — child stdout/stderr is merged into one pipe and streamed back to the client in real time via an `emit` callback; `write` pushes data to the child's stdin, with an optional `close` to signal EOF.
- **Introspection** — `list` (human-readable), `listJSON`, `inspect` (per-PID detail: uptime, restart count, policy, start time), and `status` (daemon-wide snapshot of all processes + services + daemon uptime).
- **Harness registry** — `registerHarness` / `unregisterHarness` / `services` / `startHarness` / `stopHarness` / `restartHarness`, keyed by string ID.
- **Restart policies** — `never`, `onFailure`, `always`, evaluated in the process termination handler, with a delayed (1s) re-spawn and an incrementing restart counter.
- **Environment resolution** — on first use it spins up a login shell (`$SHELL -lc "env -0"`) to capture the user's *real* interactive environment, so child processes inherit a realistic PATH etc. rather than the daemon's bare launchd environment.
- **Variable expansion** — its own hand-rolled `$VAR` / `${VAR}` substitution over command and arguments against that resolved environment.
- **A dual API shape** — every capability is reachable two ways: as a **typed XPC method** (`start`, `stop`, …) *and* as a **JSON string action** through the single `request(_ json:)` method (`"action": "start"`, `"service/register"`, etc.). The JSON path is essentially a self-contained command protocol layered on top of the typed one.

### Architecture

The structure is clean and layered:

**`Harness.swift`** — the `@main` entry point. Stands up an `NSXPCListener`, wires a `HarnessDelegate`, touches `ProcessStore.shared` to force initialization, and parks on `RunLoop.main.run()`. Minimal by design.

**`HarnessDelegate`** — per-connection setup. On each new XPC connection it sets the exported interface (`HarnessProviding`, what the daemon offers) and the remote interface (`HarnessHandling`, the callback channel back to the client), then instantiates a fresh `HarnessDaemon` as the exported object. So each client connection gets its own daemon facade with its own `ownerID`.

**`HarnessDaemon`** — the XPC-facing facade. It's almost pure delegation: nearly every method forwards to `ProcessStore.shared`, passing along its `ownerID` and an `emit` closure. The `emit` closure is the elegant bit — it resolves the remote object proxy (`HarnessHandling`) lazily and pushes output chunks back to *that specific client*. So the daemon instance is per-connection, but the actual state lives in a shared singleton.

**`ProcessStore`** — the real engine, and the heart of the module. A `@unchecked Sendable` singleton guarding a `[pid_t: TrackedProcess]` dictionary behind a **concurrent dispatch queue** with barrier writes (the classic concurrent-read / barrier-write pattern). It owns spawning, the pipe wiring and readability handlers, the termination handler (cleanup + policy-driven restart), env resolution, variable expansion, and the JSON `request` router. `TrackedProcess` is the per-process record — process handle, pipes, owner, label, start time, restart count, policy, and the captured `emit`.

**`HarnessRegistry`** — a second `@unchecked Sendable` singleton, also concurrent-queue-guarded, holding the *definitions* and the bidirectional `serviceID ↔ pid` mappings. It's deliberately separate from `ProcessStore`: the registry knows about *what services exist and which PID is currently fronting each*, while the store knows about *live processes*. This file also defines the shared value types — `HarnessPolicy`, `HarnessDefinition`, and a `Handler` type that turns raw output chunks into `Event`s (either line-split messages or a single parsed event), which is clearly a seam into the `AgencyRuntime` layer.

**`HarnessUtilities.swift`** — small free functions for JSON encode/parse and `Any?`→`Int32` coercion, the connective tissue for the JSON protocol.

The dependency direction is notable: the daemon imports `AgencyRuntime` and leans on types from it (`HarnessProviding`, `HarnessHandling`, `Event`). So the *contracts* live upstream in the runtime, and this module is the privileged implementation that actually holds the processes.

### Initial thoughts

A few things stand out about the design intent:

The **dual-interface design** (typed XPC methods *and* a JSON `request` action protocol covering the same surface) reads like a deliberate choice to support two kinds of caller: a Swift client that wants type safety, and a more dynamic/scriptable or forwarded caller that just ships JSON. That `request` method looks like the seam where higher layers (or a CLI, or a remote bridge) inject commands without binding to the XPC vtable.

The **per-connection daemon + shared singleton store** is a sensible XPC idiom. Identity (`ownerID`) and the client callback channel are scoped per-connection, but the authoritative state is global to the daemon process. That ownerID is threaded through everything, which suggests ownership/attribution matters somewhere downstream even though this module doesn't yet enforce much with it.

The **login-shell environment capture** is a telling detail. It signals the daemon expects to run things a developer would run from their own terminal — the whole `env -0` dance exists so spawned commands behave like they were launched interactively. Combined with the `$VAR` expansion, this feels oriented toward running developer tooling / local services rather than sandboxed system jobs.

The **registry/store split** is the cleanest architectural decision here: stable identity (definitions, policies) lives apart from volatile runtime state (live PIDs, pipes). That separation is what lets a service survive restarts and PID churn while keeping a stable `id` handle, and it's what `status`/`services` reconcile when they cross-reference "is the active PID actually still in the store → running vs stopped."

And the **`Handler` / `Event` type** is the one outward-facing hint about the layer above: output isn't just streamed as text, it can be interpreted as structured events. That implies the runtime layer expects child processes to speak some event protocol on stdout, and this daemon is the transport for it.

So my running map so far: **`AgencyHarness` = the privileged process-supervisor at the bottom of the stack**, contracts defined in `AgencyRuntime` above it, talking XPC to whatever clients sit higher. I'll expect the next layers to define those `HarnessProviding`/`HarnessHandling`/`Event` contracts and the client side that consumes this.

Ready for the next module whenever you are.
