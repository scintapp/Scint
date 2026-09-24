import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskSheet: Surface {
    var panel: any Panel
    var model: any Model

    @State private var scheduling = false

    var ref: Reference? { model.session.opened.document }
    var surface: AnySurface { .init(panel: panel, model: model) }

    var commands: [Reference] { Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name } }

    var body: some View {
        ScrollView {
            if let ref, let task = TasksContent.sheet(ref) {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    HStack(alignment: .center, spacing: Style.Spacing.icon) {
                        Button { TasksContent.update(ref, task: task.id) { .task($0, $1, !$2, $3) } } label: {
                            TaskCompletionIndicator(completed: task.done)
                        }
                        .buttonStyle(.plain)

                        TextField("Task", text: Binding(
                            get: { task.text },
                            set: { text in TasksContent.update(ref, task: task.id) { id, _, done, when in .task(id, text, done, when) } }
                        ))
                        .textFieldStyle(.plain)
                        .font(Typography.heading(1))
                    }

                    Divider()

                    HStack(spacing: Style.Spacing.label) {
                        SwiftUI.Menu {
                            ForEach(commands) { command in
                                Button(command.descriptor.name) {
                                    Document.update(ref) { $0.update(.command(command), at: 1) }
                                    TasksContent.schedule(ref)
                                }
                            }
                        } label: {
                            Label { Text(task.command.descriptor.name) } icon: { Iconography.icon(for: task.command) }
                        }
                        .menuStyle(.button)
                        .buttonStyle(.soft)
                        .controlSize(.small)
                        .fixedSize()

                        Button { scheduling = true } label: {
                            Label(task.when.map { $0.moment.formatted(date: .abbreviated, time: .shortened) } ?? "Schedule", systemImage: "calendar")
                        }
                        .buttonStyle(.soft)
                        .controlSize(.small)
                        .popover(isPresented: $scheduling) {
                            VStack(alignment: .leading, spacing: Style.Spacing.label) {
                                let moment = Binding(
                                    get: { task.when?.moment ?? .now },
                                    set: { moment in TasksContent.update(ref, task: task.id) { .task($0, $1, $2, When(moment, repeats: $3?.repeats ?? .never)) } }
                                )

                                DatePicker("", selection: moment, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()

                                DatePicker("", selection: moment, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.stepperField)
                                    .labelsHidden()

                                Picker("Repeat", selection: Binding(
                                    get: { task.when?.repeats ?? .never },
                                    set: { repeats in TasksContent.update(ref, task: task.id) { id, text, done, when in .task(id, text, done, When(when?.moment ?? .now, repeats: repeats)) } }
                                )) {
                                    ForEach(When.Repeat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                if task.when != nil {
                                    Button("Clear Schedule") { TasksContent.update(ref, task: task.id) { id, text, done, _ in .task(id, text, done, nil) } }
                                }
                            }
                            .padding(Style.Spacing.tile)
                        }
                    }

                    if let space = Document.with(ref, { $0.origin }) {
                        let rows = HarnessGroup.settings(Command.with(task.command, { $0.parameters }) ?? [], in: space)
                        if !rows.isEmpty {
                            Factory.build(surface, params: SectionParams(id: "parameters", name: "Parameters", header: false, items: rows), controls: HarnessGroup.controls(for: space), layout: .group)
                        }
                    }

                    Divider()

                    BlockList(document: task.material, autofocus: false)
                        .id(task.material)
                }
                .frame(maxWidth: Typography.Prose.readableWidth, alignment: .leading)
                .padding(Style.Spacing.page)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Style.Background.canvas)
    }
}
