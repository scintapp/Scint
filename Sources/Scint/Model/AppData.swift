import Foundation
import SwiftUI
import ScintRuntime


final class AppData: Codable, @unchecked Sendable {
    var inbox: Reference = Space.sentinel()
    var drafts: Reference = Space.sentinel()
    var tasks: Reference = Space.sentinel()
    var spaces: Reference = Space.sentinel()
    var library: Reference = Space.sentinel()

    init() async {
        if sort() { return }
        await RuntimeModel.load()
        await Runtime.shared.save()
        sort()
    }

    @discardableResult
    private func sort() -> Bool {
        func named(_ name: String) -> Reference? { Runtime.shared.spaces.first { $0.descriptor.name == name } }
        guard
              let inbox = named("Inbox"),
              let drafts = named("Drafts"),
              let tasks = named("Tasks"),
              let spaces = named("Spaces"),
              let library = named("Library")
        else { return false }
        self.inbox = inbox
        self.drafts = drafts
        self.tasks = tasks
        self.spaces = spaces
        self.library = library
        return true
    }
}
