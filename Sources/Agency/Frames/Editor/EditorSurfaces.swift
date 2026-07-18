import AgencyRuntime
import SwiftUI


struct EditorStatusBar: View {
    let sheet: Reference

    private var metrics: (words: Int, completedTasks: Int, totalTasks: Int) {
        Sheet.with(sheet) { sheet in
            let words = sheet.rendered.split(whereSeparator: { $0.isWhitespace }).count
            let tasks = sheet.blocks.compactMap { block -> Bool? in
                guard case .task(_, _, let completed) = block else { return nil }
                return completed
            }
            return (words, tasks.filter { $0 }.count, tasks.count)
        } ?? (0, 0, 0)
    }


    private var words: String {
        "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")"
    }

    private var tasks: String {
        "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")"
    }

    var body: some View {
        HStack(spacing: 28) {
            Text(words)
            Text(tasks)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 32)
    }
}
