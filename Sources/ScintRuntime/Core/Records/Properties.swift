import Foundation


public struct Properties: Codable, Convertible, Equatable, Hashable, Sendable {
    public var props: [Property]
    public var property: Property { .object(self.mergedObject) }
    public var properties: Properties { .array(props)}
    public init(_ props: [Property]) { self.props = props }
    public init(_ props: Property...) { self.props = props }

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        let prop = try single.decode(Property.self)
        switch prop {
            case .array(let items): self.props = items
            default:                self.props = [prop]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if props.count == 1, case .object = props[0] {
            try container.encode(props[0])
        } else {
            try container.encode(props)
        }
    }

    public static func load(_ string: String) -> Self? {
        guard let data = string.data(using: .utf8) else { return nil }
        return load(data)
    }

    public static func load(_ data: Data) -> Self? {
        return try? JSONDecoder().decode(Properties.self, from: data)
    }

    public func render() -> String {
        guard let data: Data = try? render(),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }

    public var rendered: String {
        guard let data: Data = try? render(), let render = String(data: data, encoding: .utf8)
                else { return "" }
        return render
    }

    public func render() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

public extension Properties {
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

public extension Properties {
    enum AccessError: Error, CustomStringConvertible {
        case missing(String)
        case typeMismatch(path: String, expected: String, got: Property)

        public var description: String {
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

public extension Properties {
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

public extension Properties {
    internal static func object(_ map: [String: any Convertible]) -> Properties {
        Properties(.object(map.mapValues { $0.property }))
    }

    internal static func object(_ pairs: (String, any Convertible)...) -> Properties {
        Properties(.object(Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, $0.1.property) })))
    }
}

public extension Properties {
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
