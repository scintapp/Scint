# ScintKit framework refactor plan

Status: repository audit and implementation plan only. No implementation is included.

Audit baseline: restored working tree at commit `5dc740d`, September 10, 2026. Existing edits to `ScintModel.swift`, `EditorAttachments.swift`, and `Cards.swift` were present before this audit and are outside this document's changes. Findings below describe the restored source, not the discarded refactor. During the audit, file hashes also changed for `Cards.swift`, `Style.swift`, and Xcode user interface state. Those concurrent edits were not made or reverted by this task. The only repository file written by this task is this plan. This is a source audit; no build, tests, app launch, or UI inspection was performed for this plan.

## 1. Objective and boundaries

Organize and reduce the established framework while preserving its architecture and behavior:

```text
Model / Session / References
        ↓
Query.parameters(model) + Query.controls(model)
        ↓
Panel routing → existing Surface render seam
        ↓
Factory consumes Params and wires Controls
        ↓
existing generic layouts, components, and views
```

The desired change is a smaller, reference-addressed, dimensional parameter model and an organized abstract factory. It is not a replacement rendering framework, a rewrite of the queries as unrelated utilities, or a visual redesign.

The user's parameter sketch supplies the intended vocabulary: `Params`, `Params.Panel`, `Params.Surface`, `Params.Section`, `Params.Item`, and the `Param` component/control/sizing vocabulary. [Framework.md](/Users/kaechle/Developer/Scint/Docs/Framework.md) supplies the architectural boundaries, recursive traversal rules, and observation prerequisite. The latest instruction fixes the implementation constraints below.

### Fixed constraints

- Preserve the `Query`, `Panel`, `Surface`, and `Model` protocol declarations, including associated types, getters/setters, and both query entry points. Do not remove `controls(_:)`, remove `Surface.model`, or introduce replacement capability protocols.
- Preserve model/session ownership of navigation, focus, selection, and open content. Preserve `PanelState` ownership of query/cursor/detail/expansion/window state. Do not use this refactor to change `ScintModel`, session behavior, or persistence contracts.
- Preserve the existing generic views and their behavior. `GroupLayout`, `ListLayout`, `GridLayout`, `TableLayout`, their rows/headers, and the panel/control views are the implementation assets the factory must use.
- Keep query conformers and their domain responsibilities. Migrate their returned descriptions and control wiring incrementally; do not delete queries, navigation entries, or features because their current route is incomplete.
- The factory remains the bridge that consumes parameters, chooses existing scaffolding, resolves the inputs needed to render it, and supplies behavior. Do not move that job wholesale into new `*Content` views or a second renderer.
- No view factories, `AnyView` payloads, presentation closures, symbols, or resolved colors in queries. Closures for interaction/effects remain legitimate controls; closures that manufacture UI do not.
- No domain mirror in parameters. Reference-derived metadata must be resolved on the render path, with observation verified first.
- Keep active gestures, keyboard interaction, field editing, menus, transfer, disclosure, and root presentation semantics. Removing a parameter or override must not remove the behavior it currently enables through another route.
- Every change to protected modules must have a dimensional purpose and named current consumers. Use existing types and functions before adding anything. The user-requested dimensional types do not justify an additional family of wrapper types.
- This plan authorizes no code changes. Later implementation should proceed in reviewable slices, each with a small scope and a behavior check.

## 2. Established structure to retain

| Layer | Current implementation | Treatment |
| --- | --- | --- |
| Query contract | [Query.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Types/Query.swift:4): `parameters(_ model:) -> Params` and `controls(_ model:) -> Controls` | Keep both methods and default behavior. Change concrete returned models without changing the protocol. |
| Surface contract | [Surface.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Types/Surface.swift:4): panel, model, expansion access; `AnySurface` uses `render(self, panel.parameters(model), panel.controls(model))` | Preserve the contract and generic surface. Any necessary dispatch glue belongs at this existing seam, with no new host/view-model layer. |
| Panel contract and state | [Panel.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Types/Panel.swift:17) | Preserve routing, associated types, and state ownership. A root parameter describes presentation; it does not become another session or panel controller. |
| Model verbs | [Model.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Types/Model.swift:17) | Keep `focus`, `select`, `open`, and existing extensions as the application verb boundary. |
| Factory | [Factory.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:5) | Reorganize its existing construction and wrapping work by panel/section/item. |
| Generic UI | `Sources/ScintKit/Views/Sections`, `Views/Controls`, `Views/Components`, `Views/Utilities` | Retain implementations. Make narrow parameter-input and composition changes where the new model requires them. |
| Window and menu hosting | [PanelProvider.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Providers/PanelProvider.swift:63), [MenuPanel.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Menus/MenuPanel.swift:89), [MenuController.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Menus/MenuController.swift:5) | Reuse existing hosting and lifecycle management. Do not replace custom menus with a native menu solely because the latter compiles. |

