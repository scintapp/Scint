Follow the current [mapper correction and implementation guidance](/Users/kaechle/Developer/Scint/Docs/PanelFactoryFeedback.md) for the next patch. Preserve the completed shared navigation work and the user's placement of PanelNavigation outside Core. This original plan is historical where it conflicts with that guidance, including per-host input dispatch and construction of the section hierarchy through Controls.results.

Restore the panel rendering pipeline to the architectural boundary established by ListFactory and GroupFactory. Implement this as a behavior-preserving repair across the factory and all of its consumers. The work is complete only when panel interaction no longer depends on a factory.

The repository is `/Users/kaechle/Developer/Scint`. Read `AGENTS.md` and `Docs/Style.md` before changing Swift. Inspect the current working tree and preserve existing user changes, including visual changes made since this plan was written.

Model specialization belongs at the host's `surface(...)` call boundary. Preserve the associated-type surface contracts and their concrete model inputs. Host and Mapper `parameters` and `controls` retain `any Model`. InspectorFrame has already been corrected; do not redo that work.

**The required boundary is part of the task's acceptance criteria.**

- Hosts own presentation state and feature-specific interaction. Mappers translate application information and operations into the shared UI vocabulary.
- Host parameter preparation resolves the content needed for rendering. Reading parameters or constructing controls must not mutate application or interaction state.
- A Surface supplies an authoritative Params/Controls pair to the root Factory. Factories must use that pair and never obtain a replacement from the host.
- The root Factory assembles the surface shell and dispatches sections. Layout factories construct sections and items. Their externally callable operations return views.
- Layouts receive presentation values, content closures, and scoped callbacks. They may own local hover, focus, and editing-draft state. They must not receive Host, Model, Surface, or StateContainer to discover content or execute workflows.
- Events invoke supplied behavior. No event calls a factory operation. Making an operational method private does not make it valid factory work.
- State remains owned by the host. Params can contain freshly derived presentation values; they do not become another state store. Do not cache result arrays or introduce a second selection model as part of this repair.
- Missing capabilities are represented explicitly in Params/Controls. Do not bypass the boundary through a model cast, a global lookup, an environment object, a concrete host reference, or a replacement controller that merely inherits PanelFactory's mixed responsibilities.

Limit implementation to the panel pipeline and necessary callers: Core/Factory.swift, Core/Factories/PanelFactory.swift, Core/Layouts/PanelLayout.swift, the relevant Params/Controls declarations, panel mappers, SearchPanel, ActionsPanel, ChoiceMenu, EditorMenu, and the editor's menu-input calls. Touch LoadMenu or PanelModel/PanelProvider only where the repaired input or dismissal path requires it.

TranscriptFactory is being repaired separately. Do not modify it. Do not expand this task into repairs of GroupHeader, a redesign of List/Group, changes to all application Surfaces, or a reorganization of the framework.

1. **Record the current consumers and behavior before changing ownership.**

   Trace every PanelFactory reference, every Controls.results producer and consumer, and every place that changes a panel/menu query, cursor index, active tab, or detail mode. Include the externally focused editor menu: it receives input from MarkdownInputView while the text editor remains first responder.

   Use the current files as the baseline. In particular, preserve the current panel header order, sizes, spacing, focus rules, scrolling, window placement, dismissal configuration, and action execution order. Preserve user changes rather than applying older versions of these files.

   Record the four consumers and their owned behavior:

   | Consumer | Behavior that belongs to the host |
   | --- | --- |
   | SearchPanel | Query and tab changes, cursor navigation, opening/selecting results, entering reference detail, returning from detail |
   | ActionsPanel | Query and cursor navigation, dismissing the panel and executing the chosen action in the existing order |
   | ChoiceMenu | Filtering supplied choices, cursor navigation, selection indication, dismissal, invoking onPick |
   | EditorMenu | Commands/references/forms, externally supplied query changes, cursor navigation, choosing commands, form transitions, insertion, dismissal and editor focus restoration |

   Establish a build baseline using the shared Scint scheme in Scint.xcodeproj. Record pre-existing failures so they are not attributed to this repair. Inspect the existing test runners before choosing which remain applicable; do not assume an editor interface covers panel behavior.

