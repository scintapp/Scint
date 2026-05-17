import AgencyRuntime
import SwiftUI
import Foundation

#if false
struct PanelRow: View {
    let name: String
    let image: String
    let description: String?
    let isSelected: Bool
    let onTap: () -> Void

    init(name: String, image: String, description: String? = nil, isSelected: Bool, onTap: @escaping () -> Void) {
        self.name = name
        self.image = image
        self.description = description
        self.isSelected = isSelected
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 26, height: 26)
                    .background(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .lineLimit(1)

                    if let description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .clipShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

struct SearchPanel: View {
    @Environment(AgencyModel.self) private var agency
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: agency.search.scope.image)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                TextField(
                    agency.search.scope.label,
                    text: Binding(
                        get: { agency.search.query },
                        set: { agency.search.query = $0 }
                    )
                )
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($focused)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Picker(
                "Scope",
                selection: Binding(
                    get: { agency.search.scope },
                    set: { agency.search.scope = $0 }
                )
            ) {
                ForEach(Search.Scope.allCases) { scope in
                    Label(scope.label, systemImage: scope.image).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)

            ContentUnavailableView("Search panel scaffold", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { focused = true }
    }
}

struct PanelInput: View {
    var query: String
    let image: String
    let placeholder: String
    let focused: FocusState<Bool>.Binding

    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: image)
                .foregroundStyle(.secondary.opacity(0.8))
                .font(.system(size: 24))

            TextField(placeholder, text: query)
                .foregroundStyle(.primary)
                .font(.system(size: 26))
                .textFieldStyle(.plain)
                .focused(focused)
                .onKeyPress(.upArrow)   { onUpArrow() }
                .onKeyPress(.downArrow) { onDownArrow() }
                .onKeyPress(.return)    { onReturn() }
                .onKeyPress(.tab)       { onTab() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct PanelRow: View {
    let name: String
    let image: String
    let description: String?
    let isSelected: Bool
    let onTap: () -> Void

    init(name: String,
         image: String,
         description: String? = nil,
         isSelected: Bool,
         onTap: @escaping () -> Void) {
        self.name = name
        self.image = image
        self.description = description
        self.isSelected = isSelected
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 30, height: 30)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                    Image(systemName: image)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16.5))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                        .lineLimit(1)

                    if let description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Text("↩")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .animation(.easeOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct PanelDetails: View {
    let details: SearchDetails

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary.opacity(0.85))
                .textSelection(.enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: Design.Component.icon(for: details.result.ref))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(details.result.name)
                        .font(.system(size: 17))
                        .lineLimit(1)
                }

                Spacer()
            }
            .frame(height: 80)
            .padding(.horizontal, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !details.result.description.isEmpty {
                        block("Description", details.result.description)
                    }

                    block("Specs", details.specs.stringRepresentation)

                    if !details.related.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Related")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)

                            ForEach(details.related) { relation in
                                HStack(spacing: 10) {
                                    Text(relation.role)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 86, alignment: .leading)

                                    Text(relation.name)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

}

struct SearchPanel: View {
    @Environment(AgencyModel.self) var agency

    var search: SearchModel { agency.search }
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelInput(
                query: agency.search.query,
                image: agency.search.scope.image,
                placeholder: agency.search.scope.label,
                focused: $focused,
                onUpArrow: { move(-1); return .handled },
                onDownArrow: { move(+1); return .handled },
                onReturn: { activate(); return .handled },
                onTab: { showDetails(); return .handled }
            )

            PanelContent(
                index: agency.search.index,
                onTap: { _ in activate() }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .onChange(of: agency.search.query) { _, _ in agency.search.index = 0 }
        .onChange(of: agency.search.scope) { _, _ in agency.search.reset(); focused = true }
        .background(modalitySwitchers)
    }

    private var modalitySwitchers: some View {
        ZStack {
            Button { agency.search.scope = .activity } label: { EmptyView() }
                .keyboardShortcut("1", modifiers: .command)
            Button { agency.search.scope = .files } label: { EmptyView() }
                .keyboardShortcut("2", modifiers: .command)
            Button { agency.search.scope = .controls } label: { EmptyView() }
                .keyboardShortcut("3", modifiers: .command)
            Button { agency.search.scope = .spaces } label: { EmptyView() }
                .keyboardShortcut("4", modifiers: .command)
            Button { agency.search.scope = .search } label: { EmptyView() }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func move(_ delta: Int) {
        let count = flatItems.count
        guard count > 0 else { return }
        agency.index = (agency.index + delta + count) % count
    }

    private func activate() {
        guard flatItems.indices.contains(agency.index) else { return }
        let item = flatItems[agency.index]
        agency.closures(agency).onSelect?(item)
        dismiss()
    }

    private func showDetails() {
        guard flatItems.indices.contains(agency.index) else { return }
        guard let ref = flatItems[agency.index].ref else { return }
        agency.details = Runtime.shared.searchDetails(for: ref)
    }

    private func closeDetails() {
        agency.details = nil
        focused = true
    }

    private func dismiss() {
        agency.reset()
        agency.panels["search"]?.hide()
    }
}

@MainActor public enum PanelConstructor {
    @ViewBuilder static func build(_ agency: SearchModel, _ params: Params, _ controls: Controls) -> some View {
        VStack(alignment: .leading, spacing: 0)  {
            PanelInput(
                query: agency.query,
                image: agency.scope.image,
                placeholder: agency.scope.label
            )

            ScrollView {
                PanelContent(
                    index: agency.index,
                    params: params
                )


                ForEach(params.sections) { section in
                    build(
                        section,
                        agency: agency,
                        params: params,
                        controls: controls
                    )
                }.padding(.bottom, 16)

                if let onAddSection = controls.onAddSection {
                    SectionAddItemRow() { name in onAddSection(name) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    @ViewBuilder static func build(_ params: ControlsParams, _ controls: Controls) -> some View {
        ZStack(alignment: .bottom) { }
    }

    @ViewBuilder static func build<M: Frame>(_ section: ListParams, agency: M, params: Params, controls: Controls) -> some View {
        switch section.layout {
        case .group: buildGroup(section, agency: agency, controls: controls)
        case .block: buildBlock(section)
        case .grid: buildGrid(section, agency: agency, params: params, controls: controls)
        case .list, .column: buildList(section, agency: agency, params: params, controls: controls)
        }
    }

    @ViewBuilder static func build<M: Frame>(_ item: ItemParams, agency: M, sectionId: AnyHashable,
                                                 nesting: Params.Nesting, depth: Int, controls: Controls) -> some View {

        let indent = CGFloat(depth) * 16

        let canExpand: Bool = {
            switch nesting {
            case .recursive: return true
            case .single: return depth == 0
            case .flat: return false
            }
        }()

        if item.isParent && canExpand {
            let sectionView = AnyView(
                SectionLayout(
                    name: item.name,
                    image: item.image,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    indent: indent,
                    isExpanded: agency.isExpanded(item.id),
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) },
                    onToggleExpanded: { agency.setExpanded(item.id) }
                ) {
                    ForEach(item.items) { child in
                        build(child, agency: agency, sectionId: sectionId, nesting: nesting, depth: depth + 1, controls: controls)
                    }
                }
            )

            let wrapped = controls.wrapSection?(sectionView, item, depth) ?? sectionView
            let decorated = transfer(wrapped, item: item, controls: controls)

            menu(decorated, item: item, controls: controls)
        } else {
            let linkView = AnyView(
                SectionLink(
                    name: item.name,
                    image: item.image,
                    trailingImage: item.trailingImage,
                    count: item.count,
                    indent: indent,
                    selected: controls.selected?(item) ?? false,
                    onSelect: { controls.onSelect?(item) }
                )
            )

            let wrapped = controls.wrapLink?(linkView, item, depth) ?? linkView
            let decorated = transfer(wrapped, item: item, controls: controls)
            menu(decorated, item: item, controls: controls)
        }
    }

    @ViewBuilder static func build<M: Frame>(_ section: ListParams, agency: M, controls: Controls) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func buildGrid<M: Frame>(_ section: ListParams, agency: M, params: Params, controls: Controls) -> some View {
        VStack(spacing: 0) {
            if section.header { SectionHeader(name: section.name) }
            let item = GridItem(.adaptive(minimum: 160, maximum: 160), spacing: 16, alignment: .topLeading)

            LazyVGrid(columns: [item], alignment: .leading, spacing: 16) {
                ForEach(section.items) { item in
                    let view = AnyView(ItemCard(item: item, settings: controls))
                    let decorated = transfer(view, item: item, controls: controls)
                    menu(decorated, item: item, controls: controls)
                }
            }
        }
    }

    @ViewBuilder static func buildGroup<M: Frame>(_ section: ListParams, agency: M, controls: Controls) -> some View {
        GroupLayout(title: section.name, footnote: section.footnote ?? "") {
            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { GroupDivider() }
                groupRow(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func groupRow(_ item: ItemParams, controls: Controls) -> some View {
        if item.ref != nil || item.entryId != nil {
            Button { controls.onSelect?(item) } label: {
                GroupRow(label: item.name) {
                    Image(systemName: item.image)
                } trailing: {
                    groupRowAccessory(item, controls: controls)
                }
            }
            .buttonStyle(.plain)
        } else {
            GroupRow(label: item.name) {
                Image(systemName: item.image)
            } trailing: {
                groupRowAccessory(item, controls: controls)
            }
        }
    }

    @ViewBuilder static func groupRowAccessory(_ item: ItemParams, controls: Controls) -> some View {
        switch item.trailingKind {
        case .toggle: GroupToggle(isOn: false) { }
        case .load: GroupCountButton(count: item.count) { }
        case .value:
            Text(item.description ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        default: EmptyView()
        }
    }

    @ViewBuilder static func buildList<M: Frame>(_ section: ListParams, agency: M, params: Params, controls: Controls) -> some View {
        VStack(spacing: 0) {
            if section.header {
                let header = AnyView(SectionHeader(
                    name: section.name,
                    onAdd: controls.canAddInline(sectionId: String(describing: section.id)) ? {
                        controls.onAddItem?(AnyHashable(section.id), "")
                    } : nil
                ))

                if let wrapHeader = controls.wrapHeader { wrapHeader(header, section) }
                else { header }
            }

            ForEach(section.items) { item in
                build(item, agency: agency, sectionId: section.id, nesting: params.nesting, depth: 0, controls: controls)
            }

            if controls.canAddInline(sectionId: section.id) {
                SectionAddItemRow(placeholder: "New Item") { name in
                    controls.onAddItem?(AnyHashable(section.id), name)
                }
            }
        }
    }

    @ViewBuilder static func buildBlock(_ section: ListParams) -> some View {
        Block(
            title: section.name,
            text: section.body ?? "",
            footnote: section.footnote ?? "",
        )
    }

    @ViewBuilder static func menu(_ view: AnyView, item: ItemParams, controls: Controls) -> some View {
        if controls.isEditable && controls.canEdit(item) {
            view.contextMenu {
                ItemContextMenu(
                    item: item,
                    onRename: controls.canRename(item) ? { controls.onRename?(item.id, item.name) } : nil,
                    onDuplicate: controls.canDuplicate(item) ? { controls.onDuplicate?(item.id) } : nil,
                    onDelete: controls.canDelete(item) ? { controls.onDelete?(item.id) } : nil,
                    onAddChild: controls.canAddChild(for: item) ? { controls.onAddItem?(item.id, "") } : nil
                )
            }
        }
        else { view }
    }

    static func transfer(_ view: AnyView, item: ItemParams, controls: Controls) -> AnyView {
        let canDrag = controls.canDrag?(item) ?? (item.ref != nil)
        let withDrag: AnyView

        if false, canDrag, let _ = item.ref { withDrag = view }
        else { withDrag = view }

        let types = controls.dropTypes?(item) ?? []
        guard !types.isEmpty, controls.onDrop != nil else { return withDrag }

        return AnyView(
            withDrag.onDrop(of: types, isTargeted: nil) { providers in
                controls.onDrop?(providers, item) ?? false
            }
        )
    }
}
#endif


//import AgencyRuntime
//import SwiftUI

//struct PanelRow: View {
//    let hit: SearchResult
//    let isSelected: Bool
//
//    var body: some View {
//        HStack(spacing: 12) {
//            ZStack {
//                RoundedRectangle(cornerRadius: 10, style: .continuous)
//                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
//                    .frame(width: 30, height: 30)
//                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
//                Image(systemName: icon)
//                    .font(.system(size: 15, weight: .medium))
//                    .foregroundStyle(isSelected ? .white : .primary)
//            }
//
//            Text(hit.name)
//                .font(.system(size: 16.5))
//                .foregroundStyle(isSelected ? Color.primary.opacity(1) : .primary.opacity(0.85))
//                .lineLimit(1)
//
//            Spacer()
//
//            if isSelected {
//                Text("↩")
//                    .font(.system(size: 13))
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 12)
//        .background(
//            RoundedRectangle(cornerRadius: 18, style: .continuous)
//                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
//        )
//        .animation(.easeOut(duration: 0.1), value: isSelected)
//    }
//
//    private var icon: String {
//        switch hit.category.rawValue {
//        case "service": return "app.connected.to.app.below.fill"
//        case "control": return "terminal"
//        case "artifact": return "archivebox"
//        case "space": return "cube.transparent.fill"
//        case "boundary": return "square.split.bottomrightquarter"
//        case "sheet": return "text.alignleft"
//        case "thread": return "bubble.left.and.text.bubble.right"
//        case "edge": return "point.3.connected.trianglepath.dotted"
//        default: return "square.stack.3d.up"
//        }
//    }
//}
//
//struct PanelDetailsView: View {
//    let details: SearchDetails
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack(alignment: .center, spacing: 10) {
//                Image(systemName: icon)
//                    .font(.system(size: 17, weight: .medium))
//                    .foregroundStyle(.secondary)
//
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(details.result.name)
//                        .font(.system(size: 17))
//                        .lineLimit(1)
//
//                    Text(details.result.category.rawValue)
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(.secondary)
//                }
//
//                Spacer()
//
//                Text("Tab")
//                    .font(.system(size: 12))
//                    .foregroundStyle(.secondary)
//            }
//            .frame(height: 80)
//            .padding(.horizontal, 18)
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 12) {
//                    if !details.result.description.isEmpty {
//                        detailBlock("Description", details.result.description)
//                    }
//
//                    detailBlock("Specs", details.specs.stringRepresentation)
//
//                    if !details.related.isEmpty {
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text("Related")
//                                .font(.system(size: 11, weight: .semibold))
//                                .foregroundStyle(.secondary)
//
//                            ForEach(details.related) { relation in
//                                HStack(spacing: 10) {
//                                    Text(relation.role)
//                                        .font(.system(size: 10, weight: .medium))
//                                        .foregroundStyle(.secondary)
//                                        .frame(width: 86, alignment: .leading)
//
//                                    Text(relation.name)
//                                        .font(.system(size: 12.5))
//                                        .foregroundStyle(.primary.opacity(0.85))
//                                        .lineLimit(1)
//
//                                    Spacer()
//                                }
//                                .padding(.vertical, 3)
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.bottom, 16)
//            }
//        }
//    }
//
//    func detailBlock(_ title: String, _ text: String) -> some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text(title)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//
//            Text(text)
//                .font(.system(size: 12.5))
//                .foregroundStyle(.primary.opacity(0.85))
//                .textSelection(.enabled)
//        }
//    }
//
//    private var icon: String {
//        switch details.result.category.rawValue {
//        case "service": return "app.connected.to.app.below.fill"
//        case "control": return "terminal"
//        case "artifact": return "archivebox"
//        case "space": return "cube.transparent.fill"
//        case "boundary": return "square.split.bottomrightquarter"
//        case "sheet": return "text.alignleft"
//        case "thread": return "bubble.left.and.text.bubble.right"
//        case "edge": return "point.3.connected.trianglepath.dotted"
//        default: return "square.stack.3d.up"
//        }
//    }
//}
//
//struct SearchPanel: View {
//    @Environment(AgencyModel.self) var agency
//    @FocusState private var isInputFocused: Bool
//    @FocusState private var isDetailsFocused: Bool
//    @State private var query: String = ""
//    @State private var index: Int = 0
//    @State private var details: SearchDetails?
//
//    var onSelect: (SearchResult) -> Void = { _ in }
//    private var hits: [SearchResult] { Runtime.shared.search(query, limit: .max).all }
//
//    private var input: Binding<String> {
//        Binding { query } set: { value in
//            query = value
//            index = 0
//            details = nil
//        }
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            if let details {
//                PanelDetailsView(details: details)
//                    .focusable()
//                    .focused($isDetailsFocused)
//                    .onAppear { isDetailsFocused = true }
//                    .onKeyPress(.tab) { closeDetails(); return .handled }
//            } else {
//            HStack(alignment: .center, spacing: 16) {
//                Image(systemName: "magnifyingglass")
//                    .foregroundStyle(.secondary.opacity(0.8))
//                    .font(.system(size: 24))
//
//                TextField("Search", text: input)
//                    .foregroundStyle(.secondary)
//                    .font(.system(size: 26))
//                    .textFieldStyle(.plain)
//                    .focused($isInputFocused)
//                    .onKeyPress(.upArrow) { move(-1); return .handled }
//                    .onKeyPress(.downArrow) { move(+1); return .handled }
//                    .onKeyPress(.return) { confirm(); return .handled }
//                    .onKeyPress(.tab) { showDetails(); return .handled }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 14)
//
//            ScrollViewReader { proxy in
//                ScrollView {
//                    LazyVStack(spacing: 2) {
//                        if hits.isEmpty {
//                            EmptyView()
//                        } else {
//                            ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
//                                PanelRow(hit: hit, isSelected: index == index)
//                                    .id(hit.id)
//                                    .onTapGesture { choose(hit) }
//                                    .padding(.horizontal, 8)
//                            }
//                        }
//                    }
//                    .id(query)
//                    .onChange(of: index) {
//                        guard hits.indices.contains(index) else { return }
//                        proxy.scrollTo(hits[index].id)
//                    }
//                }
//            }
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .onAppear {
//            isInputFocused = true
//            index = 0
//        }
//        .onChange(of: query) { _, _ in index = 0 }
//        .onReceive(NotificationCenter.default.publisher(for: .agencyPanelEscape)) { notification in
//            guard let event = notification.object as? PanelEscapeEvent else { return }
//            event.handled = true
//            if details != nil {
//                closeDetails()
//            } else {
//                agency.panels["search"]?.hide()
//            }
//        }
//    }
//
//    private func move(_ delta: Int) {
//        guard !hits.isEmpty else { return }
//        index = (index + delta + hits.count) % hits.count
//    }
//
//    private func confirm() {
//        guard hits.indices.contains(index) else { return }
//        choose(hits[index])
//    }
//
//    private func showDetails() {
//        guard hits.indices.contains(index) else { return }
//        details = Runtime.shared.searchDetails(for: hits[index].ref)
//    }
//
//    private func closeDetails() {
//        details = nil
//        isDetailsFocused = false
//        isInputFocused = true
//    }
//
//    private func choose(_ hit: SearchResult) {
//        onSelect(hit)
//        select(hit)
//        query = ""
//        index = 0
//        details = nil
//    }
//
//    private func select(_ hit: SearchResult) {
//        if hit.ref.type is Sheet.Type { agency.open(hit.ref) }
//        else { agency.select(hit.ref) }
//    }
//}
//
//struct SearchInput: View {
//    @Binding var query: String
//    let image: String
//    let placeholder: String
//    let focused: FocusState<Bool>.Binding
//
//    var onUpArrow: () -> KeyPress.Result = { .ignored }
//    var onDownArrow: () -> KeyPress.Result = { .ignored }
//    var onReturn: () -> KeyPress.Result = { .ignored }
//    var onTab: () -> KeyPress.Result = { .ignored }
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 16) {
//            Image(systemName: image)
//                .foregroundStyle(.secondary.opacity(0.8))
//                .font(.system(size: 24))
//
//            TextField(placeholder, text: $query)
//                .foregroundStyle(.primary)
//                .font(.system(size: 26))
//                .textFieldStyle(.plain)
//                .focused(focused)
//                .onKeyPress(.upArrow)   { onUpArrow() }
//                .onKeyPress(.downArrow) { onDownArrow() }
//                .onKeyPress(.return)    { onReturn() }
//                .onKeyPress(.tab)       { onTab() }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 14)
//    }
//}
//
//struct SearchRow: View {
//    let item: ItemParams
//    let isSelected: Bool
//    let onTap: () -> Void
//
//    var body: some View {
//        HStack(spacing: 12) {
//            ZStack {
//                RoundedRectangle(cornerRadius: 10, style: .continuous)
//                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
//                    .frame(width: 30, height: 30)
//                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
//                Image(systemName: item.image.isEmpty ? "square.stack.3d.up" : item.image)
//                    .font(.system(size: 15, weight: .medium))
//                    .foregroundStyle(isSelected ? .white : .primary)
//            }
//
//            VStack(alignment: .leading, spacing: 2) {
//                Text(item.name)
//                    .font(.system(size: 16.5))
//                    .foregroundStyle(isSelected ? Color.primary.opacity(1) : .primary.opacity(0.85))
//                    .lineLimit(1)
//
//                if let description = item.description, !description.isEmpty {
//                    Text(description)
//                        .font(.system(size: 12))
//                        .foregroundStyle(.secondary)
//                        .lineLimit(1)
//                }
//            }
//
//            Spacer()
//
//            if isSelected {
//                Image(systemName: "return")
//                    .font(.system(size: 12))
//                    .foregroundStyle(.secondary)
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 10)
//        .contentShape(Rectangle())
//        .onTapGesture(perform: onTap)
//        .animation(.easeOut(duration: 0.1), value: isSelected)
//        .background(
//            RoundedRectangle(cornerRadius: 18, style: .continuous)
//                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
//        )
//    }
//}
//
//struct SearchContent: View {
//    @Binding var index: Int
//    let params: Params
//    let onTap: (ItemParams) -> Void
//    var flatItems: [ItemParams] { params.sections.flatMap { $0.items } }
//    var isEmpty: Bool { flatItems.isEmpty }
//
//    var body: some View {
//        ScrollViewReader { proxy in
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 2) { if isEmpty { empty } else { content } }
//                    .padding(.horizontal, 8)
//                    .onChange(of: index) {
//                        guard flatItems.indices.contains(index) else { return }
//                        proxy.scrollTo(flatItems[index].id, anchor: .center)
//                    }
//            }
//        }
//    }
//
//    var content: some View {
//        ForEach(params.sections) { section in sectionView(section, startIndex: runningIndexBefore(section)) }
//            .id(params.sections.map(\.id))
//    }
//
//    func runningIndexBefore(_ section: ListParams) -> Int {
//        var count = 0
//        for s in params.sections {
//            if s.id == section.id { return count }
//            count += s.items.count
//        }
//        return count
//    }
//
//    @ViewBuilder
//    func sectionView(_ section: ListParams, startIndex: Int) -> some View {
//        if section.header && !section.name.isEmpty {
//            Text(section.name)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//                .padding(.horizontal, 8)
//                .padding(.top, 12)
//                .padding(.bottom, 6)
//        }
//
//        ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, item in
//            let absolute = startIndex + offset
//            SearchRow(
//                item: item,
//                isSelected: absolute == index,
//                onTap: {
//                    index = absolute
//                    onTap(item)
//                }
//            )
//            .id(item.id)
//        }
//    }
//
//    var empty: some View {
//        VStack {
//            Text("No results")
//                .font(.system(size: 13))
//                .foregroundStyle(.secondary)
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 32)
//    }
//}
//
//struct SearchDetails: View {
//    let details: ResultDetails
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack(alignment: .center, spacing: 10) {
//                Image(systemName: Design.Component.icon(for: details.result.ref))
//                    .font(.system(size: 17, weight: .medium))
//                    .foregroundStyle(.secondary)
//
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(details.result.name)
//                        .font(.system(size: 17))
//                        .lineLimit(1)
//
//                    Text(typeName(for: details.result.ref))
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(.secondary)
//                }
//
//                Spacer()
//
//                Text("Tab")
//                    .font(.system(size: 12))
//                    .foregroundStyle(.secondary)
//            }
//            .frame(height: 80)
//            .padding(.horizontal, 18)
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 12) {
//                    if !details.result.description.isEmpty {
//                        block("Description", details.result.description)
//                    }
//
//                    block("Specs", details.specs.stringRepresentation)
//
//                    if !details.related.isEmpty {
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text("Related")
//                                .font(.system(size: 11, weight: .semibold))
//                                .foregroundStyle(.secondary)
//
//                            ForEach(details.related) { relation in
//                                HStack(spacing: 10) {
//                                    Text(relation.role)
//                                        .font(.system(size: 10, weight: .medium))
//                                        .foregroundStyle(.secondary)
//                                        .frame(width: 86, alignment: .leading)
//
//                                    Text(relation.name)
//                                        .font(.system(size: 12.5))
//                                        .foregroundStyle(.primary.opacity(0.85))
//                                        .lineLimit(1)
//                                    Spacer()
//                                }
//                                .padding(.vertical, 3)
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.bottom, 16)
//            }
//        }
//    }
//
//    func block(_ title: String, _ text: String) -> some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text(title)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//
//            Text(text)
//                .font(.system(size: 12.5))
//                .foregroundStyle(.primary.opacity(0.85))
//                .textSelection(.enabled)
//        }
//    }
//
//    func typeName(for ref: Reference) -> String {
//        ref.type.map { String(describing: $0) } ?? "Unknown"
//    }
//}
//
//@Observable @MainActor final class SearchModel {
//    var presented: Bool = true
//    var position: CGFloat = 0
//    var expanded: Set<AnyHashable> = []
//
//    var active: Scope = .all
//    var query: String = ""
//
//    enum Scope: String, CaseIterable, Identifiable {
//        case all, space, sheets, artifacts, services
//
//        var id: String { rawValue }
//
//        var label: String {
//            switch self {
//            case .all: "All"
//            case .space: "Space"
//            case .sheets: "Sheets"
//            case .artifacts: "Artifacts"
//            case .services: "Services"
//            }
//        }
//
//        var image: String {
//            switch self {
//            case .all: "magnifyingglass"
//            case .space: "cube.transparent"
//            case .sheets: "text.alignleft"
//            case .artifacts: "archivebox"
//            case .services: "arrow.2.squarepath"
//            }
//        }
//    }
//
//    func params(_ agency: AgencyModel) -> Params {
//        switch active {
//        case .all: return LibraryObjectMap.params(agency)
//        case .space: return SpaceObjectMap.params(agency)
//        case .sheets:  return SheetObjectMap.params(agency)
//        case .artifacts: return ArtifactsObjectMap.params(agency)
//        case .services: return InterfacesObjectMap.params(agency)
//        }
//    }
//
//    func closures(_ agency: AgencyModel) -> Controls {
//        Controls(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                return agency.session.selected(ref, item.path)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, url: item.path)
//            }
//        )
//    }
//}
//
//@Observable final class Search: Frame {
//    var presented: Bool = true
//    var position: CGFloat = 0
//    var expanded: Set<AnyHashable> = []
//
//    var active: Scope = .all
//    var query: String = ""
//
//    enum Scope: String, CaseIterable, Identifiable {
//        case all, space, sheets, artifacts, services
//
//        var id: String { rawValue }
//
//        var label: String {
//            switch self {
//            case .all: "All"
//            case .space: "Space"
//            case .sheets: "Sheets"
//            case .artifacts: "Artifacts"
//            case .services: "Services"
//            }
//        }
//
//        var image: String {
//            switch self {
//            case .all: "magnifyingglass"
//            case .space: "cube.transparent"
//            case .sheets: "text.alignleft"
//            case .artifacts: "archivebox"
//            case .services: "arrow.2.squarepath"
//            }
//        }
//    }
//
//
//
//    static func params(_ agency: AgencyModel) -> Params {
//        SearchMapper.params(agency)
//    }
//
//    func closures(_ agency: AgencyModel) -> Controls {
//        Controls(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                return agency.session.selected(ref, item.path)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, url: item.path)
//            }
//        )
//    }
//
//    func build(_ agency: AgencyModel) -> some View {
//        Constructor.build(self, Self.params(agency), closures(agency))
//    }
//}
//
//
//
//
//import SwiftUI
//import AgencyRuntime
//
//
//struct SearchPanel: View {
//    @Environment(AgencyModel.self) var agency
//    @Bindable var model = PanelModel()
//    @FocusState private var focused: Bool
//
//    private var params: Params {
//        model.params(agency)
//    }
//
//    private var flatItems: [ItemParams] {
//        params.sections.flatMap { $0.items }
//    }
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            if let details = model.details {
//                SearchDetailsView(details: details)
//                    .onKeyPress(.tab) { closeDetails(); return .handled }
//            } else {
//                PanelInput(
//                    query: $model.query,
//                    image: model.active.image,
//                    placeholder: model.active.placeholder,
//                    focused: $focused,
//                    onUpArrow: { move(-1); return .handled },
//                    onDownArrow: { move(+1); return .handled },
//                    onReturn: { activate(); return .handled },
//                    onTab: { showDetails(); return .handled }
//                )
//
//                PanelContent(
//                    params: params,
//                    selectedIndex: $model.index,
//                    onTap: { _ in activate() }
//                )
//            }
//        }
//        .frame(maxWidth: .infinity)
//        .onAppear { focused = true }
//        .onChange(of: model.query) { _, _ in model.index = 0 }
//        .onChange(of: model.active) { _, _ in model.reset(); focused = true }
//        .background(modalitySwitchers)
//    }
//
//    private var modalitySwitchers: some View {
//        ZStack {
//            Button { model.active = .space } label: { EmptyView() }
//                .keyboardShortcut("1", modifiers: .command)
//            Button { model.active = .sheets } label: { EmptyView() }
//                .keyboardShortcut("2", modifiers: .command)
//            Button { model.active = .interfaces } label: { EmptyView() }
//                .keyboardShortcut("3", modifiers: .command)
//            Button { model.active = .processes } label: { EmptyView() }
//                .keyboardShortcut("4", modifiers: .command)
//            Button { model.active = .all } label: { EmptyView() }
//                .keyboardShortcut("0", modifiers: .command)
//        }
//        .frame(width: 0, height: 0)
//        .opacity(0)
//    }
//
//    private func move(_ delta: Int) {
//        let count = flatItems.count
//        guard count > 0 else { return }
//        model.index = (model.index + delta + count) % count
//    }
//
//    private func activate() {
//        guard flatItems.indices.contains(model.index) else { return }
//        let item = flatItems[model.index]
//        model.closures(agency).onSelect?(item)
//        dismiss()
//    }
//
//    private func showDetails() {
//        guard flatItems.indices.contains(model.index) else { return }
//        guard let ref = flatItems[model.index].ref else { return }
//        model.details = Runtime.shared.searchDetails(for: ref)
//    }
//
//    private func closeDetails() {
//        model.details = nil
//        focused = true
//    }
//
//    private func dismiss() {
//        model.reset()
//        agency.panels["search"]?.hide()
//    }
//}
//
//private struct SearchDetailsView: View {
//    let details: AgencyRuntime.SearchDetails
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 0) {
//            HStack(alignment: .center, spacing: 10) {
//                Image(systemName: Design.Component.icon(for: details.result.ref))
//                    .font(.system(size: 17, weight: .medium))
//                    .foregroundStyle(.secondary)
//
//                VStack(alignment: .leading, spacing: 2) {
//                    Text(details.result.name)
//                        .font(.system(size: 17))
//                        .lineLimit(1)
//
//                    Text(typeName(for: details.result.ref))
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(.secondary)
//                }
//
//                Spacer()
//
//                Text("Tab")
//                    .font(.system(size: 12))
//                    .foregroundStyle(.secondary)
//            }
//            .frame(height: 80)
//            .padding(.horizontal, 18)
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: 12) {
//                    if !details.result.description.isEmpty {
//                        block("Description", details.result.description)
//                    }
//
//                    block("Specs", details.specs.stringRepresentation)
//
//                    if !details.related.isEmpty {
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text("Related")
//                                .font(.system(size: 11, weight: .semibold))
//                                .foregroundStyle(.secondary)
//
//                            ForEach(details.related) { relation in
//                                HStack(spacing: 10) {
//                                    Text(relation.role)
//                                        .font(.system(size: 10, weight: .medium))
//                                        .foregroundStyle(.secondary)
//                                        .frame(width: 86, alignment: .leading)
//
//                                    Text(relation.name)
//                                        .font(.system(size: 12.5))
//                                        .foregroundStyle(.primary.opacity(0.85))
//                                        .lineLimit(1)
//
//                                    Spacer()
//                                }
//                                .padding(.vertical, 3)
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 16)
//                .padding(.bottom, 16)
//            }
//        }
//    }
//
//    private func block(_ title: String, _ text: String) -> some View {
//        VStack(alignment: .leading, spacing: 6) {
//            Text(title)
//                .font(.system(size: 11, weight: .semibold))
//                .foregroundStyle(.secondary)
//
//            Text(text)
//                .font(.system(size: 12.5))
//                .foregroundStyle(.primary.opacity(0.85))
//                .textSelection(.enabled)
//        }
//    }
//
//    private func typeName(for ref: Reference) -> String {
//        ref.type.map { String(describing: $0) } ?? "Unknown"
//    }
//}
