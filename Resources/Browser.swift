
import SwiftUI

import SwiftUI
import AgencyRuntime


struct AgencyBrowser: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
//        @Bindable var navigator = agency.studio.navigator
//        @Bindable var browser = agency.studiobrowser
//        @Bindable var preview = agency.studiobrowser.preview

        NavigationSplitView {
//            navigator.build(agency)
//                .environment(agency)
//                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 330)
//                .toolbar(removing: .sidebarToggle)

        } detail: {
//            browser.build(agency)
//                .environment(agency)
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .scrollRouteEffectStyle(.soft, for: .top)
//                .toolbar(removing: .title)
//                .toolbar { BrowserToolbar() }
        }
//        .inspector(isPresented: $preview.presented) {
//            preview.build(agency)
//                .environment(agency)
//                .inspectorColumnWidth(min: 200, ideal: 330, max: 440)
//                .toolbar(removing: .sidebarToggle)
//                .toolbar { PreviewToolbar() }
//        }
    }
}



//@Observable final class Bounded: Frame {
//    var mode: Mode = .grid
//    var position: CGFloat = 0
//    var presented: Bool = false
//    var expanded: Set<AnyHashable> = []
//
//    enum Mode: String, CaseIterable {
//        case grid, list, table
//
//        var image: String {
//            switch self {
//            case .grid: "app"
//            case .list: "square.and.pencil"
//            case .table: ""
//            }
//        }
//
//        @MainActor func closures(_ agency: AgencyModel) -> Controls {
//            switch self {
//            case .grid: return BoundaryMapper.closures(agency)
//            case .list: return BoundaryMapper.closures(agency)
//            case .table: return BoundaryMapper.closures(agency)
//            }
//        }
//
//        @MainActor func params(_ agency: AgencyModel) -> Params {
//            switch self {
//            case .grid: return BoundaryMapper.params(agency)
//            case .list: return BoundaryMapper.params(agency)
//            case .table: return BoundaryMapper.params(agency)
//            }
//        }
//    }
//}

//@Observable @MainActor final class ContentModel: Frame {
//    var mode: Mode = .boundary
//    var position: CGFloat = 330
//    var presented: Bool = false
//    var expanded: Set<AnyHashable> = []
//
//    enum Mode: String, CaseIterable {
//        case boundary, editor
//        @MainActor func closures(_ agency: AgencyModel) -> Controls { BoundaryMapper.closures(agency) }
//        @MainActor func params(_ agency: AgencyModel) -> Params { BoundaryMapper.params(agency) }
//    }
//
//    func build(_ agency: AgencyModel) -> some View {
//        Constructor.build(agency.studio.content, params(agency), closures(agency))
//    }
//
//    static func closures(_ agency: AgencyModel) -> Controls { return ProcessesMapper.closures(agency) }
//    static func params(_ agency: AgencyModel) -> Params { return ProcessesMapper.params(agency) }
//}

enum BrowserViewMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var image: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

struct SidebarRow: View {
    let icon: String
    let label: String
    var tint: Color = .secondary
    var trailingText: String?
    var trailingSystemImage: String?
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18)

            Text(label).lineLimit(1)

            Spacer(minLength: 8)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let trailingText {
                Text(trailingText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.16) : Color.clear)
        .clipShape(.rect(cornerRadius: 7))
    }
}

struct ToolbarChevronButtons: View {
    var body: some View {
        HStack(spacing: 0) {
            Button { } label: { Image(systemName: "chevron.left") }.help("Back")
            Divider().frame(height: 18)
            Button { } label: { Image(systemName: "chevron.right") }.help("Forward")
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
    }
}

struct ViewModePicker: View {
    let selection: BrowserViewMode
    let setSelection: (BrowserViewMode) -> Void

    var body: some View {
        Picker(
            "View",
            selection: Binding(
                get: { selection },
                set: { setSelection($0) }
            )
        ) {
            ForEach(BrowserViewMode.allCases) { mode in
                Image(systemName: mode.image)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 150)
    }
}

struct GridColumn: View {
    let icon: String
    let label: String
    var selected: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 58))
                .foregroundStyle(.blue)
                .frame(width: 76, height: 64)
                .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
                .clipShape(.rect(cornerRadius: 7))