2. **Introduce the small, explicit interface additions needed to replace hidden factory behavior.**

   Keep these existing entry signatures unchanged:

   ```swift
   func parameters(_ model: any Model) -> Params
   func controls(_ model: any Model) -> Controls

   static func parameters(_ model: any Model) -> Params
   static func controls(_ model: any Model) -> Controls
   ```

   Use the existing Params and Controls carriers. The target additions for this repair are:

   | Carrier | Addition/change | Meaning |
   | --- | --- | --- |
   | Params | `input: ItemParams?` | An explicitly designated surface-header input. Its value comes from its owner. Ordinary fields in sections remain ordinary fields. |
   | Params | `cursor: AnyHashable?` | The derived identity of the current navigable item, used for presentation such as scrolling. This is not independently stored selection state. |
   | Controls | Nested `Input` enum with `move(Int)`, `submit`, `secondary`, and `cancel` cases | Semantic interaction intents, independent of SwiftUI KeyPress and AppKit selectors. |
   | Controls | `onInput: ((Input) -> Bool)?` | Host-supplied interaction. Returns whether the event was consumed. In particular, an unconsumed cancellation may continue to the existing dismissal path. |
   | Controls | `onTabSelect: ((SectionParams) -> Void)?` | Host-supplied tab selection, including any host-specific query/cursor reset. |
   | Controls | Change `results` to return `[SectionParams]` | A mapper-to-host content query: `((SectionParams, String) -> [SectionParams])?`. It returns real content sections instead of synthetic parent items used as section headers. It is never consumed by a factory or layout. |

   Reuse existing `onValueChange` for changes to the designated input, `onSelect` for item activation, `onAction` for the declared item action, `focused` for a panel row's cursor indication, and `selected` for its independent selection indication. Keep cursor and selection distinct. The host must derive Params.cursor and Controls.focused from the same cursor resolution.

   Add defaults that leave existing List/Group callers unchanged. Do not broaden the Host protocol with panel-only controller methods, alter the Mapper entry-point signatures, add a new view-model hierarchy, or put raw keyboard events in Params.

   These are interface changes to make behavior explicit. They do not authorize any new application behavior.

3. **Move content resolution upstream and normalize the presentation description.**

   Update ReferenceList, SearchList, ActionsList, the editor's CommandsList, and ChoiceMenu's query construction as applicable. Each query producer returns explicit SectionParams with final items and stable identities. Preserve filtering, ranking, grouping, labels, and action identities.

   Convert mapper-created group headings into real sections at the mapper boundary. Do not indiscriminately flatten every ItemParams.isParent: real item hierarchy remains hierarchy. Presentation headers and separators must be represented explicitly in section structure, not inferred from fake actionable parents by PanelFactory.

   Use the same tab shape as the root List/Group pipeline. With `tabbed == false`, Params.sections are content sections. With `tabbed == true`, Params.sections are tabs and the selected tab's nested sections are its content. Preserve metadata for all tab buttons; the selected content must be fully resolved before the renderer receives it. Do not retain a special panel interpretation in which the tab itself is treated as the content section.

   Each host's `parameters(model)` incorporates the query result using its current query and active tab, supplies the explicit header input with its current value, and returns the ready-to-render description. Mapper code owns the search/filter translation; host code owns the query and tab state.

   Keep content derivation independent of rendering and input execution. Avoid a recursion cycle where parameters calls the host's controls, and the host's controls calls parameters to resolve the cursor. Obtain mapper query callbacks directly during preparation, or use a small data-only projection shared by the host's parameter and interaction paths. Do not call the host's fully decorated Controls just to obtain its query function.

   Completion condition: neither Factory nor PanelFactory nor a layout executes Controls.results, appends queried items to a section, chooses a mapper, or searches application data.

