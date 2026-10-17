The next repair is to make SearchList use the existing mapper/parameter model. This replaces the previous feedback's active implementation checklist. Preserve completed navigation work and the user's placement of PanelNavigation in PanelProvider.swift. Do not move it back into Core or treat its location as an agent violation; the user made that move deliberately.

The failure in SearchList is that its hierarchy is defined outside its parameter description. Parameters returns empty tab shells. Controls.results then decodes a tab ID into a private enum, reads a second group definition, fabricates content sections, and invokes another mapper's query callback. The host must assemble the missing hierarchy. This makes the meaning of the description depend on an extra interpretation path.

**Use the existing implementations as the baseline.**

- [ProjectOutline.parameters](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Mappers/InspectorMappers.swift:73) describes tabs with their child sections in SectionParams.
- [ProjectSettings.parameters](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Mappers/InspectorMappers.swift:146) composes sections from other mappers' parameters.
- [NavigatorMapper.parameters](/Users/kaechle/Developer/Scint/Sources/Scint/Framework/Core/Mappers/NavigatorMapper.swift:53) composes mapped items into an explicit section description.
- Their controls methods supply behavior for the described items. Mapper-to-mapper delegation is valid; generating an alternative UI hierarchy through the control interface is the defect here.

Apply this rule: **parameters declares the structure; controls supplies behavior for that structure; the host supplies its state; factories construct the described views.**

1. **Declare the complete search hierarchy in SearchList.parameters.**

   Remove SearchList.Tab and its image/groups switches. They only describe this UI and are redundant with the existing SectionParams vocabulary. Do not replace them with a configuration registry, another enum, a tuple catalog, a builder type, or a method that translates a second schema into Params.

   This is the intended parameter shape using existing types and initializers:

   ```swift
   static func parameters(_ model: any Model) -> Params {
       .init(description: "No matches", tabbed: true, sections: [
           .init(id: "everything", name: "Everything", header: false, image: "magnifyingglass", layout: .list, sections: [
               .init(id: "document", name: "Content", layout: .list),
               .init(id: "interface", name: "Interfaces", layout: .list),
               .init(id: "structure", name: "Workspace", layout: .list)
           ]),
           .init(id: "content", name: "Content", header: false, image: "command", layout: .list, sections: [
               .init(id: "document", layout: .list)
           ]),
           .init(id: "interfaces", name: "Interfaces", header: false, image: "switch.2", layout: .list, sections: [
               .init(id: "artifact", name: "Artifacts", layout: .list),
               .init(id: "command", name: "Commands", layout: .list),
               .init(id: "interface", name: "Harnesses", layout: .list)
           ]),
           .init(id: "projects", name: "Projects", header: false, image: "cube.transparent", layout: .list, sections: [
               .init(id: "structure", layout: .list)
           ])
       ])
   }
   ```

   Reading this one description must reveal the tabs, their labels/icons, their child sections, and their layouts before any query executes. Repeated category IDs in different tabs are scoped by their containing tab. Preserve the existing labels, icons, order, and runtime search filters.

   This is not a blanket prohibition on enums. Domain enums and a host's actual modes have a purpose. This particular enum is an unnecessary second representation of structure already expressible by Params.

2. **Keep the query callback scoped to a declared content section.**

   The current Mapper protocol is unchanged:

   ```swift
   static func parameters(_ model: any Model) -> Params
   static func controls(_ model: any Model) -> Controls
   ```

   Query state belongs to the host and is not an argument to Mapper.parameters. Retain the existing Controls.results signature for this focused repair:

   ```swift
   ((SectionParams, String) -> [SectionParams])?
   ```

   For reference search, its input is one actual content section from parameters and the current query. Its output is that section with its items populated. It preserves the supplied section's identity, label, header, image, layout, and other metadata. It does not receive a top-level tab and decide which child sections should exist.

   ReferenceList.controls already supplies this operation: it copies the supplied section and fills its items. SearchList.controls should reuse that callback directly, alongside its existing selection and action callbacks. It must not decode the tab ID, construct replacement sections from tuples, or choose a default tab inside results. The selected-tab fallback already belongs to the existing parameter selection path.

   The existing ReferenceList query interprets a declared leaf section's stable ID as its category filter. Keep that existing interpretation in this patch; do not add filter metadata to Core or introduce a new search abstraction. Pass the real declared section, not a temporary SectionParams manufactured solely to transport arguments.

3. **Update SearchPanel's preparation call to populate the declared children.**

   SearchPanel.parameters selects its mapper and resolves the active tab using the existing parameter interface. For results, obtain the mapper's query callback once and apply it to the selected tab's declared child sections:

   ```swift
   let results = SearchList.controls(model).results
   params.sections[index].sections = tab.sections
       .flatMap { results?($0, state.query) ?? [$0] }
       .filter { !$0.items.isEmpty }
   ```

   This fragment replaces the current call that passes the whole tab to results. Use the tab/index already resolved in the method. The mapper declaration is rebuilt on subsequent preparation, so removing empty rendered sections does not erase the definitions needed by later queries.

   The host supplies the query, chosen tab, input value, cursor, and panel configuration. It does not contain the table of search groups, recreate section labels, or know which filters belong under Everything or Interfaces. Mapper.parameters owns that information.

   The host's returned Params must be ready to render. Neither root Factory nor PanelFactory nor a layout invokes results or discovers missing content. Keep generic row navigation outside the factory pipeline as already repaired.

4. **Keep the next patch bounded.**

   Change SearchList and the necessary SearchPanel preparation call. ReferenceList's current query implementation already preserves the declared section; do not redesign it to accommodate a new abstraction.

   Preserve callback semantics, query/tab resets, cursor behavior, detail transitions, current header order, panel size, the 24-result limit per search category, and keyboard behavior. Do not change the Model protocol, Mapper signatures, factories, layout interfaces, navigation placement, or window lifecycle for this correction.

   The same separation should guide later reviews of ActionsList and CommandsList: their parameter methods also currently return placeholders while results supplies the real section collection. Do not call the entire panel mapper design corrected after fixing Search. Their existing filtering and cross-section ranking need their own bounded review; do not alter them as a side effect of this patch.

5. **Show that the framework now carries the description.**

   Check the following outcomes:

   - SearchList.parameters contains the complete tab/section hierarchy even before rows are loaded.
   - SearchList.controls composes callbacks without constructing the hierarchy or executing a search.
   - Selecting Everything resolves its three declared groups; Content resolves one; Interfaces resolves three; Projects resolves one. Inactive tabs do not trigger queries.
   - Query results preserve each declared section's metadata and order. Empty groups are hidden as before.
   - A label change in the declaration changes the UI without changing the category filter or requiring an enum/switch edit.
   - The host and factories have no search-tab/group catalog.
   - Existing selection, detail, navigation, and dismissal behavior remains intact.

   Report the actual build and behavior checks performed. Include a short trace showing the declared child section passed into the existing query callback and returned with items. Do not substitute a list of deleted methods or a passing-test count for this evidence.

The prior reviews focused too much on distributing keyboard mechanics and missed this parameter-model defect. This correction restores one representation of the UI using the types the framework already has. It does not authorize another framework design.

