import AgencyRuntime
import SwiftUI


struct TranscriptsMapper: Mapper {
    static func controls(_ model: any Model) -> Controls {
        .init(
            selected: { item in
                guard let ref = item.ref else { return false }
                return model.session.active == ref
            },
            onSelect: { item in
                guard let ref = item.ref, ref.type is Transcript.Type else { return }
                model.open(ref)
            }
        )
    }

    static func parameters(_ model: any Model) -> Params {
        let space = model.session.selected.space ?? model.session.workspace
        let calendar = Calendar.autoupdatingCurrent

        let items = Runtime.shared.transcripts(for: space)
            .map { ref -> (ref: Reference, date: Date) in
                let date = Transcript.with(ref, { $0.entries.last?.created ?? ref.descriptor.created })!
                return (ref, date)
            }
            .sorted { $0.date > $1.date }

            .map { ref, date in
                let day: String
                if calendar.isDateInToday(date) { day = "Today" }
                else if calendar.isDateInYesterday(date) { day = "Yesterday" }
                else { day = date.formatted(.dateTime.month(.abbreviated).day()) }

                return ItemParams(
                    ref: ref,
                    name: ref.descriptor.name,
                    description: "\(day), \(date.formatted(date: .omitted, time: .shortened))"
                )
            }

        return .init(
            layout: .table,
            components: [
                .init(
                    id: "transcripts",
                    name: "Transcripts",
                    header: false,
                    items: items
                )
            ],
        )
    }
}

struct SpaceSettingsMap: Mapper {
    static func controls(_ model: any Model, _ panel: any Panel) -> Controls {
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
                model.select(ref)
                model.open(ref)
            },
            onAction: { _ in
                let origin: Reference
                switch model.session.focused {
                    case .structure(let focused): origin = focused
                    default: origin = model.session.selected.structure!
                }

                func add(_ ref: Reference, to origin: Reference) {
                    if origin.type is Workspace.Type { Workspace.with(origin, { $0.add(ref) }) }
                    else { Space.with(origin, { $0.add(ref) }) }
                }

                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.canCreateDirectories = false
                panel.resolvesAliases = true
                panel.title = "Choose Files or Folders"
                panel.prompt = "Load"

                guard panel.runModal() == .OK else { return }

                for url in panel.urls {
                    let ref = Artifact.register(url.lastPathComponent, url)
                    add(ref, to: origin)
                }

                Task { try? await Runtime.shared.save() }
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

    static func parameters(_ model: any Model, _ panel: any Panel) -> Params {
        let space: Reference
        switch model.session.focused {
            case .structure(let focused): space = focused
            default: space = model.session.selected.structure!
        }

        let workspaceHarness = Workspace.with(space, { workspace in Harness.with(workspace.harness, { _ in workspace.harness }) }).flatMap { $0 }
        let closure = Space.with(space, { $0.closure }) ?? Workspace.with(space, { $0.closure })
        let state = closure.flatMap { Closure.with($0, { $0.content }) } ?? []
        let components = closure.flatMap { Closure.with($0, { $0.interfaces }) } ?? []
        let spaceHarness = Space.with(space, { $0.harness }).flatMap { $0 }
//        let harness = spaceHarness ?? workspaceHarness
//        let commands = Array(components.filter { $0.type is Command.Type })

        let files = components.filter { ref in
            Artifact.with(ref) { artifact in
                switch artifact.handler {
                    case .bookmark: return false
                    case .app, .directory, .file, .image, .script, .skill, .executable: return true
                }
            } ?? false
        }

        func items(_ refs: [Reference], image: String, tint: Color) -> [ItemParams] {
            refs
                .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
                .map {
                    .init(
                        ref: $0,
                        name: $0.descriptor.name,
                        image: image,
                        tint: tint
                    )
                }
        }

        let sheets = state.filter { $0.type is Sheet.Type }

        let automations = ComponentParams(
            id: "automations",
            name: "Automations",
            header: false,
            footer: "Automate when and how often this space runs.",
            items: [
                .init(name: "Date", image: "calendar", trailingKind: .toggle),
                .init(name: "Time", image: "clock", trailingKind: .toggle),
                .init(name: "Repeat", image: "repeat", trailingKind: .toggle),
            ]
        )

        let fileItems = ItemParams(
            name: "Files and Folders",
            image: "folder",
            trailingKind: .action,
            count: files.count
        )

        let sheetItems = ItemParams(
            name: "Sheets",
            image: "text.alignleft",
            trailingKind: .load,
            count: sheets.count,
            items: items(sheets, image: "text.alignleft", tint: Design.Tint.sheet)
        )

        let context = ComponentParams(
            id: "context",
            name: "Context",
            header: false,
            footer: "Build context with files, folders, and Sheets.",
            items: [fileItems, sheetItems]
        )

        return .init(
            name: space.descriptor.name,
            description: space.descriptor.description,
            layout: .group,
            header: true,
            components: [automations, context]
        )
    }
}
