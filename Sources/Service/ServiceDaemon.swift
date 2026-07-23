import AgencyRuntime
import Foundation
import Darwin


public final class HarnessDaemon: NSObject, ServiceProviding {
    private let connection: NSXPCConnection
    private let ownerID = UUID()
    private let store = ProcessStore.shared

    public init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    public func start(_ command: String, _ arguments: [String], _ environment: [String: String], _ reply: @escaping (Int32, String?, String?) -> Void) {
        store.start(ownerID: ownerID, command: command, arguments: arguments, env: environment, emit: emit, reply: reply)
    }

    public func stop(pid: Int32, reply: @escaping (Bool) -> Void) {
        store.stop(pid: pid, reply: reply)
    }

    public func restart(pid: Int32, reply: @escaping (Int32, String?, String?) -> Void) {
        store.restart(pid: pid, emit: emit, reply: reply)
    }

    public func list(reply: @escaping ([String]) -> Void) {
        store.list(reply: reply)
    }

    public func inspect(pid: Int32, reply: @escaping (String?) -> Void) {
        store.inspect(pid: pid, reply: reply)
    }

    public func write(pid: Int32, input: String, close: Bool, reply: @escaping (String) -> Void) {
        store.write(pid: pid, input: input, close: close, reply: reply)
    }

    public func ping(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    public func status(reply: @escaping (String) -> Void) {
        store.status(reply: reply)
    }

    public func request(_ json: String, reply: @escaping (String) -> Void) {
        store.request(ownerID: ownerID, json: json, emit: emit, reply: reply)
    }

    public func registerService(_ json: String, reply: @escaping (String) -> Void) {
        guard let dict = parseJSONDict(json), let def = ServiceDefinition(params: dict)
        else { reply(#"{"ok":false,"error":"invalid_service_definition"}"#); return }
        store.registerService(definition: def, reply: reply)
    }

    public func unregisterService(_ id: String, reply: @escaping (Bool) -> Void) {
        store.unregisterService(id: id, reply: reply)
    }

    public func services(reply: @escaping (String) -> Void) {
        store.services(reply: reply)
    }

    public func startService(_ id: String, reply: @escaping (String) -> Void) {
        store.startService(id: id, emit: emit, ownerID: ownerID, reply: reply)
    }

    public func stopService(_ id: String, reply: @escaping (Bool) -> Void) {
        store.stopService(id: id, reply: reply)
    }

    public func restartService(_ id: String, reply: @escaping (String) -> Void) {
        store.restartService(id: id, emit: emit, ownerID: ownerID, reply: reply)
    }

    private func emit(pid: Int32, chunk: String) {
        client?.handle(pid: pid, chunk: chunk)
    }

    private var client: ServiceHandling? {
        connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("agencyd: XPC client error: \(error)")
        } as? ServiceHandling
    }
}