            Text(label)
                .font(.callout)
                .lineLimit(1)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(selected ? Color.accentColor : Color.clear)
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(.rect(cornerRadius: 5))
        }
        .frame(width: 96, height: 104)
    }
}

struct FileListRow: View {
    let item: BrowserMockItem
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(item.name, systemImage: item.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary, .blue)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.tags)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(item.dateModified)
                .foregroundStyle(.secondary)
                .frame(width: 210, alignment: .leading)

            Text(item.size)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(selected ? Color.accentColor.opacity(0.20) : Color.clear)
        .clipShape(.rect(cornerRadius: 7))
    }
}

struct RoundedSpacerRow: View {
    var body: some View {
        Color(nsColor: .separatorColor)
            .opacity(0.12)
            .frame(height: 34)
            .clipShape(.rect(cornerRadius: 7))
            .padding(.vertical, 15)
    }
}

struct PathBarSegment: View {
    let icon: String
    let label: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

struct BrowserPathBar: View {
    let segments: [BrowserMockItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    PathBarSegment(icon: segment.icon, label: segment.name)

                    if index < segments.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .background(.bar)
    }
}

struct BrowserList: View {
    let items: [BrowserMockItem]
    let selectedID: UUID?
    let select: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Tags")
                    .frame(width: 140, alignment: .leading)
                Text("Date Modified")
                    .frame(width: 210, alignment: .leading)
                Text("Size")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        FileListRow(item: item, selected: selectedID == item.id)
                            .onTapGesture {
                                select(item.id)
                            }
                    }

                    ForEach(0..<9, id: \.self) { _ in
                        RoundedSpacerRow()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct BrowserGrid: View {
    let items: [BrowserMockItem]
    let selectedID: UUID?
    let select: (UUID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 26)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                ForEach(items) { item in
                    GridColumn(icon: item.icon, label: item.name, selected: selectedID == item.id)
                        .onTapGesture { select(item.id) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct Browser: View {
    @State private var selectedSidebarID = BrowserMockData.favorites.first?.id
    @State private var selectedFileID = BrowserMockData.files.last?.id
    @State private var viewMode: BrowserViewMode = .grid
    @State private var searchText = ""

    var sidebar: some View {
        List {
            Section("Favorites") {
                ForEach(BrowserMockData.favorites) { item in
                    Button { selectedSidebarID = item.id } label: {
                        SidebarRow(
                            icon: item.icon,
                            label: item.name,
                            tint: item.tint,
                            trailingSystemImage: item.trailingSystemImage,
                            selected: selectedSidebarID == item.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Locations") {
                ForEach(BrowserMockData.locations) { item in
                    Button { selectedSidebarID = item.id } label: {
                        SidebarRow(icon: item.icon, label: item.name, tint: item.tint, selected: selectedSidebarID == item.id)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Tags") {
                ForEach(BrowserMockData.tags) { item in
                    Button { selectedSidebarID = item.id } label: {
                        SidebarRow(icon: item.icon, label: item.name, tint: item.tint, selected: selectedSidebarID == item.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
    }

    var content: some View {
        Group {
            switch viewMode {
            case .grid: BrowserGrid(items: BrowserMockData.files, selectedID: selectedFileID) { id in selectedFileID = id }
            case .list: BrowserList(items: BrowserMockData.files, selectedID: selectedFileID) { id in selectedFileID = id }
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            VStack(spacing: 0) {
                content
                Divider()
                BrowserPathBar(segments: BrowserMockData.path)
            }
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .navigation) { ToolbarChevronButtons() }

                ToolbarItem(placement: .automatic) {
                    ViewModePicker(selection: viewMode) { mode in
                        viewMode = mode
                    }
                }

                ToolbarItem(placement: .automatic) { TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }
        }
    }
}
