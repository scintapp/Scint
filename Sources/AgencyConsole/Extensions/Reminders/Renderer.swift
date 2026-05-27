import Foundation


struct RemindersRenderer {
    func renderLists(_ lists: [TaskList], filters: ReminderFilters) -> String {
        let visibleLists = lists
            .map { list in
                TaskList(id: list.id, name: list.name, tasks: filter(tasks: list.tasks, using: filters))
            }
            .filter { filters.includeCompleted ? !$0.tasks.isEmpty || !filters.hasActiveFilters : !$0.activeTasks.isEmpty || !filters.hasActiveFilters }

        if visibleLists.isEmpty {
            return """
            AGENCY / REMINDERS / VIEW

            No reminders matched the current filters.
            """
        }

        var lines = ["AGENCY / REMINDERS / VIEW", ""]

        for (index, list) in visibleLists.enumerated() {
            let tasks = filters.includeCompleted ? list.tasks : list.activeTasks
            lines.append("\(list.name) (\(tasks.count) \(tasks.count == 1 ? "item" : "items"))")

            if tasks.isEmpty {
                lines.append("  no matching reminders")
            } else {
                lines.append(contentsOf: tasks.map(renderTask))
            }

            if index < visibleLists.count - 1 {
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    func renderCreatedReminder(_ task: Task, listName: String) -> String {
        "Created reminder in \(listName): \(task.title)"
    }

    func renderCreatedList(_ list: TaskList) -> String {
        "Created list: \(list.name)"
    }

    func renderUpdatedReminder(_ task: Task) -> String {
        "Updated reminder: \(task.title)"
    }

    func renderCompletedReminders(_ tasks: [Task]) -> String {
        let titles = tasks.map(\.title).joined(separator: ", ")
        return "Completed \(tasks.count) reminder\(tasks.count == 1 ? "" : "s"): \(titles)"
    }

    func renderDeletedReminder(_ task: Task) -> String {
        "Deleted reminder: \(task.title)"
    }

    private func filter(tasks: [Task], using filters: ReminderFilters) -> [Task] {
        tasks.filter { task in
            if !filters.includeCompleted && task.isCompleted {
                return false
            }

            if let priority = filters.priority, task.priority != priority {
                return false
            }

            if let query = filters.searchText?.lowercased(), !query.isEmpty {
                let haystack = "\(task.title) \(task.notes)".lowercased()
                if !haystack.contains(query) {
                    return false
                }
            }

            if let due = filters.dueFilter, !due.matches(task.dueDate) {
                return false
            }

            return true
        }
    }

    private func renderTask(_ task: Task) -> String {
        var details: [String] = []

        if task.priority != .none {
            details.append(task.priority.rawValue)
        }

        if let dueDate = task.dueDate {
            details.append("due \(format(dueDate))")
        }

        let suffix = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
        let marker = task.isCompleted ? "[x]" : "[ ]"
        return "  \(marker) \(task.title)\(suffix)"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
