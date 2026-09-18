import Foundation


enum Arguments {
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