### Generic view inventory and required preservation

| Composition | Existing building blocks | Behavior to preserve |
| --- | --- | --- |
| List | [ListSection.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Sections/ListSection.swift:39): `ListLink`, `ListRow`, `ListHeader`, `ListLayout` | Hover, selection, row hit regions, disclosure, indentation, header composition, and child content. `ListLayout` is currently an expandable parent row plus children; do not replace it with a bare stack. |
| Group | [GroupSection.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Sections/GroupSection.swift:12): `GroupRow`, `GroupDivider`, `GroupHeader`, `GroupLayout` | Header/body hierarchy, separators, leading/trailing content, background and spacing. |
| Grid | [GridSection.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Sections/GridSection.swift:37): `MaterialGlyph`, `GridIcon`, `GridLayout`, existing role metadata | Glyph previews, pointer gestures, arrangement, and reference presentation. Repair wiring rather than replacing these with unrelated grid cells. |
| Table | [TableSection.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Sections/TableSection.swift:4): `TableHeader`, `TableRow`, `TableCard`, `TableLayout` | Header expansion, lazy content, selection and existing card/row presentation. Domain-specific row inputs need separation where appropriate; the existing view is not disposable. |
| Search/panel | [PanelView.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Utilities/PanelView.swift:20): `PanelInput`, `PanelHeader`, `PanelModes`, `PanelRow`, `PanelDetail`, `PanelShortcuts`, `PanelLayout` | Input focus, arrows, Return, Tab detail, Escape handling, mode shortcuts, cursor scrolling, and detail header. |
| Editing and loading | [Pickers.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Controls/Pickers.swift:4), [Fields.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Controls/Fields.swift:4), [Toggles.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Controls/Toggles.swift:4), [Menus.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Menus/Menus.swift:121) | Existing picker, date, field, toggle, load popover, and action behavior. Remove unused inputs, not whole controls that have active callers. |
| Rich content | [Cards.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Components/Cards.swift:5), [Blocks.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Components/Blocks.swift:4), [Badges.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Components/Badges.swift:42) | Existing material/reference previews, block rendering, and status presentation. Move data selection only when its destination is defined; preserve the views. |

The filenames do not always match the contained type's name. That is not a reason for a rename sweep.

## 3. Source-audit findings

### A. The parameter structure does not express the requested dimensions

[Params.swift](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Params.swift:8) contains a flat root `Params`, optional `PanelParams`, `SectionParams.items`, and recursively nested `ItemParams.items`.

Consequences:

- Sections cannot contain sections.
- Items cannot contain sections.
- A section has no layout of its own. The factory reads root layout/nesting once and passes them downward ([Factory.swift:9](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:9)). This prevents mixed layouts within the recursive interior.
- `Nesting` constrains expansion globally to flat/single/recursive rather than describing actual composition per node.
- `ItemParams.items` has several meanings: structural children, load-menu options, and picker options. A migration must identify which relationship each caller means; blindly treating all of them as visible child rows is incorrect.
- `_isParent` carries a real distinction for unloaded/empty directories. An empty child collection cannot, by itself, determine whether something is expandable.
- Identity falls back to a transformed display name, and a `ref` takes precedence over `key`. The same reference used for different action rows can therefore receive the same ID. Rename-sensitive identity and repeated-reference roles need explicit handling.

### B. The factory already uses the desired generic views, but contains inconsistent paths

The ordinary list/group/grid branches already instantiate the generic views. Their structure should be reorganized, not re-created elsewhere.

Specific gaps:

