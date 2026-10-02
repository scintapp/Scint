import OSLog
import SwiftUI
import ScintRuntime
import ScintComponents


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

    static func remove(_ ref: Reference) {
        Task { await Runtime.shared.remove(ref) }
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

        items.append(.init(id: "delete", label: "Delete", image: "trash", role: .destructive) { _ in Action.remove(ref) })
        return items
    }

    private static func canMove(_ ref: Reference, from origin: Reference?) -> Bool {
        ref.type is Space.Type || origin != nil
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

struct LoadButton<Label: View>: View {
    let items: [ItemParams]
    let onPick: (ItemParams) -> Void
    @ViewBuilder let label: () -> Label

    @State private var presented = false
    @State private var query = ""

    var height: CGFloat { min(max(CGFloat(items.count) * 64 + 52, 132), 360) }

    var filtered: [ItemParams] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var rows: some View {
        ForEach(filtered) { item in
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
                ScrollView { VStack(alignment: .leading, spacing: 2) { rows } }
                    .scrollIndicators(.hidden)
            }
        }
        .frame(width: 280, height: height, alignment: .topLeading)
        .clipShape(Style.Shape.panel)
    }

    var body: some View {
        Button { presented = true } label: { label() }
            .popover(isPresented: $presented) { menu }
            .onChange(of: presented) { _, presented in if !presented { query = "" } }
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

struct ContextMenu: View {
    var ref: Reference
    var model: any Model

    var space: Bool { ref.type is Space.Type }
    var document: Bool { ref.type is ScintRuntime.Document.Type }
    var folder: Bool { space && Navigation().spaces(to: ref).contains(model.session.library) }
    var parent: Reference? { Space.with(ref, { $0.space }) ?? nil }
    var origin: Reference? { ReferenceTransfer.origin(of: ref) }

    var moveDestinations: [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != ref && $0 != parent && !Navigation().spaces(to: $0).contains(ref) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    var spaceDestinations: [Reference] {
        destinations(in: model.session.projects)
            .filter { destination in
                Space.with(destination, { !$0.documents.contains(ref) }) ?? false
            }
    }

    var folderDestinations: [Reference] {
        ([model.session.library] + destinations(in: model.session.library)).filter { $0 != origin }
    }

    var body: some View {
        if space {
            Button(folder ? "New Folder…" : "New Space…") {
                prompt(folder ? "New Folder" : "New Space") { name in Space.new(ref, name: name) }
            }
            if folder {
                Button("New Document…") { prompt("New Document") { name in Document.new(ref, name: name) } }
            }
            Divider()
        }

        Button("Rename…") {
            prompt("Rename", ref.descriptor.name) { name in Catalog.shared.update(ref) { $0.name = name } }
        }

        if space {
            SwiftUI.Menu("Move To") {
                if parent != nil {
                    Button("Top Level") {
                        ReferenceTransfer.detach(ref, from: nil)
                    }
                    Divider()
                }
                ForEach(moveDestinations, id: \.self) { destination in
                    Button(destination.descriptor.name) {
                        ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                    }
                }
            }
        }

        if document {
            if !spaceDestinations.isEmpty {
                SwiftUI.Menu("Add to Space") {
                    ForEach(spaceDestinations, id: \.self) { destination in
                        Button(destination.descriptor.name) {
                            ReferenceTransfer.paste([ref], by: nil, move: false, to: destination)
                        }
                    }
                }
            }

            if !folderDestinations.isEmpty {
                SwiftUI.Menu("Move to Folder") {
                    ForEach(folderDestinations, id: \.self) { destination in
                        Button(destination.descriptor.name) {
                            ReferenceTransfer.paste([ref], by: nil, move: true, to: destination)
                        }
                    }
                }
            }
        }

        Divider()
        Button("Copy Link") {
            guard let url = Reference.Link.url(for: ref) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        }
        Button("Copy Markdown Link") {
            guard let markdown = Reference.Link.markdown(for: ref) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(markdown, forType: .string)
        }

        Divider()
        Button("Remove", role: .destructive) { Action.remove(ref) }
    }

    private func destinations(in root: Reference) -> [Reference] {
        Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0 != root && Navigation().spaces(to: $0).contains(root) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private func prompt(_ title: String, _ initial: String = "", _ apply: @escaping (String) -> Void) {
        let field = NSTextField(string: initial)
        field.placeholderString = "Name"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)

        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        alert.beginSheetModal(for: window) { response in
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard response == .alertFirstButtonReturn, !name.isEmpty else { return }
            apply(name)
        }
    }
}

@Observable @MainActor final class ReferenceSelection {
    static let shared = ReferenceSelection()
    var selected: Reference?
    private init() {}
}

enum PanelContext: CaseIterable, Sendable { case canvas, editor, navigator, search, settings }
enum SurfaceContext: CaseIterable, Sendable { case activity, harness, documents, node, tasks, transcript }
enum SearchAction: String, CaseIterable, Sendable { case search, disclose, activate }
enum StructureAction: String, CaseIterable, Sendable { case new, update, add, remove, attach, detach, delete }
enum ContentAction: String, CaseIterable, Sendable { case new, update, open, insert, clear, remove, delete }
enum InterfaceAction: String, CaseIterable, Sendable { case register, run, remove, unregister }
enum CompositionAction: String, CaseIterable, Sendable { case compose, resolve, start, stop }

@MainActor enum ReferenceAction {
    @discardableResult
    static func open(_ ref: Reference) -> Bool {
        if let url = Artifact.with(ref, { $0.handler.url }) ?? nil { return open(url) }
        return true
    }

    private static func open(_ url: URL) -> Bool {
        guard url.isFileURL else { return NSWorkspace.shared.open(url) }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else { return false }
        if isDirectory.boolValue, url.pathExtension.lowercased() != "app" { NSWorkspace.shared.open(url) }
        else { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        return true
    }
}
