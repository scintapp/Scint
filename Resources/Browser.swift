//import SwiftUI
//import AgencyRuntime
//
//
//@Observable final class BrowserModel {
//    let console = Console()
//    let content = BrowserContent()
//    let inspector = Inspector()
//}
//
//@Observable final class BrowserContent: Frame {
//    var mode: BrowserViewMode = .grid
//    var position: CGFloat = 280
//    var presented: Bool = true
//    var expanded: Set<AnyHashable> = []
//    var searchText = ""
//
//    @MainActor func build(_ agency: AgencyModel) -> some View {
//        BrowserCollection(
//            model: self,
//            params: BrowserMapper.params(agency, self),
//            closures: BrowserMapper.closures(agency, self)
//        )
//    }
//}
//
//struct BrowserToolbar: ToolbarContent {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some ToolbarContent {
//        @Bindable var content = agency.browser.content
//        @Bindable var console = agency.browser.console
//
//        ToolbarItem(placement: .navigation) { NavigationControls() }
//        ToolbarItem(placement: .principal) { RuntimeControls() }
//        ToolbarItem(placement: .primaryAction) {
//            ViewModePicker(selection: content.mode) { content.mode = $0 }
//        }
//        ToolbarItem(placement: .automatic) {
//            TextField("Search", text: $content.searchText)
//                .textFieldStyle(.roundedBorder)
//                .frame(width: 220)
//        }
//        ToolbarItem(placement: .primaryAction) {
//            BrowserConsoleToggle(presented: $console.presented)
//        }
//        ToolbarItem(placement: .primaryAction) { BrowserInspectorButton() }
//        ToolbarItem(placement: .accessoryBar(id: "browser-path")) { BrowserPathBar() }
//    }
//}
//
//struct BrowserInspectorToolbar: ToolbarContent {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some ToolbarContent {
//        @Bindable var inspector = agency.browser.inspector
//        ToolbarSpacer(.flexible, placement: .automatic)
//        ToolbarItem(placement: .primaryAction) {
//            InspectorToggle(presented: $inspector.presented)
//        }
//        .sharedBackgroundVisibility(inspector.presented ? .hidden : .visible)
//    }
//}
//
//struct BrowserInspectorButton: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        @Bindable var inspector = agency.browser.inspector
//        InspectorToggle(presented: $inspector.presented)
//    }
//}
//
//struct BrowserConsoleToggle: View {
//    @Binding var presented: Bool
//
//    var body: some View {
//        Button { presented.toggle() } label: {
//            Image(systemName: "dock.rectangle")
//                .help(presented ? "Hide console" : "Show console")
//        }
//        .buttonBorderShape(.circle)
//        .labelsHidden()
//    }
//}
//
//struct BrowserCollection: View {
//    let model: BrowserContent
//    let params: Params
//    let closures: Closures
//
//    var body: some View {
//        VStack(spacing: 0) {
//            Group {
//                switch model.mode {
//                case .grid:
//                    BrowserGrid(sections: params.sections, model: model, closures: closures)
//                case .list:
//                    BrowserList(sections: params.sections, model: model, closures: closures)
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//
//            Divider()
//            BrowserPathBar()
//        }
//        .background(Color(nsColor: .controlBackgroundColor))
//    }
//}
//
//struct BrowserMapper: Mapper {
//    static func closures(_ agency: AgencyModel, _ frame: any Frame) -> Closures {
//        Closures(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                return agency.session.selected(ref, item.path)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, from: item.origin, url: item.path)
//            },
//            onOpen: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, from: item.origin, url: item.path)
//                if item.isParent { frame.setExpanded(item.id) }
//            }
//        )
//    }
//
//    static func params(_ agency: AgencyModel, _ frame: any Frame) -> Params {
//        let expanded = frame.expanded
//        let query = (frame as? BrowserContent)?.searchText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
//
//        func matches(_ name: String) -> Bool {
//            query.isEmpty || name.localizedCaseInsensitiveContains(query)
//        }
//
//        func sort(_ items: [ItemParams]) -> [ItemParams] {
//            items.sorted {
//                if $0.isParent != $1.isParent { return $0.isParent && !$1.isParent }
//                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
//            }
//        }
//
//        func sheet(for ref: Reference, origin: Reference) -> ItemParams? {
//            guard let sheet = Sheet.with(ref, { $0 }), matches(sheet.name) else { return nil }
//            return .init(
//                ref: sheet.ref,
//                origin: origin,
//                name: sheet.name,
//                image: "doc.text",
//                description: sheet.content
//            )
//        }
//
//        func space(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
//            let name = Boundary.with(ref, { $0.name }) ?? "Boundary"
//            let childBoundaries = Boundary.with(ref, { $0.boundaries }) ?? []
//            let childSheets = Boundary.with(ref, { $0.closure })
//                .flatMap { Closure.with($0, { $0.sheets }) } ?? []
//            let hasChildren = !childBoundaries.isEmpty || !childSheets.isEmpty
//            let isExpanded = expanded.contains(AnyHashable(ref))
//
//            let children: [ItemParams]
//            if isExpanded {
//                let boundaries = childBoundaries.compactMap { space(for: $0, in: agency) }
//                let sheets = childSheets.compactMap { sheet(for: $0, origin: ref) }
//                children = sort(boundaries + sheets)
//            } else {
//                children = []
//            }
//
//            guard matches(name) || !children.isEmpty || (query.isEmpty && hasChildren) else { return nil }
//
//            return .init(
//                ref: ref,
//                name: name,
//                image: "folder.fill",
//                count: childBoundaries.count + childSheets.count,
//                items: children,
//                isParent: hasChildren
//            )
//        }
//
//        func space(for ref: Reference, in agency: AgencyModel) -> ItemParams? {
//            let name = Space.with(ref, { $0.name }) ?? "Space"
//            let childRefs = Space.with(ref, { $0.boundaries }) ?? []
//            let isExpanded = expanded.contains(AnyHashable(ref))
//
//            let children = isExpanded
//            ? sort(childRefs.compactMap { space(for: $0, in: agency) })
//            : []
//
//            guard matches(name) || !children.isEmpty || query.isEmpty else { return nil }
//
//            return .init(
//                ref: ref,
//                name: name,
//                image: "folder.fill",
//                count: childRefs.count,
//                items: children,
//                isParent: true
//            )
//        }
//
//        return .init(
//            nesting: .recursive,
//            sections: [
//                .init(
//                    id: "spaces",
//                    name: "Workspaces",
//                    showsHeader: false,
//                    items: sort(Runtime.shared.spaces.compactMap { space(for: $0, in: agency) })
//                )
//            ]
//        )
//    }
//}
//
//enum BrowserViewMode: String, CaseIterable, Identifiable {
//    case grid
//    case list
//
//    var id: String { rawValue }
//
//    var image: String {
//        switch self {
//        case .grid: "square.grid.2x2"
//        case .list: "list.bullet"
//        }
//    }
//}
//
//struct ToolbarChevronButtons: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        HStack(spacing: 0) {
//            Button { agency.backward() } label: { Image(systemName: "chevron.left") }
//                .disabled(!agency.session.canGoBack)
//                .help("Back")
//            Divider().frame(height: 18)
//            Button { agency.forward() } label: { Image(systemName: "chevron.right") }
//                .disabled(!agency.session.canGoForward)
//                .help("Forward")
//        }
//        .buttonStyle(.borderless)
//        .controlSize(.large)
//    }
//}
//
//struct ViewModePicker: View {
//    let selection: BrowserViewMode
//    let setSelection: (BrowserViewMode) -> Void
//
//    var body: some View {
//        Picker(
//            "View",
//            selection: Binding(
//                get: { selection },
//                set: { setSelection($0) }
//            )
//        ) {
//            ForEach(BrowserViewMode.allCases) { mode in
//                Image(systemName: mode.image)
//                    .tag(mode)
//            }
//        }
//        .pickerStyle(.segmented)
//        .labelsHidden()
//        .frame(width: 150)
//    }
//}
//
//struct GridColumn: View {
//    let item: ItemParams
//    var selected: Bool = false
//
//    private var icon: String { item.isParent ? "folder.fill" : item.image }
//
//    var body: some View {
//        VStack(spacing: 8) {
//            Image(systemName: icon)
//                .symbolRenderingMode(.hierarchical)
//                .font(.system(size: 58))
//                .foregroundStyle(item.isParent ? .blue : .secondary)
//                .frame(width: 76, height: 64)
//                .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
//                .clipShape(.rect(cornerRadius: 7))
//
//            Text(item.name)
//                .font(.callout)
//                .lineLimit(1)
//                .padding(.horizontal, 5)
//                .padding(.vertical, 1)
//                .background(selected ? Color.accentColor : Color.clear)
//                .foregroundStyle(selected ? .white : .primary)
//                .clipShape(.rect(cornerRadius: 5))
//        }
//        .frame(width: 96, height: 104)
//    }
//}
//
//struct FileListRow: View {
//    let item: ItemParams
//    let depth: Int
//    var expanded: Bool = false
//    var selected: Bool = false
//    var toggle: () -> Void = {}
//
//    private var kind: String {
//        guard let ref = item.ref else { return item.isParent ? "Folder" : "Item" }
//        switch ref.type {
//        case is Space.Type: return "Space"
//        case is Boundary.Type: return "Boundary"
//        case is Sheet.Type: return "Sheet"
//        default: return item.isParent ? "Folder" : "Item"
//        }
//    }
//
//    private var size: String {
//        guard item.isParent else { return "-" }
//        let count = item.count ?? item.items.count
//        return "\(count) items"
//    }
//
//    var body: some View {
//        HStack(spacing: 0) {
//            HStack(spacing: 8) {
//                HStack(spacing: 0) {
//                    Color.clear.frame(width: CGFloat(depth) * 18)
//                    Button(action: toggle) {
//                        Image(systemName: item.isParent ? "chevron.right" : "")
//                            .font(.caption)
//                            .rotationEffect(.degrees(expanded ? 90 : 0))
//                            .foregroundStyle(.secondary)
//                            .frame(width: 16)
//                    }
//                    .buttonStyle(.plain)
//                    .disabled(!item.isParent)
//                }
//
//                Label(item.name, systemImage: item.isParent ? "folder.fill" : item.image)
//                    .symbolRenderingMode(.hierarchical)
//                    .foregroundStyle(.primary, item.isParent ? .blue : .secondary)
//                    .lineLimit(1)
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//
//            Text(kind)
//                .foregroundStyle(.secondary)
//                .frame(width: 140, alignment: .leading)
//
//            Text(item.tags.joined(separator: ", "))
//                .foregroundStyle(.secondary)
//                .frame(width: 210, alignment: .leading)
//
//            Text(size)
//                .foregroundStyle(.secondary)
//                .frame(width: 90, alignment: .trailing)
//        }
//        .font(.callout)
//        .padding(.horizontal, 10)
//        .frame(height: 34)
//        .background(selected ? Color.accentColor.opacity(0.20) : Color.clear)
//        .clipShape(.rect(cornerRadius: 7))
//    }
//}
//
//struct RoundedSpacerRow: View {
//    var body: some View {
//        Color(nsColor: .separatorColor)
//            .opacity(0.12)
//            .frame(height: 34)
//            .clipShape(.rect(cornerRadius: 7))
//            .padding(.vertical, 15)
//    }
//}
//
//struct BrowserPathSegment: View {
//    let ref: Reference
//
//    var body: some View {
//        Label(Runtime.shared.get(ref).name, systemImage: Design.Component.icon(for: ref))
//            .font(.caption)
//            .foregroundStyle(.secondary)
//            .labelStyle(.titleAndIcon)
//    }
//}
//
//struct BrowserPathBar: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 5) {
//                ForEach(Array(agency.session.path.enumerated()), id: \.element.id) { index, ref in
//                    Button { agency.select(ref) } label: {
//                        BrowserPathSegment(ref: ref)
//                    }
//                    .buttonStyle(.plain)
//
//                    if index < agency.session.path.count - 1 {
//                        Image(systemName: "chevron.right")
//                            .font(.caption2)
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//            .padding(.horizontal, 12)
//            .padding(.vertical, 5)
//            .frame(maxWidth: .infinity, alignment: .leading)
//        }
//        .background(.bar)
//    }
//}
//
//struct BrowserList: View {
//    let sections: [ListParams]
//    let model: BrowserContent
//    let closures: Closures
//
//    var body: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 0) {
//                Text("Name")
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                Text("Kind")
//                    .frame(width: 140, alignment: .leading)
//                Text("Tags")
//                    .frame(width: 210, alignment: .leading)
//                Text("Size")
//                    .frame(width: 90, alignment: .trailing)
//            }
//            .font(.caption.weight(.semibold))
//            .foregroundStyle(.secondary)
//            .padding(.horizontal, 18)
//            .padding(.vertical, 8)
//            .background(Color(nsColor: .controlBackgroundColor))
//
//            ScrollView {
//                LazyVStack(spacing: 0) {
//                    ForEach(sections) { section in
//                        BrowserListRows(items: section.items, model: model, closures: closures)
//                    }
//
//                    ForEach(0..<9, id: \.self) { _ in
//                        RoundedSpacerRow()
//                    }
//                }
//                .padding(.horizontal, 12)
//                .padding(.top, 8)
//            }
//        }
//        .background(Color(nsColor: .controlBackgroundColor))
//    }
//}
//
//struct BrowserListRows: View {
//    let items: [ItemParams]
//    let model: BrowserContent
//    let closures: Closures
//    var depth: Int = 0
//
//    var body: some View {
//        ForEach(items) { item in
//            FileListRow(
//                item: item,
//                depth: depth,
//                expanded: model.isExpanded(item.id),
//                selected: closures.selected?(item) ?? false,
//                toggle: { model.setExpanded(item.id) }
//            )
//            .contentShape(Rectangle())
//            .onTapGesture { closures.onSelect?(item) }
//            .onTapGesture(count: 2) { closures.onOpen?(item) }
//
//            if model.isExpanded(item.id) {
//                BrowserListRows(items: item.items, model: model, closures: closures, depth: depth + 1)
//            }
//        }
//    }
//}
//
//struct BrowserGrid: View {
//    let sections: [ListParams]
//    let model: BrowserContent
//    let closures: Closures
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 28) {
//                ForEach(sections) { section in
//                    BrowserGridLevel(items: section.items, model: model, closures: closures)
//                }
//            }
//            .padding(.horizontal, 28)
//            .padding(.vertical, 24)
//            .frame(maxWidth: .infinity, alignment: .topLeading)
//        }
//        .background(Color(nsColor: .controlBackgroundColor))
//    }
//}
//
//struct BrowserGridLevel: View {
//    let items: [ItemParams]
//    let model: BrowserContent
//    let closures: Closures
//    var depth: Int = 0
//
//    private let columns = [
//        GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 26)
//    ]
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 18) {
//            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
//                ForEach(items) { item in
//                    GridColumn(item: item, selected: closures.selected?(item) ?? false)
//                        .onTapGesture { closures.onSelect?(item) }
//                        .onTapGesture(count: 2) { closures.onOpen?(item) }
//                }
//            }
//
//            ForEach(items.filter { model.isExpanded($0.id) && !$0.items.isEmpty }) { item in
//                VStack(alignment: .leading, spacing: 12) {
//                    Label(item.name, systemImage: "folder.fill")
//                        .font(.caption.weight(.semibold))
//                        .foregroundStyle(.secondary)
//                        .padding(.leading, CGFloat(depth + 1) * 18)
//
//                    BrowserGridLevel(items: item.items, model: model, closures: closures, depth: depth + 1)
//                        .padding(.leading, CGFloat(depth + 1) * 18)
//                }
//            }
//        }
//    }
//}
//
//struct Browser: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        @Bindable var console = agency.browser.console
//        @Bindable var inspector = agency.browser.inspector
//
//        VerticalSplit(
//            $console.presented,
//            position: $console.position,
//            collapsedHeight: 30,
//            minTopHeight: 0,
//            minBottomHeight: 0
//        ) {
//            agency.browser.content.build(agency)
//        } bottom: {
//            agency.browser.console.build(agency)
//        }
//        .environment(agency)
//        .ignoresSafeArea(.container, edges: .top)
//        .scrollEdgeEffectStyle(.soft, for: .top)
//        .toolbar(removing: .title)
//        .toolbar { BrowserToolbar() }
//        .inspector(isPresented: $inspector.presented) {
//            inspector.build(agency)
//                .environment(agency)
//                .ignoresSafeArea(.container, edges: .top)
//                .inspectorColumnWidth(min: 200, ideal: 330, max: 440)
//                .toolbar(removing: .sidebarToggle)
//                .toolbar { BrowserInspectorToolbar() }
//        }
//    }
//}
