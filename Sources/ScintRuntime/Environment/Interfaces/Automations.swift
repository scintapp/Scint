import Foundation


enum Automation {
    static let schedule = "Schedule Job"
    static let unschedule = "Remove Job"

    static let parameters: [Harness.Parameter] = [
        .argument(name: "date", type: .date(.distantPast)),
        .argument(name: "time", type: .date(.distantPast)),
        .argument(
            name: "repeat",
            type: .sequence([.string("never"), .string("hourly"), .string("daily"), .string("weekly")]),
            default: .string("never")
        ),
        .argument(name: "command", type: .reference(Command.self))
    ]

    private enum When {
        case at(Date)
        case cron(String)
    }

    static func job(_ space: Reference) -> String { "scint-\(space.id.uuidString.lowercased())" }

    static func start(_ space: Reference) {
        let config = Space.with(space, { $0.config }) ?? [:]
        guard case .reference(let target)? = config["command"],
              let command = Command.with(target, { $0 }),
              let executable = command.executable,
              let when = when(config)
                else { return }

        let line = ([executable] + command.arguments()).map(quote).joined(separator: " ")
        var values: [String: Value] = [
            "name": .string(job(space)),
            "command": .collection(["--command": .string(line)])
        ]
        switch when {
            case .at(let date): values["at"] = .collection(["--at": .string(Value.formatter.string(from: date))])
            case .cron(let expression): values["cron"] = .collection(["--cron": .string(expression)])
        }

        run(unschedule, ["name": .string(job(space))]) { run(schedule, values) }
    }

    static func stop(_ space: Reference) {
        run(unschedule, ["name": .string(job(space))])
    }

    private static func when(_ config: Config) -> When? {
        func date(_ key: String) -> Date? {
            switch config[key] {
                case .date(let value)?: value
                case .string(let value)?: Value.formatter.date(from: value)
                default: nil
            }
        }

        let day = date("date")
        let time = date("time")
        let recurrence = config["repeat"]?.rendered.last ?? "never"
        guard day != nil || time != nil || recurrence != "never" else { return nil }

        let calendar = Calendar.current
        let dayParts = calendar.dateComponents([.year, .month, .day, .weekday], from: day ?? .now)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time ?? day ?? .now)
        let hour = timeParts.hour ?? 0
        let minute = timeParts.minute ?? 0

        switch recurrence {
            case "hourly": return .cron("\(minute) * * * *")
            case "daily": return .cron("\(minute) \(hour) * * *")
            case "weekly": return .cron("\(minute) \(hour) * * \((dayParts.weekday ?? 1) - 1)")
            default:
                var moment = dayParts
                moment.weekday = nil
                moment.hour = hour
                moment.minute = minute
                return calendar.date(from: moment).map(When.at)
        }
    }

    private static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func run(_ name: String, _ values: [String: Value], then next: (@Sendable @MainActor () -> Void)? = nil) {
        guard let command = Runtime.shared.all(as: Command.self).first(where: { $0.0.descriptor.name == name })?.1
                else { return }
        guard let next else { _ = command.run(values); return }
        _ = command.run(values) { line in
            guard Handler.exit(of: line) != nil else { return }
            Task { @MainActor in next() }
        }
    }
}

