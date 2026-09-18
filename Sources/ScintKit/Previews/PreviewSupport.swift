import SwiftUI


#if DEBUG
@MainActor struct PreviewFixture {
    let model: StudioModel
    let root: Reference
    let workspace: Reference
    let material: Reference
    let file: Reference
    let link: Reference
    let command: Reference

    static let shared = make()

    var references: [Reference] { [material, file, link, command, workspace] }

    var loadItems: [ItemParams] {
        references.map { ref in
            let icon = Iconography.icon(for: ref)
            return ItemParams(
                ref: ref,
                name: ref.descriptor.name,
                image: icon.symbol,
                tint: icon.tint,
                description: ref.descriptor.description,
                active: ref == material
            )
        }
    }

    var pickerItems: [ItemParams] {
        [
            .init(key: "density", name: "Compact", value: "compact"),
            .init(key: "density", name: "Comfortable", value: "comfortable"),
            .init(key: "density", name: "Spacious", value: "spacious")
        ]
    }

    private static func make() -> PreviewFixture {
        let previewData = FileManager.default.temporaryDirectory
            .appending(path: "ScintPreviews")
            .appending(path: String(ProcessInfo.processInfo.processIdentifier))
        setenv("XDG_DATA_HOME", previewData.path, 1)

        let root = Space.new("Spaces")
        let inbox = Space.new(root, name: "Inbox")
        let drafts = Space.new(root, name: "Drafts")
        let outlines = Space.new(root, name: "Outlines")
        let workspace = Space.new(root, name: "Research Desk")
        Space.update(workspace) {
            $0.description = "Shared research, materials, and reusable tools."
        }

        let file = Artifact.new(
            "Design notes.md",
            previewData.appending(path: "Design notes.md")
        )
        Artifact.update(file) {
            $0.description = "Interview notes and source material for the research brief."
        }

        let link = Artifact.new(
            "SwiftUI documentation",
            URL(string: "https://developer.apple.com/documentation/swiftui")!
        )
        Artifact.update(link) {
            $0.description = "Apple's reference for SwiftUI views and controls."
        }

        let executable = Artifact.new("curl", URL(filePath: "/usr/bin/curl"))
        let command = Command.new("Fetch Web Page", exec: executable, params: [
            .fixed(.string("-L")),
            .argument(name: "URL", type: .string(""), required: true)
        ])
        Command.update(command) {
            $0.description = "Download a source page for the research workspace."
        }

        let material = Material.new(workspace, name: "Research Brief")
        Material.update(material) {
            $0.description = "A working brief for the next discovery call."
            $0.insert(.text(UUID(), "Collect the goal, audience, and constraints before the call."), at: nil)
            $0.insert(.task(UUID(), "Review the source notes", false), at: nil)
            $0.insert(.artifact(file), at: nil)
            $0.insert(.artifact(link), at: nil)
        }

        Space.with(workspace) {
            $0.add(file)
            $0.add(link)
            $0.add(command)
        }

        let data = AppData(
            previewSpace: root,
            inbox: inbox,
            drafts: drafts,
            outlines: outlines
        )
        let model = StudioModel(Session(data))
        model.select(workspace)
        model.open(material)

        return PreviewFixture(
            model: model,
            root: root,
            workspace: workspace,
            material: material,
            file: file,
            link: link,
            command: command
        )
    }
}

struct PreviewPanelFrame<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content

    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        Float(content: content)
            .frame(width: size.width, height: size.height)
            .background(Style.Background.overlay.opacity(Style.Opacity.faint))
            .padding(Style.Spacing.xxl)
            .background(Style.Background.base)
    }
}

struct PreviewControlRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: Style.Spacing.xl) {
            Text(title)
                .font(Typography.row)
                .foregroundStyle(Style.Foreground.secondary)
            Spacer(minLength: Style.Spacing.xl)
            control
        }
        .padding(.horizontal, Style.Spacing.lg)
        .frame(height: Style.Spacing.rowDetailHeight)
    }
}
#endif