1. **Table construction is missing:** [Factory.swift:92](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:92) renders `EmptyView` for `.table`, although `TableLayout` exists. `MaterialsList` and `TranscriptsList` already request that layout. A well-formed table parameter must reach the existing table scaffolding.
2. **Search mapping is in the renderer:** [Factory.swift:473](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:473) filters result groups and constructs sections/items, copying names, descriptions, icons, and tints. Group formation belongs to the existing search queries; reference presentation belongs to the render bridge and iconography.
3. **Panel items have a separate construction path:** [Factory.swift:263](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:263) bypasses normal item wrapping. The refactor must specify which controls belong on a search result versus a detail value/action and avoid accidentally applying every list affordance everywhere.
4. **Surface wrappers are mutually exclusive:** [Factory.swift:285](/Users/kaechle/Developer/Scint/Sources/ScintKit/Core/Factory/Factory.swift:285) returns after installing drop behavior, before considering the surface menu. Compose independent controls once; do not return early and suppress another capability.
5. **Layout choice, item control rendering, icon rendering, header rendering, transfer wrapping, and result mapping are all overloads named `build`.** Organize around the three requested factory entry points and keep any necessary private helpers subordinate to them. Do not obtain a three-method factory by moving all its work into replacement view types.
6. **The `.button` trailing branch is intentionally empty:** the group and panel row branches attach the action to the whole row. Preserve the row action when reorganizing it; an empty trailing slot alone is not proof the button behavior is dead.

### C. The controls object contains unused extension points

The restored `Controls` has 37 stored optional properties plus `isEditable`. Declarations, initializer forwarding, presence checks, and actual callback invocations must remain separate in the inventory.

The following 24 properties have no query producer in the audited tree:

| Group | Properties | Disposition |
| --- | --- | --- |
| No operational use | `onMaterialPosition`; `onAddSection`, `onMove` only participate in availability checking | Remove these fields, initialization, and dead checks. |
| Unconfigured row callbacks | `focused`, `onOpen`, `onAddItem`, `onRename`, `onDelete`, `onDuplicate` | Remove unused override plumbing. Retain working model actions, generic view affordances, and separately implemented menu actions. |
| View-producing wrappers/accessories | `wrapLink`, `wrapSection`, `wrapHeader`, `sectionLeadingAccessory`, `itemAccessory`, `sectionAccessory` | Remove unused `AnyView` extension points. Use existing view composition when a real caller needs an affordance. |
| Unconfigured predicates/sets | `addableSections`, `isItemEditable`, `canAddChild`, `isItemRenameable`, `isItemDeleteable`, `isItemDuplicateable` | Remove dead predicate machinery together with its unavailable actions. Preserve needed eligibility rules in their existing domain/provider home. |
| Unconfigured transfer overrides | `canDrag`, `dropTypes`, `onDrop` | Remove override fields; retain the working `ReferenceTransfer` eligibility, provider creation, drop-type and handling paths. |

Sparse fields require a more careful disposition:

- `surfacePalette` and `surfaceDropTarget` each have one producer in `SpacesList.controls`. `AssistantSidebar` reuses only `SpacesList.parameters`, so it does not inherit these controls. Reorganize any needed menu/transfer behavior through existing provider/action functions and node scope, rather than preserving special surface-only callbacks or deleting the query.
- `sectionDropTarget` has one producer in [AssistantSidebar.controls](/Users/kaechle/Developer/Scint/Sources/Scint/Queries/SidebarQueries.swift:17), which checks `"spaces"`. The query emits `"base"` and `"projects"`. This is a concrete wiring mismatch, not a missing transfer implementation. Address the section scope directly in the new model; preserve intended project-section dropping without retaining a string-ID special case.
- `itemLeadingAccessory` has one producer in [MaterialsList.controls](/Users/kaechle/Developer/Scint/Sources/Scint/Queries/ListQueries.swift:165), and constructs a SwiftUI button inside a query. Remove that presentation closure. The close-material operation already has a session home; an existing row/control view should express it if that route needs it. `MaterialsList` currently requests `.table`, so this list-only accessory would not appear there even if the query were routed.
- `results`, `detail`, `onToggle`, and `itemPalette` have few invocation sites because the factory centralizes them. Their behavior has multiple producers. Retain the behavior, eliminating redundant callback shape only after an equivalent query/control path exists.
- `onChange`, `onValueChange`, `selected`, `onSelect`, and `onAction` have substantial use. Keep their responsibilities and semantics during control-model organization.

Do not conflate unused factory overrides with the absence of working rename/delete/transfer functions in `Menus.swift` and `TransferProvider.swift`.

### D. Reference-derived payload and addressing are mixed together

