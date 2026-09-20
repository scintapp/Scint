import Foundation
import SwiftUI
import ScintRuntime


final class AppData: Codable, @unchecked Sendable {
    var inbox: Reference = Space.sentinel()
    var activity: Reference = Space.sentinel()
    var scheduled: Reference = Space.sentinel()
    var spaces: Reference = Space.sentinel()
    var library: Reference = Space.sentinel()

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
