# Orchestration and composition

A design document for intents, clusters, bridges, and the context model that ties
them together. It records what the design is for, what is built, and what is still
open. Status markers: **Built** (exists in code today), **Gap** (a named missing piece
the design depends on), **Open** (a decision not yet made).

Source: working notes in `Orchestration and Composition.md`, checked against the
code on 2026-09-14.

---

## 1. Thesis

Scint builds **clusters**: a handful of spaces joined in a process tree that behaves,
from the outside, like one agent. Inside, each space is a separate scope of context
with its own harness, tools, documents, and transcript. Structure, tools, and harness
assignments together decide how the cluster behaves.

A cluster is not a workflow. DAGs, pipelines, and workflow engines specify control
flow, and they suit elaborate business processes. A cluster specifies **scope** (who
can see what) and leaves flow to the agents working inside it. That keeps a cluster
small enough to understand and judge.

The canvas exists to design, tune, and refine these constructs.

---

## 2. Vocabulary

| Term | Meaning | Type in code |
| --- | --- | --- |
| **Space** | A container of context and the agent working in it. Holds a closure, a harness, transcripts, and bridges. | `Space` (`Structural`) |
| **Closure** | What a space contains: artifacts, commands, harnesses, documents, transcripts. | `Closure` |
| **Harness** | The process that works in a space: a command plus an intent and parameters. | `Harness` (`Functional`) |
| **Intent** | What kind of work a harness does. It decides which tools the harness gets and how its context is built. | `Intent`: `compose`, `dispatch`, `observe`, `evaluate`, `search` |
| **Cluster** | A tree of spaces with one composer, presented outward as a single agent. | Space tree |
| **Composition** | A running process for a space. | `Composition`, `Composer` |
| **Bridge** | A harnessless closure shared by two spaces in different parts of the tree. | `Bridge` (`Structural`) |
| **Transcript** | Append-only record of what processing produced. A side effect, not the agent's identity. | `Transcript` (`Material`) |
| **Alcove** | A branch transcript holding context that stays out of the primary thread unless it's needed. | `.transcript(Reference, Intent, Date)` entry |
| **Fold** | The context an agent sees on a turn, built fresh by walking and serializing parts of the transcript tree and closure. | `Renderer` |
| **Descriptor** | Name, description, and tags for any object. The index that routing uses. | `Catalog` |

---

## 3. Intents

### 3.1 Roles

| Intent | Role | Receives | Produces | Harness examples |
| --- | --- | --- | --- | --- |
| **Compose** | Orchestration. Sees the cluster at a high level, starts and stops children, watches the health of each context, and presents one front to the user. | Name, description, and state of every space in the cluster | Direction to children; a single voice outward | Composer |
| **Evaluate** | Work. Handles the tasks in exactly one space. | That space's preamble, documents, capabilities, recent thread, and the request | Solutions and document changes | Codex Harness, Claude Code harness |
| **Dispatch** | Pure execution. Holds large tool sets (MCP servers, connectors) so other spaces don't carry the tool index or the tool-call noise. | Tool definitions and a request | Tool results | Dispatcher |
| **Search** | Retrieval. Deep research, ranking, aggregation, outward search, so workers get a clear result instead of low-signal search noise. | A question and a little framing, without the space's documents | A dense, aggregated result | Searcher |
| **Observe** | Automation. Waits on a predicate (a time, a folder, an endpoint) and acts when it fires. | A predicate and a target | Side effects | Scheduled Observer, Directory Observer |

### 3.2 Context polarity

Intent sets both the tools a harness can use and the shape of context it gets. The
axis runs from depth within one space to breadth across many.

```
 below the floor          tight, robust           robust, sparse
 ───────────────────────────────────────────────────────────────▶
 Observe   Dispatch        Evaluate                Compose
 predicate tool defs +     one space, complete     many spaces, each
 + target  request                                 as name/description/state

 Search:   sparse in ─────────────────────────────▶ dense out
```

- **Observe** needs less than anything else: a predicate and a target, with no request at all.
- **Dispatch** is tight on purpose. Withholding context from everyone else is its job, so it can't hold much itself without defeating the point.
- **Evaluate** holds the densest concrete context. It's limited to one space, but complete within it. **Built** as `Renderer.evaluation`.
- **Compose** trades depth for breadth. It sees sixty spaces but not their contents.
- **Search** is asymmetric: a thin question goes in and a dense result comes out. It's the only intent whose input and output sit at opposite ends of the axis, which is why it resists a single definition.
- **Observe** is asymmetric in a different way: sparse in, **side effects** out. It's the only intent whose product isn't context at all. That makes it the unpredictable one: nothing about the intent constrains what it does when it fires.

### 3.3 Serialization per intent

`Renderer` is the model-facing prose serializer. Moving `Arguments` out of it left
`Renderer` with one job, so each intent can get its own serialization.