| Current fields | Required treatment |
| --- | --- |
| `ItemParams.image`, `tint`; copied `name`/`description` on referenced items | Remove copied appearance and metadata. Resolve the reference on the observed render path, and use `Iconography` for appearance. |
| `ItemParams.trailingImage`, `count` | No producers; remove these parameter inputs and forwarding. Any future reference-derived counts must use existing data access and presentation, not resurrect a generic optional payload field. |
| `ItemParams.init(icon:)` | Argument is ignored and has no callers. Remove it. |
| `SectionParams.image`, `tint` | No explicit consumers. Remove them; copying result-group imagery currently ends here. |
| `SectionParams.footer` | Always defaulted to nil in current query construction. Remove the parameter slot. Do not infer that `GroupLayout` or its presentation must be replaced. |
| Root `Params.id`, `PanelParams.id` | No meaningful current consumers. Remove obsolete conformance/plumbing when the new dimensional root replaces it. Preserve section/item identity used by `ForEach`, cursor, selection, and expansion. |
| Root `Params.name`, `description`, `ref`, `header` | Search-detail and group-header behavior is real. Express it at its actual item/section with a reference and presentation intent rather than as sparsely consumed root fields. |
| `PanelParams.input`, `items`, `selection` | Search input and mode selection are real. Organize them under root components/controls; continue using `PanelInput` and `PanelModes`. Do not replace them with new general-purpose picker/view types. |
| `PanelParams.sizing`, `dismissal`, `movable`, `resizable`, `pinnable` | These describe root/window behavior, not reference metadata. See the root-setting decision below: remove redundant per-instance configuration without hardcoding away capabilities explicitly named by the spec. |
| `key`, `origin`, `path`, `entryId`, `value`, `active`, `isParent` | Separate addressing, editable values, and derived state. These are not all removable merely because a reference exists. Preserve their information until an equivalent address/control exists. |

Addressing cases that must survive:

- A filesystem child uses an artifact root reference plus a URL. The root reference alone does not identify that file, its name, its directory status, or the selection target.
- A material block uses its material reference plus an entry UUID. Text and task blocks are not separate runtime references.
- A setting uses its owning space/workspace plus a configuration key. Its current value and available choices come from the harness/configuration, not that owner's descriptor.
- A transfer/menu operation may need the parent occurrence/origin. Inferring a single parent from a reference is not always equivalent to the current occurrence's scope.
- Mode labels, section labels, action labels, and unbacked navigation entries have no runtime reference. They need stable keys and only the literal content that the runtime genuinely cannot answer.
- Selection/focus is session state. A reference's descriptor does not answer whether the current session selected it.

Use existing reference/key/URL/UUID vocabulary. Do not invent references for unbacked UI or introduce an open-ended role taxonomy to replace the deleted fields. Iconography for non-reference roles belongs in the existing iconography/view layer, not in query-supplied symbol/color payloads.

### E. Observation exists; its end-to-end behavior must be proved before payload removal

The source already provides these chains:

```text
Reference.descriptor → Runtime.get → Catalog.get → @Observable Index.entries
Typed .with(ref)      → existing store routing → @Observable Store.entries
Typed .update(ref)    → existing bounding/store update → persistence scheduling
```

Evidence: [Reference.swift:95](/Users/kaechle/Developer/Scint/Sources/ScintRuntime/Core/Identity/Reference.swift:95), [Index.swift:4](/Users/kaechle/Developer/Scint/Sources/ScintRuntime/Core/Data/Index.swift:4), [Store.swift:4](/Users/kaechle/Developer/Scint/Sources/ScintRuntime/Core/Data/Store.swift:4), [Resolvable.swift:32](/Users/kaechle/Developer/Scint/Sources/ScintRuntime/Core/Identity/Resolvable.swift:32), and [DataModel.swift:35](/Users/kaechle/Developer/Scint/Sources/ScintRuntime/Core/Data/DataModel.swift:35).

This supports observation through existing reference access, but it is not runtime proof that every read is performed inside the rendering observation scope. The dictionaries also imply potentially broad invalidation; do not claim per-reference invalidation from the source alone.

Required checks before deleting reference-derived payload:

- A descriptor rename refreshes a row/detail title for the same ID.
- A referenced value change refreshes its visible state and reference-driven icon without a session change.
- Changes to child collections update composition; sorting/filtering still belongs to the query and is reevaluated when its dependencies change.
- Optional/missing/deleted references are handled deliberately. `Reference.descriptor` currently reaches a fatal lookup for missing descriptors; retaining a dangling reference must not become a new crash introduced by the migration.
- Typed mutations retain persistence scheduling. Do not bypass the bounding update path to write an observable dictionary directly.
- Repeated computed-property access in a single body does not repeat expensive topology queries unnecessarily.

If these checks pass, use the existing machinery. If one fails, identify and repair the narrow read/update path as a separately scoped prerequisite. Do not add a parallel subscription system, cached presentation model, or model/protocol redesign.

