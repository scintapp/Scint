# Transcripts

A transcript is a `Material` with a `ref`, an `origin`, and an append-only list of entries:

```swift
public enum Entry {
    case record(Record, Date)
    case signal(UUID, Signal, Date)
    case transcript(Reference, Intent, Date)
}
```

`.record` and `.signal` are immutable, concrete data. `.transcript` is the only relational case: it references another transcript.

## Root and branch

- **Root**: `origin` is a Space. There is one per Space, and it is added to the Space's closure content. It outlives any `Process`: `Process.new` finds it again by its `.compose(space)` signal.
- **Branch**: `origin` is a Transcript. There is one per `Handler`. `Transcript.new(root, for: intent)` always creates a new one, unpublished, and appends `.transcript(branch, intent)` to the root. Its only caller is `Process.compose`, which runs on a `.start(input)` when no handler owns that input.

A handler lives from that `.start` until `.complete(branch)` or `.fail(branch)` drops it. While it is alive, another `.start(input)` becomes `.update(input)` and continues the same branch. After it is dropped, the next `.start(input)` creates a new branch, so one input document can have several branches over time. Dropping a handler leaves its branch and the root's `.transcript` entry in place.

Every transcript, root or branch, is stored in the Library store under its own ref and is read directly with `Transcript.with(ref)`.

## Structure

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 520}}}%%
flowchart TB
    S["Space"]
    L["Library store · every transcript by its own ref"]
    P["Process · one per Space<br/>key = .context(space) · transcript = root"]
    H["Handler · one per running input<br/>transcript = branch · dropped on complete / fail"]

    R["ROOT TRANSCRIPT<br/>origin = Space · in Space.closure.content · published<br/>―――<br/>.signal compose(space)<br/>.signal start(input)<br/>.record type=input · key.ref = root · origin = space<br/>.transcript(branch, intent)<br/>.record type=output, no channel · key.ref = branch · origin = harness<br/>.signal update(input) / cancel(space)<br/>.signal complete(branch) / fail(branch)<br/>…repeats per input, one .transcript entry each"]

    B["BRANCH TRANSCRIPT<br/>origin = root · named 'Intent Context' · unpublished<br/>―――<br/>.record type=method (tool calls)<br/>.record type=output with a channel (reasoning, …)<br/>.record type=error<br/>every record: key.ref = branch · origin = harness<br/>no signals"]

    S -->|"closure.content"| R
    S ---|"keys"| P
    L --- R
    L --- B
    P -->|"appends signals + input record"| R
    P -->|"creates on .start when no handler owns the input"| H
    R ==>|".transcript entry"| B
    B -.->|"origin"| R
    H -->|"appends every other record"| B
    H -->|"appends the final reply"| R
```

## Placement

| Entry | Written by | Stored in | `key.ref` | `origin` |
|---|---|---|---|---|
| `.signal(.compose(space))` | `Process.new`, when the Space has no root yet | root | | |
| `.signal(.start(input))`, `.signal(.update(input))` | `Process` | root | | |
| `.record`, `type=input` | `Process.compose` | root | root | space |
| `.transcript(branch, intent)` | `Transcript.new(root, for:)` | root | | |
| `.record`, `type=output` with no channel (the reply) | `Handler` | root | branch | harness |
| `.record`, anything else (method, reasoning, error, …) | `Handler` | branch | branch | harness |
| `.signal(.complete(branch))`, `.signal(.fail(branch))` | `Process`, called by `Handler` | root | | |
| `.signal(.cancel(space))` | `Process` | root | | |

`Record.key.ref` names the transcript that produced the record. The reply is stored in the root but produced by the branch. `Record.origin` is the speaker.

## Order of writes

```mermaid
sequenceDiagram
    autonumber
    participant C as Composer / Runtime
    participant P as Process (one per Space)
    participant R as Root Transcript
    participant B as Branch Transcript
    participant H as Handler (one per running input)

    Note over P,R: Process.new(space) reuses the root whose entries contain .compose(space), otherwise Transcript.new(space) adds it to the Space closure and appends .compose(space)

    C->>P: handle(.start(input))
    P->>R: append .signal(.start(input))
    P->>R: append .record type=input, key.ref=root, origin=space
    P->>B: Transcript.new(root, for: intent)
    B-->>R: append .transcript(branch, intent) to its origin
    P->>H: Handler(transcript: branch), stored in handlers
    H->>H: harness .start runs

    loop every Value the harness emits
        alt type=output with no channel (the reply)
            H->>R: append .record key.ref=branch, origin=harness
        else anything else (method, reasoning, error, …)
            H->>B: append .record key.ref=branch, origin=harness
        end
    end

    alt exit 0 and the signal ends the run (observe .start never does)
        H->>P: handle(.complete(branch))
        P->>R: append .signal(.complete(branch)), handler dropped
    else nonzero exit or thrown error
        H->>B: append .record type=error (thrown error only)
        H->>P: handle(.fail(branch))
        P->>R: append .signal(.fail(branch)), handler dropped
    end

    Note over C,H: While the handler is alive, signals for its input continue its branch
    C->>P: handle(.start(input)) while a handler owns input
    P->>P: becomes .update(input)
    P->>H: handle(.update(input))
    P->>R: append .signal(.update(input))
    Note over H,B: same placement, and on exit 0 the reply is also appended to the input Document
    C->>P: handle(.cancel(space))
    P->>H: handle(.cancel) on every handler
    P->>R: append .signal(.cancel(space))
    H->>P: harness stop exits, handle(.complete(branch)) or handle(.fail(branch))
    P->>R: append the terminal signal, handler dropped

    Note over C,B: Once the handler is dropped, the next .start(input) takes the creation path again and gets a new branch
```
