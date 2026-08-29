# Scint — Two-Day Punch List

**Target: demo-able.** Launch the app, open a space, hit run, watch an agent work
through a legible transcript, with context-scoped tools reaching it via MCP.

---

## Lane 1 — MCP: getting tools to agents

Construction is done and correct. `ServerTool.all(in:)` walks the space's
closure, takes published Commands and Harnesses, and generates JSON Schema from
their declared `Value` types — including reference-typed arguments validated
against what's actually in closure scope. The contextual-scope thesis is
implemented and working.

**The gap is delivery, not construction.**

- [ ] **Nothing tells a spawned agent the server exists.** Outside
      `Sources/ScintServer/`, the string `mcp` appears nowhere in the codebase.
      The process is spawned with `SCINT_CONTEXT` in its environment — the
      bearer token — but never with the server address. Credential delivered,
      address withheld.

- [ ] **`ContextServer.args` is dead code.** It encodes the exact registration
      (`mcp add Scint --url … --bearer-token-env-var SCINT_CONTEXT`) and is
      referenced only by the "Copy Server Address" menu item in `ScintStudio`.

- [ ] **Declare MCP attachment as a harness parameter, per vendor.** The Claude
      Code and Codex harnesses in `SampleData` declare `--model`, `--add-dir`,
      `--permission-mode`, `-c model_reasoning_effort=…`, `--output-format
      stream-json` — every vendor flag except the one that attaches a server.
      Claude Code takes `--mcp-config`; Codex takes `-c mcp_servers.…`.
      This belongs in the parameter model next to `--model`, where the rest of
      the per-vendor CLI knowledge already lives. `ContextServer` doesn't move.

- [ ] **Then get one end-to-end trace on record.** Real agent, real handshake,
      `tools/list` returning the space's tools, one `tools/call` round-tripping.

### Verify only once a client is actually connecting

Two code paths in `ContextServer` that may or may not bite. Don't touch them
until a real client is talking — they're cheap to check then, and speculative
now.

- [ ] `notifications/initialized` has no `id` by definition. If the client omits
      the `MCP-Protocol-Version: 2025-06-18` header, `handle` takes the modern
      branch and returns `Invalid Request` on the missing id before reaching
      the 202. Only reachable when the header is absent.
- [ ] `validate` requires `params["_meta"]["io.modelcontextprotocol/…"]` fields
      that the code's own comment says no shipping client emits. Same trigger:
      only reached when the legacy header is absent.
- [ ] `ping` isn't handled; falls through to `-32601`. One line if a client
      health-checks with it.

---

## Lane 2 — The messaging model

Highest demo-visibility per hour spent.

- [ ] **Define the messaging model that speaks to the runtime's requirements.**
      `Signal` today is a *transport* enum — eight cases each wrapping a `Value`.
      No role, no content blocks, no tool-call/tool-result pairing, no call IDs,
      no streaming deltas.

- [ ] **Implement vendor JSON sniffing into it.** The live hole is
      `ServiceRegistry.Handler.handle`, `.events` case, which returns the raw
      line verbatim under a comment saying structured decoding "belongs to a
      declared vendor format … the raw line is kept until one exists."
      `Services.signals(_:)` falls through the same way.
      **Consequence: the transcript renders raw vendor JSON on screen.**

- [ ] Cover Codex (`item.completed` envelopes) and Claude Code (`assistant` /
      `result` envelopes with `text` / `thinking` / `tool_use` blocks). Both
      harnesses already run with `--json` / `--output-format stream-json`, so
      the structured output is arriving and being discarded.

---

## Lane 3 — Agent context composition

- [ ] **Re-implement context composition.** `Context.start` currently sends
      `Runtime.shared.rendered(origin)` as the prompt — a raw recursive
      projection with no preamble, no framing, no content handles, no thread.
      The agent gets a dump and is told nothing about the space it's in or the
      tools it has. Pairs directly with Lane 1: registering the server is
      pointless if the agent is never told what the tools are for.

- [ ] **Restore argument validation on the space-start path.** `Context.start`
      renders arguments straight from config — its own trace line says "nothing
      validates them now." The MCP tool path already validates via
      `Command.bind` / `Harness.bind`. Route both through `bind`.

---

## Lane 4 — App polish

- [ ] *(needs the actual list — small quality and polish issues)*

---

## Lane 5 — Housekeeping

- [ ] **Replace `Resources/serviceRegistration.sh` with `SMAppService`.** It runs
      as a Run Script phase on *every* build (the phase has "Based on dependency
      analysis" unchecked) and rewrites the current user's `com.kaechle.scintd`
      LaunchAgent.

- [ ] **One cold build before the demo.** The green build on record was
      incremental — real `SwiftCompile` phases and a real codesign, but no link
      step.

- [ ] Delete `Sources/ScintRuntime/Extensions/Instructions.swift` — 190 lines,
      entirely commented out, superseded by Lane 3.

- [ ] Strip `Trace` once the Contextual flow is settled. The file says so
      itself: "Scaffolding, not architecture."

---

## Not in scope

- **The abstract factory.** Out of scope by decision. Dependent modules work.
  Regular view modules are fine meanwhile.

- **The intent structs.** `Composing` / `Dispatching` / `Evaluating` /
  `Observing` / `Searching` are declared scaffold — the header comment says the
  identical bodies are deliberate sketches, not accidental duplication. They've
  sat for months without blocking anything. Not a two-day problem. When they do
  get built out, the semantics are the work, not the shape.

- **Dispatch / Evaluate / Search intents.** Same reason.

---

## Where I've been — do not repeat

Deleted in `921ee2e`.

| Module | Lines | Did | Note |
|---|---|---|---|
| `TranscriptContent.swift` | 87 | Vendor JSON → `.message` / `.reasoning` / `.tool` | Closest prior art for Lane 2. **Lossy by construction:** dropped tool arguments, results, and call IDs; returned only the *first* matching content block, so a Claude message with both `thinking` and `text` lost the text. Carried display verbs (`"Ran"`, `"Called"`) in a runtime type. All vendor knowledge in one `init?`. |
| `Serialization.swift` | 182 | Composed the agent context document | Prior art for Lane 3 — preamble, content handles, thread windowing. Its commented-out twin is still sitting in `Instructions.swift`. |
| `Parser.swift` | 105 | Validated + bound command/harness arguments | Superseded by `Command.bind` / `Harness.bind`. Lane 3 finishes the migration. |
| `Observers.swift` | 40 | Fired observe-intent spaces on a watched space's terminal | Paired with the "Cron Observer" command in the old `Executors.swift`. Re-read before any future observe work. |
| `Executors.swift` | 491 | `SampleInterfaces` — sample harness/command declarations | Not lost; merged into `SampleData.swift`. |
| `Properties.swift` | 160 | — | Not lost; consolidated into `Property.swift`. |

Read one with:

```
git show 921ee2e^:Sources/ScintRuntime/Core/Records/TranscriptContent.swift
```
