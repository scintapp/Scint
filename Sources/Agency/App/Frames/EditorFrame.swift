import AgencyRuntime
import SwiftUI


struct EditorStatusBar: View {
    @Environment(AgencyModel.self) var agency
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


    private var wordLabel: String {
        "\(metrics.words) \(metrics.words == 1 ? "Word" : "Words")"
    }

    private var taskLabel: String {
        "\(metrics.completedTasks) of \(metrics.totalTasks) \(metrics.totalTasks == 1 ? "Task" : "Tasks")"
    }

    var body: some View {
        HStack(spacing: 28) {
            Text(wordLabel)
            Text(taskLabel)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 32)
    }
}

struct EditorFrame: View {
    @Environment(AgencyModel.self) var agency
    let sheet: Reference

    var toolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .principal) {
                Text(agency.session.active?.descriptor.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .primaryAction) {
                Button { } label: {
                    Label("Search", systemImage: "play.fill")
                }
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(placement: .primaryAction) {
                Button { } label: {
                    Label("Search", systemImage: "info.circle")
                }
            }
        }
    }

    var body: some View {
        VStack {
            ScrollView {
                Color.clear
                    .frame(height: 32)
                EditorComponent(sheet)
                    .frame(maxWidth: 700, maxHeight: .infinity, alignment: .top)
                Color.clear
                    .frame(height: 128)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
        }
        .background(Design.Background.editor)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
        .safeAreaBar(edge: .bottom) { EditorStatusBar(sheet: sheet) }
        .toolbar(removing: .title)
        .toolbar { toolbar }
    }
}
