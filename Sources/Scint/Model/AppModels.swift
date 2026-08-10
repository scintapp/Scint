import Foundation
import SwiftUI


enum AppKey: String, Identifiable, CaseIterable {
    case editor, studio
    var id: String { self.model }
    var app: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(app).\(model)" }
}

enum PanelKey: String, Identifiable, CaseIterable {
    case actions, assistant, outline, search, tasks
    var id: String { self.panel }
    var panel: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(model).panels.\(panel)" }
}

@Observable final class AppState {
    var presented: Bool
    var position: CGFloat
    var index: Int = 0
    var query: String = ""
    var filter: String = ""
    var expanded: Set<AnyHashable>
    var values: Values

    init(presented: Bool? = false, position: CGFloat? = 0, expanded: Set<AnyHashable>? = [], values: Values? = [:]) {
        self.presented = presented ?? false
        self.position = position ?? 0
        self.expanded = expanded ?? []
        self.values = values ?? [:]
    }

    func isExpanded(_ id: AnyHashable) -> Bool { expanded.contains(id) }

    func setExpanded(_ id: AnyHashable) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }

    subscript<Value: Hashable>(_ key: AnyHashable, as type: Value.Type) -> Value? {
        get { values[key]?.base as? Value }
        set {
            if let newValue { values[key] = AnyHashable(newValue) }
            else { values[key] = nil }
        }
    }
}

@Observable @MainActor final class PanelsModel {
    var actions: ActionsPanel
    var assistant: AssistantPanel
    var outline: OutlinePanel
    var search: SearchPanel
    var tasks: TasksPanel

    init(_ resolver: ModelResolving) {
        self.actions = .init()
        self.assistant = .init()
        self.outline = .init()
        self.search = .init()
        self.tasks = .init()
    }
}

@Observable @MainActor final class EditorModel: Model {
    var session: Session
    var content: EditorContent

    init(_ session: Session) {
        self.content = .init()
        self.session = session
    }
}

@Observable @MainActor final class StudioModel: Model {
    var session: Session
    var sidebar: StudioSidebar
    var content: StudioContent
    var inspector: StudioInspector

    init(_ session: Session) {
        self.sidebar = .init()
        self.content = .init()
        self.inspector = .init()
        self.session = session
    }
}
