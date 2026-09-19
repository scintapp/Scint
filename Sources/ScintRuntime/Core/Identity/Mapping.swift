import Foundation


struct Mapping: Keyed {
    let key: Key
    let value: Value

    enum Value: Codable, Sendable, Equatable {
        case ref(Reference)
        case sequence([Mapping.Value])
        case collection([String: Mapping.Value])

        var context: [Composition] { self.refs.compactMap { $0.context } }
        var names: [String] { self.refs.compactMap { $0.descriptor.name } }
        var types: [Resolvable.Type?] { self.refs.compactMap { $0.type } }
        var descriptions: [String] { self.refs.compactMap { $0.descriptor.description } }
        var tags: [String] { self.refs.compactMap { $0.descriptor.tags.joined() } }
        var updated: [Date] { self.refs.compactMap { $0.descriptor.updated } }
        var rendered: [String] { self.refs.compactMap { render($0) } }

        var refs: [Reference] {
            switch self {
                case .ref(let ref): [ref]
                case .sequence(let refs): refs.flatMap { $0.refs }
                case .collection(let refs): refs.values.flatMap { $0.refs }
            }
        }

        func batch(_ type: any Functional.Type, values: [String: Value]? = nil) -> [(pid: Int32, error: String?)] {
            refs.filter({ $0.type is any Functional.Type }).map {
                switch type {
                    case is Command.Type:
                        guard let command = Command.with($0, { $0 })
                        else { return (0, nil) }
                        return command.run() ?? (0, nil)
                    case is Harness.Type:
                        guard let harness = Harness.with($0, { $0 })
                        else { return (0, nil) }
                        return harness.run() ?? (0, nil)
                    default: return (0, nil)
                }
            }
        }

        func render(_ ref: Reference) -> String {
            switch ref.type {
                case is Material.Type: Material.with(ref, { $0 })?.rendered ?? ""
                case is Space.Type: Space.with(ref, { $0 })?.rendered ?? ""
                case is Harness.Type: Harness.with(ref, { $0 })?.rendered ?? ""
                case is Command.Type: Command.with(ref, { $0 })?.rendered ?? ""
                case is Artifact.Type: Artifact.with(ref, { $0 })?.rendered ?? ""
                case is Bridge.Type: Bridge.with(ref, { $0 })?.rendered ?? ""
                default: ""
            }
        }
    }

    init( _ origin: Reference, _ value: Mapping.Value) {
        self.key = .map(.init(), origin)
        self.value = value
    }
}
