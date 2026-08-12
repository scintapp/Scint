import Foundation
import OSLog


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

    func output(pid: Int32, _ handler: @escaping (Signal) -> Void) {
        let receive: (String) -> Void = { [weak self] chunk in
            guard let self else { return }
            for signal in self.signals(pid: pid, chunk: chunk) {
                handler(signal)
                if signal.terminal { self.removeOutputHandler(pid: pid) }
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

    private func signals(pid: Int32, chunk: String) -> [Signal] {
        let lines = lock.withLock { () -> [String] in
            let content = (buffers.removeValue(forKey: pid) ?? "") + chunk
            let parts = content.split(separator: "\n", omittingEmptySubsequences: false)
            guard content.last == "\n" else {
                buffers[pid] = parts.last.map(String.init) ?? ""
                return parts.dropLast().map(String.init)
            }
            return parts.dropLast().map(String.init)
        }
        return lines.flatMap(signals)
    }

    /// A line is usually one thing, but a termination envelope can arrive appended to
    /// a partial line of output. Losing it means the caller never sees a terminal
    /// signal and waits out its timeout on a command that already succeeded.
    private func signals(_ line: String) -> [Signal] {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        if let signal = terminal(value) { return [signal] }

        if let brace = value.lastIndex(of: "{"), brace != value.startIndex, let signal = terminal(String(value[brace...])) {
            let head = String(value[..<brace]).trimmingCharacters(in: .whitespacesAndNewlines)
            return head.isEmpty ? [signal] : [.updated(.string(head)), signal]
        }

        return [.updated(.string(value))]
    }

    private func terminal(_ value: String) -> Signal? {
        guard let properties = Properties.load(value),
              (properties["type"]?.string ?? properties["event"]?.string)?.lowercased() == "terminated"
        else { return nil }
        return properties["exitCode"]?.int == 0 ? .completed(nil) : .failed(.string(value))
    }

    func request(_ json: String, timeout: TimeInterval = 5.0) -> String? {
        sem(timeout: timeout) { service, signal in service.request(json) { signal($0) } }
    }

    func start(_ command: String, arguments: [String] = [], environment: [String: String] = [:], timeout: TimeInterval = 5.0) -> (pid: Int32, error: String?)? {
        print("Sending command: \(command) with args: \(arguments.joined()) to XPC.")
        var result: (pid: Int32, error: String?)?
        let done = DispatchSemaphore(value: 0)

        service().start(command, arguments, environment) { pid, _, error in
            result = (pid, error)
            done.signal()
        }

        guard done.wait(timeout: .now() + timeout) == .success, let result else { return nil }
        if result.error == nil {
            if let context = environment["SCINT_CONTEXT"].flatMap(UUID.init(uuidString:)) {
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
            print("XPC error: \(error)")
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
