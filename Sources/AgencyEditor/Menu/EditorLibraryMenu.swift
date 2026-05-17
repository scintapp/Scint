import SwiftUI


struct EditorLibrarySectionView: View {
    @Environment(EditorModel.self) private var editor
    let section: EditorLibrarySection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader

            ForEach(section.items) { item in
                let selected = editor.libraryItems[safe: editor.menu.libraryIndex]?.id == item.id
                EditorLibraryRow(item: item, selected: selected)
                    .id(item.id)
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: section.icon)
                .font(.system(size: 10, weight: .medium))
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct EditorLibraryRow: View {
    @Environment(EditorModel.self) private var editor
    let item: EditorLibraryItem
    let selected: Bool

    var body: some View {
        Button {
            editor.selectLibraryItem(item)
            editor.commitMenu()
        } label: {
            HStack(spacing: 10) {
                EditorMenuIconTile(icon: item.icon, selected: selected)
                titleBlock
                Spacer(minLength: 0)
                if selected { returnHint }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(selected ? .white : .primary.opacity(0.86))
                .lineLimit(1)

            if !item.description.isEmpty {
                Text(item.description)
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? .white.opacity(0.65) : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var returnHint: some View {
        Image(systemName: "return")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }
}

struct EditorLibraryMenu: View {
    @Environment(EditorModel.self) private var editor
    let focus: FocusState<EditorMenuFocus?>.Binding

    private var menu: MenuModel { editor.menu }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            Divider().overlay(Color.white.opacity(0.08))
            results
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 360, height: 360, alignment: .topLeading)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "at")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            TextField("Search library", text: Binding(
                get: { menu.query },
                set: {
                    menu.query = $0
                    menu.libraryIndex = 0
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused(focus, equals: .library)
            .onSubmit { editor.commitMenu() }
            .onKeyPress(.upArrow) { editor.moveMenuSelection(-1); return .handled }
            .onKeyPress(.downArrow) { editor.moveMenuSelection(1); return .handled }
            .onKeyPress(.escape) { menu.close(); return .handled }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var results: some View {
        let sections = editor.librarySections
        let flatItems = editor.libraryItems

        return Group {
            if flatItems.isEmpty {
                EditorMenuEmptyState(title: "No library results", width: 360, height: 310)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(sections) { section in
                                EditorLibrarySectionView(section: section)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: menu.libraryIndex) { _, index in
                        guard flatItems.indices.contains(index) else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(flatItems[index].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
