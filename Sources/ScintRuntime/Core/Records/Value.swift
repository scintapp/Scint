import Foundation


indirect enum Value: Codable, Sendable, Equatable {
    case bool(Bool)
    case integer(Int)
    case decimal(Decimal)
    case string(String)
    case sequence([Value])
    case collection([String: Value])
    case reference(Reference)

    init?(_ property: Property) {
        switch property {
            case .null: return nil
            case .bool(let value): self = .bool(value)
            case .integer(let value): self = .integer(value)
            case .decimal(let value): self = .decimal(Decimal(value))
            case .string(let value): self = .string(value)
            case .array(let values): self = .sequence(values.compactMap(Value.init))
            case .object(let values): self = .collection(values.compactMapValues(Value.init))
        }
    }

    static func reference(_ type: Resolvable.Type) -> Value { .reference(Reference(type)) }
    static func sequence(_ value: Value) -> Value { .sequence([value]) }
    static var anyReference: Value { .sequence([]) }

    var type: Any.Type? {
        switch self {
            case .bool: return Bool.self
            case .integer: return Int.self
            case .decimal: return Decimal.self
            case .string: return String.self
            case .sequence: return Array<Value>.self
            case .collection: return Dictionary<String, Value>.self
            case .reference(let ref): return ref.type
        }
    }

    var rendered: [String] { render(nested: false) }

    var references: [Reference] {
        switch self {
            case .reference(let ref): return [ref]
            case .sequence(let values): return values.flatMap(\.references)
            case .collection(let values): return values.values.flatMap(\.references)
            default: return []
        }
    }

    func construct(_ supplied: Value, name: String) throws -> Value {
        switch (self, supplied) {
            case (.bool, .bool), (.integer, .integer), (.decimal, .decimal), (.string, .string):
                return supplied

            case (.bool, .string(let value)) where Bool(value) != nil:
                return .bool(Bool(value)!)

            case (.integer, .string(let value)) where Int(value) != nil:
                return .integer(Int(value)!)

            case (.decimal, .string(let value)) where Decimal(string: value) != nil:
                return .decimal(Decimal(string: value)!)

            case (.reference(let expected), .reference(let received)) where expected.typeId == received.typeId:
                return supplied

            case (.sequence(let alternatives), .reference) where alternatives.isEmpty:
                return supplied

            case (.sequence(let alternatives), _) where alternatives.count > 1:
                guard alternatives.contains(where: { (try? $0.construct(supplied, name: name)) != nil })
                        else { throw ParsingError.invalid("Argument \(name) is not an allowed value.") }
                return supplied

            case (.sequence(let template), .sequence(let values)):
                guard let element = template.first else { return supplied }
                return .sequence(try values.map { try element.construct($0, name: name) })

            case (.collection(let template), .collection(let values)):
                var constructed: [String: Value] = [:]
                for (key, expected) in template {
                    guard let value = values[key] else { throw ParsingError.invalid("Argument \(name) is missing \(key).") }
                    constructed[key] = try expected.construct(value, name: name)
                }
                guard Set(values.keys) == Set(template.keys) else { throw ParsingError.invalid("Argument \(name) has an invalid shape.") }
                return .collection(constructed)

            case (.collection(let template), _):
                guard template.count == 1, let (key, expected) = template.first else {
                    throw ParsingError.invalid("Argument \(name) expects a collection.")
                }
                return .collection([key: try expected.construct(supplied, name: name)])

            default:
                throw ParsingError.invalid("Argument \(name) has an invalid value type.")
        }
    }
    var property: Property {
        switch self {
            case .bool(let value): return .bool(value)
            case .integer(let value): return .integer(value)
            case .decimal(let value): return .decimal(NSDecimalNumber(decimal: value).doubleValue)
            case .string(let value): return .string(value)
            case .sequence(let values): return .array(values.map(\.property))
            case .collection(let values): return .object(values.mapValues(\.property))
            case .reference(let ref): return .string(ref.id.uuidString)
        }
    }

    private func render(nested: Bool) -> [String] {
        switch self {
            case .bool(let value): return [String(value)]
            case .integer(let value): return [String(value)]
            case .decimal(let value): return [String(describing: value)]
            case .string(let value): return [value]
            case .sequence(let values): return values.flatMap { $0.render(nested: nested) }
            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    let rendered = value.render(nested: true)
                    if nested { return ["\(key)=\(rendered.joined(separator: ","))"] }
                    return [key] + rendered
                }
            case .reference(let ref):
                switch ref.type {
                    case is Artifact.Type: return [Artifact.with(ref, { $0.rendered }) ?? ""]
                    case is Command.Type: return Command.with(ref, { $0.rendered }) ?? []
                    case is Harness.Type: return Harness.with(ref, { $0.rendered }) ?? []
                    case is Sheet.Type: return [Sheet.with(ref, { $0.rendered }) ?? ""]
                    case is Transcript.Type: return Transcript.with(ref, { $0.rendered }) ?? []
                    default: return [ref.descriptor.name]
                }
        }
    }
}
