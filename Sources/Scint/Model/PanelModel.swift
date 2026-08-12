import Foundation
import SwiftUI


enum ModelKey: String, Identifiable, CaseIterable {
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

@Observable @MainActor final class EditorModel: Model {
    var session: Session
    var content: EditorPanel

    init(_ session: Session) {
        self.content = .init()
        self.session = session
    }
}

@Observable @MainActor final class StudioModel: Model {
    var session: Session
    var sidebar: NavigatorPanel
    var content: ContentPanel
    var inspector: InspectorPanel

    init(_ session: Session) {
        self.sidebar = .init()
        self.content = .init()
        self.inspector = .init()
        self.session = session
    }

    /// Opening a sheet is a request to edit it, so the rail follows.
    func open(_ ref: Reference) {
        guard session.open(ref) else { return }
        if ref.type is Material.Type { content.rail = .editor }
        select(ref)
    }
}

@Observable final class PanelState {
    var presented: Bool
    var pinned: Bool = false
    var detail: Bool = false
    var position: CGFloat
    var index: Int = 0
    var mode: String = ""
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
