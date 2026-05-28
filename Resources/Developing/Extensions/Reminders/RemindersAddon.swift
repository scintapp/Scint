import Foundation


struct RemindersAddon: CommandAddon {
    private let interface = RemindersInterface()

    var commands: [AgencyCommand] {
        [
            AgencyCommand(path: ["reminders"], documentation: RemindersDocumentation.root, handler: interface.handleRoot),
            AgencyCommand(path: ["reminders", "create"], documentation: RemindersDocumentation.create, handler: interface.handleCreate),
            AgencyCommand(path: ["reminders", "view"], documentation: RemindersDocumentation.view, handler: interface.handleView),
            AgencyCommand(path: ["reminders", "update"], documentation: RemindersDocumentation.update, handler: interface.handleUpdate),
            AgencyCommand(path: ["reminders", "complete"], documentation: RemindersDocumentation.complete, handler: interface.handleComplete),
            AgencyCommand(path: ["reminders", "delete"], documentation: RemindersDocumentation.delete, handler: interface.handleDelete)
        ]
    }
}

struct ReminderFilters {
    let priority: Task.Priority?
    let dueFilter: DueFilter?
    let searchText: String?
    let includeCompleted: Bool

    var hasActiveFilters: Bool {
        priority != nil || dueFilter != nil || (searchText?.isEmpty == false)
    }
}

enum DueFilter {
    case exactDay(Date)
    case overdue
    case none

    func matches(_ dueDate: Date?) -> Bool {
        switch self {
        case .none:
            return dueDate == nil
        case .overdue:
            guard let dueDate else { return false }
            return dueDate < Calendar.current.startOfDay(for: Date())
        case .exactDay(let date):
            guard let dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }
    }
}

private final class RemindersInterface {
    private let bridge = RemindersBridge()
    private let renderer = RemindersRenderer()
    private let docs = Renderer()

    func handleRoot(context: CommandContext) async throws -> String {
        if context.invocation.options.has("help") {
            return docs.render(RemindersDocumentation.root)
        }

        if !context.invocation.positionals.isEmpty {
            throw CommandError.unsupportedArguments("Unknown reminders command: \(context.invocation.positionals[0])")
        }

        guard context.invocation.options.isEmpty else {
            if let query = context.invocation.options.value(for: "search") {
                let results = context.registry.searchDocumentation(scope: ["reminders"], query: query)
                return docs.renderSearch(scope: RemindersDocumentation.root, query: query, results: results)
            }

            throw CommandError.unsupportedArguments("`agency reminders` only supports `--help` and `--search` without a subcommand.")
        }

        return docs.render(RemindersDocumentation.root)
    }

    func handleView(context: CommandContext) async throws -> String {
        try await authorize()

        let filters = try makeFilters(from: context.invocation.options)
        let listQuery = context.invocation.options.value(for: "list")
        let lists = try await bridge.getLists(matching: listQuery)
        return renderer.renderLists(lists, filters: filters)
    }

    func handleCreate(context: CommandContext) async throws -> String {
        try await authorize()

        let title = context.invocation.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let listName = context.invocation.options.value(for: "list")

        if title.isEmpty {
            guard let listName, !listName.isEmpty else {
                throw CommandError.missingArgument("Provide a reminder title, or pass `--list <name>` to create a new list.")
            }

            let list = try bridge.createList(named: listName)
            return renderer.renderCreatedList(list)
        }

        let dueDate = try parseDueDate(context.invocation.options.value(for: "due"))
        let priority = try parsePriority(context.invocation.options.value(for: "priority"), allowNone: false) ?? .none
        let notes = context.invocation.options.value(for: "notes") ?? ""
        let url = try parseURL(context.invocation.options.value(for: "url"))
        let targetList = try await resolveList(named: listName)

        let task = Task(
            id: "",
            title: title,
            notes: notes,
            url: url,
            dueDate: dueDate,
            priority: priority,
            isCompleted: false
        )

        let created = try bridge.addTask(to: targetList.id, task: task)
        return renderer.renderCreatedReminder(created, listName: targetList.name)
    }

    func handleUpdate(context: CommandContext) async throws -> String {
        try await authorize()

        let query = context.invocation.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw CommandError.missingArgument("Tell me which reminder to update.")
        }

        let match = try await resolveReminder(named: query, listName: context.invocation.options.value(for: "list"), includeCompleted: true)

        var updated = match.task

        if let title = context.invocation.options.value(for: "title") {
            updated.title = title
        }

        if let notes = context.invocation.options.value(for: "notes") {
            updated.notes = notes
        }

        if context.invocation.options.has("due") {
            updated.dueDate = try parseDueDate(context.invocation.options.value(for: "due"))
        }

        if context.invocation.options.has("priority") {
            updated.priority = try parsePriority(context.invocation.options.value(for: "priority"), allowNone: true) ?? .none
        }