| Intent | Serializer | Status |
| --- | --- | --- |
| Evaluate | `Renderer.evaluation` | **Built** |
| Compose | Cluster summary: descriptor and state per space | **Gap** |
| Dispatch | Tool definitions and the request | **Gap** |
| Search | Question and framing | **Gap** |
| Observe | None needed: the predicate is in its arguments | — |

### 3.4 Where intents are going

The goal is real distinctions, not labels:
- **Search:** a family of harnesses for deep research, information retrieval, ranking, and aggregation.
- **Dispatch:** pluggable MCP servers and other connectors at the harness level, without loading every tool into the host.
- **Compose:** a layer above execution that watches, occasionally nudges, and mainly carries context between the user and the network of agents below.

---

## 4. Clusters

### 4.1 Shape

```
            Composer (Compose)
           ╱        │         ╲
   Outreach log   Drafting    Task watcher
    (Search)     (Evaluate)    (Observe)
                     │
               Voice classifier
                 (Evaluate)
```

Example: an email cluster. One space catalogs outreach and response rates, one runs
drafts through a classifier so they sound like the user, and one watches for new
tasks and keeps the task list in order. From outside, the user sends one message to
one agent.

### 4.2 The outward face

**Built.** `ToolIdentity.resolve` matches a bearer token to one composition, and every
tool a caller can reach is scoped to that space by `Scope.reachable`. A caller has no
way to address anything past the space its token resolves to. A cluster is opaque by
default. Leaking its internals would take deliberate work, so "feels like one agent"
needs no facade.

### 4.3 What a composer does

| Responsibility | Status |
| --- | --- |
| Start children | **Built** |
| See each child's name, description, and state | **Built** (`Catalog`, `Composition.state`) |
| Learn that a child stopped or failed | **Gap**, see §7 |
| Watch context health (size, staleness) | **Open** |
| Keep its own descriptor accurate as work happens | **Open**, see §6.2 |
| Recover from a child's failure without breaking the single front | **Gap** (depends on §7) |

### 4.4 Composers should be long-lived

Every layer of composer adds a CLI cold start in front of the worker. Two layers
mean three sequential starts. A composer that stays running avoids that. **Built:** an
observe-intent composition stays `.active` indefinitely and still answers MCP calls.

### 4.5 Failure is where the single front is tested

The single front holds only while everything works. When a child fails mid-request,
the composer either repairs it quietly or lets the internals show. Today it wouldn't
know to do either, because nothing tells it the child failed.

---

## 5. Bridges

### 5.1 What a bridge is

A bridge is a closure with no harness, shared by two spaces in otherwise separate
parts of the tree. Content, interfaces, and tools can be added to and removed from it
like any space. It does nothing on its own. **The seam is a place, not a pipe.**

```
 ┌ Cluster 1 ┐        ┌ Cluster 2 ┐        ┌ Cluster 3 ┐
 │   tree    │── A ───│   tree    │─── B ──│   tree    │
 └───────────┘        └───────────┘        └───────────┘
```

**Built:**
- `Bridge` is `Structural`, has its own `Closure`, and `add`/`remove` accept `Functional` and `Material` refs like `Space`.
- `Bridge` has no `harness` property (`Space` has `harness: Reference?`). Being harnessless is part of the type, not a convention.
- `Runtime.adjacent` and `Runtime.cross` traverse bridges, which is the graph walk the canvas needs.
- `Space.bridges` records each bridge on both ends, and `Scope.structures` lists them.

### 5.2 Not transitive by construction

Cluster 1 holds A, cluster 2 holds A and B, cluster 3 holds B. Cluster 3 can't
address A, not because a rule forbids it but because A isn't in its set of reachable
references. Information moves from A to B only if cluster 2 carries it across on
purpose. That structural guarantee keeps clusters from quietly turning into a mesh.

### 5.3 Why bridges have no behavior

A workflow edge transforms or routes, which makes it a step. A bridge only holds
things, so it defines scope and leaves flow to whoever reads it. This is the choice
that keeps a cluster a cluster and not a pipeline.

## 6. Recursion

### 6.1 A cluster of composers

A composer that presents half a dozen agents as one can, one level up, be one of
several composers under a meta-composer. **Built structurally:**
- Spaces nest arbitrarily. `Runtime.walk` does a cycle-safe depth-first walk.
- Each space has its own closure, transcript, composition, and MCP context token.
- `ToolIdentity.resolve` matches a bearer to a space, a transcript, or a branch, so separate identities within one composition already work.
- Transcripts form their own tree through origin and branches.
- Bridges add links that aren't part of the hierarchy.

Nothing in the model prevents a composer of composers. It's a status of
**Open, hypothetical**: the idea is clear, the details aren't.

### 6.2 Routing to contexts, not models

