import Foundation
import SwiftUI


enum AppKey: String, CaseIterable {
    case assistant, builder, editor, panels, studio
    var prefix: String { "scint." }
    var value: String { self.prefix + self.rawValue }
}

@Observable @MainActor final class EditorModel: Model {
    var sidebar: EditorSidebar
    var content: EditorContent
    var inspector: EditorInspector
    var session: Session

    init(_ session: Session) {
        self.sidebar = .init()
        self.content = .init()
        self.inspector = .init()
        self.session = session
    }
}

@Observable @MainActor final class PanelsModel: Model {
    var actions: ActionsPanel
    var assistant: AssistantPanel
    var outline: OutlinePanel
    var search: SearchPanel
    var tasks: TasksPanel
    var session: Session
    var controller: Controller

    init(_ session: Session) {
        self.actions = .init()
        self.assistant = .init()
        self.outline = .init()
        self.search = .init()
        self.tasks = .init()
        self.session = session
        self.controller = .init()
    }

    func toggleActions() {
        let parameters = self.search.parameters(self)
        guard let panel = parameters.panel else { return }
        controller.toggle(parameters.id, parameters: panel, view: self.actions.surface(self)) {
            [weak self] presented in self?.actions.state.presented = presented
        }
    }

    func toggleAssistant() {
        let parameters = self.search.parameters(self)
        guard let panel = parameters.panel else { return }
        controller.toggle(parameters.id, parameters: panel, view: self.assistant.surface(self)) {
            [weak self] presented in self?.assistant.state.presented = presented
        }
    }

    func toggleOutline() {
        let parameters = self.search.parameters(self)
        guard let panel = parameters.panel else { return }
        controller.toggle(parameters.id, parameters: panel, view: self.outline.surface(self)) {
            [weak self] presented in self?.outline.state.presented = presented
        }
    }

    func toggleSearch() {
        let parameters = self.search.parameters(self)
        guard let panel = parameters.panel else { return }
        controller.toggle(parameters.id, parameters: panel, view: self.search.surface(self)) {
            [weak self] presented in self?.search.state.presented = presented
        }
    }

    func toggleTasks() {
        let parameters = self.search.parameters(self)
        guard let panel = parameters.panel else { return }
        controller.toggle(parameters.id, parameters: panel, view: self.tasks.surface(self)) {
            [weak self] presented in self?.tasks.state.presented = presented
        }
    }
}

@Observable @MainActor final class StudioModel: Model {
    var sidebar: StudioSidebar
    var content: StudioContent
    var inspector: StudioInspector
    var session: Session

    init(_ session: Session) {
        self.sidebar = .init()
        self.content = .init()
        self.inspector = .init()
        self.session = session
    }
}