### F. Existing queries and surfaces reveal the migration work

| Area | Existing route and responsibility | Required migration |
| --- | --- | --- |
| Navigator | `NavigatorPanel` → `AssistantSidebar`; nested spaces supplied by `SpacesList.parameters` | Preserve query routing and entries. Express hierarchy and section scope explicitly; remove copied imagery and the drop-ID mismatch. |
| Settings | `InspectorPanel` / `SettingsPicker` → `SpaceSettings` → `HarnessGroup`, `CommandsGroup`, `ArtifactsGroup` | Preserve these conformers and their feature boundaries. Keep picker options, defaults, selected states, editable fields, and add/remove actions. Replace shared key/type-based forwarding in `SpaceSettings.controls` with explicit node-scoped routing using the existing control contract. |
| Search | `SearchPanel.PanelSurface.query` selects `ContentSearch`, `InterfaceSearch`, `WorkspaceSearch`, `EverythingSearch`; `SearchDetail` supplies detail | Preserve all search scopes, filters, limits, ordering, and open-versus-select behavior. Move result-to-param mapping out of Factory into these queries. Preserve input/cursor/detail and existing panel views. |
| Other list/group queries | `FoldersList`, `ArtifactsList`, `HarnessesList`, `CommandsList`, `MaterialsList`, `TranscriptsList`, `MaterialsGroup` | Record reachability separately from validity. Migrate their schema without erasing their domain logic. Empty or unconnected routes are not permission to remove visible product concepts or their implementations. |
| Bespoke surfaces | `SpaceSurface`, `TasksSurface`, `TranscriptSurface`, `MaterialsSurface` / `MaterialSurface` | Identify their query/data-selection work and generic compositions. Migrate one at a time only when recursive params can express the current behavior. Keep existing editor and content components. |
| Menu/editor integration | `MenuController`, `MenuItem`, `MenuPanelPresenter`, existing editor menu surface | Record the root/menu adapter requirements. Do not rewrite the editor or menu framework incidentally while changing search-panel parameters. |

Additional concrete issues to keep distinct from structural migration:

- [FoldersList.parameters:20](/Users/kaechle/Developer/Scint/Sources/Scint/Queries/ListQueries.swift:20) uses an always-empty expansion set, suppressing directory children. The protocol only accepts `model`; it does not receive a panel. Decide whether the query supplies the hierarchy and the existing surface controls visibility, or uses an already available scope source. Do not add a protocol argument or claim this is solved by using another empty set.
- [MaterialsList.parameters:188](/Users/kaechle/Developer/Scint/Sources/Scint/Queries/ListQueries.swift:188) uses an empty ordering dictionary. Preserve deterministic sorting and report absent ordering data; do not fabricate session state.
- [GridLayout:208](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Sections/GridSection.swift:208) classifies subviews, but there are no assignments to its container role in the audited tree. The materials subset is computed but never rendered. Repair the existing layout/role wiring with an explicit fixture; do not replace the entire grid implementation.
- [LoadMenu:140](/Users/kaechle/Developer/Scint/Sources/ScintKit/Menus/Menus.swift:140) iterates `items`, while the empty-state branch consults `filtered`. Filtering can therefore leave nonmatching rows visible. Fix within the existing menu in a distinct behavior change.
- [ItemPicker:10](/Users/kaechle/Developer/Scint/Sources/ScintKit/Views/Controls/Pickers.swift:10) force-unwraps its selected option. Missing/stale selection needs a defined presentation/selection rule, without writing a default into the runtime during rendering.
- `TasksSection` stores expansion in local `@State` ([TasksSurface.swift:82](/Users/kaechle/Developer/Scint/Sources/Scint/Surfaces/TasksSurface.swift:82)); `GridLayout` also declares local expansion. Migrate actual expansion behavior to existing `Surface`/`PanelState` access; remove a local variable only if it has no behavior.
- Several rich views and bespoke surfaces select domain data directly. Examples include grid previews, table cards, task aggregation, and transcript entries. Separating those responsibilities is required for the wider-framework target, but must not erase their UI or replace their content with a generic label.

## 4. Model decisions that must be explicit

The example and Framework.md are direction, not a fully consistent drop-in Swift definition. Settle the following in the model review, without changing the protocols to make the conflicts disappear.

### 4.1 Control declarations versus behavior, with protocols unchanged

The sketch puts `[Param.Control]` on nodes, but the established protocol deliberately produces `Controls` separately. The requested factory signatures have no `Controls` argument, and the root `Panel` protocol has no `model` property from which the factory can recover the query context.

