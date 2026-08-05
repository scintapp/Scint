import Foundation
import OrderedCollections


typealias Encode = @Sendable (any Resolvable, JSONEncoder) throws -> Data
typealias Decode = @Sendable (Data, JSONDecoder) throws -> any Resolvable
typealias EncodeFrom = @Sendable (Bounding, Reference, JSONEncoder) throws -> Data?

public typealias Config = OrderedDictionary<String, Value>
public typealias ActivityId = UUID
public typealias ContextId = UUID
public typealias DescriptorId = UUID
public typealias StorageId = UUID
public typealias TypeId = UUID

protocol Storable: Codable & Sendable {}
protocol Storing: Sendable { func store(for ref: Reference?) -> Store? }
protocol Environmenting: Sendable { var entries: Library { get } }
protocol Persisting: Sendable { func encode<T: Resolvable>(_ type: T.Type) throws -> [StorableObject]; func decode(_ records: [StorableObject]) }
protocol Bounding: Sendable { func store(for ref: Reference?) -> Store?; var stores: [Store] { get } }
protocol Indexing: Sendable {}

protocol ExpressibleThings: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral, ExpressibleByNilLiteral {}
protocol ExpressibleNumbers: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {}
protocol Expressible: ExpressibleNumbers, ExpressibleThings {}
protocol Convertible: Sendable { var property: Property { get } }

@objc public protocol ServiceProviding {
    func start(_ command: String, _ arguments: [String], _ environment: [String: String], _ reply: @escaping (Int32, String?, String?) -> Void)
    func stop(pid: Int32, reply: @escaping (Bool) -> Void)
    func restart(pid: Int32, reply: @escaping (Int32, String?, String?) -> Void)
    func list(reply: @escaping ([String]) -> Void)
    func inspect(pid: Int32, reply: @escaping (String?) -> Void)
    func write(pid: Int32, input: String, close: Bool, reply: @escaping (String) -> Void)
    func ping(reply: @escaping (Bool) -> Void)
    func status(reply: @escaping (String) -> Void)
    func request(_ json: String, reply: @escaping (String) -> Void)
    func registerService(_ json: String, reply: @escaping (String) -> Void)
    func unregisterService(_ id: String, reply: @escaping (Bool) -> Void)
    func services(reply: @escaping (String) -> Void)
    func startService(_ id: String, reply: @escaping (String) -> Void)
    func stopService(_ id: String, reply: @escaping (Bool) -> Void)
    func restartService(_ id: String, reply: @escaping (String) -> Void)
}
@objc public protocol ServiceHandling { func handle(pid: Int32, chunk: String) }

public protocol Resolvable: Codable, Sendable { var ref: Reference { get } }
public protocol Keyable: Resolvable { var key: Key { get }; var origin: Reference { get } }
public protocol Composable: Resolvable { init(_ ref: Reference) }
public protocol Functional: Composable {}
public protocol Malleable: Composable { var owner: Reference { get set } }
public protocol Structural: Composable {}
public protocol Contextual: Keyable { init(_ origin: Reference); var transcript: Reference { get } }
