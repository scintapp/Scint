import AgencyRuntime
import SwiftUI
import Foundation


@Observable final class Search {
    var scope: Scope = .search
    var position: CGFloat = 0
    var presented: Bool = true
    var expanded: Set<AnyHashable> = []

    var index: Int = 0
    var query: String = ""
    var details: AgencyRuntime.SearchDetails?

    enum Scope: String, CaseIterable, Identifiable {
        case search, files, activity, controls, spaces

        var id: String { rawValue }

        var label: String {
            switch self {
            case .search: "Search"
            case .files: "Files"
            case .activity: "Activity"
            case .controls: "Controls"
            case .spaces: "Spaces"

            }
        }

        var image: String {
            switch self {
            case .search: "magnifyingglass"
            case .files: "folder"
            case .activity: "Activity"
            case .controls: "switch.2"
            case .spaces: "app"
            }
        }
    }

//    private func params(_ agency: AgencyModel) -> Params {
//        switch scope {
//        case .search: SearchMapper.params(agency)
//        case .files: ArtifactsMapper.params(agency)
//        case .activity: ActivityMapper.params(agency)
//        case .controls: InterfaceMapper.params(agency)
//        case .spaces: SpacesMapper.params(agency)
//        }
//    }

//    private func closures(_ agency: AgencyModel) -> Controls {
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

    func reset() {
        query = ""
        index = 0
        details = nil
        expanded.removeAll()
    }
}


//@Observable final class Search: Frame {
//    var active: Scope = .all
//    var presented: Bool = true
//    var position: CGFloat = 0
//    var expanded: Set<AnyHashable> = []
//    var query: String = ""
//    var index: Int = 0
//    var details: AgencyRuntime.SearchDetails?
//
//    enum Scope: String, CaseIterable, Identifiable {
//        case all, space, sheets, interfaces, processes
//
//        var id: String { rawValue }
//
//        var label: String {
//            switch self {
//            case .all: "All"
//            case .space: "Space"
//            case .sheets: "Sheets"
//            case .interfaces: "Interfaces"
//            case .processes: "Processes"
//            }
//        }
//
//        var image: String {
//            switch self {
//            case .all: "magnifyingglass"
//            case .space: "cube.transparent"
//            case .sheets: "text.alignleft"
//            case .interfaces: "switch.2"
//            case .processes: "arrow.2.squarepath"
//            }
//        }
//
//        var placeholder: String {
//            switch self {
//            case .all: "Search"
//            default: label
//            }
//        }
//    }
//
//    static func params(_ agency: AgencyModel) -> Params {
//        SearchMapper.params(agency)
//    }
//
//    static func closures(_ agency: AgencyModel) -> Controls {
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
//    func reset() {
//        query = ""
//        index = 0
//        details = nil
//        expanded.removeAll()
//    }
//}

//struct PanelDetails: View {
//    let details: SearchDetails
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
//                PanelDetails(details: details)
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