Recommended integration to prototype: retain `Query.parameters` as description and `Query.controls` as behavior. Use the existing three-input surface render seam to associate the declared node control slots with that query's control implementation before dispatching to the dimensional factory methods. The bound node control representation must fit the user-requested `Param.Control` vocabulary, and must remain ephemeral, not stored model/view state.

This is a design to prove, not a claim that an existing binder already exists. Before changing the schema, demonstrate it with one setting and one search action, including their owner/key and selection context. Specify association and lifetime explicitly. Do not make `Query.controls` an unused compatibility stub, populate all behavior inside `parameters`, invoke queries again at every recursive node, or introduce an environment service/protocol to smuggle a model into the root factory.

Closure-bearing controls also affect `Hashable` synthesis. Preserve stable identity rather than inventing closure equality or retaining a false whole-object hashing contract.

### 4.2 Recursion

The sketch gives `Section` children but no child slot on `Item`. Framework.md explicitly requires section→section, section→item, item→item, and item→section traversal.

The minimal candidate is to use the existing proposed `Params.Surface` union for mixed children at both interior tiers. That requires a deliberate extension to the supplied `Item` sketch, not a new wrapper type. Confirm that representation and distinguish structural children from picker/load option relationships before implementation.

Keep layout local to each node. Preserve disclosure as behavior through the existing surface, rather than equating every child-bearing node with an expanded list row. Preserve empty-but-expandable nodes where the data model requires them.

### 4.3 Root traversal

The sketch's `Panel.params: [Params]` can syntactically contain another panel. Framework.md says the root is entered once and cannot be revisited from the interior.

Choose either a root-restricted child representation or an explicit validation rule at the existing construction boundary. Do not silently render nested windows/menus, silently skip nested panels, or give child layout tags permission to change root window settings. Standalone surface parameters use their existing host; they do not create a second root.

### 4.4 Reference resolution ownership

Framework.md says both “Views resolve” and that atomic views do not read runtime data; it also identifies queries as the data-selection layer.

Working interpretation: queries select/filter/sort topology and describe addressed content; reference-backed presentation resolves on the observed render path through the existing reference and iconography facilities. The factory supplies those current inputs to the existing atomic views. Atomic rows should not perform global runtime searches or select domain collections. A reference-aware existing component must have its resolution responsibility stated rather than duplicated in a query payload.

Do not solve this by creating a mirrored view model or copying every field into a new component enum. Use this boundary consistently for a row and a rich preview before applying it broadly.

### 4.5 Components, keys, and edit state

`Param.Component` and `Param.Control` are not defined in current source. The typo-free names and the case semantics must be specified, but this is not permission to design a second open-ended type system.

Build the vocabulary from existing, independently meaningful components and controls. For each proposed case, name its existing view, current producer(s), reference/key resolution, and behavior source. Use already existing control distinctions such as toggle, load, value, picker, field, date, remove, and whole-row action as audit inputs, not an automatic mandate to carry every old switch case forward.

Keep literal text only for content the reference cannot answer. Keep edit buffers transient in existing controls and commits in `Controls`; query construction must not write configuration. Do not equate a component's displayed value with a storage key or its stable identity.

### 4.6 Root settings and menu integration

The user's removal rule targets dormant/redundant configuration, while Framework.md explicitly names resizable, pinnable, detachable, and dismissal behavior as root concerns. Current callers use fixed defaults for many of these, but the provider implements actual settings.

Recommended treatment: retain existing provider capabilities and state; consolidate repeated defaults at the existing root/hosting boundary. Only emit per-instance settings that differ or are intentionally needed by the agreed root model. Record each removed parameter's default and replacement configuration source. Do not remove `PanelState.pinned` or rewrite provider lifecycle as a shortcut to a smaller parameter initializer.

`PanelType` is absent; `Modality`, unused `PanelParams.Kind`, and the separate menu presenter exist. Unify only the root classification needed by the requested model, preserving protocol-facing `mode` and existing hosts. A menu type must map to the existing menu presentation semantics; substituting `SwiftUI.Menu` without handling its existing interaction contract is not a valid implementation.

## 5. Implementation sequence

### Phase 1 — freeze contracts and establish behavior evidence

Scope: documentation/fixtures and verification, no production restructuring.

1. Record protocol declarations, query conformers/routes, generic view inventory, and current user changes.
2. Establish a baseline build using the required Xcode toolchain.
3. Define fixtures for list/group/grid/table, search/detail, harness settings, URL/entry addressing, and transfers.
4. Classify known current defects separately from regressions. Do not mark a broken table branch as behavior to preserve.