4. **Put panel interaction on its actual state owners.**

   Have each host supply Controls.onInput and the relevant value/tab/action callbacks. A private instance method on that host may implement its input handling. These callbacks are also the entry point for non-view callers such as the text editor.

   Derive the navigable order and current item from the same prepared content used by parameters. Share that definition within the host; do not separately encode one order for rendering, another for arrow keys, and another for Enter. Eligibility is a host/mapper decision. A section's visual layout alone must not decide whether its contents are actionable.

   Preserve the established behavior of wrapping navigation, no-result input, and cursor reset. Empty or changed results must produce a valid cursor or no cursor, never an invalid array access. Do not introduce a separate retained result list merely to implement movement.

   SearchPanel owns the complete transition into and out of reference detail. Invoking an arbitrary onAction elsewhere must have no implicit effect on detail mode. ActionsPanel and ChoiceMenu retain their existing dismissal and action ordering. EditorMenu retains its commands, reference insertion, task/link forms, and focus restoration.

   Query/index reset must occur in the owning query-change operation, including changes arriving through EditorMenu.open from the still-focused text editor. Remove the reliance on a factory-installed onChange observer. Tab callbacks likewise perform the host's complete tab transition, including any required query and cursor changes.

   Small shared stateless algorithms are allowed when genuinely reused by these hosts. Their inputs are values such as arrays, identities, and indices. They may not accept Host/Model/Surface, retain state, invoke callbacks, or decide feature transitions. Do not move the entire old PanelFactory controller into a renamed utility.

   Completion condition: input can move and choose menu items without constructing a Surface or any view, and without calling any Factory type.

5. **Make the root Factory assemble the panel shell and make PanelFactory match List/Group.**

   Keep the root entry point:

   ```swift
   @ViewBuilder static func build(
       _ surface: some Surface,
       _ params: Params,
       _ controls: Controls
   ) -> some View
   ```

   Replace PanelFactory's entry points with the same section/item signatures as ListFactory and GroupFactory:

   ```swift
   @ViewBuilder static func build(
       _ surface: some Surface,
       _ section: SectionParams,
       _ controls: Controls
   ) -> some View

   @ViewBuilder static func build(
       _ surface: some Surface,
       _ item: ItemParams,
       _ controls: Controls
   ) -> some View
   ```

   The root Factory constructs PanelLayout from the supplied Params/PanelParams, composes the explicit header input, reference header, tabs, and body, and dispatches sections to the appropriate view builders. Retain generic tab resolution at root composition. When a host supplies onTabSelect, wire that callback; the root must not append its own query/index/detail changes after it. Preserve the existing generic tab behavior for non-panel callers that do not supply the callback.

   PanelFactory constructs section and item views only. It uses the supplied predicates for row presentation and forwards item events through supplied callbacks. It cannot receive a whole Params object, StateContainer, cursor object, or a sequence of operational arguments as an alternative API.

   Derive the existing compact/regular presentation from the supplied PanelParams at the shell. Carry that purely visual choice through the existing SwiftUI controlSize environment to the panel components, with an explicit compact/regular mapping. Preserve their existing styling constants. This is presentation context only: never put a Host, Model, or state container in the environment to bypass the factory signatures.

   Delete PanelFactory.sections, choices, current, move, choose, select, and handle. Their responsibilities must already have their proper owners. Do not transplant those methods wholesale into the root Factory, ViewContainer, PanelLayout, or another factory extension.

   Completion condition: PanelFactory's callable surface consists of view-building overloads, and its construction code never reads surface.host.state or re-fetches parameters/controls through surface.host.

