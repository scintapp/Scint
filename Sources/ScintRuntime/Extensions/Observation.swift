import Foundation


struct Schedule: Codable, Sendable, Equatable {
    var anchor: Date
    var recurrence: Recurrence

    enum Recurrence: String, Codable, Sendable, CaseIterable {
        case never, hourly, daily, weekly

        var label: String { rawValue.capitalized }

        var step: (component: Calendar.Component, value: Int)? {
            switch self {
                case .never: nil
                case .hourly: (.hour, 1)
                case .daily: (.day, 1)
                case .weekly: (.weekOfYear, 1)
            }
        }
    }

    func next(after moment: Date = .now, calendar: Calendar = .current) -> Date? {
        if anchor > moment { return anchor }
        guard let step = recurrence.step else { return nil }

        var candidate = anchor
        var iterations = 0
        while candidate <= moment, iterations < 100_000 {
            guard let advanced = calendar.date(byAdding: step.component, value: step.value, to: candidate)
                    else { return nil }
            candidate = advanced
            iterations += 1
        }
        return candidate > moment ? candidate : nil
    }
}

extension Schedule {
    static let dateFormat = "yyyy-MM-dd"
    static let timeFormat = "HH:mm"

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    static func date(_ value: String) -> Date? { formatter(dateFormat).date(from: value) }

    static func time(_ value: String) -> DateComponents? {
        guard let parsed = formatter(timeFormat).date(from: value) else { return nil }
        return Calendar.current.dateComponents([.hour, .minute], from: parsed)
    }

    static func render(date: Date) -> String { formatter(dateFormat).string(from: date) }
    static func render(time: Date) -> String { formatter(timeFormat).string(from: time) }
}

