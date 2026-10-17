Build the center Tasks content shown in the [reference image](/Users/kaechle/Developer/Scint/Docs/References/AgendaContent.png) using the current Scint framework. The center consists of the existing page header, a horizontal day selector, and grouped task rows with inline expansion. The left navigator and the right Unscheduled column, its New Task button, and its drop area are outside this task. Do not reproduce the window toolbar or introduce another split view.

The existing theme determines typography, controls, colors, spacing, and surfaces. The image determines the content arrangement and relationships. It does not supply production task names, dates, durations, or a replacement theme.

Read [AGENTS.md](/Users/kaechle/Developer/Scint/AGENTS.md) and [Docs/Style.md](/Users/kaechle/Developer/Scint/Docs/Style.md). Preserve the working changes in Scint, ScintRuntime, and ScintComponents. The earlier navigator/icon guide has not been implemented and is not a dependency of this work. These findings were checked against the working source on October 15, 2026.

**Use two new rendering modules.** RowFactory/RowLayout should render a horizontal collection of peer items. TableFactory/TableLayout should render grouped, aligned rows with optional expanded content. These are different layout responsibilities. Agenda-specific mappers describe the days and tasks using those primitives; neither factory should become an agenda controller.

| Piece | Owns | Must not own |
| --- | --- | --- |
| AgendaDays mapper | Calendar dates, stable day identities, formatted day labels, and the current-day marker | Selected-day state or view layout |
| AgendaTasks mapper | Task projection, schedule interpretation, grouping, ordering, and callbacks for task operations | Host state, layout measurements, or another task store |
| AgendaMapper | Composition of the mode, day, and table descriptions using Params/SectionParams/ItemParams | A second configuration schema interpreted later by a factory |
| ContentFrame | The active mode, selected day, and expansion state through its existing StateContainer; preparation of the selected mapped branch | A new task collection, a scheduling algorithm, or task rendering |
| AgendaContent | The Surface boundary and existing page chrome: host/model, prepared parameters/controls, header placement | A second manual ForEach task renderer alongside the factory path |
| Factory | Opt-in composition of the new section layouts and ownership of the content scroll container | Date filtering, task queries, or task mutations |
| RowFactory / TableFactory | Construction from the supplied parameters and controls, including scoped selection/expansion callbacks | Reads through Document, Space, Session, or concrete frame/model casts to discover missing data |
| RowLayout / TableLayout and their small supporting views | Arrangement, presentation, native controls, and supplied event callbacks | Model/Host/Surface/StateContainer dependencies or runtime writes |

Only the existing state owner stores UI choices. Only runtime stores hold task data. Parameters are fresh presentation values, not another observable model. A native control may use an inline Binding to its supplied value and callback; it must not maintain a copied task, checked state, selected date, or results array and synchronize it afterward.

**Start from these actual artifacts.**

| Source | How to use it |
| --- | --- |
| [AgendaHeader](/Users/kaechle/Developer/Scint/Sources/Scint/App/Agenda/AgendaHeader.swift), [LibraryHeader](/Users/kaechle/Developer/Scint/Sources/Scint/App/Library/LibraryHeader.swift) | Preserve the themed header structure: 12-point spacing, Typography.pageTitle, IconButton, existing shadows, maximum height 40, horizontal padding 12, bottom padding 8. Do not recreate the screenshot's larger title or move its sidebar button into the header. |
| [SegmentedTabs](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Controls/Tabs.swift) | Reuse the actual segmented control and its inline binding. Do not draw a second segmented control. |
| [Buttons](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Controls/Buttons.swift) | Reuse IconButton and the existing soft styles where their roles fit. Leave shared control geometry unchanged. |
| [Typography](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Tokens/Typography.swift), [Style](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Tokens/Style.swift) | Use existing page/item/detail/footnote typography, canvas/selection backgrounds, borders, shapes, and spacing tokens. Keep new local tuning local; do not retune global tokens for this screen. |
| [TaskCompletionIndicator and DocumentBlock](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Blocks/DocumentBlock.swift) | Reuse completion visuals inside an accessible control and existing block rendering for read-only detail content. Supply values; do not create a second Markdown renderer. |
| [ListFactory](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factories/ListFactory.swift), [GroupFactory](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factories/GroupFactory.swift) | Baselines for consuming descriptors, constructing layouts, and binding callbacks. Preserve ViewContainer and the established context-menu/drag behavior where applicable. |
| [TaskHeader](/Users/kaechle/Developer/Scint/Sources/Scint/App/Agenda/Task/TaskHeader.swift), [TaskSettings](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Mappers/InspectorMappers.swift) | Existing task/schedule access and mutation semantics. Do not copy an older task schema from Resources. |

