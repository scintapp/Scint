import SwiftUI
import LinkPresentation


#if DEBUG
#Preview("Cards") {
    let previewData = FileManager.default.temporaryDirectory
        .appending(path: "ScintCardPreviews")
        .appending(path: String(ProcessInfo.processInfo.processIdentifier))
    precondition(setenv("XDG_DATA_HOME", previewData.path, 1) == 0)

    let workspace = Space.new("Research Desk")
    Space.update(workspace) { $0.description = "Shared research, materials, and tools." }
    let space = Space.new(workspace, name: "Client research")
    Space.update(space) { $0.description = "Prepare the next discovery call." }
    let file = Artifact.register("Design notes.md", previewData.appending(path: "Design notes.md"))
    Artifact.update(file) { $0.description = "Notes and reference material for the interview." }
    let link = Artifact.register("SwiftUI documentation", URL(string: "https://developer.apple.com/documentation/swiftui")!)
    Artifact.update(link) { $0.description = "Apple's documentation for SwiftUI." }
    let executable = Artifact.register("curl", URL(filePath: "/usr/bin/curl"))
    let command = Command.register("Fetch Web Page", exec: executable, params: [
        .fixed(.string("-L")),
        .fixed(.string("--max-time 20")),
        .argument(name: "URL", type: .string(""), required: true)
    ])
    Command.update(command) { $0.description = "Fetch the contents of a web page with curl." }
    let harness = Harness.register("Research Harness", command: command, intent: .observe)
    Harness.update(harness) { $0.description = "Observe changes while collecting research." }

    let material = Material.new(space, name: "Descriptor fallback title")
    Material.update(material) {
        $0.description = "Descriptor fallback description."
        $0.update(.text(UUID(), "# Research Brief Template"), at: 0)
        $0.insert(.text(UUID(), "Turn a topic into a research brief with a working question, audience context, and source plan.\nCapture the intended use of the finished brief."), at: nil)
        $0.insert(.task(UUID(), "Review the brief", false), at: nil)
        $0.insert(.task(UUID(), "Collect design references", true), at: nil)
        $0.insert(.artifact(file), at: nil)
    }
    let fallback = Material.new(space, name: "Material without a heading")
    Material.update(fallback) {
        $0.description = "This card uses its descriptor because the heading and following text are absent."
        $0.delete(at: 0)
    }
    let transcript = Transcript.new(workspace)
    Transcript.update(transcript) {
        $0.name = "Observe Transcript"
        $0.description = "Watch the Research Desk for changes."
    }
    let refs = [material, fallback, command, harness, transcript, file, link, space, workspace]

    return ScrollView {
        VStack(alignment: .leading, spacing: Style.Spacing.xl) {
            ForEach(refs) { ref in
                Card(ref: ref, style: .group)
            }
        }
        .padding(Style.Spacing.xxl)
    }
    .frame(width: Style.Spacing.contentMaxWidth, height: Style.Dimension.taskPanel.height)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}

#Preview("Chips") {
    let previewData = FileManager.default.temporaryDirectory
        .appending(path: "ScintCardPreviews")
        .appending(path: String(ProcessInfo.processInfo.processIdentifier))
    precondition(setenv("XDG_DATA_HOME", previewData.path, 1) == 0)

    let workspace = Space.new("Research Desk")
    let material = Material.new(workspace, name: "Research Brief Template")
    let file = Artifact.register("Design notes.md", previewData.appending(path: "Design notes.md"))
    let executable = Artifact.register("curl", URL(filePath: "/usr/bin/curl"))
    let command = Command.register("Fetch Web Page", exec: executable)

    return VStack(alignment: .leading, spacing: Style.Spacing.lg) {
        Chip(ref: material)
        Chip(ref: command)
        Chip(ref: file)
        Chip(ref: workspace)
        Chip(ref: material, label: "Selected reference", isSelected: true)
    }
    .padding(Style.Spacing.xxl)
    .frame(width: Style.Spacing.contentMaxWidth, alignment: .leading)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}

#Preview("Blocks") {
    let blocks: [Material.Block] = [
        .text(UUID(), "A **formatted note** with *emphasis* and an `inline code` example."),
        .task(UUID(), "Collect the prospect URL and latest email thread before running the brief.", false),
        .task(UUID(), "Group questions by business goal, constraints, and decision process.", true),
        .task(UUID(), "Add a final section for risks that should not be waved away during the call.", false)
    ]

    return VStack(alignment: .leading, spacing: Style.Spacing.md) {
        ForEach(blocks) { block in
            MaterialBlock(block: block)
        }
    }
    .padding(Style.Spacing.xxl)
    .frame(width: Style.Spacing.contentMaxWidth)
    .background(Style.Background.base)
    .preferredColorScheme(.dark)
}
#endif
