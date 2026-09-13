import Foundation



protocol ExpressibleThings: ExpressibleByStringInterpolation, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {}
protocol ExpressibleNumbers: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {}
protocol ExpressibleCollections: ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {}
protocol Expressible: ExpressibleNumbers, ExpressibleThings, ExpressibleCollections {}
protocol Convertible: Sendable { var property: Property { get } }

extension Int: Convertible { var property: Property { .integer(self) }}
extension Double: Convertible { var property: Property { .decimal(self) }}
extension String: Convertible { var property: Property { .string(self) }}
extension Bool: Convertible { var property: Property { .bool(self) }}
extension Optional: Convertible where Wrapped: Convertible { var property: Property { self?.property ?? .null } }

enum Property: Codable, Convertible, Equatable, Hashable, Expressible {
    case bool(Bool)
    case integer(Int)
    case decimal(Double)
    case string(String)
    case array([Property])
    case object([String: Property])
    case null

    init(_ key: String, _ value: Property) { self = .object([key: value]) }
    init(_ key: String, _ value: String) { self = .object([key: .string(value)]) }
    init(_ key: String, _ value: Int) { self = .object([key: .integer(value)]) }
    init(_ key: String, _ value: Double) { self = .object([key: .decimal(value)]) }
    init(_ key: String, _ value: Bool) { self = .object([key: .bool(value)]) }

    init(from decoder: Decoder) throws {
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

    var property: Property { self }

    func encode(to encoder: Encoder) throws {
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

extension Property {
    var string: String? { if case .string(let v) = self { v } else { nil } }
    var double: Double? { if case .decimal(let v) = self { v } else { nil } }
    var int: Int? { if case .integer(let v) = self { v } else { nil } }
    var bool: Bool? { if case .bool(let v) = self { v } else { nil } }
    var array: [Property]? { if case .array(let v) = self { v } else { nil } }
    var object: [String: Property]? { if case .object(let v) = self { v } else { nil } }
}

extension Property {
    init(nilLiteral: ()) { self = .null }
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .integer(value) }
    init(floatLiteral value: Double) { self = .decimal(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: Property...) { self = .array(elements) }

    /// Without this, only string *literals* become properties — an interpolated string stays a
    /// String and fails to convert inside an object literal.
    init(stringInterpolation: DefaultStringInterpolation) {
        self = .string(String(stringInterpolation: stringInterpolation))
    }

    init(dictionaryLiteral elements: (String, Property)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

extension Property {
    /// A JSON Schema object, which is the one shape written often enough to be worth a name.
    /// Everything inside it is an ordinary literal.
    static func schema(_ properties: [String: Property], required: [String] = []) -> Property {
        var schema: Property = [
            "type": "object",
            "properties": .object(properties),
            "additionalProperties": false
        ]
        if !required.isEmpty { schema["required"] = .array(required.map(Property.string)) }
        return schema
    }
}

extension Property {
    var properties: Properties? {
        guard case .object(let m) = self else { return nil }
        return Properties(.object(m))
    }
}

extension Property {
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

extension Property {
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

extension Property {
    static func fromCodable<T: Codable>(_ value: T) -> Property {
        guard let data = try? JSONEncoder().encode(value),
              let any = try? JSONSerialization.jsonObject(with: data) else { return .null }
        return .fromJSONAny(any)
    }

    static func fromCodables<C: Collection>(_ values: C) -> Property where C.Element: Codable {
        .array(values.map { fromCodable($0) })
    }
}

extension Property {
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

extension Property {
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

extension Property {
    var isNull: Bool { if case .null = self { return true } else { return false } }
    var isPresent: Bool { !isNull }
}

struct Properties: Codable, Convertible, Equatable, Hashable, Sendable {
    var props: [Property]
    var property: Property { .object(self.mergedObject) }
    var properties: Properties { .array(props)}
    init(_ props: [Property]) { self.props = props }
    init(_ props: Property...) { self.props = props }

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        let prop = try single.decode(Property.self)
        switch prop {
            case .array(let items): self.props = items
            default:                self.props = [prop]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if props.count == 1, case .object = props[0] {
            try container.encode(props[0])
        } else {
            try container.encode(props)
        }
    }

    static func load(_ string: String) -> Self? {
        guard let data = string.data(using: .utf8) else { return nil }
        return load(data)
    }

    static func load(_ data: Data) -> Self? {
        return try? JSONDecoder().decode(Properties.self, from: data)
    }

    func render() -> String {
        guard let data: Data = try? render(),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    var rendered: String {
        guard let data: Data = try? render(), let render = String(data: data, encoding: .utf8)
                else { return "" }
        return render
    }

    func render() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

extension Properties {
    var mergedObject: [String: Property] {
        var merged: [String: Property] = [:]
        for p in props {
            if case .object(let m) = p {
                merged.merge(m) { _, new in new }
            }
        }
        return merged
    }

    subscript(_ keyPath: String) -> Property? {
        get {
            let root = Property.object(mergedObject)
            return root[keyPath]
        }
        mutating set {
            var root = Property.object(mergedObject)
            root[keyPath] = newValue
            guard case .object(let updated) = root else { return }
            self.props = [.object(updated)]
        }
    }
}

extension Properties {
    enum AccessError: Error, CustomStringConvertible {
        case missing(String)
        case typeMismatch(path: String, expected: String, got: Property)

        var description: String {
            switch self {
                case .missing(let p): return "Missing required key: \(p)"
                case .typeMismatch(let path, let exp, let got):
                    return "Type mismatch at '\(path)'. Expected \(exp), got \(got)"
            }
        }
    }

    func require(_ keyPath: String) throws -> Property {
        guard let v = self[keyPath] else { throw AccessError.missing(keyPath) }
        return v
    }

    func requireString(_ keyPath: String) throws -> String {
        let v = try require(keyPath)
        guard let s = v.string else {
            throw AccessError.typeMismatch(path: keyPath, expected: "string", got: v)
        }
        return s
    }

    func requireObject(_ keyPath: String) throws -> Properties {
        let v = try require(keyPath)
        guard let obj = v.properties else {
            throw AccessError.typeMismatch(path: keyPath, expected: "object", got: v)
        }
        return obj
    }
}

extension Properties {
    static func object(_ map: [String: Property]) -> Properties {
        Properties(.object(map))
    }

    static func object(_ pairs: (String, Property)...) -> Properties {
        Properties(.object(Dictionary(uniqueKeysWithValues: pairs)))
    }

    static func array(_ values: [Property]) -> Properties {
        Properties(values)
    }
}

extension Properties {
    internal static func object(_ map: [String: any Convertible]) -> Properties {
        Properties(.object(map.mapValues { $0.property }))
    }

    internal static func object(_ pairs: (String, any Convertible)...) -> Properties {
        Properties(.object(Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, $0.1.property) })))
    }
}

extension Properties {
    func firstProperty(of keyPaths: [String]) -> Property? {
        for path in keyPaths {
            if let v = self[path], v.isPresent { return v }
        }
        return nil
    }

    func firstString(of keyPaths: [String]) -> String? {
        firstProperty(of: keyPaths)?.string
    }

    func firstInt(of keyPaths: [String]) -> Int? {
        firstProperty(of: keyPaths)?.int
    }

    func hasAny(_ keyPaths: [String]) -> Bool {
        for path in keyPaths where self[path]?.isPresent == true { return true }
        return false
    }
}