6. **Make panel layouts translate input and wire every consumer through the repaired interfaces.**

   PanelLayout and PanelField receive scoped values and callbacks. They translate physical key events into Controls.Input intents and turn the returned consumed flag into the platform's event-handling result. This translation may be shared privately inside the layout module if both views need it. It contains no search, cursor-resolution, or feature-transition logic.

   Root composition supplies input values and change callbacks. PanelField must not bind itself to host.query. Ordinary section fields remain associated with their own ItemParams and onValueChange callback; only Params.input identifies the surface-header input.

   Preserve current input meanings: arrows move; Return submits; panel Tab emits the host's secondary intent, whose meaning the host supplies; Escape offers cancellation to the host before falling through to the existing dismissal path. Preserve the editor's existing forward/backward Tab movement through its selector-to-intent translation. Preserve modifier behavior observed in the baseline rather than adding keyboard features during the repair.

   Update MarkdownInputView's menu path to call EditorMenu's supplied semantic input callback instead of creating panels.editor.surface(panels) and calling PanelFactory. Both the SwiftUI panel input and the AppKit editor input must reach the same host-owned selection and activation behavior.

   Keep panel presentation, positioning, key-window behavior, and configured dismissal in PanelModel/PanelProvider. If their Escape delivery prevents an owned detail-cancel operation from running, repair that narrow routing so the host gets the declared opportunity to consume it; do not move the window lifecycle into rendering code. An event must be acted on once.

   Migrate SearchPanel, ActionsPanel, ChoiceMenu, and every EditorMenu mode. Do not declare the migration complete while an old path remains behind a compatibility wrapper. Keep intermediate changes reviewable and compiling; temporary migration code must be removed before completion.

7. **Verify behavior and inspect the boundary directly.**

   Build the shared Scint scheme after the migration and run applicable existing checks. Add focused behavior tests where the existing interface can exercise the changed logic. Prefer tests of observable navigation, query changes, action delivery, and cancellation over tests that merely repeat implementation branches. Exercise UI focus and window dismissal in the running app; source inspection alone does not verify those behaviors.

   Required coverage:

   | Scenario | Required result |
   | --- | --- |
   | Search query and tab changes | Correct ordered results; the established cursor reset; tabs and input remain in the current visual order |
   | Search secondary action and Escape | Enter detail only for search; return to results before dismissal when detail cancellation is consumed |
   | Action palette | Filtering and navigation work; the selected action executes once with the existing dismissal order |
   | Choice menu | Filtering, checked selection, keyboard activation, click activation, and dismissal remain correct |
   | Editor commands and references | The editor can retain focus, update the query, navigate both directions, and insert the chosen result without constructing a Surface |
   | Editor task/link forms | Header input edits the owned form value; submission, dismissal, and editor focus restoration remain correct |
   | Empty or shrinking results | No invalid cursor or accidental activation; event handling remains intentional |
   | Cursor versus selection | Row highlight, scroll target, and activation refer to the same current item; checked selection remains independent |
   | Repeated parameter/control/render evaluation | No query reset, cursor movement, mode transition, dismissal, or action execution |
   | Explicit Params/Controls pair differing from host defaults | The renderer honors the supplied pair and never substitutes the host's default mapping |
   | Ordinary editable field in panel content | The field uses its supplied value and edit callback; it is not promoted to the header or rebound to the query |
   | Navigator and Inspector | Existing List/Group rendering, expansion, selection, and tab behavior remain intact |

   Review references as evidence, not just naming. Search every PanelFactory call and confirm it requests a View. Check factories for host.parameters, host.controls, host.state, model/session traversal, results invocation, and operational state mutations. The root's existing generic tab-state access is narrowly permitted; query, cursor, and feature-mode control are not.

   Check layout dependencies for whole Host/Model/Surface/StateContainer access. Confirm that no old control algorithm was simply hidden in a closure, extension, layout, ViewContainer, or renamed shared controller. Inspect all remaining Controls.results uses: every consumer must be an upstream mapper/host preparation step.

8. **Report completion against the contract.**

   Return the final signature table, where content preparation and each interaction now live, which old methods and call sites were removed, the behavior checks performed and their results, and any genuine remaining failures. Distinguish pre-existing failures from failures introduced by this work.

   Completion requires all four consumers to use the repaired pipeline, no operational factory API or compatibility shims, no new state owner, and no unrequested repair of TranscriptFactory or the other excluded modules. Fewer lines or newly named types do not establish completion; the ownership and call-direction constraints do.
