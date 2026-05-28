import AgencyRuntime
import Foundation
import Darwin


private struct TrackedProcess {
    let process: Process
    let command: String
    let arguments: [String]
    let outputPipe: Pipe
    let inputPipe: Pipe
    let ownerID: UUID
    let label: String?
    let started: Date
    var exitCode: Int32?
    var restartCount: Int
    let policy: HarnessPolicy
    let emit: (Int32, String) -> Void
}

final class ProcessStore: @unchecked Sendable {
    static let shared = ProcessStore()
    private let queue = DispatchQueue(label: "com.kaechle.agencyd.store", attributes: .concurrent)
    private var processes: [pid_t: TrackedProcess] = [:]
    private let registry = HarnessRegistry.shared
    private let iso8601 = ISO8601DateFormatter()
    private lazy var userEnvironment: [String: String] = resolveUserEnvironment()
    let started = Date()

    func start(ownerID: UUID,command: String,arguments: [String],env: [String: String] = [:],label: String? = nil,restartCount: Int = 0,policy: HarnessPolicy = .never,emit: @escaping (Int32, String) -> Void, reply: @escaping (Int32, String?, String?) -> Void) {
        let sanitizedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedCommand.isEmpty else { reply(-1, nil, "Command is required")
            return
        }

        queue.async { [weak self] in
            guard let self else { return }

            let mergedEnvironment = self.userEnvironment.merging(env) { _, new in new }
            let expandedCommand = Self.expandVariables(in: sanitizedCommand, environment: mergedEnvironment)
            let expandedArguments = arguments.map { Self.expandVariables(in: $0, environment: mergedEnvironment) }
            let process = Process()
            let outputPipe = Pipe()
            let inputPipe = Pipe()

            process.standardOutput = outputPipe
            process.standardError = outputPipe
            process.standardInput = inputPipe
            process.environment = mergedEnvironment
            process.executableURL = URL(fileURLWithPath: expandedCommand)
            process.arguments = expandedArguments

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
                emit(process.processIdentifier, chunk)
            }

            do { try process.run() }
            catch { reply(-1, nil, error.localizedDescription); return }
            let pid = process.processIdentifier
            let started = Date()

            self.queue.async(flags: .barrier) {
                self.processes[pid] = TrackedProcess(
                    process: process,
                    command: expandedCommand,
                    arguments: expandedArguments,
                    outputPipe: outputPipe,
                    inputPipe: inputPipe,
                    ownerID: ownerID,
                    label: label,
                    started: started,
                    exitCode: nil,
                    restartCount: restartCount,
                    policy: policy,
                    emit: emit
                )
            }

            process.terminationHandler = { [weak self] proc in
                guard let self else { return }
                let pid = proc.processIdentifier
                let exitCode = proc.terminationStatus

                self.queue.async(flags: .barrier) {
                    guard let tracked = self.processes[pid] else { return }

                    tracked.outputPipe.fileHandleForReading.readabilityHandler = nil
                    tracked.outputPipe.fileHandleForReading.closeFile()
                    tracked.inputPipe.fileHandleForWriting.closeFile()
                    self.processes.removeValue(forKey: pid)

                    if let sid = self.registry.serviceID(for: pid) { self.registry.clearPID(for: sid) }

                    let shouldRestart: Bool
                    switch tracked.policy {
                    case .always: shouldRestart = true
                    case .onFailure: shouldRestart = exitCode != 0
                    case .never: shouldRestart = false
                    }

                    let savedEmit = tracked.emit
                    let savedLabel = tracked.label
                    let savedCommand = tracked.command
                    let savedArgs = tracked.arguments
                    let savedPolicy = tracked.policy
                    let savedOwnerID = tracked.ownerID
                    let nextCount = tracked.restartCount + 1

                    savedEmit(
                        pid,
                        jsonString([
                            "event": "terminated",
                            "pid": Int(pid),
                            "exitCode": Int(exitCode)
                        ]) + "\n"
                    )

                    guard shouldRestart else { return }

                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.start(ownerID: savedOwnerID, command: savedCommand,
                                    arguments: savedArgs, label: savedLabel, restartCount: nextCount,
                                    policy: savedPolicy, emit: savedEmit) {

                            newPid, _, error in
                            if let label = savedLabel, newPid > 0 { self?.registry.setActivePID(newPid, for: label) }
                            if let error { NSLog("agencyd: restart failed for '\(savedCommand)': \(error)") }
                        }
                    }
                }
            }