Exit: a concrete preservation checklist and a baseline against which each subsequent slice can be assessed.

### Phase 2 — verify reference observation and safe resolution

Scope: existing reference/index/store paths and focused tests; runtime changes only if a demonstrated gap requires them.

Run the checks in section 3E, including deletion/missing-reference behavior and nested child updates. Preserve existing typed mutation and persistence paths. Resolve any failed dependency tracking before removing reference-derived presentation payload.

Exit: proven live reference resolution under unchanged parameter identity, with no new cache or observation subsystem.

### Phase 3 — remove dead parameter and control plumbing narrowly

Scope: `Params.swift`, `Controls.swift`, exact `Factory.swift` consumers, and initializer arguments in existing queries/views.

Remove the no-producer fields, ignored argument, dead section appearance data, and never-populated optional payload identified above. Remove associated dead nil checks and initializer boilerplate. Keep query methods, generic view implementations, functioning menus and transfer fallbacks. For sparse-but-real behavior, first identify the equivalent existing provider/model/view path, then remove its redundant special hook.

Exit: smaller API with the same working interactions. Build and check each deletion group; no deleted routes or replacement views.

### Phase 4 — agree the dimensional model and prove one integration slice

Scope: the protected parameter/control model and existing surface dispatch implementation, with protocol declarations unchanged.

Resolve section 4. Use the user's named types only where needed. Show one list branch and one settings control described through the new model and rendered using `ListLayout`/`ListLink` and existing control views. Preserve the generic surface call contract and both query methods. Any transitional initializer/adapter must have a named removal step; do not retain the old property bag behind a permanent alias.

Exit: a concrete, working demonstration of control association, stable identity, observation, and mixed children with no replacement architecture.

### Phase 5 — organize the factory around the three requested entry points

The intended build interface is:

```swift
@MainActor enum Factory {
    @ViewBuilder static func build(_ panel: some Panel, params: Params.Panel) -> some View {}
    @ViewBuilder static func build(_ surface: some Surface, section: Params.Section) -> some View {}
    @ViewBuilder static func build(_ surface: some Surface, item: Params.Item) -> some View {}
}
```

Responsibilities:

| Entry point | Construction responsibility | Existing implementation to use |
| --- | --- | --- |
| Panel | Apply root presentation once, construct root controls and initial regions, retain host lifecycle | `PanelLayout`, `PanelInput`, `PanelModes`, `PanelDetail`, `PanelShortcuts`; existing panel/menu providers |
| Section | Select the node's own layout and recurse through child sections/items | `GroupLayout`, `ListLayout` where expandable-region semantics apply, `GridLayout`, `TableLayout`, existing headers/dividers |
| Item | Compose the indicated existing components, recurse where allowed, then wire terminal item controls once | `ListLink`/`ListRow`, `GroupRow`, `GridIcon`, existing table/card/panel rows and field/picker/load/action views |

Retain factory construction rather than delegating it to a parallel renderer. Private helpers may share mechanics, but must not reintroduce feature-specific routing or repeated final item passes. Preserve parent/child wrapping boundaries so a menu or drop handler is not installed twice for the same target.

Wire `.table` to the existing table scaffolding. A declared layout must not silently render `EmptyView`. For a genuinely unsupported composition, record the missing capability instead of adding an empty switch arm.

Exit: all agreed layouts render representative trees; root entry and terminal item wrapping obey the documented traversal rules.

### Phase 6 — migrate the established queries one family at a time

Order:

1. `SpacesList` and `AssistantSidebar`: hierarchical identity, local layouts, section scope, existing selection/menu/drop behavior.
2. `HarnessGroup`, `CommandsGroup`, `ArtifactsGroup`, `SpaceSettings`: settings data and behavior stay in their existing conformers; remove duplicated metadata and key/type dispatch where explicit scope replaces it.
3. Search query family and `SearchDetail`: move result-to-param mapping out of Factory; preserve grouping/ranking, open-versus-select behavior, modes, and detail actions.
4. Remaining list/group queries: preserve file/entry addressing, sorting and empty states; repair proven routing/data gaps separately.

Do not merge the conformers into one arbitrary enum utility. Do not remove a query because it has one current host. Parameters contain reference addresses and minimal intent; controls carry the corresponding behavior without constructing views.

Exit per family: source diff shows the same domain selection/operations with fewer duplicated presentation fields; UI is built by the same generic components.