AgendaContent currently reads task references and builds AgendaCard views directly. Its scope state changes the header selection but does not filter that collection. ContentFrame currently has no agenda parameters/controls overrides. Account for both gaps; merely adding new factory files will not put this screen on the framework pipeline.

The commented TasksOverview/TasksList/TasksSection files in Resources are visual experiments with stale task signatures. They are not an implementation to uncomment. Likewise, the Inspector's GroupHeader is a reference-editing header with its own runtime behavior; reuse the page-header artifacts above for this screen.

**Declare the content before rendering it.**

Preserve the actual protocol signatures in [Types.swift](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Types.swift):

```swift
static func parameters(_ model: any Model) -> Params
static func controls(_ model: any Model) -> Controls

func parameters(_ model: any Model) -> Params
func controls(_ model: any Model) -> Controls

static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View
```

The first pair belongs to mappers, the second to hosts, and the last is the entry point for each layout factory. Keep AgendaContent constructed with `host` and `model`. Model specialization stays at Frame.surface(AppModel). Do not add a date argument to the Mapper requirement, cast `any Model` to AppModel to find ContentFrame, or instantiate a fake model to carry calendar state.

The composed description needs this shape. These are logical descriptor relationships, not a new Swift configuration type:

```text
Tasks / active mode
  day selector                    Row section
    day choices                   stable ID, weekday, day number, today marker
  agenda                          Table section with one column description
    Morning                       group section
      task rows
    Afternoon                     group section
      task rows
    Later                         group section
      task rows
```

Declare the groups, their labels, and their order in the mapper's parameter description. Controls does not manufacture the hierarchy. Factories do not recognize “Morning,” “Tasks,” or a task reference type. Empty mapped groups may be omitted during preparation; do not mutate the declaration or runtime while rendering.

The user confirmed that the header must retain **Today, Upcoming, Later, and All Tasks**, in that order. Use the reference for the body arrangement; do not introduce its Inbox mode or rename/remove the existing tabs. Declare the modes in mapper parameters and keep the active choice in host state. The current task collection is not filtered by its scope selection, so retaining these tabs does not establish their filtering semantics. Any required filtering policy must be defined in mapper preparation, with the host selecting the active mapped branch; factories and layouts must not infer it from mode names. The Later tab is distinct from the Later time-of-day group within a day agenda. Renderers consume supplied parameters without knowing any mode names.

For the shown day agenda, start with five consecutive calendar days beginning today. Generate dates and labels with Calendar and locale-aware formatting. Do not hardcode September 26, add 86,400 seconds to advance days, or use formatted display labels/array offsets as identities. Use the same canonical day identity in the selector and dated task groups. The marker denotes today; selection is independent. Additional calendar paging is not required by this reference.

Keep the selected day in ContentFrame.state under an agenda-specific key. One bounded preparation approach that preserves the Mapper interface is to have the mappers describe the selectable days and their dated task groups, then have ContentFrame select the matching mapped day branch before rendering. The host chooses among described content; schedule arithmetic and grouping remain in the mapper. Default to the mapped today choice without writing state during parameters evaluation. Do not enumerate unbounded recurring dates or build a query/controller subsystem for a five-day strip.

ContentFrame should delegate the tasks branch to AgendaMapper and supply the necessary state callbacks. Preserve its other content branches. AgendaContent consumes the prepared pair, and its header receives the same active mode and callback as the content. Replace the old independent scope binding when wiring this path. Preserve the header's visual body; making its inputs plain values/callbacks does not authorize redesigning it.

**Give each layout enough explicit presentation data.**