            reply(pid, nil, nil)
        }
    }

    private func resolveUserEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        if environment["HOME"] == nil {
            environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        }

        let shellPath = environment["SHELL"] ?? {
            guard let pwd = getpwuid(getuid()), let shell = pwd.pointee.pw_shell else { return "/bin/zsh" }
            return String(cString: shell)
        }()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lc", "env -0"]
        process.environment = environment

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return environment
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0, !data.isEmpty else {
            return environment
        }

        let shellEnvironment = data
            .split(separator: 0)
            .reduce(into: [String: String]()) { result, entry in
                guard let pair = String(data: Data(entry), encoding: .utf8),
                      let separator = pair.firstIndex(of: "=") else { return }
                let key = String(pair[..<separator])
                let value = String(pair[pair.index(after: separator)...])
                result[key] = value
            }

        return environment.merging(shellEnvironment) { _, new in new }
    }

    func stop(pid: Int32, reply: @escaping (Bool) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { reply(false); return }
            guard let tracked = self.processes[pid] else { reply(false); return }

            tracked.process.terminate()
            tracked.outputPipe.fileHandleForReading.readabilityHandler = nil
            tracked.inputPipe.fileHandleForWriting.closeFile()

            if let sid = self.registry.serviceID(for: pid) {
                self.registry.clearPID(for: sid)
            }

            self.processes.removeValue(forKey: pid)
            reply(true)
        }
    }

    func restart(pid: Int32,emit: @escaping (Int32, String) -> Void,reply: @escaping (Int32, String?, String?) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { reply(-1, nil, "service_unavailable"); return }
            guard let tracked = self.processes[pid] else { reply(-1, nil, "pid_not_found"); return }

            let command = tracked.command
            let arguments = tracked.arguments
            let label = tracked.label
            let nextCount = tracked.restartCount + 1
            let policy = tracked.policy
            let ownerID = tracked.ownerID

            tracked.process.terminate()
            tracked.outputPipe.fileHandleForReading.readabilityHandler = nil
            tracked.inputPipe.fileHandleForWriting.closeFile()
            self.processes.removeValue(forKey: pid)

            if let sid = self.registry.serviceID(for: pid) {
                self.registry.clearPID(for: sid)
            }

            DispatchQueue.global().async { [weak self] in
                self?.start(
                    ownerID: ownerID,
                    command: command,
                    arguments: arguments,
                    label: label,
                    restartCount: nextCount,
                    policy: policy,
                    emit: emit
                ) { newPid, info, error in
                    if let label, newPid > 0 { self?.registry.setActivePID(newPid, for: label) }
                    reply(newPid, info, error)
                }
            }
        }
    }

    func write(pid: Int32, input: String, close: Bool = false, reply: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }
            guard let tracked = self.processes[pid] else {
                reply(#"{"ok":false,"error":"pid_not_found"}"#); return
            }
            guard let data = input.data(using: .utf8) else {
                reply(#"{"ok":false,"error":"input_not_utf8"}"#); return
            }

            do {
                try tracked.inputPipe.fileHandleForWriting.write(contentsOf: data)
                if close {
                    tracked.inputPipe.fileHandleForWriting.closeFile()
                }
                reply(jsonString(["ok": true, "pid": Int(pid), "bytes": data.count]))
            } catch {
                reply(jsonString(["ok": false, "pid": Int(pid), "error": error.localizedDescription]))
            }
        }
    }

    func list(reply: @escaping ([String]) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply([]); return }
            let entries = self.processes.map { pid, tracked in
                let a = tracked.arguments.joined(separator: " ")
                return "\(pid) \(tracked.command)\(a.isEmpty ? "" : " \(a)")"
            }
            reply(entries.sorted())
        }
    }

    func listJSON(reply: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }

            let items: [[String: Any]] = self.processes
                .map { pid, tracked -> [String: Any] in
                    var e: [String: Any] = [
                        "pid": Int(pid),
                        "command": tracked.command,
                        "arguments": tracked.arguments,
                        "uptime": Date().timeIntervalSince(tracked.started),
                        "restartCount": tracked.restartCount,
                        "policy": tracked.policy.rawValue
                    ]
                    if let label = tracked.label { e["label"] = label }
                    return e
                }
                .sorted { ($0["pid"] as? Int ?? 0) < ($1["pid"] as? Int ?? 0) }

            reply(jsonString(["ok": true, "processes": items]))
        }
    }

    func inspect(pid: Int32, reply: @escaping (String?) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply(nil); return }
            guard let tracked = self.processes[pid] else { reply(nil); return }

            var e: [String: Any] = [
                "ok": true,
                "pid": Int(pid),
                "command": tracked.command,
                "arguments": tracked.arguments,
                "started": self.iso8601.string(from: tracked.started),
                "uptime": Date().timeIntervalSince(tracked.started),
                "restartCount":  tracked.restartCount,
                "policy": tracked.policy.rawValue,
                "state": "running"
            ]
            if let label = tracked.label { e["label"] = label }

            reply(jsonString(e))
        }
    }

    func status(reply: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }

            let processList: [[String: Any]] = self.processes
                .map { pid, tracked -> [String: Any] in
                    var e: [String: Any] = [
                        "pid": Int(pid),
                        "command": tracked.command,
                        "uptime": Date().timeIntervalSince(tracked.started),
                        "restartCount": tracked.restartCount
                    ]
                    if let label = tracked.label { e["label"] = label }
                    return e
                }
                .sorted { ($0["pid"] as? Int ?? 0) < ($1["pid"] as? Int ?? 0) }

            let serviceList: [[String: Any]] = self.registry.all().map { def in
                var e: [String: Any] = [
                    "id": def.id,
                    "command": def.command,
                    "policy": def.policy.rawValue
                ]
                if let pid = self.registry.activePID(for: def.id), self.processes[pid] != nil {
                    e["state"] = "running"
                    e["pid"] = Int(pid)
                } else {
                    e["state"] = "stopped"
                }
                return e
            }

            reply(jsonString([
                "ok": true,
                "uptime": Date().timeIntervalSince(self.started),
                "processCount": self.processes.count,
                "serviceCount": self.registry.all().count,
                "processes": processList,
                "services": serviceList
            ]))
        }
    }

    func registerHarness(definition: HarnessDefinition, reply: @escaping (String) -> Void) {
        registry.register(definition)
        reply(jsonString(["ok": true, "id": definition.id]))
    }

    func unregisterHarness(id: String, reply: @escaping (Bool) -> Void) {
        if let pid = registry.activePID(for: id) { stop(pid: pid) { _ in } }
        reply(registry.unregister(id))
    }

    func services(reply: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }

            let items: [[String: Any]] = self.registry.all().map { def in
                var e = def.params()
                if let pid = self.registry.activePID(for: def.id), self.processes[pid] != nil {
                    e["state"] = "running"
                    e["pid"] = Int(pid)
                } else {
                    e["state"] = "stopped"
                }
                return e
            }

            reply(jsonString(["ok": true, "services": items]))
        }
    }

    func startHarness(id: String, emit: @escaping (Int32, String) -> Void, ownerID: UUID, reply: @escaping (String) -> Void) {
        guard let def = registry.definition(for: id) else {
            reply(jsonString(["ok": false, "error": "service_not_found", "id": id]))
            return
        }

        queue.async { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }

            if let pid = self.registry.activePID(for: id), self.processes[pid] != nil {
                reply(jsonString(["ok": false, "error": "already_running", "pid": Int(pid)]))
                return
            }

            self.start(
                ownerID: ownerID,
                command: def.command,
                arguments: def.arguments,
                label: def.id,
                restartCount:  0,
                policy: def.policy,
                emit: emit
            ) { [weak self] pid, _, error in
                if let error {
                    reply(jsonString(["ok": false, "error": error]))
                } else {
                    self?.registry.setActivePID(pid, for: id)
                    reply(jsonString(["ok": true, "id": id, "pid": Int(pid)]))
                }
            }
        }
    }

    func stopHarness(id: String, reply: @escaping (Bool) -> Void) {
        guard let pid = registry.activePID(for: id) else { reply(false); return }
        stop(pid: pid, reply: reply)
    }

    func restartHarness(id: String,emit: @escaping (Int32, String) -> Void,ownerID: UUID,reply: @escaping (String) -> Void) {
        guard let def = registry.definition(for: id) else {
            reply(jsonString(["ok": false, "error": "service_not_found", "id": id]))
            return
        }

        queue.async(flags: .barrier) { [weak self] in
            guard let self else { reply(#"{"ok":false,"error":"service_unavailable"}"#); return }

            if let pid = self.registry.activePID(for: id),
               let tracked = self.processes[pid] {
                tracked.process.terminate()
                tracked.outputPipe.fileHandleForReading.readabilityHandler = nil
                tracked.inputPipe.fileHandleForWriting.closeFile()
                self.processes.removeValue(forKey: pid)
                self.registry.clearPID(for: id)
            }

            DispatchQueue.global().async { [weak self] in
                self?.start(ownerID: ownerID, command: def.command, arguments: def.arguments,
                            label: def.id, restartCount:  0, policy: def.policy,
                            emit: emit) { [ weak self] pid, _, error in

                    if let error { reply(jsonString(["ok": false, "error": error]))}
                    else { self?.registry.setActivePID(pid, for: id); reply(jsonString(["ok": true, "id": id, "pid": Int(pid)]))
                    }
                }
            }
        }
    }


    func request(
        ownerID: UUID, json: String,
        emit: @escaping (Int32, String) -> Void,
        reply: @escaping (String) -> Void) {

            guard let req = parseJSONDict(json) else {
                reply(#"{"ok":false,"error":"invalid_json"}"#)
                return
            }

            guard let action = req["action"] as? String else {
                reply(#"{"ok":false,"error":"missing_action"}"#)
                return
            }

            switch action {
            case "ping": reply(jsonString(["ok": true, "pong": true]))
            case "status": status(reply: reply)
            case "list": listJSON(reply: reply)
            case "inspect":
                guard let pid = Self.int32(from: req["pid"])
                else { reply(#"{"ok":false,"error":"missing_pid"}"#); return }
                inspect(pid: pid) { reply($0 ?? #"{"ok":false,"error":"pid_not_found"}"#) }

            case "start":
                let command = (req["command"] as? String) ?? ""
                let arguments = (req["arguments"] as? [String]) ?? []
                let label = req["label"] as? String
                let policy = HarnessPolicy.from(req["policy"] as? String)

                start(ownerID: ownerID, command: command, arguments: arguments,
                      label: label, policy: policy, emit: emit) { pid, _, error in
                    if let error { reply(jsonString(["ok": false, "error": error]))}
                    else { reply(jsonString(["ok": true, "pid": Int(pid)])) }
                }

            case "stop":
                guard let pid = Self.int32(from: req["pid"])
                else { reply(#"{"ok":false,"error":"missing_pid"}"#); return }
                stop(pid: pid) { ok in reply(jsonString(["ok": ok, "pid": Int(pid)]))}

            case "restart":
                guard let pid = Self.int32(from: req["pid"])
                else { reply(#"{"ok":false,"error":"missing_pid"}"#); return }
                restart(pid: pid, emit: emit) { newPid, _, error in
                    if let error { reply(jsonString(["ok": false, "error": error]))}
                    else { reply(jsonString(["ok": true, "pid": Int(newPid)]))}}

            case "write":
                guard let pid = Self.int32(from: req["pid"])
                else { reply(#"{"ok":false,"error":"missing_pid"}"#); return }
                guard let input = req["input"] as? String
                else { reply(#"{"ok":false,"error":"missing_input"}"#); return }
                let close = req["close"] as? Bool ?? false
                write(pid: pid, input: input, close: close, reply: reply)

            case "service/register":
                guard let def = HarnessDefinition(params: req)
                else { reply(#"{"ok":false,"error":"invalid_service_definition"}"#); return }
                registerHarness(definition: def, reply: reply)

            case "service/unregister":
                guard let id = req["id"] as? String
                else {reply(#"{"ok":false,"error":"missing_id"}"#); return }
                unregisterHarness(id: id) { ok in reply(jsonString(["ok": ok, "id": id])) }

            case "service/list":
                services(reply: reply)

            case "service/start":
                guard let id = req["id"] as? String
                else { reply(#"{"ok":false,"error":"missing_id"}"#); return }
                startHarness(id: id, emit: emit, ownerID: ownerID, reply: reply)

            case "service/stop":
                guard let id = req["id"] as? String
                else { reply(#"{"ok":false,"error":"missing_id"}"#); return }
                stopHarness(id: id) { ok in reply(jsonString(["ok": ok, "id": id])) }

            case "service/restart":
                guard let id = req["id"] as? String
                else { reply(#"{"ok":false,"error":"missing_id"}"#); return }
                restartHarness(id: id, emit: emit, ownerID: ownerID, reply: reply)

            default:
                reply(jsonString(["ok": false, "error": "unknown_action", "action": action]))
            }
        }

    private static func int32(from value: Any?) -> Int32? {
        switch value {
        case let v as Int32: return v
        case let v as Int: return Int32(v)
        case let v as NSNumber: return v.int32Value
        case let v as String: return Int32(v)
        default: return nil
        }
    }

    private static func expandVariables(in value: String, environment: [String: String]) -> String {
        guard !value.isEmpty else { return value }

        var result = ""
        var index = value.startIndex

        while index < value.endIndex {
            guard value[index] == "$" else {
                result.append(value[index])
                index = value.index(after: index)
                continue
            }

            let dollar = index
            let next = value.index(after: dollar)
            guard next < value.endIndex else {
                result.append("$")
                break
            }

            if value[next] == "{" {
                guard let close = value[value.index(after: next)...].firstIndex(of: "}") else {
                    result.append("$")
                    index = next
                    continue
                }

                let nameStart = value.index(after: next)
                let name = String(value[nameStart..<close])
                result.append(environment[name] ?? "")
                index = value.index(after: close)
                continue
            }

            var end = next
            while end < value.endIndex {
                let scalar = value[end].unicodeScalars.first
                let isIdentifier = scalar.map { CharacterSet.alphanumerics.contains($0) || $0 == "_" } ?? false
                guard isIdentifier else { break }
                end = value.index(after: end)
            }

            guard end > next else {
                result.append("$")
                index = next
                continue
            }

            let name = String(value[next..<end])
            result.append(environment[name] ?? "")
            index = end
        }

        return result
    }
}
