import Foundation
import OSLog


@objc protocol ServiceHandling {
    func handle(pid: Int32, chunk: String)
}

@objc protocol ServiceProviding {
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


final class Services: NSObject, ServiceHandling, ObservableObject, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "Services")
    private let connection: NSXPCConnection
    private var handlers: [Int32: (String) -> Void] = [:]
    private var pending: [Int32: [String]] = [:]
    private var buffers: [Int32: String] = [:]
    private var draining: Set<Int32> = []
    private var contextByPID: [Int32: ContextId] = [:]
    private let lock = NSLock()

    override init() {
        connection = NSXPCConnection(machServiceName: "com.kaechle.scintd", options: [])
        super.init()
        connection.exportedObject = self
        connection.exportedInterface = NSXPCInterface(with: ServiceHandling.self)
        connection.remoteObjectInterface = NSXPCInterface(with: ServiceProviding.self)
        connection.resume()
    }

    deinit { connection.invalidate() }

    func handle(pid: Int32, chunk: String) {
        let delivery = lock.withLock { () -> (((String) -> Void)?, Bool) in
            guard let handler = handlers[pid], !draining.contains(pid) else {
                pending[pid, default: []].append(chunk)
                return (nil, true)
            }
            return (handler, false)
        }
        if delivery.1 {
            Self.logger.debug("Buffered \(chunk.utf8.count) bytes for pid \(pid) before handler readiness")
        } else {
            Self.logger.debug("Delivering \(chunk.utf8.count) bytes to pid \(pid)")
        }
        delivery.0?(chunk)
    }

    func output(pid: Int32, _ handler: @escaping (String) -> Void) {
        let receive: (String) -> Void = { [weak self] chunk in
            guard let self else { return }
            for line in self.lines(pid: pid, chunk: chunk) {
                handler(line)
                if self.terminated(line) { self.removeOutputHandler(pid: pid) }
            }
        }
        let pendingCount = lock.withLock { () -> Int in
            handlers[pid] = receive
            draining.insert(pid)
            return pending[pid]?.count ?? 0
        }
        Self.logger.debug("Registered output handler for pid \(pid) with \(pendingCount) pending chunks")

        while let chunks = lock.withLock({ () -> [String]? in
            guard let chunks = pending.removeValue(forKey: pid), !chunks.isEmpty else {
                draining.remove(pid)
                return nil
            }
            return chunks
        }) {
            chunks.forEach(receive)
        }
    }

    func removeOutputHandler(pid: Int32) {
        lock.withLock {
            handlers.removeValue(forKey: pid)
            pending.removeValue(forKey: pid)
            buffers.removeValue(forKey: pid)
            draining.remove(pid)
            contextByPID.removeValue(forKey: pid)
        }
    }

    private func lines(pid: Int32, chunk: String) -> [String] {
        lock.withLock { () -> [String] in
            let content = (buffers.removeValue(forKey: pid) ?? "") + chunk
            let parts = content.split(separator: "\n", omittingEmptySubsequences: false)
            guard content.last == "\n" else {
                buffers[pid] = parts.last.map(String.init) ?? ""
                return parts.dropLast().map(String.init)
            }
            return parts.dropLast().map(String.init)
        }
    }

    private func terminated(_ line: String) -> Bool {
        func envelope(_ value: String) -> Bool {
            guard let properties = Properties.load(value) else { return false }
            return (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
        }
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if envelope(value) { return true }
        guard let brace = value.lastIndex(of: "{"), brace != value.startIndex else { return false }
        return envelope(String(value[brace...]))
    }

    func request(_ json: String, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in service.request(json) { signal($0) } }
    }

    func start(_ command: String, args: [String] = [], env: [String: String] = [:], timeout: TimeInterval = 5.0) -> (pid: Int32, error: String?)? {
        Self.logger.debug("Dispatching \(command, privacy: .public) \(args.joined(separator: " "), privacy: .public) to Scint Service.")
        var result: (pid: Int32, error: String?)?
        let done = DispatchSemaphore(value: 0)

        service().start(command, args, env) { pid, _, error in
            result = (pid, error)
            done.signal()
        }

        guard done.wait(timeout: .now() + timeout) == .success, let result else { return nil }
        if result.error == nil {
            if let context = env["SCINT_CONTEXT"].flatMap(UUID.init(uuidString:)) {
                lock.withLock { contextByPID[result.pid] = context }
            }
            _ = write(pid: result.pid, input: "", close: true, timeout: timeout)
        }
        return result
    }

    func stop(context: ContextId, timeout: TimeInterval = 5.0) -> Bool {
        let pids = lock.withLock { contextByPID.compactMap { $0.value == context ? $0.key : nil } }
        return pids.reduce(true) { stopped, pid in
            let result = stop(pid: pid, timeout: timeout)
            if result { removeOutputHandler(pid: pid) }
            return stopped && result
        }
    }

    func stop(pid: Int32, timeout: TimeInterval = 5.0) -> Bool {
        var ok = false
        let done = DispatchSemaphore(value: 0)
        service().stop(pid: pid) { ok = $0; done.signal() }
        _ = done.wait(timeout: .now() + timeout)
        return ok
    }

    func restart(pid: Int32, timeout: TimeInterval = 5.0) -> (pid: Int32, error: String?)? {
        var result: (Int32, String?)?
        let done = DispatchSemaphore(value: 0)
        service().restart(pid: pid) { newPid, _, error in
            result = (newPid, error)
            done.signal()
        }
        guard done.wait(timeout: .now() + timeout) == .success else { return nil }
        return result
    }

    func list(timeout: TimeInterval = 5.0) -> [String]? {
        var result: [String]?
        let done = DispatchSemaphore(value: 0)
        service().list { result = $0; done.signal() }
        guard done.wait(timeout: .now() + timeout) == .success else { return nil }
        return result
    }

    @discardableResult func write(pid: Int32, input: String, close: Bool = false, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in
            service.write(pid: pid, input: input, close: close) { signal($0) }
        }
    }

    func inspect(pid: Int32, timeout: TimeInterval = 5.0) -> String? {
        var result: String?
        let done = DispatchSemaphore(value: 0)
        service().inspect(pid: pid) { result = $0; done.signal() }
        guard done.wait(timeout: .now() + timeout) == .success else { return nil }
        return result
    }

    func ping(timeout: TimeInterval = 3.0) -> Bool {
        var ok = false
        let done = DispatchSemaphore(value: 0)
        service().ping { ok = $0; done.signal() }
        return done.wait(timeout: .now() + timeout) == .success && ok
    }

    func status(timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in
            service.status { signal($0) }
        }
    }

    func registerService(_ json: String, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in
            service.registerService(json) { signal($0) }
        }
    }

    func unregisterService(_ id: String, timeout: TimeInterval = 5.0) -> Bool {
        var ok = false
        let done = DispatchSemaphore(value: 0)
        service().unregisterService(id) { ok = $0; done.signal() }
        _ = done.wait(timeout: .now() + timeout)
        return ok
    }

    func services(timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in
            service.services { signal($0) }
        }
    }

    func startService(_ id: String, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in service.startService(id) { signal($0) } }
    }

    func stopService(_ id: String, timeout: TimeInterval = 5.0) -> Bool {
        var ok = false
        let done = DispatchSemaphore(value: 0)
        service().stopService(id) { ok = $0; done.signal() }
        _ = done.wait(timeout: .now() + timeout)
        return ok
    }

    func restartService(_ id: String, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in
            service.restartService(id) { signal($0) }
        }
    }

    private func service() -> ServiceProviding {
        connection.remoteObjectProxyWithErrorHandler { error in
            Self.logger.error("XPC connection error: \(String(describing: error), privacy: .public)")
        } as! ServiceProviding
    }

    private func sem(timeout: TimeInterval, call: (ServiceProviding, @escaping (String) -> Void) -> Void) -> String? {
        let done = DispatchSemaphore(value: 0)
        var response: String?
        call(service()) { result in
            response = result
            done.signal()
        }
        return done.wait(timeout: .now() + timeout) == .success ? response : nil
    }
}
