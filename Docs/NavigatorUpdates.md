Implement section disclosure, disclosure animations, and customizable Space icons in the existing navigator pipeline. These are additions to the current design. Preserve its ownership boundaries, interaction behavior, and tuned geometry.

Read [AGENTS.md](/Users/kaechle/Developer/Scint/AGENTS.md) and [Docs/Style.md](/Users/kaechle/Developer/Scint/Docs/Style.md). Inspect the working tree before editing and preserve the user's existing changes. This handoff was checked against the source on October 15, 2026; verify the named interfaces still match before applying it.

The scope is the visible Spaces and Library section headers, existing folder disclosures, and identity icons on top-level Space rows. Preserve the headerless Agenda/Documents/Spaces shortcuts. The user confirmed that icon customization applies only to top-level Space rows; descendant activity dots must remain unchanged. The reusable picker should support later callers without adding those callers now.

**Framework rules apply to both features.** Parameters describes the UI; controls supplies behavior for that description; the host owns interaction state; factories construct views and connect their inputs; layouts and controls render those inputs and emit events. Observable runtime stores own domain values.

| Layer | Responsibility and permitted access |
| --- | --- |
| Runtime | Store the chosen icon metadata, expose observable reads, and perform persistence through the existing update path. No SwiftUI types or picker state. |
| Mapper | Read the model/runtime and produce the existing Params/SectionParams/ItemParams description. Supply callbacks that act on the described reference. Domain checks and decisions about which items support icon editing belong here. |
| Host/Frame | Own StateContainer and supply the model, mapped parameters, and controls through the established Surface entry point. No additional navigator controller or copied icon state. |
| Surface | Carry host/model and adapt the host's generic expansion state through the existing expansion interface. Supply the authoritative parameter/control pair to Factory. |
| Factory/ListFactory | Consume that pair, choose and construct the existing layout components, and bind specific values and callbacks to them. Wire disclosure through Surface's generic expansion capability, as existing folder expansion demonstrates. Runtime lookup, icon persistence, domain classification, new host-state traversal, and a callable interaction API are not. |
| List layouts/reusable picker | Receive the presentation values, content, and callbacks they need. Own native presentation mechanics such as hover or animation. New picker code must not receive Model, Host, Surface, or StateContainer to discover its data. |

Preserve these entry signatures and their existing call direction:

```swift
func parameters(_ model: any Model) -> Params
func controls(_ model: any Model) -> Controls
static func parameters(_ model: any Model) -> Params
static func controls(_ model: any Model) -> Controls
static func build(_ surface: some Surface, _ section: SectionParams, _ controls: Controls) -> some View
static func build(_ surface: some Surface, _ item: ItemParams, _ controls: Controls) -> some View
```

The navigator's path is NavigatorFrame → AnySurface → Factory → ListFactory → ListHeader/ListLayout/ListLink. NavigatorMapper composes SpacesList and LibraryList parameters. Follow [ListFactory](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factories/ListFactory.swift) and [GroupFactory](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factories/GroupFactory.swift) for construction and callback wiring. Follow the actual [Host/Frame/Surface declarations](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Types.swift); model specialization remains at the host's surface call.

The following are acceptance requirements:

- Parameter generation, control construction, and rendering perform reads and construction. They do not initialize state, select items, save icons, or trigger refreshes as a side effect.
- Declare capability and presentation in the existing parameter vocabulary. Extend it narrowly when a genuinely missing value is required. Do not introduce a second navigator schema, configuration interpreter, or factory/controller to reconstruct it.
- Factories expose view construction. Events invoke supplied callbacks or the established generic state capability. No caller asks a factory to operate the live navigator.
- Factory code must not identify NavigatorFrame, cast the model, inspect Space.Type, or recognize a section by its display name. Mappers decide domain eligibility; stable IDs identify state.
- Derived Params values are legitimate render inputs. Caching them in a view model, copying runtime values into @State, or synchronizing the copies with onChange creates another owner and is prohibited.
- An inline Binding that adapts a value and callback to a native control is appropriate. A second stored selection, binding infrastructure, or a synchronization layer is not. Local hover/focus state and a popover's presented Boolean are legitimate UI state when needed.
- Preserve wrapHeader, wrapLink, ViewContainer, selection/focus callbacks, drag/drop, and context menus. Their behavior must survive both expanded and collapsed rendering.

**Task 1: add section disclosure and native animation.**

1. Add a small declarative section capability, for example `SectionParams.disclosable`, defaulting to false. Enable it on the visible Spaces and Library sections in [NavigatorMapper](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Mappers/NavigatorMapper.swift). ListFactory responds to that capability. It must not contain a switch over navigator section IDs. Leave other factories and nonparticipating sections unchanged.

