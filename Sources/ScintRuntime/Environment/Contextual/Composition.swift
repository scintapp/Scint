import Foundation


struct Composition: Codable, Sendable {
    let structure: Reference
    private var context: Context? { Composer.shared.context(structure) }
    private var intents: [Intent] { context?.intents ?? [] }

    enum State: Codable, Sendable, Equatable {
        case active, working, inactive

        var label: String {
            switch self {
                case .active: "Active"
                case .inactive: "Inactive"
                case .working: "Working"
            }
        }
    }

    var harness: Reference? { context?.harness }
    var transcript: Reference { context?.transcript ?? structure }

    var state: State {
        guard let intents = context?.intents, !intents.isEmpty else { return .inactive }
        return intents.contains { !$0.observing } ? .working : .active
    }
}
