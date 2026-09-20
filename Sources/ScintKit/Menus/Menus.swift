import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents



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

enum SearchMenu {
    static func search(for query: String, filters: [String] = [], limit: Int = 60, take: Int = 12, matching: (Reference) -> Bool = { _ in true }) -> [MenuItem] {
        Runtime.shared.search(query, filters: filters, limit: limit).all.compactMap { result in
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

enum Action {
    static func create(_ ref: Reference, in model: any Model) {}
    static func open(_ ref: Reference, in model: any Model) {}
    static func start(_ ref: Reference, in model: any Model) {}

    @MainActor static func rename(_ ref: Reference, in model: any Model) {
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
        }
    }

    static func delete(_ ref: Reference) {
        Task {
            do { try await ref.delete() }
            catch {
                Logger(subsystem: "com.kaechle.scint", category: "Actions")
                    .error("Delete failed for \(ref.id.uuidString, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    @MainActor static func createDocument(in origin: Reference, name: String = "New Document", model: any Model) {
        let ref = Document.new(origin, name: name)
        model.open(ref)
    }

    @MainActor static func createSpace(in origin: Reference, name: String = "New Space", model: any Model) {
        let ref = Space.new(origin, name: name)
        model.select(ref)
    }

    static func surfaceItems(for origin: Reference) -> [Item] {
        [
            .init(id: "new-document", label: "New Document", image: "text.alignleft") { Action.createDocument(in: origin, model: $0) },
            .init(id: "new-space", label: "New Space", image: "app") { Action.createSpace(in: origin, model: $0) }
        ]
    }

    static func itemItems(for item: ItemParams) -> [Item] {
        guard let ref = item.ref else { return [] }
        var items: [Item] = [
            .init(id: "rename", label: "Rename", image: "pencil") { Action.rename(ref, in: $0) }
        ]

        items.append(.init(id: "delete", label: "Delete", image: "trash", role: .destructive) { _ in Action.delete(ref) })
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
                            tint: item.tint ?? Style.Tint.space.bright,
                            sizing: 15,
                            selected: item.active
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Style.Foreground.secondary)
                            .lineLimit(1)
                    }
                    .frame(height: 42, alignment: .leading)

                    Spacer(minLength: 0)

                    if item.active {
                        Image(systemName: "checkmark")
                            .frame(height: 32, alignment: .leading)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Style.Foreground.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 42, alignment: .leading)
                .contentShape(Style.Shape.panel)
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
                        .foregroundStyle(Style.Foreground.secondary)
                    Text(query.isEmpty ? "Nothing in library" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(Style.Foreground.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView { VStack(alignment: .leading, spacing: 2) { button } }
                    .scrollIndicators(.hidden)
            }
        }
        .frame(width: 280, height: height, alignment: .topLeading)
        .clipShape(Style.Shape.panel)
    }

    var body: some View {
        Button { presented = true } label: {
            HStack {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13))
                    .foregroundStyle(Style.Foreground.primary)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .size(width: 20, height: 20, anchor: .center)
                            .fill(Style.Background.selection)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $presented) { menu }
        .onChange(of: presented) { _, presented in if !presented { query = "" } }
    }
}

struct TranscriptMenu: View {
    var ref: Reference
    var model: any Model

    var documents: [Reference] { Space.with(ref, { $0.documents }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }
    var selected: Bool { model.session.selection.selected(ref) }

    @State private var selection: Reference?

    var transcript: Reference? {
        if let selection, transcripts.contains(selection) { return selection }
        return transcripts.max { $0.descriptor.created < $1.descriptor.created }
    }

    var body: some View {
        SwiftUI.Menu {
            ForEach(transcripts) { transcript in
                Button {
                    selection = transcript
                    if !model.session.selection.selected(ref) { model.select(ref) }
                    model.select(transcript)
                } label: {
                    if transcript == self.transcript {
                        Label(transcript.descriptor.name, systemImage: "checkmark")
                    } else {
                        Text(transcript.descriptor.name)
                    }
                }
            }
        } label: {
            HStack(spacing: Style.Spacing.label) {
                Iconography.Icon(symbol: "text.bubble", tint: Style.Foreground.secondary, sizing: 16)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Style.Spacing.detail) {
                        Text(transcript?.descriptor.name ?? "None")
                        if let transcript = transcript {
                            let count = Transcript.with(transcript, { $0.records.count }) ?? 0
                            Text("· \(count) \(count == 1 ? "message" : "messages")")
                                .foregroundStyle(Style.Foreground.secondary)
                        }
                    }
                    .fixedSize()
                    Text(transcript?.descriptor.name ?? "None")
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .font(Typography.body)
            .foregroundStyle(Style.Foreground.primary)
            .padding(.horizontal, Style.Spacing.label)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Style.Shape.control.fill(Style.Background.surface))
            .overlay(Style.Shape.control.strokeBorder(Style.Border.hairline, lineWidth: 1))
            .contentShape(Style.Shape.control)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(transcripts.isEmpty)
    }
}
