import AgencyRuntime
import SwiftUI


struct SpaceInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.space ?? model.session.workspace }
        }

        let closure = (Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure }))!

        return .init(
            onToggle: { item in
                guard let key = item.key else { return }
                Closure.update(closure) {
                    var arguments = $0.arguments ?? [:]
                    arguments[key] = .bool(!item.active)
                    $0.arguments = arguments.isEmpty ? nil : arguments
                }
            },
            onChange: { item, selection in
                guard let key = item.key else { return }
                Closure.update(closure) {
                    var arguments = $0.arguments ?? [:]
                    if let value = selection.value { arguments[key] = .string(value) }
                    else { arguments.removeValue(forKey: key) }
                    $0.arguments = arguments.isEmpty ? nil : arguments
                }
            },
            onValueChange: { item, value in
                guard let key = item.key else { return }
                Closure.update(closure) {
                    var arguments = $0.arguments ?? [:]
                    if value.isEmpty { arguments.removeValue(forKey: key) }
                    else { arguments[key] = .string(value) }
                    $0.arguments = arguments.isEmpty ? nil : arguments
                }
            },
            onSelect: { item in
                guard let ref = item.ref, !item.active else { return }
                Closure.update(closure) { $0.interfaces.insert(ref) }
            },
            onAction: { item in
                if let ref = item.ref, ref.type is Harness.Type {
                    if space.type is Workspace.Type { Workspace.update(space) { $0.harness = ref } }
                    else { Space.update(space) { $0.harness = ref } }
                    return
                }
                if let ref = item.ref, ref.type is Artifact.Type {
                    Closure.update(closure) { $0.content.remove(ref) }
                    return
                }

                let panel = NSOpenPanel()
                panel.title = "Add Files or Folders"
                panel.prompt = "Add"
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                guard panel.runModal() == .OK else { return }
                for url in panel.urls {
                    let artifact = Artifact.register(url.lastPathComponent, url)
                    if space.type is Workspace.Type { Workspace.with(space, { $0 })?.add(artifact) }
                    else { Space.with(space, { $0 })?.add(artifact) }
                }
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        var space: Reference {
            if case .structure(let ref) = model.session.focused { return ref }
            else { return model.session.space ?? model.session.workspace }
        }

        let closure = (Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure }))!
        let harnesses = Closure.with(closure, { $0.harnesses })!
        let activeHarness = Space.with(space, { $0.harness }).flatMap { $0 } ?? Workspace.with(space, { $0.harness })
        let configured = Closure.with(closure, { $0.arguments ?? [:] }) ?? [:]
        let parameters = activeHarness.flatMap { Harness.with($0, { $0.parameters }) } ?? []

        var executionItems: [ItemParams] = []
        for parameter in parameters {
            guard case .argument(let key, let type, let required, let defaultValue) = parameter,
                  !required,
                  !key.hasPrefix("agency.")
            else { continue }

            let selected: String? = if case .string(let value) = configured[key] { value } else { nil }

            if key == "model" {
                var values: [ItemParams] = [
                    .init(name: "GPT-5.6 Sol", value: "gpt-5.6-sol"),
                    .init(name: "GPT-5.6 Terra", value: "gpt-5.6-terra"),
                    .init(name: "GPT-5.6 Luna", value: "gpt-5.6-luna"),
                    .init(name: "GPT-5.5", value: "gpt-5.5"),
                    .init(name: "GPT-5.4", value: "gpt-5.4"),
                    .init(name: "GPT-5.4 Mini", value: "gpt-5.4-mini")
                ]
                for value in [selected].compactMap({ $0 }) where !values.contains(where: { $0.value == value }) {
                    values.append(.init(name: value, value: value))
                }
                executionItems.append(
                    .init(
                        key: key,
                        name: "Model",
                        image: "cpu",
                        tint: Design.Tint.harness,
                        trailingKind: .picker,
                        value: selected ?? "",
                        items: [.init(name: "Default")] + values
                    )
                )
                continue
            }

            if key == "reasoningEffort" {
                executionItems.append(
                    .init(
                        key: key,
                        name: "Reasoning Effort",
                        image: "gauge.with.dots.needle.50percent",
                        tint: Design.Tint.harness,
                        trailingKind: .picker,
                        value: selected ?? "",
                        items: [
                            .init(name: "Default"),
                            .init(name: "Low", value: "low"),
                            .init(name: "Medium", value: "medium"),
                            .init(name: "High", value: "high"),
                            .init(name: "Extra High", value: "xhigh"),
                            .init(name: "Maximum", value: "max"),
                            .init(name: "Ultra", value: "ultra")
                        ]
                    )
                )
                continue
            }

            if key == "sandbox" {
                executionItems.append(
                    .init(
                        key: key,
                        name: "Sandbox",
                        image: "lock.shield",
                        tint: Design.Tint.command,
                        trailingKind: .picker,
                        value: selected ?? "",
                        items: [
                            .init(name: "Default"),
                            .init(name: "Read Only", value: "read-only"),
                            .init(name: "Workspace Write", value: "workspace-write"),
                            .init(name: "Full Access", value: "danger-full-access")
                        ]
                    )
                )
                continue
            }

            if case .bool = type {
                let fallback = defaultValue.flatMap { value -> Bool? in
                    guard case .bool(let value) = value else { return nil }
                    return value
                } ?? false
                executionItems.append(
                    .init(
                        key: key,
                        name: key.capitalized,
                        image: "switch.2",
                        tint: Design.Tint.command,
                        trailingKind: .toggle,
                        active: configured[key].flatMap { if case .bool(let value) = $0 { value } else { nil } } ?? fallback
                    )
                )
            } else if case .string = type {
                executionItems.append(
                    .init(
                        key: key,
                        name: key.capitalized,
                        image: "slider.horizontal.3",
                        tint: Design.Tint.command,
                        trailingKind: .field,
                        value: selected ?? ""
                    )
                )
            }
        }

        let artifacts = Closure.with(closure, { $0.artifacts })!.filter { ref in
            Artifact.with(ref) { artifact in
                switch artifact.handler {
                    case .app, .file, .image, .script, .skill, .exec: true
                    case .http: false
                }
            }!
        }.map { ref in
            ItemParams(
                ref: ref,
                name: ref.descriptor.name,
                trailingKind: .remove
            )
        }

        let library = Runtime.shared.all(as: Harness.self)
            .map { $0.0 }
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    description: ref.descriptor.description,
                    active: harnesses.contains(ref)
                )
            }

        let loaded = harnesses
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
            .map { ref in
                let icon = Iconography.icon(for: ref)
                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    image: icon.symbol,
                    tint: icon.tint,
                    trailingKind: ref == activeHarness ? .value : .action,
                    value: ref == activeHarness ? "Active" : "Activate",
                    description: ref.descriptor.description
                )
            }

        let loaderIcon = Iconography.Icon(symbol: "plus", tint: Design.Tint.harness)

        var components: [ComponentParams] = [
            .init(
                id: "harnesses",
                name: "Harnesses",
                items: [
                    .init(
                        name: "Harness Library",
                        image: loaderIcon.symbol,
                        tint: loaderIcon.tint,
                        trailingKind: .load,
                        count: harnesses.count,
                        items: library
                    )
                ] + loaded
            )
        ]
        if !executionItems.isEmpty {
            components.append(.init(id: "execution", name: "Execution", items: executionItems))
        }
        components.append(
            .init(
                id: "files",
                name: "Files & Folders",
                items: [
                    .init(
                        key: "add-files",
                        name: "Add Files...",
                        image: "folder.badge.plus",
                        tint: Design.Tint.artifact,
                        trailingKind: .button
                    )
                ] + artifacts
            )
        )

        return .init(
            ref: space,
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: components
        )
    }
}

