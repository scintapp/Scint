import Foundation
import SwiftUI
import ScintRuntime


final class DataModel: Codable, @unchecked Sendable {
    var scint: Reference = Space.sentinel()
    var inbox: Reference = Space.sentinel()
    var projects: Reference = Space.sentinel()
    var library: Reference = Space.sentinel()
    var tasks: Reference = Space.sentinel()

    init() async {
        if sort() { return }
        await RuntimeModel.load()
        await Runtime.shared.save()
        sort()
    }

    var documents: [Reference] {
        let order: [Reference: Int] = [:]
        func position(_ ref: Reference) -> Int { order[ref] ?? .max }

        return Runtime.shared.all(as: Document.self)
            .map { $0.0 }
            .filter { $0.descriptor.name != "Input" }
            .compactMap { ref in
                guard ref.type is ScintRuntime.Document.Type else { return nil }
                return ref
            }.sorted {
                let lhs = position($0)
                let rhs = position($1)
                if lhs != rhs { return lhs < rhs }
                return $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
    }

    @discardableResult
    private func sort() -> Bool {
        func named(_ name: String) -> Reference? { Runtime.shared.spaces.first { $0.descriptor.name == name } }
        guard
              let scint = named("Scint"),
              let inbox = named("Inbox"),
              let projects = named("Projects"),
              let library = named("Library"),
              let tasks = named("Tasks")
        else { return false }
        self.scint = scint
        self.inbox = inbox
        self.projects = projects
        self.library = library
        self.tasks = tasks
        return true
    }
}
