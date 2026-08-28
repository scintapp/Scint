import Foundation


struct Chunk: Keyable {
    var key: Key
    var origin: Reference
    var value: Value
    var created: Date

    init(_ ref: Reference, _ origin: Reference? = nil, _ value: Value) {
        self.key = .context(ref)
        self.origin = origin ?? ref
        self.value = value
        self.created = .now
    }
}

indirect enum Value: Codable, Sendable, Equatable {
    /// The one textual form a date takes anywhere it leaves the runtime — config, argv,
    /// or a control's value. Built per call; the formatter type is not Sendable.
    static var formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    case bool(Bool)
    case integer(Int)
    case decimal(Decimal)
    case string(String)
    case date(Date)
    case sequence([Value])
    case collection([String: Value])
    case reference(Reference)

    static func reference(_ type: Resolvable.Type) -> Value { .reference(Reference(type)) }
    static func sequence(_ value: Value) -> Value { .sequence([value]) }
    static var anyReference: Value { .sequence([]) }

    var type: Any.Type? {
        switch self {
            case .bool: return Bool.self
            case .date: return Date.self
            case .integer: return Int.self
            case .decimal: return Decimal.self
            case .string: return String.self
            case .sequence: return Array<Value>.self
            case .collection: return Dictionary<String, Value>.self
            case .reference(let ref): return ref.type
        }
    }

    var rendered: [String] { render() }

    var described: String {
        switch self {
            case .bool: return "<true|false>"
            case .date: return "<date>"
            case .integer: return "<integer>"
            case .decimal: return "<number>"
            case .string(let value): return value.isEmpty ? "<string>" : "<\(value)>"
            case .reference(let ref): return "<\(ref.type.map { "\($0)" } ?? "reference")>"
            case .sequence(let values):
                if values.isEmpty { return "<reference>" }
                if values.count == 1 { return "\(values[0].described)..." }
                let choices = values.compactMap { if case .string(let value) = $0 { value } else { nil } }
                return choices.count == values.count ? "<\(choices.joined(separator: "|"))>" : "<\(values.map(\.described).joined(separator: "|"))>"
            case .collection(let values):
                return values.keys.sorted().map { key in
                    guard let value = values[key] else { return key }
                    return "\(key) \(value.described)"
                }.joined(separator: " ")
        }
    }

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

            case (.date, .date):
                return supplied

            case (.date, .string(let value)) where Value.formatter.date(from: value) != nil:
                return .date(Value.formatter.date(from: value)!)

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

    private func render() -> [String] {
        switch self {
            case .bool(let value): return [String(value)]
            case .date(let value): return [Value.formatter.string(from: value)]
            case .integer(let value): return [String(value)]
            case .decimal(let value): return [String(describing: value)]
            case .string(let value): return [value]
            case .sequence(let values): return values.flatMap { $0.render() }
            case .collection(let values):
                return values.keys.sorted().flatMap { key -> [String] in
                    guard let value = values[key] else { return [] }
                    let rendered = value.render()
                    return ["\(key)=\(rendered.joined(separator: ","))"]
                }
            case .reference(let ref):
                let rendered = Runtime.shared.rendered(ref)
                return rendered.isEmpty ? [] : [rendered]
        }
    }
}
