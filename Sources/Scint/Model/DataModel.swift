import Foundation
import SwiftUI
import ScintRuntime


@Observable final class DataModel {
    var app: Reference
    var agenda: Reference
    var library: Reference
    var spaces: Reference

    init(_ app: Reference) {
        self.app = app
        self.agenda = Self.scope(app, "Agenda")
        self.library = Self.scope(app, "Library")
        self.spaces = Self.scope(app, "Spaces")
    }

    static func scope(_ model: Reference, _ name: String) -> Reference {
        guard let spaces = Space.with(model, { $0 })?.spaces else { fatalError("Invalid model \(model)") }
        guard let scope = spaces.first(where: { $0.descriptor.name == name }) else { fatalError("Unknown scope \(name)") }
        return scope
    }
}