RowLayout is a horizontal peer collection. Its cells need a primary label, secondary label, optional small marker, selected appearance, and activation callback. The calendar interpretation belongs entirely to AgendaDays. Use equal-width cells at normal widths, with a native horizontal overflow treatment if needed at narrow widths. Day cells and their separators remain aligned; selection changes their treatment without changing their dimensions.

TableLayout needs one ordered column description shared across its groups: time, completion control, flexible title/summary, Space metadata, optional duration, and disclosure. The labels and values come from the mapper. Keep compact columns stable and let the title absorb width changes. Missing metadata must not cause rows to invent different column positions.

Extend the existing parameter carriers only for real missing presentation data: column sizing/alignment, cells, and optional expanded detail content. A small table-specific payload with nested column/cell declarations is appropriate if ItemParams cannot express those directly. It remains immutable presentation data carried through Params/SectionParams/ItemParams, with the existing reference/identity and Controls callbacks. Do not introduce a parallel TaskRow model with its own state, store view closures in Hashable parameters, or hide an entire Document behind an opaque payload for the factory to decode.

Keep cells and expanded detail distinct from ItemParams.items unless they actually represent child items. Currently `isParent` and `Params.rows` interpret items as children. Putting metadata chips or columns there silently changes navigation semantics. An expanded note is detail content, not a nested task list. If detail rendering needs a supplied content closure, its availability and values must still be explicit in the row description; the closure renders that supplied content rather than querying for missing task data.