2. Keep the header visible when the section is closed and omit only its items. Add the disclosure affordance to ListHeader while preserving its existing typography, alignment, and height. ListHeader receives expansion state and a callback; it does not retrieve either through a host or runtime reference. Apply the existing wrapHeader to the resulting interactive header, preserving its context menu. An empty section still retains its existing header behavior.

3. Store section expansion in the existing host StateContainer and access it through Surface's expansion interface. Sections start expanded, preserving today's initial appearance. The current one-argument isExpanded/setExpanded methods assume initially closed rows; do not silently change that behavior. Add a narrow generic read/toggle overload accepting the initial expansion value if needed. Its implementation belongs at the Surface/StateContainer boundary and can use the existing typed `values` subscript, with absence meaning the supplied default. ListFactory supplies a namespaced section key and an initial value of true; it receives a Boolean and wires the callback without reaching through host.state itself. Do not add another dictionary, mutate state during rendering, or invert the meaning of `isExpanded` to store collapsed sections in `expanded`. Keep the existing folder path intact. Closing a section must not clear its children's expansion state. Section keys must be independent of row IDs, names, order, and icon choices.

4. Animate the section and folder disclosure actions using SwiftUI's native animation transaction, initially `withAnimation(.default)` around the supplied toggle callback. The layout owns this presentation choice; the runtime does not. Animate content insertion/removal and the disclosure indication with built-in SwiftUI mechanisms. A native rotation or symbol transition can animate the chevron without changing its frame. Do not add measured heights, GeometryReader/PreferenceKey plumbing, timers, custom Animatable types, or a second animation-progress state. Avoid applying animation to the entire navigator's changing data. Respect Reduce Motion through SwiftUI's environment.