The meta-composer reasons over sparse context and routes a request to the **composer
that was there for it**, not to a model that could do it. Mixture-of-experts routes
on capability. This routes on situated knowledge, and it needs far less context,
because it matches what a space is *about* rather than what it can *do*.

This means continuity isn't a memory system. The router doesn't have to recall the
conversation. It has to send the request to the context that never lost it.

The index already exists: `Catalog` holds a descriptor for everything, and
`Runtime.search` scores over them. **Gap:** descriptors are written once at creation
and go stale as soon as a space does real work. The small fix is to make keeping its
own descriptor current part of a composer's job, so routing has accurate information.

## Context model

### Context is not the thread

Transcripts are a side effect of processing, not the agent's identity. What an agent
sees on a turn is built fresh each time: a fold over the relevant branches, shaped by
intent. It works more like a person pulling together what they need from a body of
information, closer to shape than to content.

### 8.2 Transcripts as a rose tree

**Built:**
- A transcript's branches aren't nested inside it. They're found by filtering its own entries for `.transcript(Reference, Intent, Date)`. Each child is a separate object with its own reference and entries.
- `entries` is `private(set)` with only `insert` exposed, so transcripts are append-only by construction.
- `Transcript` is `Material`, not `Structural`: a transcript is content, not architecture.
- Branches exist only as references. Logically, every transcript stands on its own.
- `Handler.handle` sends message readings to the root and everything else to the branch, so branch content is kept out of the main thread when it's written.

### 8.3 The split point is an entry

The `.transcript` entry sits in order among the entries before it and carries its own
date. The parent's entry list is therefore a complete, ordered record that includes
the moment each branch was cut. What was true when a branch began is the parent's
entries up to that index.

### 8.4 Intent is on the edge

The intent is stored on the link to a branch, not inside the branch. A fold can pick
which subtrees to include without opening any of them. Selection is a walk over
labeled links, and serialization cost applies only to what's selected. That's what
makes shape-based context affordable.

### 8.5 Gaps and open questions

| Item | Detail | Status |
| --- | --- | --- |
| The only serializer is a flat tail | `Renderer.thread(limit: 12)` takes the last 12 turns of one node, and `records` ignores `.transcript` entries, so the tree is invisible to it. The gap is contained: one function, and everything it needs to walk is already typed and labeled. | **Gap** |
| One branch per intent, forever | `Context.branch(for:)` reuses a branch named `"<intent> Context"`. The branch's creation is recorded in the parent, but later invocations in that branch aren't. If folds work over moments, the tree is one level too shallow: add a branch per invocation under each intent branch, or turn the intent branch into a label on per-invocation branches. | **Open** |
| Recording what an agent saw | Transcripts record what an agent said, not what it saw. If context is rebuilt by folding every turn, "why did it do that" can't be answered from the transcript. Fix that fits the model: record the fold **specification** (references plus a strategy), not the text. There's a slot for it: `Signal.started(Reference, Value)` currently fills its `Value` with `.reference(origin)`, which repeats the first field. | **Open** |

---

## 9. Lifecycle and telemetry

### 9.1 How long a thread lives

The goal isn't perfect memory. It's managing context so that a conversation between
user and agent can run much longer before quality degrades. Branches that never end
serve that goal, but **Open:** how does that design change what users think of as a
thread or a conversation?

### 9.2 When a transcript is retired

When a transcript is deleted, archived, or abandoned, its structure should yield
dense, well-organized metadata on the way out, grouped into five streams and linked
back to the user conversation that started it:

| Stream | Typical source |
| --- | --- |
| Automation | Observe branches |
| Information retrieval | Search branches |
| Tool execution | Dispatch branches |
| Task reasoning | Evaluate branches |
| Contextual reasoning | Compose branches and the primary thread |

Ordering survives however branches were split, because every entry is dated.

### 9.3 Data-driven by construction

There's no database, but everything is keyed, tabled, and linked into a web of
references the moment it's created. Telemetry is a by-product of structure, not an
added layer.

---

## 10. Open decisions

| # | Decision | Depends on it |
| --- | --- | --- |
| 1 | Signals fan out to the parent, or composers poll | Supervision, failure recovery, the single front |
| 2 | Merge bridge closures into `Scope.contents` | Bridges as shared rooms |
| 3 | Branch granularity: per intent, per invocation, or both | Folding over moments |
| 4 | Store the fold specification in `Signal.started`'s `Value` | Explaining agent behavior |
| 5 | Who maintains descriptors, and when | Routing to contexts |
| 6 | How branches are pulled back into the primary thread | The context-scale upward edge |
| 7 | Limits on what an Observer can do when it fires | Safety of automation |
| 8 | Thread lifecycle as users experience it | Product model of conversations |

Decisions 1, 2 and 6 are the same missing upward edge at three scales (§7). Deciding
one probably shapes the other two.
