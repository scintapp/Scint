import Foundation


struct Task: Identifiable, Sendable {
    let id: String
    var title: String
    var notes: String
    var url: URL?
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool

    enum Priority: String, Codable, Sendable {
        case none
        case low
        case medium
        case high

        var ekValue: Int {
            switch self {
            case .high: return 1
            case .medium: return 5
            case .low: return 9
            case .none: return 0
            }
        }

        static func from(ekValue: Int) -> Priority {
            switch ekValue {
            case 1: return .high
            case 5: return .medium
            case 9: return .low
            default: return .none
            }
        }
    }

    init(
        id: String,
        title: String,
        notes: String = "",
        url: URL? = nil,
        dueDate: Date? = nil,
        priority: Priority = .none,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.url = url
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
    }
}

struct TaskList: Identifiable, Sendable {
    let id: String
    let name: String
    let tasks: [Task]

    var activeTasks: [Task] {
        tasks.filter { !$0.isCompleted }
    }
}