### Phase 7 — bring bespoke compositions under the existing framework

Scope: one surface at a time, after the recursive model and factory can express its current view tree.

For each space/task/transcript/material composition, list its runtime queries, state owners, view components, and actions. Move filtering/sorting/aggregation into conforming queries; describe the composition with nested sections/items; retain the existing headers/cards/blocks/editor/controls as leaves or composition pieces.

Only replace a bespoke surface body with `AnySurface` once that route has behavior parity. If card/canvas/editor composition cannot be expressed by the agreed dimensions and existing controls, document the exact gap and the existing consumers. Do not add speculative layout cases or a single-use wrapper as a workaround. Do not change models, protocols, editor operation, or menu lifecycle in this phase.

Exit: each migrated route retains its UI and interactions; any remaining bespoke route has a specific documented expressiveness gap.

### Phase 8 — remove migration-only code and finish verification

Remove old flat parameter structs, obsolete `Nesting` plumbing, temporary conversion code, and dead overloads only after their consumers have migrated. Keep the four protocol declarations unchanged. Verify that all remaining special fields/cases have a named current producer and consumer, or are an explicitly agreed root/dimensional requirement.

Finish token cleanup only in touched UI code; preserve existing token use. Do not bundle unrelated formatting, renames, model fixes, or service changes. Update framework documentation to reflect decisions actually implemented, not merely planned.

## 6. Acceptance criteria

### Architecture and API

- No changes to the `Query`, `Panel`, `Surface`, or `Model` protocol declarations.
- Query conformers still expose both data and behavior methods; neither becomes a dead stub.
- The three factory entry points consume the dimensional objects and construct the existing generic views.
- No parallel view-model/renderer/wrapper family. No query-produced `AnyView`, colors, or SF Symbol strings.
- No stored reference-derived metadata cache in params or inside a renamed component payload.
- Section/item recursion supports the agreed mixed traversal and per-node layouts. Root settings are not revisited, and terminal item wrapping is applied once.

### Data, identity, and observation

- Identical references in different action/occurrence roles have distinct stable identity when needed.
- Renames do not change row identity. URL and block-entry selection still address the intended object.
- Empty-but-expandable nodes and cyclic domain graphs have deliberate behavior; no accidental infinite recursion or fabricated references.
- Descriptor, content, selection, configuration, and collection changes update the appropriate rendering through existing observation.
- Constructing/reconstructing parameters does not mutate stores, start work, register artifacts, or open dialogs. Those effects happen only when a control is invoked.

### Behavior and visual preservation

- Lists retain hover, selection, disclosure, indentation, context menus, and transfer semantics.
- Groups retain headers, separators, labels/details, and all active trailing controls.
- Grid glyphs/previews and table/card content remain present; no replacement generic cell or empty layout stands in for them.
- Search retains scopes/ranking, keyboard cursor, Return, Tab detail, Escape, mode shortcuts, scrolling, and open/select distinctions.
- Settings retain available/loaded options, defaults, field/toggle/date edits, and correct owner/key mutation. A stale picker selection does not crash or silently write a new value.
- Window/menu configuration, outside-click dismissal, focus, visibility callbacks, and root state remain correct for existing hosts.

### Verification procedure for later implementation

There is no dedicated test suite/test target evident in the audited tree. Plan a minimal focused verification fixture using the existing types rather than inventing a production testing framework. Tests should exercise observation, mixed traversal/control dispatch, identity, and query behavior—not merely count declarations or mirror constructor assignments.

Build with:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project Scint.xcodeproj -scheme Scint -destination 'platform=macOS' build
```

Confirm both `BUILD SUCCEEDED` and actual `SwiftCompile` / `Ld` phases. Do not trust a zero exit code from the machine's default CommandLineTools `xcodebuild`.

Visual/interactive parity requires a later expressly authorized app/UI verification pass; a successful build alone does not prove it. This audit does not claim that validation. Source-only checks can establish the property/consumer inventory and absence of protocol changes, but not actual focus, hover, keyboard, or window behavior.

## 7. Recommended first implementation slice

Begin with observation verification and the narrow dead-field/control cleanup. Preserve all query conformers, generic layouts, protocols, models, and visible entries. Then prove the dimensional model with one existing list composition and one existing settings control before expanding its use.

The deliverable for each slice is the same: exact fields/plumbing removed, existing behavior path retained, generic views still used, validation performed, and any unresolved capability explicitly named. A smaller compiling API is not sufficient if obtaining it deletes the framework it was meant to organize.
