# ScintServer

ScintServer is the protocol projection of an active runtime context. It does not own
processes, capability scope, or execution history. Those remain properties of
`Context`, its active `Harness`, the origin's `Closure`, and the XPC process service.

## Runtime invariants

- A `Context` is the runtime process boundary for one `Workspace` or `Space`.
- The origin's active `Harness` is the process managed through `scintd`.
- `Closure.interfaces` is the authoritative set of functional capabilities available
  in that context.
- `SCINT_CONTEXT` carries the origin's contextual identity into the Harness process and
  any capability process it starts.
- A composition must be active or running for its MCP surface to exist.
- MCP keeps no parallel grant, session, capability snapshot, or process registry.

## Server boundary

`ScintServer` owns only the MCP wire boundary:

1. Accept a request on the loopback MCP endpoint.
2. Read the context identifier supplied through the configured bearer environment
   variable.
3. Resolve the live composition and its origin.
4. Derive tools directly from the origin's current Closure.
5. Translate MCP arguments into runtime `Value`s.
6. Execute the selected functional interface through the existing runtime and XPC
   service path.
7. Translate runtime signals into an MCP result.

`ScintService` remains unaware of MCP. It continues to own executable launch, process
identifiers, standard input and output, termination, and restart behavior.

## Protocol surface

The server implements MCP revision `2026-07-28` over Streamable HTTP with one POST
endpoint at `/mcp` and JSON responses. It also accepts the sessionless subset of
revision `2025-06-18` used by the installed Codex CLI. Its functional surface remains:

- `server/discover`
- `tools/list`
- `tools/call`

For `2025-06-18` clients, `initialize` returns the same tool capability and
`notifications/initialized` is accepted as a no-op. These requests establish no server
state and no `Mcp-Session-Id` is issued. Every request remains independent. The server
does not implement protocol sessions, server-sent events, subscriptions, prompts,
resources, tasks, sampling, roots, logging, elicitation, or extensions.

`2026-07-28` requests must carry the `MCP-Protocol-Version` and `Mcp-Method` headers
required by the HTTP binding. `tools/call` must also carry `Mcp-Name`. Mirrored header
values must agree with the JSON-RPC body. Compatibility requests after `initialize`
must carry `MCP-Protocol-Version: 2025-06-18`. The endpoint remains bound to
`127.0.0.1` and rejects a supplied non-loopback `Origin`.

## Context selection

The CLI is configured to use `SCINT_CONTEXT` as the bearer value. The value is a
context selector, not an independently managed capability token. On every request the
server resolves a live composition whose structural reference carries that context
identifier. The composition must originate from a `Space` and be active or running.

No state is retained when a context becomes inactive. The same contextual identifier
becoming usable again when the Context runs again is intentional runtime continuity.

## Tool catalog

The tool catalog is derived on demand from the origin's Closure. A functional reference
is exposed when:

- it belongs to `Closure.interfaces`;
- it resolves to a `Command` or `Harness`; and
- its descriptor is published.

The active Harness is stored on the structure outside the Closure. It is therefore not
implicitly exposed as a tool. A Harness present in `Closure.interfaces` is an explicitly
authored capability and is exposed.

Tools are sorted deterministically by protocol name. Lists are private to the selected
context and have no freshness lifetime because the Closure remains the live source of
truth.

## Tool identity

Tool identity is a pure function of the functional reference:

```text
Scint.command.<reference-id>
Scint.harness.<reference-id>
```

The complete lowercase UUID is used. Descriptor names remain human-facing titles and
may change without changing protocol identity. Material command rendering uses the same
naming rule without a registry or mapping.

## Schemas and arguments

Only caller-bound `.argument` parameters appear in a tool's input schema. Fixed Command
parameters and Harness command fragments, requirements, and targets remain runtime
concerns.

Runtime `Value` shapes map to JSON Schema as follows:

| Runtime value | JSON Schema |
| --- | --- |
| `bool` | `boolean` |
| `integer` | `integer` |
| `decimal` | `number` |
| `string` | `string` |
| `reference` | `string` resolved against the current Closure |
| sequence containing alternatives | `enum` |
| empty or single-template sequence | `array` |
| multi-field collection | closed `object` with required fields |
| single-template collection | the contained schema |

MCP payloads use the runtime's `Property` and `Properties` JSON algebra. Argument
properties construct supplied runtime values and then delegate required arguments,
defaults, and final validation to `Parser.parse(_:for:)`.

## Invocation

A Command tool call is evaluated as:

```text
MCP arguments -> Value dictionary -> Parser -> Command rendering -> Command.dispatch
```

A Harness tool call is evaluated as:

```text
MCP arguments -> Value dictionary -> Parser -> underlying Command rendering
              + Harness rendering -> Command.dispatch
```

Both paths pass the origin's existing `SCINT_CONTEXT` to the launched process. They do
not create another Context or Intent. `Command.dispatch` registers the existing
`Services` output handler, and the MCP request waits for its terminal runtime signal.
Updated values become text content; a failed signal produces a tool execution error.

Unknown tool names and malformed JSON-RPC requests are protocol errors. Runtime parsing,
launch, and process failures are tool execution errors surfaced to the agentic process.

## Material integration

`Material.Block.command` renders the deterministic MCP tool name
`Scint.command.<reference-id>` instead of the Command's process invocation fragments.
Rendering still requires the reference to resolve to a Command. It does not execute the
Command, create an Intent, or maintain a separate interface mapping.