5. Retain the present layout structure. This task does not require replacing it with SwiftUI List, OutlineGroup, or a default-styled DisclosureGroup. Native animation can operate on the existing views. If a native disclosure control is used, prove that its styling preserves the measured layout before adopting it. [Apple's animation APIs](https://developer.apple.com/documentation/swiftui/animations) describe the state transaction and value-scoped mechanisms; [DisclosureGroup](https://developer.apple.com/documentation/swiftui/disclosuregroup) supports externally supplied expansion state.

Treat these current measurements as constraints, not cleanup opportunities:

| Existing element | Preserve |
| --- | --- |
| ListLink/ListLayout icon slot | 16 × 16; existing dot scaling and icon rendering |
| Folder disclosure | Existing 20 × 20 treatment, 8-point heavy chevron, corner radius, and leading/trailing padding |
| ListRow | 24-point minimum height, 2-point vertical padding, 13-point name text, 7-point selection/background radius |
| Child indentation | Existing 16-point increment and row-specific offsets |
| Root item spacing | ListFactory's 1-point vertical padding |
| ListHeader | 11-point text, existing opacity, 6-point bottom padding, 4-point horizontal padding, label origin |
| Surface/section spacing | Factory's 8-point horizontal inset and 16-point section bottom spacing; NavigatorFrame's existing chrome |

Read [ListLayout.swift](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Layouts/ListLayout.swift) and [Factory.swift](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Factory.swift) for the full modifier chains. The table is not permission to change unlisted values. Add the header affordance without shifting the existing title. Do not reorder modifiers, normalize constants, or adjust surrounding layout to compensate for a new control's default padding.

**Task 2: add a reusable icon chooser backed by runtime metadata.**

1. Establish the authoritative value before wiring UI. At inspection, neither [Space](/Users/kaechle/Developer/ScintRuntime/Sources/ScintRuntime/Environment/Domain/Structural/Space.swift) nor [Descriptor](/Users/kaechle/Developer/ScintRuntime/Sources/ScintRuntime/Core/Identity/Descriptor.swift) contains an icon override. Observation exists; the requested data field does not. The proposed addition is an optional `Descriptor.icon: String?`, alongside the existing name/description metadata. Nil means the existing automatic icon. Store a symbol name, never Image, Color, or a client-side icon object. Use `Catalog.shared.update(ref) { $0.icon = symbol }`, matching existing descriptor edits and their persistence notification path. If this field has been added since inspection, use its established owner instead of creating another one.

2. Keep mapping and mutation upstream. SpacesList reads the override through the live runtime and describes icon-editing eligibility for the intended rows. Its callback writes to the reference supplied by the item, never whichever Space happens to be selected when the picker closes. NavigatorMapper must forward the needed behavior: it currently composes SpacesList's parameters but supplies its own Controls, so changing SpacesList.controls alone does not wire the navigator. Keep the existing selection/drop/context-menu behavior while adding this callback.

3. Use a small, explicit parameter/control addition if required. The information the factory needs is whether this item supports icon editing, its current optional override, and a callback accepting a new optional symbol. Keep the resolved display symbol in the existing ItemParams.image path. Do not infer editability from the symbol name, parenthood, or whether a stored override happens to be non-nil. Nil must support editing a default icon as well as resetting to it. This is render data and a callback, not a new state object. Keep this information distinct from ItemParams.items, which already describes navigator children.

4. Put the reusable visual control alongside the existing controls in Framework/Views, for example `IconPicker.swift`. Its essential interface is `IconPicker(value: String?, onSelect: (String?) -> Void)`; a choice list can be a presentation input if needed. It receives no Space/model/store and owns no selected-icon state. The factory binds the parameter value and supplied callback to it, just as GroupFactory binds existing picker controls. A small fixed set of named SF Symbols and a default/reset choice is sufficient. Do not add image uploads, symbol indexing/search, color customization, or a settings subsystem.

5. Prefer a native menu palette first. SwiftUI's `.pickerStyle(.palette)` supports compact symbol choices inside menus and is available on macOS 14+, below this app's deployment target. Build its selection Binding inline from the supplied value and callback, including a valid nil/default choice. Outside a menu, this style becomes segmented, so do not assume it produces a floating icon grid. [Apple's palette picker documentation](https://developer.apple.com/documentation/swiftui/pickerstyle/palette) describes that behavior. If the palette is unsuitable for the chosen small set of icons, use a simple native popover containing buttons, with only local presentation state. Avoid a second selectedIcon/draft/save/cancel model: choosing an icon updates the runtime directly.

6. Preserve the existing row interactions when adding the entry point. A menu entry avoids consuming row width or taking over the folder-disclosure hit target. Compose it into the existing row context menu; attaching competing contextMenu modifiers is not sufficient. The current navigator menu is supplied by wrapLink. If factory-built picker content needs an explicit menu-content slot, add only that slot and adapt the navigator/SpacesList menu composition that needs it. Keep runtime writes in the mapper callback and component construction at the factory boundary. Do not solve this by passing the whole Controls/Surface into IconPicker, replacing the folder hover accessory, or reorganizing all menu infrastructure. Preserve existing actions and ViewContainer's drag/drop behavior on both parent and leaf rows.

7. Resolve identity icons consistently. [Iconography.icon(for:)](/Users/kaechle/Developer/ScintComponents/Sources/ScintComponents/Tokens/Iconography.swift) already owns Space identity-symbol resolution. Its Space branch should honor the optional override while preserving the current automatic fallback and tint calculation. SpacesList continues mapping that resolved symbol into ItemParams.image. Leave Iconography.Dot and the descendant activity-dot mapping intact, as explicitly confirmed by the user. Resetting the override restores the automatic symbol; it does not store a copy of today's fallback. Choosing a symbol must not change the 16-point icon slot, count, indentation, selection highlight, or disclosure target.

The two event paths must remain readable:

```text
Disclosure button → supplied toggle → host-owned expansion value
IconPicker selection → supplied Controls callback → Catalog.update(item.ref)
Observable metadata read → mapper parameters → factory → rendered icon
```

A runtime update does not require a client refresh token, notification, onChange bridge, or reconstructed host. If observation fails, trace the live read and owner instead of adding synchronization machinery.

**Implement and verify in small steps.** First establish the current build and expanded/collapsed visual baseline. Add root disclosure and verify its state behavior, then animate disclosures, then add the metadata/picker path. Preserve independent working-tree changes in all three repositories.

- Confirm named sections initially remain open; headerless shortcuts remain as they are. Collapse/reopen a section after expanding a child and verify the child's state survives. Verify section keys cannot toggle a row accidentally.
- Verify animation in both directions, rapid repeated toggles, and Reduce Motion. Confirm ordinary selection, runtime activity updates, and icon changes do not trigger unrelated disclosure animation.
- Compare identical before/after expanded states, including hovered, selected, and indented rows. Apart from the added header affordance and explicitly chosen icon, existing positions, heights, widths, colors, and spacing must match.
- Choose and reset an icon on Space A while Space B is selected. Only A changes. Verify live updates at existing identity-icon callers, unchanged activity dots, and unchanged fallback appearance for all uncustomized Spaces. Offer icon editing only on top-level Space rows, not descendant activity-dot rows.
- Check persistence through the existing save/load path and decoding of old records without the new optional field. Add focused coverage for this data-compatibility boundary; do not build a new UI test framework for the feature.
- Check context menus, header menus, row selection, nested disclosure clicks, and drag/drop on both parent and leaf rows. Confirm a picker click does not also select or expand the row.
- Build the Scint scheme with its local ScintRuntime/ScintComponents dependencies and run relevant existing checks. Report what was actually tested and distinguish pre-existing failures from introduced failures. A passing build is not evidence that geometry or observation was verified.

The completion report should identify each changed responsibility, show the icon read/write and disclosure paths, and include the visual/runtime checks performed. Limit changes to these features and their required callers. Panels, PanelNavigation, TranscriptFactory, Inspector behavior, navigator tree ordering/flattening, and unrelated cleanup remain outside this task.
