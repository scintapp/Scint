# **View Framework — Rebuild Spec**

**Status: direction, not implementation. High-level on purpose.**

## **Thesis**

**Params carry identity and intent. The runtime carries data. Views resolve.**

**Everything below follows from that one sentence. The current framework violates it —**
**`ItemParams` carries sixteen stored properties, most of them nil most of the time, most of**
**them duplicating something a `Reference` could already answer. That duplication is the**
**source of the bloat, the staleness, and the endless temptation to add "just one more**
**field" instead of composing.**

---

## **The layers**

### **Models / Sessions**

****What it is.** The app's answer to *where am I and what am I looking at*. `Session` holds**
**focus, selection, open content, navigation history, and the active workspace — as**
**references and cursors, never as content. `Model` is the app's verb surface: select, focus,**
**open, start, search.**

****Produces.** Session transitions.**
****Consumes.** References from the runtime.**
****Never.** Holds domain data. There is no view model mirroring the runtime.**

### **Params**

****What it is.** A description of what should appear and where it sits in the composition —**
**addressed by reference. A coordinate plus a semantic role, not a payload.**

****Produced by.** Queries, exclusively.**
****Consumed by.** The Factory, exclusively.**
****Never.** Carries anything the reference can answer.**

### **Controls**

****What it is.** Behavior that lands on the seams between views, where it cannot be**
**expressed as a static description because it involves interaction, transfer, or an effect**
**that crosses a module boundary.**

****Produced by.** Queries.**
****Consumed by.** The Factory, which wires them into the views it stamps out.**

****In scope:** activation and selection; transfer (drag, drop, paste, reference exchange);**
**context menus and commands; disclosure and expansion; edit commit; routing that moves**
**focus to another surface.**

****Out of scope, with a named home:** presentation → Params. Domain behavior → `Model` or**
**the runtime. Transient view-local state (hover, in-flight text) → the view. Anything**
**cross-cutting that is not a seam is a runtime concern, not a control.**

**This boundary is the whole point. Controls became a dumping ground because there was no**
**stated criterion for rejection; the criterion is *does this exist at a seam between two**
**views, or between a view and the world outside the framework*. If not, it belongs**
**somewhere else, and that somewhere else must be named in the rejection.**

### **Queries**

****What it is.** The only place the runtime is read for presentation. A pure function from**
**(model, reference scope) to (params, controls).**

****Produces.** Params and Controls.**
****Consumes.** Runtime and Session.**
****Never.** Contains a view, and never makes a view's decisions — no resolving symbols, no**
**picking colors, no deciding what an indicator looks like. The mapper says what a thing is;**
**the view decides what it looks like.**

### **Panels / Surfaces / Views**

****Panel** — a host. Owns `PanelState` and routes its current surface to a mapper. Panels**
**are the only place surface-to-mapper wiring lives.**

****Surface** — renders params and controls through the Factory. Should be near-empty, and**
**usually should not exist at all: a panel case that maps cleanly returns the generic**
**surface. A bespoke surface is an admission the framework couldn't express something, and**
**should be treated as a bug report against the framework.**

****Views** — where UI composition happens, in two kinds. *Layouts* are structural and**
**consume params. *Views* are atomic and consume plain values. Neither reads the runtime and**
**neither carries business logic, but within presentation this is the tier meant to absorb**
**change: visual iteration should land here, not in params and not in the Factory.**

**A visual need that looks like it requires a new param field or a new Factory branch is**
**almost always a view that has not been composed yet.**

### **Factory**

****What it is.** The deterministic translation from params and controls into SwiftUI. A**
**total function with no judgment of its own — given well-formed params it always renders**
**something, and it never decides *what* should appear, only *how* what was described gets**
**drawn.**

****This is the most protected module in the system.** It grows only when a new dimension**
**appears. It never grows to accommodate a case.**

---

## **Dimensionality**

**The current framework has three tiers and hides them. Make them explicit, name them**
**identically across params, controls, factory methods, and layouts, so that the tier a**
**thing belongs to is legible from its name alone.**

### **1. Root — the frame**

**Top-down construction begins here. One per surface. Declares the container's nature:**
**fixed or floating, detachable, resizable, pinnable, how it dismisses, and which layout**
**contract the composition below it opens with.**

**Corresponds to the Factory's first build method. Nothing below it may renegotiate what the**
**root declared.**

### **2. Section — the region**

**Scoped composition inside the frame, after the layout contract is signed. Chooses a**
**structural form: list, grid, table, group, card, canvas. **Recursive** — sections contain**
**sections, which is what makes multi-region and multi-surface composition possible without**
**resorting to hand-written SwiftUI.**

**This is the tier the current framework is weakest at, and the reason bespoke surfaces keep**
**getting written: anything more structured than a list and less structured than a**
**free-form view has nowhere to go. Sections are that place. More precise than a smattering**
**of SwiftUI, less parametric than a tree.**

**Corresponds to the Factory's middle methods, where scaffolding is stamped and generic**
**views are wired to params and controls.**

### **3. Item — the leaf**

