import AgencyRuntime
import SwiftUI
import Foundation


func search(_ query: String, facet: String, limit: Int) -> [ItemParams] {
    Runtime.shared
        .search("\(query) !\(facet)", limit: limit)
        .all
        .map(item(from:))
}

func item(from result: SearchResult) -> ItemParams {
    ItemParams(
        ref: result.ref,
        name: result.name,
        image: Design.Component.icon(for: result.ref),
        description: result.description,
        tags: result.tags.sorted()
    )
}

struct SearchQueries {
    @MainActor static func params(_ agency: AgencyModel) -> Params {
        let query = agency.search.query

        return Params(
            nesting: .flat,
            sections: [
                section(
                    id: "space",
                    name: "Space",
                    image: "cube.transparent",
                    items: search(query, facet: "structural", limit: 50)
                ),
                section(
                    id: "sheets",
                    name: "Sheets",
                    image: "text.alignleft",
                    items: search(query, facet: "sheet", limit: 50)
                ),
                section(
                    id: "interfaces",
                    name: "Interfaces",
                    image: "switch.2",
                    items: search(query, facet: "interfacing", limit: 50)
                ),
                section(
                    id: "processes",
                    name: "Processes",
                    image: "arrow.2.squarepath",
                    items: search(query, facet: "service", limit: 50)
                )
            ].compactMap { $0 }
        )
    }

    private static func section(id: String, name: String, image: String, items: [ItemParams]) -> ListParams? {
        guard !items.isEmpty else { return nil }
        return ListParams(id: id, name: name, image: image, layout: .list, items: items)
    }
}

struct SearchInput: View {
    @Binding var query: String
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

            TextField(placeholder, text: $query)
                .foregroundStyle(.primary)
                .font(.system(size: 26))
                .textFieldStyle(.plain)
                .focused(focused)
                .onKeyPress(.upArrow) { onUpArrow() }
                .onKeyPress(.downArrow) { onDownArrow() }
                .onKeyPress(.return) { onReturn() }
                .onKeyPress(.tab) { onTab() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SearchDetails: View {
    let details: SearchResultDetails

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

                    Text(typeName(for: details.result.ref))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("Tab")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
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

    func block(_ title: String, _ text: String) -> some View {
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

    func typeName(for ref: Reference) -> String {
        ref.type.map { String(describing: $0) } ?? "Unknown"
    }
}

struct SearchRow: View {
    let item: ItemParams
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                Image(systemName: item.image.isEmpty ? "square.stack.3d.up" : item.image)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16.5))
                    .foregroundStyle(isSelected ? Color.primary.opacity(1) : .primary.opacity(0.85))
                    .lineLimit(1)

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

struct SearchContent: View {
    @Binding var index: Int
    let params: Params
    let onTap: (ItemParams) -> Void
    var flatItems: [ItemParams] { params.sections.flatMap { $0.items } }
    var isEmpty: Bool { flatItems.isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) { if isEmpty { empty } else { content } }
                    .padding(.horizontal, 8)
                    .onChange(of: index) {
                        guard flatItems.indices.contains(index) else { return }
                        proxy.scrollTo(flatItems[index].id, anchor: .center)
                    }
            }
        }
    }

    var content: some View {
        ForEach(params.sections) { section in sectionView(section, startIndex: runningIndexBefore(section)) }
            .id(params.sections.map(\.id))
    }

    func runningIndexBefore(_ section: ListParams) -> Int {
        var count = 0
        for s in params.sections {
            if s.id == section.id { return count }
            count += s.items.count
        }
        return count
    }

    @ViewBuilder
    func sectionView(_ section: ListParams, startIndex: Int) -> some View {
        if section.header && !section.name.isEmpty {
            Text(section.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 6)
        }

        ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, item in
            let absolute = startIndex + offset
            SearchRow(
                item: item,
                isSelected: absolute == index,
                onTap: {
                    index = absolute
                    onTap(item)
                }
            )
            .id(item.id)
        }
    }

    var empty: some View {
        VStack {
            Text("No results")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct SearchPanel: View {
    @Environment(AgencyModel.self) var agency
    @FocusState private var focused: Bool

    private var params: Params {
        agency.search.params(agency)
    }

    private var flatItems: [ItemParams] {
        params.sections.flatMap { $0.items }
    }

    var body: some View {
        @Bindable var search = agency.search

        VStack(alignment: .leading, spacing: 0) {
            if let details = agency.search.details {
                SearchDetails(details: details)
                    .onKeyPress(.tab) { closeDetails(); return .handled }
            } else {
                SearchInput(
                    query: $search.query,
                    image: agency.search.scope.image,
                    placeholder: agency.search.scope.placeholder,
                    focused: $focused,
                    onUpArrow: { move(-1); return .handled },
                    onDownArrow: { move(+1); return .handled },
                    onReturn: { activate(); return .handled },
                    onTab: { showDetails(); return .handled }
                )

                SearchContent(
                    index: $search.index,
                    params: params,
                    onTap: { _ in activate() }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .onChange(of: agency.search.query) { _, _ in agency.search.index = 0 }
        .onChange(of: agency.search.scope) { _, _ in agency.search.reset(); focused = true }
        .background(modalitySwitchers)
    }

    private var modalitySwitchers: some View {
        ZStack {
            Button { agency.search.scope = .everything } label: { EmptyView() }
                .keyboardShortcut("1", modifiers: .command)
            Button { agency.search.scope = .space } label: { EmptyView() }
                .keyboardShortcut("2", modifiers: .command)
            Button { agency.search.scope = .controls } label: { EmptyView() }
                .keyboardShortcut("3", modifiers: .command)
            Button { agency.search.scope = .library } label: { EmptyView() }
                .keyboardShortcut("4", modifiers: .command)
            Button { agency.search.scope = .activity } label: { EmptyView() }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func move(_ delta: Int) {
        let count = flatItems.count
        guard count > 0 else { return }
        agency.search.index = (agency.search.index + delta + count) % count
    }

    private func activate() {
        guard flatItems.indices.contains(agency.search.index) else { return }
        let item = flatItems[agency.search.index]
        agency.search.closures(agency).onSelect?(item)
        dismiss()
    }

    private func showDetails() {
        guard flatItems.indices.contains(agency.search.index) else { return }
        guard let ref = flatItems[agency.search.index].ref else { return }
        agency.search.details = Runtime.shared.searchDetails(for: ref)
    }

    private func closeDetails() {
        agency.search.details = nil
        focused = true
    }

    private func dismiss() {
        agency.search.reset()
        agency.panels["search"]?.hide()
    }
}

