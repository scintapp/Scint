import SwiftUI
import ScintRuntime
import ScintComponents


struct TaskSheet: Surface {
    @State private var scheduling = false
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var commands: [Reference] { Runtime.shared.all(as: Command.self).map { $0.0 }.sorted { $0.descriptor.name < $1.descriptor.name } }
    var surface: AnySurface { .init(panel: panel, model: model) }

    var body: some View {
        ScrollView {
            if let ref, case let (command?, material?, when)? = Sheet.with(ref, { ($0.command, $0.material, $0.when) }) {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    TaskHeader(ref: ref, onStart: { model.start(ref) }, onStop: { model.stop(ref) })

                    Divider()

                    HStack(spacing: Style.Spacing.label) {
                        SwiftUI.Menu {
                            ForEach(commands) { option in
                                Button(option.descriptor.name) {
                                    Sheet.update(ref) { $0.command = option }
                                    model.start(ref)
                                }
                            }
                        } label: {
                            Label { Text(command.descriptor.name) } icon: { Iconography.icon(for: command) }
                        }
                        .menuStyle(.button)
                        .buttonStyle(.soft)
                        .controlSize(.small)
                        .fixedSize()

                        Button { scheduling = true } label: {
                            Label(when.map { $0.moment.formatted(date: .abbreviated, time: .shortened) } ?? "Schedule", systemImage: "calendar")
                        }
                        .buttonStyle(.soft)
                        .controlSize(.small)
                        .popover(isPresented: $scheduling) {
                            VStack(alignment: .leading, spacing: Style.Spacing.label) {
                                let moment = Binding(
                                    get: { when?.moment ?? .now },
                                    set: { moment in
                                        Sheet.update(ref) { $0.when = When(moment, repeats: $0.when?.repeats ?? .never) }
                                        model.start(ref)
                                    }
                                )

                                DatePicker("", selection: moment, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()

                                DatePicker("", selection: moment, displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(.stepperField)
                                    .labelsHidden()

                                Picker("Repeat", selection: Binding(
                                    get: { when?.repeats ?? .never },
                                    set: { repeats in
                                        Sheet.update(ref) { $0.when = When($0.when?.moment ?? .now, repeats: repeats) }
                                        model.start(ref)
                                    }
                                )) {
                                    ForEach(When.Repeat.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                if when != nil {
                                    Button("Clear Schedule") {
                                        Sheet.update(ref) { $0.when = nil }
                                        model.stop(ref)
                                    }
                                }
                            }
                            .padding(Style.Spacing.tile)
                        }
                    }

                    if let space = Sheet.with(ref, { $0.origin }) {
                        let config: [String: Value] = if case .collection(let values)? = Space.with(space, { $0.config[ref] }) ?? nil { values } else { [:] }
                        let rows = HarnessGroup.settings(Command.with(command, { $0.parameters }) ?? [], config: config)
                        if !rows.isEmpty {
                            Factory.build(surface, params: SectionParams(id: "parameters", name: "Parameters", header: false, items: rows), controls: HarnessGroup.controls(for: space, owner: ref), layout: .group)
                        }
                    }

                    BlockList(document: material, autofocus: false)
                        .id(material)
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
