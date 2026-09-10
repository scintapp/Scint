import SwiftUI


enum SearchMenu {
    static func search(for query: String, limit: Int = 60, take: Int = 12, matching: (Reference) -> Bool = { _ in true }) -> [MenuItem] {
        Runtime.shared.search(query, limit: limit).all.compactMap { result in
            guard matching(result.ref) else { return nil }
            return MenuItem.reference(
                result.ref,
                name: result.name,
                description: result.description,
                tags: result.tags.sorted()
            )
        }
        .prefix(take)
        .map { $0 }
    }
}

struct Item: Identifiable {
    let id: String
    let label: String
    let image: String
    let role: ButtonRole?
    let enabled: @MainActor (any Model) -> Bool
    let action: @MainActor (any Model) -> Void

    init(id: String, label: String, image: String = "", role: ButtonRole? = nil, enabled: @escaping @MainActor (any Model) -> Bool = { _ in true }, action: @escaping @MainActor (any Model) -> Void) {
        self.id = id
        self.label = label
        self.image = image
        self.role = role
        self.enabled = enabled
        self.action = action
    }
}

@MainActor enum Action {
    static func create(_ ref: Reference, in model: any Model) {}
    static func open(_ ref: Reference, in model: any Model) {}
    static func start(_ ref: Reference, in model: any Model) {}

    static func rename(_ ref: Reference, in model: any Model) {
        let field = NSTextField(string: ref.descriptor.name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = "Rename"
        alert.informativeText = "Enter a new name."
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            Catalog.shared.update(ref) { descriptor in
                descriptor.name = name
            }
            Task { await Runtime.shared.save() }
        }
    }

    static func delete(_ ref: Reference, from origin: Reference?, in model: any Model) {
        Task { try? await ref.delete() }
    }

    static func createMaterial(in origin: Reference, model: any Model) {
        let ref = Material.new(origin, name: "New Material")
        model.open(ref)
        Task { await Runtime.shared.save() }
    }

    static func createSpace(in origin: Reference, name: String = "New Space", model: any Model) {
        let ref = Space.new(origin, name: name)
        model.select(ref)
        Task { await Runtime.shared.save() }
    }

    static func surfaceItems(for origin: Reference) -> [Item] {
        [
            .init(id: "new-material", label: "New Material", image: "text.alignleft") { Action.createMaterial(in: origin, model: $0) },
            .init(id: "new-space", label: "New Space", image: "app") { Action.createSpace(in: origin, model: $0) }
        ]
    }

    static func itemItems(for item: ItemParams) -> [Item] {
        guard let ref = item.ref else { return [] }
        let origin = item.origin
        var items: [Item] = [
            .init(id: "rename", label: "Rename", image: "pencil") { Action.rename(ref, in: $0) }
        ]

        items.append(.init(id: "delete", label: "Delete", image: "trash", role: .destructive) { Action.delete(ref, from: origin, in: $0) })
        return items
    }

    private static func canMove(_ ref: Reference, from origin: Reference?) -> Bool {
        ref.type is Space.Type || origin != nil
    }
}

struct ActionMenu: View {
    let model: any Model
    let items: [Item]

    var body: some View {
        ForEach(items) { item in
            Button(role: item.role) { item.action(model) } label: {
                if item.image.isEmpty { Text(item.label) }
                else { Label(item.label, systemImage: item.image) }
            }
            .disabled(!item.enabled(model))
        }
    }
}

struct LoadMenu: View {
    let count: Int?
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void

    @State var presented: Bool = false
    @State var query: String = ""

    var height: CGFloat { min(max(CGFloat(items.count) * 64 + 52, 132), 360) }

    var filtered: [ItemParams] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var button: some View {
        ForEach(items) { item in
            Button {
                onPick(item)
                presented = false
            } label: {
                HStack(alignment: .center) {
                    if let ref = item.ref { Iconography.icon(for: ref, size: 15) }
                    else {
                        Iconography.Icon(
                            symbol: item.image,
                            tint: item.tint ?? Style.Tint.space,
                            sizing: 15,
                            selected: item.active
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Style.Foreground.muted)
                            .lineLimit(1)
                    }
                    .frame(height: 42, alignment: .leading)

                    Spacer(minLength: 0)

                    if item.active {
                        Image(systemName: "checkmark")
                            .frame(height: 32, alignment: .leading)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Style.Foreground.faint)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42, alignment: .leading)
                .contentShape(Style.Shape.large)
            }
            .buttonStyle(.plain)
        }
    }

    var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Filter(text: $query).padding(.top, 8)
            Divider().opacity(0.42)

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Style.Foreground.faint)
                    Text(query.isEmpty ? "Nothing in library" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.faint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(alignment: .leading, spacing: 2) { button } }
            }
        }
        .frame(width: 280, height: height, alignment: .topLeading)
        .glassEffect(.regular, in: Style.Shape.large)
        .clipShape(Style.Shape.large)
    }

    var body: some View {
        CountButton(count: count) { presented = true }
            .popover(isPresented: $presented) { menu }
            .onChange(of: presented) { _, presented in if !presented { query = "" } }
    }
}
