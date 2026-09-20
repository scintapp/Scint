# Domain and Intent tools

The MCP endpoint remains `http://127.0.0.1:7345/mcp`. `tools/list` returns exactly
`scint.domain` and `scint.intent`. Enum cases select methods inside these tools;
they do not create additional MCP tools.

Every call uses the existing `Property` / `Properties` representation:

```json
{
  "name": "scint.domain",
  "arguments": {
    "domain": "document",
    "action": "create",
    "arguments": { "name": "Notes", "text": "First note" }
  }
}
```

The inner `arguments` object is required, including for methods with no arguments.
Schemas are published with the tools. The server validates the selected method's
schema, rejects unknown fields, checks identity, and resolves every reference
before entering the runtime. A reference is a canonical `scint://<kind>/<id>` URL;
the URL kind must match the stored reference's type.

## Domain

| Domain | Actions | Arguments and behavior |
| --- | --- | --- |
| `document` | `create`, `insert`, `delete` | Create takes `name`, optional `text` and `space`. Insert takes `ref` plus `text` (optional task `done`), or `member` for a reference block. Optional `index` inserts at a position; `block` instead edits an existing text/task block. Delete takes `ref`; optional `block` deletes only that block. |
| `interface` | `create`, `run`, `delete` | Create takes `kind` (`artifact`, `command`, `harness`), `name`, optional `space`, and kind-specific fields below. Run takes `ref` and optional interface `arguments`. Delete takes `ref` and rejects interfaces with dependents. |
| `structure` | `create`, `update`, `delete` | Create takes `name` and optional `parent`. Update takes optional `ref` (current space by default), metadata (`name`, `description`, `tags`), `config`, one relationship change (`add` or `remove`), and optional `harness` (`null` clears it). Delete takes an empty, uncomposed child space's `ref`. |

Artifact creation takes an absolute `url`. Command creation takes an artifact
`source`, optional string-array `fixed` arguments, and optional `parameters`.
Harness creation takes a command `source`, an `intent`, and optional `parameters`.
Each parameter is an object with `name`, `type` (`string`, `boolean`, `integer`,
`number`, or `date`), optional `required`, and optional typed `default`.

```json
{
  "domain": "interface",
  "action": "create",
  "arguments": {
    "kind": "command",
    "name": "Print a message",
    "source": "scint://artifact/<id>",
    "fixed": ["%s\n"],
    "parameters": [{ "name": "message", "type": "string", "required": true }]
  }
}
```

Setting a space's `harness` also adds that harness to the space. Replacing or
removing an active harness requires stopping its intent first. `remove` detaches
membership; `delete` deletes the underlying record. Shared values, referenced
interfaces/documents, recorded transcripts, and the caller's origin cannot be
deleted through Domain.

## Intent

| Intent | Actions | Behavior |
| --- | --- | --- |
| `compose` | `compose`, `start`, `update`, `stop` | Compose creates/reuses a runtime context without executing. Start runs a compose harness; update stops and replaces that intent; stop terminates it. |
| `dispatch` | `dispatch`, `start`, `update`, `stop` | Dispatch returns a dispatch harness's output. Start runs it in the background and returns a transcript; update/stop manage that intent. |
| `observe` | `start`, `update`, `stop` | Runs an observe harness in the background and returns its transcript. Updates use fresh arguments and a fresh branch identity. |
| `search` | `search` | Catalog `method=list`, `describe`, or `search` discovers references, reads content, and reports scopes/schemas. Alternatively, supply a search `harness` and its arguments to execute research. |

Lifecycle methods take optional `space`, `harness`, `input`, and harness
`arguments`; stop takes only `space`. A default harness must implement the
selected intent. An explicit harness must already be in scope. A target space
needs a configured harness before it can be composed. Update requires an active
handler for that intent; it is a replacement, not a write to process stdin.

Discover and read:

```json
{
  "intent": "search",
  "action": "search",
  "arguments": { "method": "list", "domain": "document" }
}
```

```json
{
  "intent": "search",
  "action": "search",
  "arguments": { "method": "describe", "ref": "scint://document/<id>" }
}
```

Catalog search takes `query`, optional `domain`, and optional `scope` (`space`
by default, or `library`). Library discovery returns published metadata with
`import` scope; it does not authorize reading or running the value. Use Domain
structure/update/add to attach that value to an owned space. Importing a document
preserves its existing origin, and a value shared with another origin remains
read-only.

## Identity and reference scopes

`SCINT_CONTEXT` is the bearer identity. Tool arguments cannot override it. The
server binds a request to one running composition, then rechecks that identity
at dispatch and when resolving references. A cached tool binding is not a grant.

The caller can manage its origin and descendants. Parents, siblings, and bridge
targets are outside that scope. Published documents/interfaces in those spaces
can be read; unshared documents can be edited; commands/harnesses can run.
Private input documents are unavailable. Transcript roots and their recorded
branches can be read, including unpublished intent branches, but never edited.

Every background run receives a new transcript branch and uses that branch's
context ID in its process environment. Stop, update, and completion remove the
handler, revoking the branch bearer. Stopping one intent preserves other handlers
in the same composition. The existing live origin/root bearer remains accepted
while that composition has running handlers.

## Verification

Run `./script/test_tools.sh` to build and exercise the JSON-RPC router, tool
schemas, scoped operations, topology validation, and identity/grant revocation.
A real MCP SDK client also connects over loopback HTTP, negotiates its protocol
version, authenticates using the existing handler environment, lists the two
tools, and calls both Domain and Intent.
Tests use an isolated XDG data directory and synthetic active process records;
they never launch an agent. `./script/test_tools.sh --skip-build` reuses the last
build. XPC execution and graphical interaction require a separate live smoke test.

`./script/build_and_run.sh --build-only` uses isolated Xcode output and skips
LaunchAgent registration. The default `./script/build_and_run.sh` builds and
launches Scint using the repository's service registration workflow.
