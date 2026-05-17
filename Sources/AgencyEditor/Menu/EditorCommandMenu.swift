import SwiftUI


struct EditorCommandRow: View {
    @Environment(EditorModel.self) private var editor
    let item: MenuItem

    private var selected: Bool {
        item.id == editor.menu.item
    }

    var body: some View {
        Button {
            editor.menu.select(itemId: item.id)
            editor.commitMenu()
        } label: {
            HStack(spacing: 8) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(selected ? .white : .primary.opacity(0.8))
                        .frame(width: 20, height: 20)
                }

                Text(item.label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(selected ? .white : .primary.opacity(0.8))

                Spacer(minLength: 0)

                if item.submenu != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
}

struct EditorCommandMenu: View {
    @Environment(EditorModel.self) private var editor
    private var menu: MenuModel { editor.menu }

    var body: some View {
        HStack(spacing: 0) {
            commandPane
            if let submenu = menu.presentedSubmenu {
                Divider().overlay(Color.white.opacity(0.06))
                submenuPane(submenu)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var commandPane: some View {
        Group {
            if menu.filtered.isEmpty {
                EditorMenuEmptyState(title: "No commands found", width: 280, height: 230)
            } else {
                commandList
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 280, height: 230, alignment: .topLeading)
    }

    private var commandList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(menu.filtered) { item in
                        if case .divider = item.kind {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        } else {
                            EditorCommandRow(item: item)
                                .id(item.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: menu.item) { _, newId in
                guard let newId else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(newId, anchor: .center)
                }
            }
        }
    }

    private func submenuPane(_ submenu: MenuSubmenu) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    editor.menu.closeSubmenu()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Text(submenu.title)
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 6) {
                Text("Coming Soon")
                    .font(.system(size: 12, weight: .semibold))

                Text(submenu.placeholder)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Spacer()
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 280, height: 230, alignment: .topLeading)
    }
}