struct SheetInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                model.select(ref, entry: item.entryId, url: item.path)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        func item(for block: Sheet.Block, owner: Reference) -> ItemParams {
            let icon = Iconography.icon(for: block)

            switch block {
                case .artifact(let ref), .command(let ref):
                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description
                    )
                case .text(let id, let text):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: text,
                        image: icon.symbol,
                        tint: icon.tint
                    )
                case .sheet(let ref):
                    let children = Sheet.with(ref, { sheet in
                        sheet.blocks.map { item(for: $0, owner: ref) }
                    }) ?? []

                    return .init(
                        ref: ref,
                        origin: owner,
                        name: ref.descriptor.name,
                        image: icon.symbol,
                        tint: icon.tint,
                        description: ref.descriptor.description,
                        items: children
                    )
                case .task(let id, let title, _):
                    return .init(
                        ref: owner,
                        origin: owner,
                        entryId: id,
                        name: title,
                        image: icon.symbol,
                        tint: icon.tint
                    )
            }
        }

        guard case .content(let sheet) = model.session.focused, sheet.type is Sheet.Type
        else { return .init(layout: .group) }
        let items = Sheet.with(sheet, { value in value.blocks.map { item(for: $0, owner: sheet) } }) ?? []

        return .init(
            ref: sheet,
            name: sheet.descriptor.name,
            description: sheet.descriptor.description,
            layout: .group,
            nesting: .recursive,
            header: true,
            components: [
                .init(
                    id: "outline",
                    name: "Content Outline",
                    header: true,
                    items: items
                )
            ]
        )
    }
}

struct PreviewInspector: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                if let url = item.path { return model.session.selected.selected(ref, url) }
                if let entry = item.entryId { return model.session.selected.selected(ref, entry) }
                return model.session.selected.selected(ref)
            },
            onSelect: { item in
                guard let ref = item.ref else { return }
                if ref.type is Workspace.Type || ref.type is Space.Type { model.select(ref) }
                else { model.focus(ref) }
            },
            onOpen: { item in
                guard let ref = item.ref else { return }
                model.open(ref)
            },
            surfaceActions: {
                let ref: Reference
                switch model.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = model.session.selected.structure!
                }
                return Action.surfaceItems(for: ref)
            },
            surfaceDropTarget: {
                let ref: Reference
                switch model.session.focused {
                    case .structure(let focused): ref = focused
                    default: ref = model.session.selected.structure!
                }
                return .init(ref: ref, name: ref.descriptor.name)
            },
            itemActions: { item in
                Action.itemItems(for: item)
            }
        )
    }

    static func parameters(_ studio: any Model) -> Params {
        .init(
            layout: .group,
            components: [
                .init(
                    id: "context",
                    name: "Context",
                    footer: "A preview of this space's context, as the agent or model sees it."
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    footer: "An estimate of the tokens required to process this space.",
                    items: [
                        .init(name: "Input Tokens",  trailingKind: .value, description: "0"),
                        .init(name: "Cached Tokens", trailingKind: .value, description: "0"),
                        .init(name: "Output Tokens", trailingKind: .value, description: "0"),
                    ]
                ),
            ]
        )
    }
}

