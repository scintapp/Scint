import Foundation



public enum Property: Codable, Convertible, Equatable, Hashable, Expressible {
    case bool(Bool)
    case integer(Int)
    case decimal(Double)
    case string(String)
    case array([Property])
    case object([String: Property])
    case null

    public init(_ key: String, _ value: Property) { self = .object([key: value]) }
    public init(_ key: String, _ value: String) { self = .object([key: .string(value)]) }
    public init(_ key: String, _ value: Int) { self = .object([key: .integer(value)]) }
    public init(_ key: String, _ value: Double) { self = .object([key: .decimal(value)]) }
    public init(_ key: String, _ value: Bool) { self = .object([key: .bool(value)]) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .integer(v); return }
        if let v = try? c.decode(Double.self) { self = .decimal(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([Property].self) { self = .array(v); return }
        if let v = try? c.decode([String: Property].self) { self = .object(v); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported Property"))
    }

    public var property: Property { self }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()

        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .integer(let v): try c.encode(v)
        case .decimal(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

public extension Property {
    var string: String? { if case .string(let v) = self { v } else { nil } }
    var double: Double? { if case .decimal(let v) = self { v } else { nil } }
    var int: Int? { if case .integer(let v) = self { v } else { nil } }
    var bool: Bool? { if case .bool(let v) = self { v } else { nil } }
    var array: [Property]? { if case .array(let v) = self { v } else { nil } }
    var object: [String: Property]? { if case .object(let v) = self { v } else { nil } }
}

public extension Property {
    init(nilLiteral: ()) { self = .null }
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .integer(value) }
    init(floatLiteral value: Double) { self = .decimal(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

public extension Property {
    var properties: Properties? {
        guard case .object(let m) = self else { return nil }
        return Properties(.object(m))
    }
}

public extension Property {
    subscript(_ keyPath: String) -> Property? {
        get {
            guard !keyPath.isEmpty else { return self }
            let parts = keyPath.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
            return self[parts]
        }
        mutating set {
            let parts = keyPath.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
            self[parts] = newValue
        }
    }

    subscript(_ path: [String]) -> Property? {
        get {
            guard !path.isEmpty else { return self }
            guard case .object(let m) = self else { return nil }
            let head = path[0]
            if path.count == 1 { return m[head] }
            guard let next = m[head] else { return nil }
            return next[Array(path.dropFirst())]
        }
        mutating set {
            guard !path.isEmpty else {
                if let v = newValue { self = v }
                return
            }

            var m: [String: Property]
            switch self {
            case .object(let existing): m = existing
            default: m = [:]
            }

            let head = path[0]
            if path.count == 1 {
                m[head] = newValue ?? .null
                self = .object(m)
                return
            }

            var child = m[head] ?? .object([:])
            child[Array(path.dropFirst())] = newValue
            m[head] = child
            self = .object(m)
        }
    }

    subscript(index i: Int) -> Property? {
        get {
            guard case .array(let a) = self, a.indices.contains(i) else { return nil }
            return a[i]
        }

        mutating set {
            guard case .array(var a) = self, a.indices.contains(i) else { return }
            a[i] = newValue ?? .null
            self = .array(a)
        }
    }
}

public extension Property {
    func toJSONAny() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .integer(let v): return v
        case .decimal(let v): return v
        case .string(let v): return v
        case .array(let v): return v.map { $0.toJSONAny() }
        case .object(let v): return v.mapValues { $0.toJSONAny() }
        }
    }

    static func fromJSONAny(_ any: Any) -> Property {
        switch any {
        case is NSNull: return .null
        case let v as Bool: return .bool(v)
        case let v as Int: return .integer(v)
        case let v as Double: return .decimal(v)
        case let v as String: return .string(v)
        case let v as [Any]: return .array(v.map(Property.fromJSONAny))
        case let v as [String: Any]: return .object(v.mapValues(Property.fromJSONAny))
        default: return .string(String(describing: any))
        }
    }
}

public extension Property {
    static func fromCodable<T: Codable>(_ value: T) -> Property {
        guard let data = try? JSONEncoder().encode(value),
              let any = try? JSONSerialization.jsonObject(with: data) else { return .null }
        return .fromJSONAny(any)
    }

    static func fromCodables<C: Collection>(_ values: C) -> Property where C.Element: Codable {
        .array(values.map { fromCodable($0) })
    }
}

public extension Property {
    var stringRepresentation: String {
        switch self {
        case .string(let v): return v
        case .bool(let v): return String(v)
        case .integer(let v): return String(v)
        case .decimal(let v): return String(v)
        case .null: return "null"
        case .array, .object:
            guard let data = try? JSONEncoder().encode(self),
                  let s = String(data: data, encoding: .utf8) else { return "" }
            return s
        }
    }

    var type: String {
        switch self {
        case .bool: return "boolean"
        case .integer: return "integer"
        case .decimal: return "number"
        case .string: return "string"
        case .array: return "array"
        case .object: return "object"
        case .null: return "null"
        }
    }
}

public extension Property {
    var strings: [String]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap(\.string)
    }

    var ints: [Int]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap(\.int)
    }

    var doubles: [Double]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap(\.double)
    }

    var bools: [Bool]? {
        guard case .array(let arr) = self else { return nil }
        return arr.compactMap(\.bool)
    }
}

public extension Property {
    var isNull: Bool { if case .null = self { return true } else { return false } }
    var isPresent: Bool { !isNull }
}