**The finest grain. **Recursive and co-recursive with Section** — an item may contain items,**
**and may contain a section. This is what makes nested trees, data-heavy components, and**
**detail composition expressible.**

**Corresponds to the Factory's leaf methods.**

### **Layout is a tag, not a contract**

**A layout is nothing more than a tag telling the Factory which scaffolding to stamp. It**
**carries no authority of its own and binds nothing below it. Sections and items are free to**
**choose their own.**

### **Traversal: rigid edges, flexible middle**

**The three tiers are not equally free. The composition is a one-way pipeline with a**
**recursive interior.**

****Entrance — panel definition, once.** The root is declarative and terminal in the**
**downward direction. It is entered, not revisited. Nothing below renegotiates the frame.**

****Middle — section and item, freely recursive.** This is where all the flexibility lives.**
**Sections become sections. Sections become items. Items become items. Items become**
**sections. There is no ordering restriction and no depth restriction; the seam between**
**section and item is fully co-recursive, and layout tags may differ at every step.**

****Exit — item controls, once.** The item pass is terminal. Controls may be applied at**
**every stage of the Factory, and some already are — but once a component has taken its pass**
**of items and been wrapped with context menus and transfer behavior, that branch is sealed.**
**There is no second pass of items over a wrapped component.**

**The practical rule: **compose downward and inward; never reach back up or re-enter.** Any**
**design that needs a second item pass over an already-wrapped component is describing a**
**section that should have existed one level higher.**

### **The naming rule**

**One vocabulary, four modules. If a thing is a section, it is called a section in the**
**params, in the controls that address it, in the factory method that builds it, and in the**
**layout that draws it. A reader should never have to learn a mapping table.**

---

## **Minimalism: lean on the runtime**

**Params should be light parcels encoded with semantically rich data — not variety packs**
**covering every scenario imaginable.**

**An item is: **an address** (a reference, or a key when it isn't runtime-backed), **a role****
**(what kind of thing it is, semantically), **children**, and **overrides only where the**
**runtime genuinely cannot answer**.**

**Name, description, icon, tint, timestamps, counts, tags — all of it is resolvable from the**
**reference at render time. `Reference` already reaches its descriptor and its iconography.**
**Copying those into params duplicates the runtime, goes stale the moment anything changes,**
**and grows the param object without bound because every new display need looks like it**
**needs a new field.**

**The willful dependency on content-addressed references is the feature. A param that says**
*****this reference, in this role, with these children* is complete. A param that says *this****
**reference, and also its name, and also its icon, and also its subtitle* is a cache — and**
**an unmanaged cache is the thing we are trying to delete.**

****Consequence worth stating plainly:** this only works if the runtime can tell a view that**
**a reference changed. Minimal params and reactive observation are not two projects. They**
**are the same project, and the observation work is the prerequisite. Doing the param**
**rebuild first would produce a framework that resolves correctly and refreshes wrongly.**

---

## **Standards**

**Two classes of component, two different bars.**

### **Protected — Factory, Params, Controls, Layouts**

**Additions here are strategic only, never tactical. To change one, all of the following**
**must hold:**

1. **It adds a **dimension**, not a case. A new arm on an existing switch is a case.**
2. **It **cannot** be expressed by an existing tier plus a control.**
3. **It serves **more than one** call site, in practice, today.**
4. **It does not increase the Factory's branching without removing branching elsewhere.**
5. **The Factory remains **total** — every well-formed param still renders something.**
6. **It preserves the naming rule across all four modules.**

**If a change fails any of these, the correct output is a written explanation of what the**
**framework cannot express — not a workaround, and not a bespoke view.**

### **Consumable — mappers, views, surfaces, plain SwiftUI**

**Cheap to add, but bounded:**

- ******Queries.** No views. Pure — same inputs, same params. No stored param property that a****
  **reference could answer. Runtime writes go through controls, not through `parameters`.**
- ******Views.** Design tokens only, no literals. No runtime access. No domain types in the****
  **signature beyond `Reference`. Reusable at two or more call sites, or the work belonged**
  **in a mapper.**
- ******Surfaces.** Default to the generic surface. A bespoke one requires a stated reason****
  **the framework cannot express it.**
- ******Single-use types are the smell.** Six single-use view structs in one file means the****
  **work belonged in a mapper. This has already happened once and cost four hundred lines.**

---

## **Open decisions**

- ******Controls shape.** Today it is a single struct of ~37 optional closures with a 37-argument****
  **initializer. Options: tier-scoped control structs mirroring root/section/item, or**
  **capability protocols the Factory queries rather than nil-checks. The second is cleaner**
  **and the bigger change.**
- ******Role vocabulary.** If params carry a semantic role instead of concrete presentation,****
  **that role set has to be defined and closed. It is effectively a second type system over**
  **the runtime's, and it will rot if it is open-ended.**
- ******Key vs Reference.** Params need to address things the runtime does not own (a filter****
  **chip, a mode toggle). Where the boundary sits between "has a reference" and "has a key"**
  **should be decided once, not per mapper.**
- ******Ordering.** Observation first, then params. Confirm.****
