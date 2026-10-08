import SwiftUI
import ScintRuntime
import ScintComponents


//struct TaskTitle: View {
//    let ref: Reference
//
//    var task: Block? { Document.with(ref, { $0.blocks.first }) ?? nil }
//
//    var name: Binding<String> {
//        Binding(
//            get: { if case .task(_, let text, _, _)? = task { text } else { "" } },
//            set: { text in
//                guard case .task(let id, _, let done, let when)? = task else { return }
//                Document.update(ref) { $0.update(.task(id, text, done, when), at: 0) }
//            }
//        )
//    }
//
//    var body: some View {
//        if case .task(let id, let text, let done, let when)? = task {
//            HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.label) {
//                Button { Document.update(ref) { $0.update(.task(id, text, !done, when), at: 0) } } label: { TaskCompletionIndicator(completed: done, size: 18) }
//                    .buttonStyle(.plain)
//
//                TextField("Task", text: name, axis: .vertical)
//                    .textFieldStyle(.plain)
//                    .font(Typography.heading(3))
//            }
//        }
//    }
//}

//struct TaskNotes: View {
//    let ref: Reference
//
//    @State private var note = ""
//
//    func append() {
//        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !text.isEmpty else { return }
//        Document.update(ref) { $0.insert(.text(UUID(), text), at: nil) }
//        note = ""
//    }
//
//    var body: some View {
//        GroupLayout(title: "Notes", footer: nil) {
//            TextField("Add a note…", text: $note, axis: .vertical)
//                .textFieldStyle(.plain)
//                .padding(12)
//                .onSubmit(append)
//        }
//    }
//}

//struct TaskSettings: Surface {
//    var host: any Host
//    var model: any Model
//
//    var ref: Reference? { model.session.selection.content }
//
//    var summary: String {
//        guard let ref else { return "" }
//        return DocumentMapper.summary(ref)
//    }
//
//    var body: some View {
//        ScrollView {
//            if let ref {
//                VStack(alignment: .leading, spacing: Style.Spacing.section) {
//                    TaskTitle(ref: ref)
//
//                    VStack(alignment: .leading) {
//                        TaskSpace(ref: ref, scope: model.session.projects)
//                        HStack { TaskTime(ref: ref) }
//                    }
//
//                    Divider()
//
//                    GroupLayout(title: "Description", footer: nil) {
//                        Text(summary.isEmpty ? "No description" : summary)
//                            .foregroundStyle(summary.isEmpty ? Style.Foreground.subtle : Style.Foreground.primary)
//                            .lineSpacing(Typography.Prose.lineSpacing)
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .padding(12)
//                    }
//
//                    TaskSetup(host: host, model: model)
//
//                    TaskNotes(ref: ref)
//                        .id(ref)
//                }
//                .font(Typography.body)
//                .frame(maxWidth: .infinity, alignment: .topLeading)
//                .padding(20)
//            }
//        }
//    }
//}

