import Foundation
import SwiftUI
import ScintRuntime


@Observable final class DataModel {
    var app: Reference = Space.sentinel()
    var inbox: Reference = Space.sentinel()
    var projects: Reference = Space.sentinel()
    var library: Reference = Space.sentinel()
    var tasks: Reference = Space.sentinel()

    init(_ app: Reference) {
        self.app = app
        self.inbox = scope("Inbox")
        self.library = scope("Library")
        self.projects = scope("Projects")
        self.tasks = scope("Tasks")
    }

    func scope( _ name: String) -> Reference {
        guard let spaces = Space.with(app, { $0 })?.spaces, let scope = spaces.first(where: { $0.descriptor.name == name })
        else { fatalError() }
        return scope
    }
}
