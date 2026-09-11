import SwiftUI


struct NewSpacesList: NewQuery {
    static func params(_ model: any Model) -> NewParams {
        let workspace = model.session.workspace

        func spaces(of ref: Reference) -> [Reference] {
            let found = Space.with(ref, { $0.spaces }) ?? Workspace.with(ref, { $0.spaces }) ?? []
            return found.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
        }

        func space(_ ref: Reference) -> NewParams.Surface {
            let children = spaces(of: ref).map(space)

            guard !children.isEmpty else {
                return .item(
                    .init(
                        ref,
                        components: [.icon(), .text(.name)],
                        controls: [.action { model.select(ref) }]
                    )
                )
            }

            return .section(
                .init(
                    ref,
                    layout: .list,
                    components: [.icon(.stack), .text(.name)],
                    controls: [.action { model.select(ref) }],
                    params: children
                )
            )
        }

        return .surface(
            .section(
                .init(
                    id: "workspace",
                    layout: .list,
                    components: [.text(.literal("Spaces"))],
                    params: [space(workspace)]
                )
            )
        )
    }
}

struct NewSpaceSettings: NewQuery {
    static func params(_ model: any Model) -> NewParams {
        var space: Reference {
            if case .structure(let ref) = model.session.focus { return ref }
            else { return model.session.origin }
        }

        func configure(_ value: Value?, for key: String) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.configure(value, for: key) }
            else { Space.with(space, { $0 })?.configure(value, for: key) }
        }

        func load(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
            else { Space.update(space) { $0.harness = ref } }
        }

        func add(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(ref) }
            else { Space.with(space, { $0 })?.add(ref) }
        }

        func remove(_ ref: Reference) {
            if space.type is Workspace.Type { Workspace.with(space, { $0 })?.remove(ref) }
            else { Space.with(space, { $0 })?.remove(ref) }
        }

        func label(_ value: String) -> String {
            value.reduce(into: "") { label, character in
                if character == "-" || character == "_" { label.append(" ") }
                else {
                    if character.isUppercase, !label.isEmpty { label.append(" ") }
                    label.append(character)
                }
            }.capitalized
        }

        func leaf(_ value: Value) -> Value {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.map(leaf) ?? value
                case .sequence(let values) where values.count > 1: values.first.map(leaf) ?? value
                case .range(let values): values.first.map(leaf) ?? value
                default: value
            }
        }

        func scale(_ value: Value) -> [String] {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.map(scale) ?? []
                case .range(let values): values.compactMap { $0.rendered.last }
                default: []
            }
        }

        func choices(_ value: Value) -> [String] {
            switch value {
                case .collection(let values) where values.count == 1: values.values.first.map(choices) ?? []
                case .sequence(let values) where values.count > 1: values.compactMap { $0.rendered.last }
                case .range(let values): values.compactMap { $0.rendered.last }
                default: []
            }
        }

        func sorted(_ refs: [Reference]) -> [Reference] {
            refs.sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
        }

        // MARK: Harness

        let harnesses = sorted(Runtime.shared.all(as: Harness.self).map { $0.0 })
        let harness = Space.with(space, { $0.harness }).flatMap { $0 }
            ?? Workspace.with(space, { $0.harness }).flatMap { $0 }

        let declaration = harness.flatMap { ref in
            Harness.with(ref) { (intent: $0.intent, parameters: $0.parameters) }
        }

        let harnessSection = NewParams.Section(
            id: "harness",
            layout: .group,
            components: [.text(.literal("Harness"))],
            params: [
                .item(
                    .init(
                        id: "harness-loader",
                        ref: harness,
                        layout: .column,
                        components: harness == nil
                            ? [
                                .model(.harness(.executor)),
                                .text(.literal("No harness")),
                                .text(.detail("Pick one to configure this space."))
                              ]
                            : [.icon(), .text(.name), .text(.description)],
                        controls: [.load("Load", harnesses, load)]
                    )
                )
            ]
        )

        // MARK: Parameters

        let config = Space.with(space, { $0.config }) ?? Workspace.with(space, { $0.config }) ?? [:]

        let arguments: [Harness.Parameter] = {
            guard let declaration, declaration.intent == .evaluate || declaration.intent == .observe
            else { return [] }
            return declaration.parameters
        }()

        let parameters: [NewParams.Surface] = arguments.compactMap { parameter in
            guard case .argument(let key, let type, let required, let fallback) = parameter, !required
            else { return nil }

            let configured = config[key]
            let options = choices(type)
            let resting = fallback.map(leaf)?.rendered.last ?? ""
            let value = configured?.rendered.last ?? resting

            let control: NewParam.Control? = {
                let ordered = scale(type)
                if !ordered.isEmpty {
                    return .range(ordered, value, { picked in configure(.string(picked), for: key) })
                }

                if !options.isEmpty {
                    return .picker(["Default"] + options, configured == nil ? "Default" : value, { picked in
                        configure(picked == "Default" ? nil : .string(picked), for: key)
                    })
                }

                switch leaf(type) {
                    case .bool:
                        let active: Bool = if case .bool(let flag) = configured { flag } else { false }
                        return .toggle(active, { flag in configure(.bool(flag), for: key) })

                    case .date:
                        let date: Date = if case .date(let value) = configured { value } else { .now }
                        return .date(date, { picked in configure(.date(picked), for: key) })

                    case .string, .integer, .decimal:
                        return .field(value, { entered in
                            configure(entered.isEmpty ? nil : .string(entered), for: key)
                        })

                    case .sequence, .range, .collection, .reference:
                        return nil
                }
            }()

            guard let control else { return nil }

            return .item(
                .init(
                    id: key,
                    layout: .row,
                    components: [
                        .symbol("slider.horizontal.3", Style.Tint.command),
                        .text(.literal(label(key)))
                    ],
                    controls: [control]
                )
            )
        }

        let parametersSection = NewParams.Section(
            id: "parameters",
            layout: .group,
            components: [.text(.literal("Parameters"))],
            params: parameters
        )

        let loadedCommands = Space.with(space, { $0.commands }) ?? Workspace.with(space, { $0.commands }) ?? []

        let library = sorted(Runtime.shared.all(as: Command.self).map { $0.0 })
            .filter { !loadedCommands.contains($0) }

        let commandsSection = NewParams.Section(
            id: "commands",
            layout: .group,
            components: [.text(.literal("Commands"))],
            params: [
                .item(
                    .init(
                        id: "add-command",
                        layout: .row,
                        components: [
                            .model(.material(.command)),
                            .text(.literal("Add Command..."))
                        ],
                        controls: [.load("Load", library, add)]
                    )
                )
            ] + sorted(loadedCommands).map { ref in
                NewParams.Surface.item(
                    .init(
                        ref,
                        layout: .row,
                        components: [.icon(), .text(.name)],
                        controls: [.button("Remove", { remove(ref) })]
                    )
                )
            }
        )

        let loadedArtifacts = Space.with(space, { $0.artifacts }) ?? Workspace.with(space, { $0.artifacts }) ?? []
        let artifactsSection = NewParams.Section(
            id: "artifacts",
            layout: .group,
            components: [.text(.literal("Artifacts"))],
            params: sorted(loadedArtifacts).map { ref in
                NewParams.Surface.item(
                    .init(
                        ref,
                        layout: .row,
                        components: [.icon(), .text(.name)],
                        controls: [.button("Remove", { remove(ref) })]
                    )
                )
            } + [
                .item(
                    .init(
                        id: "add-files",
                        layout: .row,
                        components: [
                            .symbol("folder.badge.plus", Style.Tint.artifact),
                            .text(.literal("Add Files..."))
                        ],
                        controls: [
                            .button("Add", {
                                let picker = NSOpenPanel()
                                picker.title = "Add Files or Folders"
                                picker.prompt = "Add"
                                picker.canChooseFiles = true
                                picker.canChooseDirectories = true
                                picker.allowsMultipleSelection = true
                                guard picker.runModal() == .OK else { return }
                                for url in picker.urls { add(Artifact.register(url.lastPathComponent, url)) }
                            })
                        ]
                    )
                )
            ]
        )

        return .surface(
            .section(
                .init(
                    id: "settings",
                    layout: .list,
                    params: [
                        .section(harnessSection),
                        .section(parametersSection),
                        .section(commandsSection),
                        .section(artifactsSection)
                    ]
                )
            )
        )
    }
}
