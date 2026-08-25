import Foundation
import SwiftUI


enum PanelKey: String, Identifiable, CaseIterable {
    case actions, assistant, outline, search, tasks
    var id: String { self.panel }
    var panel: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(model).panels.\(panel)" }
}

enum ModelKey: String, Identifiable, CaseIterable {
    case editor, studio
    var id: String { self.model }
    var app: String { self.rawValue }
    var model: String { "scint" }
    var namespace: String { "\(app).\(model)" }
}

@Observable final class PanelState {
    var presented: Bool
    var pinned: Bool = false
    var detail: Bool = false
    var position: CGFloat
    var index: Int = 0
    var surface: String = ""
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

    var bindable: Bindable<PanelState> {
        @Bindable var state = self
        return $state
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

@Observable @MainActor final class EditorModel: Model {
    var navigator: NavigatorPanel
    var content: EditorPanel
    var session: Session

    init(_ session: Session) {
        self.navigator = .init()
        self.content = .init()
        self.session = session
    }
}

@Observable @MainActor final class StudioModel: Model {
    var navigator: NavigatorPanel
    var content: ContentPanel
    var inspector: InspectorPanel
    var session: Session

    init(_ session: Session) {
        self.navigator = .init()
        self.content = .init()
        self.inspector = .init()
        self.session = session
    }

    func open(_ ref: Reference) {
        guard session.open(ref) else { return }
        if ref.type is Material.Type { content.surface = .editor }
        select(ref)
    }
}
