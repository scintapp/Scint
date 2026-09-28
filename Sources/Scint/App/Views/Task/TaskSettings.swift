import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskTitle: View {
    let ref: Reference

    var name: Binding<String> {
        Binding(
            get: { Sheet.with(ref) { $0.name } ?? "" },
            set: { text in Sheet.update(ref) { $0.name = text } }
        )
    }

    var body: some View {
        if let done = Sheet.with(ref, { $0.done }) {
            HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.label) {
                Button { Sheet.update(ref) { $0.done = !done } } label: { TaskCompletionIndicator(completed: done, size: 18) }
                    .buttonStyle(.plain)

                TextField("Task", text: name, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Typography.heading(3))
            }
        }
    }
}

struct TaskNotes: View {
    let ref: Reference

    @State private var note = ""

    /// Appends the note to the end of the task's document.
    func append() {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let material = Sheet.with(ref, { $0.material }) ?? nil else { return }
        Document.update(material) { $0.insert(.text(UUID(), text), at: nil) }
        note = ""
    }

    var body: some View {
        GroupLayout(title: "Notes", footer: nil) {
            TextField("Add a note…", text: $note, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .onSubmit(append)
        }
    }
}

struct TaskSettings: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.selection.content }

    var summary: String {
        guard let ref else { return "" }
        return DocumentMapper.summary(ref)
    }

    var body: some View {
        ScrollView {
            if let ref {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    TaskTitle(ref: ref)

                    VStack(alignment: .leading) {
                        TaskSpace(ref: ref, scope: model.session.projects)
                        HStack { TaskTime(ref: ref) }
                    }

                    Divider()

                    GroupLayout(title: "Description", footer: nil) {
                        Text(summary.isEmpty ? "No description" : summary)
                            .foregroundStyle(summary.isEmpty ? Style.Foreground.subtle : Style.Foreground.primary)
                            .lineSpacing(Typography.Prose.lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }

                    TaskSetup(panel: panel, model: model)

                    TaskNotes(ref: ref)
                        .id(ref)
                }
                .font(Typography.body)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(20)
            }
        }
    }
}

