import AppKit
import SwiftUI
import AgencyRuntime


enum EditorSurface {
    static let menu: [MenuItem] = [
        .init(id: "new-task", label: "New Task", icon: "checkmark.app", keywords: ["task", "todo"]),
        .init(id: "new-link", label: "New Link", icon: "link", keywords: ["link", "web", "url"]),
        .divider("primary-divider"),
        .init(id: "controls", label: "Controls", icon: "switch.2", submenu: .controls, keywords: ["control", "tool", "action"]),
        .init(id: "skills", label: "Skills", icon: "sparkles", submenu: .skills, keywords: ["skill"]),
        .divider("secondary-divider"),
        .init(id: "add-files", label: "Add files or folders...", icon: "folder.badge.plus", keywords: ["file", "folder", "directory", "artifact", "open"])
    ]

    @MainActor static func build(for item: MenuItem) -> [Sheet.Entry]? {
        switch item.id {
        case "new-link":
            let ref = Artifact.register("Link", nil)
            Artifact.update(ref) { $0.entry = .http(nil) }
            return [.artifact(ref)]

        case "new-task":
            return [.todo(UUID(), "", false)]

        case "add-files":
            let panel = NSOpenPanel()
            panel.title = "Add Files or Folders"
            panel.prompt = "Add"
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = true
            guard panel.runModal() == .OK else { return nil }
            let entries = panel.urls.map { url in
                let name = url.lastPathComponent.isEmpty ? "Artifact" : url.lastPathComponent
                return Sheet.Entry.artifact(Artifact.register(name, url))
            }
            return entries.isEmpty ? nil : entries

        default:
            return nil
        }
    }
}

struct AgencyEditor: View {
    @State var state: EditorModel
    let ref: Reference
    let mode: EditorCanvas.Mode
    let onSubmit: (() -> Void)?
    let onActivate: ((Entry) -> Void)?

    @MainActor init(
        ref: Reference,
        mode: EditorCanvas.Mode = .document,
        onSubmit: (() -> Void)? = nil,
        onActivate: ((Entry) -> Void)? = nil
    ) {
        self.ref = ref
        self.mode = mode
        self.onSubmit = onSubmit
        self.onActivate = onActivate

        _state = State(
            initialValue: EditorModel(
                sheet: SheetModel(ref: ref),
                menuItems: EditorSurface.menu,
                makeEntries: EditorSurface.build(for:),
                activateExternalEntry: { _ in })
        )
    }

    public var body: some View {
        EditorCanvas(mode: mode, onSubmit: onSubmit)
            .environment(state)
            .onChange(of: state.sheet.dirty) { _, dirty in if dirty { state.sheet.sync() } }
            .onDisappear { if state.sheet.dirty { state.sheet.sync() } }
//            .task(id: ref) {
//                $state.activateExternalEntry = { entry in
//                    if let onActivate {
//                        onActivate(entry)
//                        return
//                    }
//                    if case .artifact(let ref) = entry,
//                       let url = Artifact.with(ref, { $0.entry.url }).flatMap({ $0 }) {
//                        NSWorkspace.shared.open(url)
//                    }
//                }
//            }
    }
}