        let result = try bridge.updateTask(id: updated.id, with: updated)
        return renderer.renderUpdatedReminder(result)
    }

    func handleComplete(context: CommandContext) async throws -> String {
        try await authorize()

        guard !context.invocation.positionals.isEmpty else {
            throw CommandError.missingArgument("Name at least one reminder to complete.")
        }

        var completed: [Task] = []
        for query in context.invocation.positionals {
            let match = try await resolveReminder(named: query, listName: context.invocation.options.value(for: "list"), includeCompleted: false)
            completed.append(try bridge.completeTask(id: match.task.id))
        }

        return renderer.renderCompletedReminders(completed)
    }

    func handleDelete(context: CommandContext) async throws -> String {
        try await authorize()

        let query = context.invocation.positionals.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw CommandError.missingArgument("Tell me which reminder to delete.")
        }

        let match = try await resolveReminder(named: query, listName: context.invocation.options.value(for: "list"), includeCompleted: true)
        try bridge.deleteTask(id: match.task.id)
        return renderer.renderDeletedReminder(match.task)
    }

    private func authorize() async throws {
        do {
            try await bridge.authorize()
        } catch {
            throw CommandError.execution(error.localizedDescription)
        }
    }

    private func resolveList(named name: String?) async throws -> TaskList {
        if let name, !name.isEmpty {
            let lists = try await bridge.getLists(matching: name)
            guard let list = lists.first else {
                throw CommandError.notFound("List not found: \(name)")
            }
            return list
        }

        do {
            return try bridge.defaultList()
        } catch {
            throw CommandError.execution(error.localizedDescription)
        }
    }

    private func resolveReminder(named query: String, listName: String?, includeCompleted: Bool) async throws -> (list: TaskList, task: Task) {
        let lists = try await bridge.getLists(matching: listName)
        let normalized = query.lowercased()

        for list in lists {
            let candidates = includeCompleted ? list.tasks : list.activeTasks

            if let exact = candidates.first(where: { $0.id == query || $0.title.lowercased() == normalized }) {
                return (list, exact)
            }
        }

        for list in lists {
            let candidates = includeCompleted ? list.tasks : list.activeTasks

            if let fuzzy = candidates.first(where: { $0.title.lowercased().contains(normalized) }) {
                return (list, fuzzy)
            }
        }

        throw CommandError.notFound("Reminder not found: \(query)")
    }

    private func makeFilters(from options: CommandOptions) throws -> ReminderFilters {
        ReminderFilters(
            priority: try parsePriority(options.value(for: "priority"), allowNone: false),
            dueFilter: try parseDueFilter(options.value(for: "due")),
            searchText: options.value(for: "search"),
            includeCompleted: options.has("all")
        )
    }

    private func parsePriority(_ rawValue: String?, allowNone: Bool) throws -> Task.Priority? {
        guard let rawValue else { return nil }

        let normalized = rawValue.lowercased()
        if allowNone, normalized == "none" {
            return Task.Priority.none
        }

        guard let priority = Task.Priority(rawValue: normalized), priority != .none else {
            throw CommandError.invalidValue(flag: "priority", value: rawValue, expected: allowNone ? "`none`, `low`, `medium`, or `high`" : "`low`, `medium`, or `high`")
        }

        return priority
    }

    private func parseDueFilter(_ rawValue: String?) throws -> DueFilter? {
        guard let rawValue else { return nil }

        let normalized = rawValue.lowercased()
        if normalized == "overdue" {
            return .overdue
        }

        if normalized == "none" {
            return DueFilter.none
        }

        return .exactDay(try parseNamedDate(rawValue))
    }

    private func parseDueDate(_ rawValue: String?) throws -> Date? {
        guard let rawValue else { return nil }
        if rawValue.lowercased() == "none" {
            return nil
        }
        return try parseNamedDate(rawValue)
    }

    private func parseNamedDate(_ rawValue: String) throws -> Date {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current
        let now = Date()

        switch normalized {
        case "today":
            return calendar.startOfDay(for: now)
        case "tomorrow":
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        default:
            break
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        if let date = formatter.date(from: normalized) {
            return calendar.startOfDay(for: date)
        }

        let weekdayNames = formatter.weekdaySymbols.map { $0.lowercased() }
        if let weekdayIndex = weekdayNames.firstIndex(of: normalized) {
            let weekday = weekdayIndex + 1
            var components = DateComponents()
            components.weekday = weekday
            components.hour = 9
            components.minute = 0
            guard let date = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) else {
                throw CommandError.invalidValue(flag: "due", value: rawValue, expected: "`today`, `tomorrow`, a weekday, or `YYYY-MM-DD`")
            }
            return date
        }

        throw CommandError.invalidValue(flag: "due", value: rawValue, expected: "`today`, `tomorrow`, a weekday, or `YYYY-MM-DD`")
    }

    private func parseURL(_ rawValue: String?) throws -> URL? {
        guard let rawValue else { return nil }
        guard let url = URL(string: rawValue) else {
            throw CommandError.invalidValue(flag: "url", value: rawValue, expected: "a valid URL")
        }
        return url
    }
}
