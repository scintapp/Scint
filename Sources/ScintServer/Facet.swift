import Foundation


struct Facet: Sendable {
    let name: String
    let definition: Property
    let call: @Sendable (Properties) async -> ServerTool.Invocation

    @MainActor
    static func all(in origin: Reference) -> [Facet] {
        ServerTool.all(in: origin).map(\.facet)
            + ContentTool.all(in: origin).map(\.facet)
    }

    @MainActor
    static func find(_ name: String, in origin: Reference) -> Facet? {
        all(in: origin).first { $0.name == name }
    }
}

extension ServerTool {
    var facet: Facet {
        Facet(name: name, definition: definition, call: { arguments in
            await self.call(arguments)
        })
    }
}

extension ContentTool {
    var facet: Facet {
        Facet(name: operation.toolName, definition: definition, call: { arguments in
            await MainActor.run { self.call(arguments) }
        })
    }
}
