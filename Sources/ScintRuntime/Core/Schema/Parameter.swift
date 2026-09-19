import Foundation


enum Parameter: Codable, Sendable, Equatable {
    case argument(name: String, type: Value, required: Bool = false, default: Value? = nil)
    case command(name: String, ref: Value)
    case fixed(Value)

    static func marshal(_ value: Value) -> [String] {
        switch value {
            case .bool(let value):
                return [String(value)]

            case .integer(let value):
                return [String(value)]

            case .decimal(let value):
                return [String(describing: value)]

            case .string(let value):
                return [value]

            case .date(let value):
                return [Value.formatter.string(from: value)]

            case .sequence(let values), .range(let values):
                return values.flatMap(marshal)

            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    return marshal(value).map { "\(key)=\($0)" }
                }

            case .reference(let ref):
                switch ref.type {
                    case is Artifact.Type:
                        guard let path = Artifact.with(ref, { $0.rendered }), !path.isEmpty else { return [] }
                        return [path]

                    case is Command.Type:
                        return Command.with(ref) { command -> [String] in
                            guard let executable = command.executable else { return [] }
                            return [executable] + command.arguments()
                        } ?? []

                    default:
                        guard let url = Reference.Link.url(for: ref) else { return [] }
                        return [url.absoluteString]
                }
        }
    }

    static func marshal(_ values: [Value]) -> [String] { values.flatMap(marshal) }
}

extension Parameter {
    private enum CodingKeys: String, CodingKey, CaseIterable { case argument, command, fixed }
    private enum Fields: String, CodingKey { case name, type, required, `default`, ref }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.tag() {
            case .argument:
                let f = try c.nestedContainer(keyedBy: Fields.self, forKey: .argument)
                self = .argument(
                    name: try f.decode(String.self, forKey: .name),
                    type: try f.decode(Value.self, forKey: .type),
                    required: try f.decodeIfPresent(Bool.self, forKey: .required) ?? false,
                    default: try f.decodeIfPresent(Value.self, forKey: .default)
                )
            case .command:
                let f = try c.nestedContainer(keyedBy: Fields.self, forKey: .command)
                self = .command(name: try f.decode(String.self, forKey: .name), ref: try f.decode(Value.self, forKey: .ref))
            case .fixed:
                self = .fixed(try c.decode(Value.self, forKey: .fixed))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .argument(let name, let type, let required, let fallback):
                var f = c.nestedContainer(keyedBy: Fields.self, forKey: .argument)
                try f.encode(name, forKey: .name)
                try f.encode(type, forKey: .type)
                try f.encode(required, forKey: .required)
                try f.encodeIfPresent(fallback, forKey: .default)
            case .command(let name, let ref):
                var f = c.nestedContainer(keyedBy: Fields.self, forKey: .command)
                try f.encode(name, forKey: .name)
                try f.encode(ref, forKey: .ref)
            case .fixed(let value):
                try c.encode(value, forKey: .fixed)
        }
    }
}
