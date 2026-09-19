import Foundation
import SwiftUI


final class AppData: Codable, @unchecked Sendable {
    var inbox: Reference = Reference(Space.self)
    var activity: Reference = Reference(Space.self)
    var scheduled: Reference = Reference(Space.self)
    var spaces: Reference = Reference(Space.self)
    var library: Reference = Reference(Space.self)

    init() async {
        Harnesses.load()
        SampleInterfaces.load()
        if sort() { return }
        await Manifest.load()
        await Runtime.shared.save()
        sort()
    }

    @discardableResult
    private func sort() -> Bool {
        func named(_ name: String) -> Reference? { Runtime.shared.spaces.first { $0.descriptor.name == name } }
        guard let spaces = named("Spaces"),
              let inbox = named("Inbox"),
              let activity = named("Activity"),
              let scheduled = named("Scheduled"),
              let library = named("Library")
        else { return false }
        self.inbox = inbox
        self.activity = activity
        self.scheduled = scheduled
        self.spaces = spaces
        self.library = library
        return true
    }
}
