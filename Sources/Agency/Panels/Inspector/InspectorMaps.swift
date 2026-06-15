import AppKit
import SwiftUI
import AgencyRuntime


struct CompositionMap: Mapper {
    private static let chooseFilesTag = "choose-files"

    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init(
            onSelect: { item in
                let origin = agency.session.space ?? agency.session.workspace
                if item.tags.contains(chooseFilesTag) {
                    Task { @MainActor in chooseFiles(to: origin) }
                    return
                }
                guard let ref = item.ref else { return }
                add(ref, to: origin)
                return
            }
        )
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        let origin = agency.session.space ?? agency.session.workspace
        let closure = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
        let attachedComponents = closure.flatMap { Closure.with($0, { $0.components }) } ?? []
        let attachedSheets = closure.flatMap { Closure.with($0, { $0.sheets }) } ?? []
        let loadedHarness = attachedComponents.first { $0.type is Harness.Type }
        let attachedControls = attachedComponents.filter { $0.type is Command.Type }
        let attachedArtifacts = attachedComponents.filter { $0.type is Artifact.Type }
        let attachedFiles = attachedComponents.filter { ref in
            Artifact.with(ref, { $0.kind.url?.isFileURL == true }) == true
        }

        func libraryItems<T: Resolvable>(_ type: T.Type, image: String, tint: Color) -> [ItemParams] {
            Runtime.shared.all(as: type)
                .sorted { $0.1.name.localizedCaseInsensitiveCompare($1.1.name) == .orderedAscending }
                .map { ref, entry in
                    ItemParams(
                        ref: ref,
                        origin: origin,
                        name: entry.name,
                        image: image,
                        tint: tint,
                        active: attachedComponents.contains(ref) || attachedSheets.contains(ref)
                    )
                }
        }

        return .init(
            header: true,
            sections: [
                .init(
                    id: "automations",
                    name: "Automations",
                    layout: .group,
                    footnote: "Automate when and how often this space runs.",
                    items: [
                        ItemParams(name: "Date", image: "calendar", trailingKind: .toggle),
                        ItemParams(name: "Time", image: "clock", trailingKind: .toggle),
                        ItemParams(name: "Repeat", image: "repeat", trailingKind: .toggle),
                    ]
                ),

                    .init(
                        id: "interfaces",
                        name: "Interfaces",
                        layout: .group,
                        footnote: "Load artifacts, controls, and services for this space.",
                        items: [
                            .init(
                                name: "Artifacts",
                                image: "archivebox",
                                trailingKind: .load,
                                count: attachedArtifacts.count,
                                items: libraryItems(Artifact.self, image: "archivebox", tint: Design.Tint.artifact)
                            ),
                            .init(name: "Controls",
                                  image: "switch.2",
                                  trailingKind: .load,
                                  count: attachedControls.count,
                                  items: libraryItems(Command.self, image: "switch.2", tint: Design.Tint.control)),
                            .init(name: "Harness",
                                  image: "arrow.2.squarepath",
                                  trailingKind: .load,
                                  count: loadedHarness == nil ? 0 : 1,
                                  description: loadedHarness.map { Runtime.shared.get($0).name } ?? "None",
                                  items: libraryItems(Harness.self, image: "arrow.2.squarepath", tint: Design.Tint.service)),
                        ]
                    ),
                .init(
                    id: "sheets",
                    name: "Sheets",
                    layout: .group,
                    footnote: "Load sheets from the library to use as templates.",
                    items: [
                        .init(
                            name: "Sheets",
                            image: "text.alignleft",
                            trailingKind: .load,
                            count: attachedSheets.count,
                            items: libraryItems(Sheet.self, image: "text.alignleft", tint: Design.Tint.sheet)
                        )
                    ]
                ),
                .init(
                    id: "files",
                    name: "Files and Folders",
                    layout: .group,
                    footnote: "Share access to local files and folders.",
                    items: [
                        .init(
                            name: "Files and Folders",
                            image: "folder",
                            trailingKind: .action,
                            count: attachedFiles.count,
                            tags: [chooseFilesTag]
                        )
                    ]
                ),
            ]
        )
    }

    private static func add(_ ref: Reference, to origin: Reference) {
        if origin.type is Workspace.Type {
            Workspace.with(origin, { $0.add(ref: ref) })
        } else {
            Space.with(origin, { $0.add(ref: ref) })
        }
    }

    @MainActor private static func chooseFiles(to origin: Reference) {
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
    }
}

struct PreviewMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls { .init() }

    static func parameters(_ studio: AgencyModel, _ panel: any Panel) -> Parameters {
        .init(
            sections: [
                .init(
                    id: "context",
                    name: "Context",
                    layout: .group,
                    footnote: "A preview of this space's context, as the agent or model sees it.",
                    body: ""
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    layout: .group,
                    footnote: "An estimate of the tokens required to process this space.",
                    items: [
                        ItemParams(name: "Input Tokens",  trailingKind: .value, description: "0"),
                        ItemParams(name: "Cached Tokens", trailingKind: .value, description: "0"),
                        ItemParams(name: "Output Tokens", trailingKind: .value, description: "0"),
                    ]
                ),
            ]
        )
    }
}

struct TranscriptsMap: Mapper {
    static func controls(_ agency: AgencyModel, _ panel: any Panel) -> Controls {
        .init()
    }

    static func parameters(_ agency: AgencyModel, _ panel: any Panel) -> Parameters {
        .init()
    }
}
