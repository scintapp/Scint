import Foundation


enum Value: Codable, Sendable, Equatable {
    case bool(Bool)
    case integer(Int)
    case decimal(Decimal)
    case string(String)
    case date(Date)
    case reference(Reference)
    case sequence([Value])
    case range([Value])
    case collection([String: Value])

    static func reference(_ type: Resolvable.Type) -> Value { .reference(Reference(type)) }
    static func sequence(_ value: Value) -> Value { .sequence([value]) }

    static var formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    var type: Any.Type? {
        switch self {
            case .bool: return Bool.self
            case .date: return Date.self
            case .integer: return Int.self
            case .decimal: return Decimal.self
            case .string: return String.self
            case .sequence, .range: return Array<Value>.self
            case .collection: return Dictionary<String, Value>.self
            case .reference(let ref): return ref.type
        }
    }

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
            case .range(let values):
                let choices = values.compactMap { if case .string(let value) = $0 { value } else { nil } }
                if choices.count == values.count, let first = choices.first, let last = choices.last {
                    return "<\(first)..\(last)>"
                }
                return "<\(values.map(\.described).joined(separator: "|"))>"
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
            case .sequence(let values), .range(let values): return values.flatMap(\.references)
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

            case (.range(let scale), .integer(let index)) where !scale.isEmpty:
                return scale[min(max(index, 0), scale.count - 1)]

            case (.range(let scale), _):
                guard scale.contains(supplied)
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
                guard template.count == 1, let (key, expected) = template.first
                else { throw ParsingError.invalid("Argument \(name) expects a collection.") }
                return .collection([key: try expected.construct(supplied, name: name)])

            default:
                throw ParsingError.invalid("Argument \(name) has an invalid value type.")
        }
    }
    
    var rendered: [String] { Renderer.value(self) }
}

struct Join: Keyed {
    let key: Key
    let origin: Reference
    let value: Value

    init(_ ref: Reference, _ origin: Reference, _ value: Value) {
        self.key = .map(.init(), ref)
        self.origin = origin
        self.value = value
    }
}