Use a native SwiftUI Grid/GridRow implementation as the initial basis for TableLayout: it supports aligned columns and spanning content for group headings and expanded detail. A module named TableLayout does not have to wrap SwiftUI.Table. The screenshot needs variable-height detail spanning several columns, while the native Table is primarily a columnar data control. Evaluate Table only if it meets those requirements without replacing the desired interaction or introducing AppKit workarounds. [Apple's Grid documentation](https://developer.apple.com/documentation/SwiftUI/Grid) describes column alignment and spans; [Table](https://developer.apple.com/documentation/swiftui/table) describes the native data-table API.

Use one column policy across Morning/Afternoon/Later, not independently sized grids that drift with their labels. Expanded content starts at the task-text column and shares the row's selected/expanded background. It must not introduce its own vertical scrolling. Begin with normal SwiftUI layout; add neither a custom measurement engine nor per-cell GeometryReader state. For large collections, measure before replacing the layout with a lazy alternative.

**Add an explicit route for mixed content.**

[Factory.swift](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factory.swift) currently dispatches non-panel sections using Params.layout, and only handles .group and .list. Adding `.row` to the enum or declaring `.table` on a section will not render this screen.

Also, SectionParams.layout already has an internal meaning in GroupFactory: Inspector sections use .grid, .list, and .table while the surface remains .group. Globally changing dispatch to `section.layout ?? params.layout` would reinterpret existing forms. Do not do that as an incidental change.

Use an explicit opt-in composition mode for this content, for example `Layout.stack`, plus the new `Layout.row` primitive. In that mode, Factory dispatches the prepared section's declared layout to RowFactory or TableFactory. Existing .group/.list and panel routes keep their current interpretation. The existing .table enum case can identify the new table within this route; audit its older declarations before enabling it elsewhere. A routing mode is sufficient; do not add a registry, configurable renderer protocol, or AgendaFactory that manages live state.

Keep a single vertical scroll owner in the content shell. RowFactory/TableFactory return section content; they do not each create a ScrollView. Preserve AgendaContent's themed canvas and top safe-area header placement. Any content-specific inset/spacing policy belongs to the new composition path, without changing the navigator's 8-point inset or the Inspector's group spacing. The screenshot does not require sticky day-strip behavior; do not add scroll synchronization for it.

**Map real task data and keep the interactions independent.**

| Display/operation | Existing source or owner |
| --- | --- |
| Task collection | Documents attached to model.session.agenda; retain only actual task documents using Header.content and the valid task block |
| Title / completion | The task block returned by TaskHeader.task(document), not an assumed matching descriptor name |
| Date / repetition | TaskHeader.schedule(document) and When; keep calendar computation in the mapper |
| Summary / expanded text | The document's actual body blocks, excluding its metadata/title block; reuse existing read-only block rendering |
| Space association | The metadata association used by AgendaCard/TaskTarget; it is not necessarily document.origin, which is often the Tasks container |
| Command/provider chip | Existing document command/interface values; omit when absent. Do not populate “Codex” from the sample image. |
| Duration | No established task-duration field was found in the inspected task path. Keep it optional and blank when unavailable; do not infer estimates from adjacent start times or create runtime scheduling fields for a visual example. |
| Selection | Existing model/session selection via Controls.selected/onSelect |
| Completion | Controls.onToggle reads the current task block inside Document.update and changes its completion value, preserving its ID/text |
| Detail expansion | Host-owned state accessed through Surface's expansion capability, using stable row identity |
| Open task | The existing model.open operation through a supplied callback; preserve current task-opening behavior |

Sort by actual scheduled time and a stable tie-breaker. For the pictured day groups, a reasonable initial rule is before noon / noon to 17:00 / 17:00 onward; keep that rule in the mapper and identify it as the chosen policy, not a runtime fact. Filter with calendar day intervals, including their boundaries. Account for When.next being strictly after its argument; a task exactly at midnight must not disappear. Use existing recurrence semantics rather than inventing completion-per-occurrence or rescheduling behavior. If multiple occurrences are displayed, their presentation identities must distinguish occurrences while mutations still target the original document.

A checkbox click changes completion, a disclosure click changes expansion, and a row activation selects or opens according to the existing behavior. One must not implicitly perform the others. Do not derive expansion from done/selected, remove a completed task merely to imitate a different app, or let row gestures swallow embedded controls. The reference includes a completed row still visible and expanded. Completion must not invoke the separate Schedule/Compose workflow.

The header's existing plus/overflow treatment stays. If the requested header work connects task creation, reuse the existing new-task operation in [ActionProvider](/Users/kaechle/Developer/Scint/Sources/Scint/Model/Providers/ActionProvider.swift) through a supplied callback; do not create another creation flow. Preserve unrelated unfinished actions. Keep context menus and drag providers for task rows, but do not add drag-to-schedule or the sidebar drop target in this task.

**Build in reviewable stages and verify the boundaries.**

1. Record the current build and center-header appearance. Add RowLayout/TableLayout with local preview values to verify five day choices, short/long titles, aligned columns, missing metadata, and one expanded row. Preview fixtures are not production data or a new mock model layer.
2. Add RowFactory/TableFactory and their small parameter additions. Their callable API returns views. Demonstrate them with supplied descriptors and callbacks before connecting runtime data.
3. Add AgendaDays/AgendaTasks/AgendaMapper together in a feature file such as Core/Mappers/AgendaMappers.swift. Declare the full hierarchy, then connect ContentFrame preparation/state and AgendaContent's factory rendering. Remove the old card rendering from this screen's active path; leave AgendaCard and other consumers alone.
4. Add the opt-in root composition route and verify that existing List/Group/Panel routing is unchanged, particularly Inspector sections already marked .table. No factory should fetch another Params/Controls pair from the host or query a runtime store.
5. Verify the header retains Today, Upcoming, Later, and All Tasks in that order. Verify live task edits/completion from another view update this screen, and edits here target the clicked reference even when another task is selected. Verify day/mode changes do not mutate schedules or completion, and ordinary redraws do not reset the selected day or expansion.
6. Compare the center against the reference's hierarchy and the current app's theme at normal and narrow widths. Check alignment across groups, long titles, detail expansion/collapse, accessible completion/disclosure labels, keyboard access to actual controls, empty content, and dates near midnight/DST. Use the existing Style.Motion.disclosure animation with native SwiftUI behavior and respect Reduce Motion.
7. Build the Scint scheme and run relevant existing checks. Add focused coverage for date/grouping and target-document mutation if new logic warrants it; avoid tests that merely restate view modifiers. Report actual results, pre-existing failures, and any unavailable data such as duration.

The completion report must show the final module/signature map and these paths: day selection → host state → prepared mapped branch; completion → supplied callback → Document.update; disclosure → Surface → host state; runtime read → mapper → factory → layout. Neither sidebars nor navigator icon/disclosure work belongs in this patch. Do not use the new content feature as a reason to repair panels, rewrite the scheduler, reorganize the theme, or change unrelated editor behavior.
