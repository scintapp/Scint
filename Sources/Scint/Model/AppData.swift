import Foundation
import SwiftUI


final class AppData: Codable, @unchecked Sendable {
    var inbox: Reference = Reference(Space.self)
    var drafts: Reference = Reference(Space.self)
    var outlines: Reference = Reference(Space.self)
    var space: Reference = Reference(Space.self)
    var spaces: [Reference] { Array(Space.with(space, { $0 })?.spaces ?? []) }

    init() async {
        Harnesses.load()
        ObserveHarnesses.load()
        if sort() { return }
        await Manifest.load()
        await Runtime.shared.save()
        sort()
    }

    @discardableResult
    private func sort() -> Bool {
        func named(_ name: String) -> Reference? { Runtime.shared.spaces.first { $0.descriptor.name == name } }
        guard let inbox = named("Inbox"),
              let drafts = named("Drafts"),
              let outlines = named("Outlines"),
              let space = named("Spaces")
        else { return false }
        self.inbox = inbox
        self.drafts = drafts
        self.outlines = outlines
        self.space = space
        return true
    }

#if DEBUG
    init(previewSpace: Reference, inbox: Reference, drafts: Reference, outlines: Reference) {
        self.inbox = inbox
        self.drafts = drafts
        self.outlines = outlines
        self.space = previewSpace
    }
#endif
}
