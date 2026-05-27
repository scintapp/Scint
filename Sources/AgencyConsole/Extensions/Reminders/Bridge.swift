import EventKit
import Foundation


final class RemindersBridge {
    private let store = EKEventStore()
    private var authorized = false

    func authorize() async throws {
        guard !authorized else { return }

        let granted: Bool
        if #available(macOS 14.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                store.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }

        guard granted else {
            throw BridgeError.accessDenied
        }

        authorized = true
    }

    func getLists(matching query: String? = nil) async throws -> [TaskList] {
        let calendars = store.calendars(for: .reminder).filter { calendar in
            guard let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else {
                return true
            }

            return calendar.calendarIdentifier == query || calendar.title.localizedCaseInsensitiveContains(query)
        }

        var lists: [TaskList] = []
        for calendar in calendars {
            let tasks = await fetchTasks(in: calendar)
            lists.append(TaskList(id: calendar.calendarIdentifier, name: calendar.title, tasks: tasks))
        }

        return lists.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func defaultList() throws -> TaskList {
        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw BridgeError.noDefaultList
        }

        return TaskList(id: calendar.calendarIdentifier, name: calendar.title, tasks: [])
    }

    func createList(named name: String) throws -> TaskList {
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = name
        calendar.source = try resolveSource()
        try store.saveCalendar(calendar, commit: true)
        return TaskList(id: calendar.calendarIdentifier, name: calendar.title, tasks: [])
    }

    func addTask(to listID: String, task: Task) throws -> Task {
        let calendar = try findCalendar(id: listID)
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        apply(task, to: reminder)
        try store.save(reminder, commit: true)
        return makeTask(from: reminder)
    }

    func updateTask(id: String, with task: Task) throws -> Task {
        let reminder = try findReminder(id: id)
        apply(task, to: reminder)
        try store.save(reminder, commit: true)
        return makeTask(from: reminder)
    }

    func completeTask(id: String) throws -> Task {
        let reminder = try findReminder(id: id)
        reminder.isCompleted = true
        reminder.completionDate = Date()
        try store.save(reminder, commit: true)
        return makeTask(from: reminder)
    }

    func deleteTask(id: String) throws {
        let reminder = try findReminder(id: id)
        try store.remove(reminder, commit: true)
    }

    private func fetchTasks(in calendar: EKCalendar) async -> [Task] {
        await withCheckedContinuation { continuation in
            let predicate = store.predicateForReminders(in: [calendar])
            store.fetchReminders(matching: predicate) { [weak self] reminders in
                guard let self else {
                    return continuation.resume(returning: [])
                }

                let tasks = (reminders ?? []).map(self.makeTask).sorted(by: self.compare)
                continuation.resume(returning: tasks)
            }
        }
    }

    private func apply(_ task: Task, to reminder: EKReminder) {
        reminder.title = task.title
        reminder.notes = task.notes
        reminder.priority = task.priority.ekValue
        reminder.url = task.url
        reminder.isCompleted = task.isCompleted
        reminder.dueDateComponents = task.dueDate.map {
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .timeZone], from: $0)
        }
    }

    private func makeTask(from reminder: EKReminder) -> Task {
        Task(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes ?? "",
            url: reminder.url,
            dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
            priority: .from(ekValue: reminder.priority),
            isCompleted: reminder.isCompleted
        )
    }

    private func compare(_ lhs: Task, _ rhs: Task) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            return left == right ? lhs.title < rhs.title : left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.title < rhs.title
        }
    }

    private func resolveSource() throws -> EKSource {
        if let source = store.defaultCalendarForNewReminders()?.source {
            return source
        }

        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("iCloud") }) {
            return icloud
        }

        if let local = store.sources.first(where: { $0.sourceType == .local }) {
            return local
        }

        throw BridgeError.noSource
    }

    private func findReminder(id: String) throws -> EKReminder {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw BridgeError.taskNotFound(id)
        }

        return reminder
    }

    private func findCalendar(id: String) throws -> EKCalendar {
        guard let calendar = store.calendars(for: .reminder).first(where: {
            $0.calendarIdentifier == id || $0.title == id
        }) else {
            throw BridgeError.listNotFound(id)
        }

        return calendar
    }

    enum BridgeError: LocalizedError {
        case accessDenied
        case noDefaultList
        case noSource
        case taskNotFound(String)
        case listNotFound(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Reminders access denied."
            case .noDefaultList:
                return "No default Reminders list is configured."
            case .noSource:
                return "No calendar source is available for new Reminders lists."
            case .taskNotFound(let id):
                return "Task not found: \(id)"
            case .listNotFound(let id):
                return "List not found: \(id)"
            }
        }
    }
}
