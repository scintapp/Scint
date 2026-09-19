import ScintComponents
import SwiftUI
import Foundation


struct SpaceMenu: View {
    @State private var hovered = false
    let model: any Model
    var selection: Selection { model.session.selection }
    var path: [Reference] { model.session.navigation.path(for: selection) }

    var body: some View {
        if let ref = path.last {
            Button { model.select(ref) } label: {
                HStack(alignment: .center) {
                    Iconography.icon(for: ref, size: 13.5)
                    Text(ref.descriptor.name).font(.system(size: 13.5, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct SpaceSurface: Surface {
    var panel: any Panel
    var model: any Model

    @State private var tab = "Events"
    @State private var draft = ""
    @State private var done = [true, true, false, false]

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var body: some View {
        HStack {
            events
            document
                .frame(maxWidth: 380, maxHeight: .infinity)
        }
        .background(Style.Background.canvas)
        .safeAreaBar(edge: .top) {
            if let ref { ActivityHeader(ref: ref, panel: panel, model: model) }
        }
    }

    private var events: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Style.Spacing.heading) {
                    HStack(alignment: .center) {
                        SegmentedTabs(selection: $tab, options: ["Events", "Transcript"], title: \.self)
                        SwiftUI.Menu {
                            Button("All events") {}
                            Button("Tasks") {}
                            Button("Context") {}
                        } label: {
                            HStack(spacing: Style.Spacing.label) {
                                Text("All events")
                                Image(systemName: "chevron.down").font(.caption)
                            }
                        }
                        .menuStyle(.button)
                        .menuIndicator(.hidden)
                        .buttonStyle(.soft)
                        .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    timeline
                }
                .padding(Style.Spacing.page)
            }
            ComposerField("Add direction or note…", text: $draft) {}
                .padding([.horizontal, .bottom], 12)
        }
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            TimelineRow(time: "9:14 AM", tint: .transcript) {
                ActivityRow("Direction received", icon: .transcript) {
                    Text("“Use the outline’s assigned spaces to derive state.”")
                }
            }
            Divider()
            TimelineRow(time: "9:14 AM", tint: .evaluate) {
                ActivityRow("Intent started", icon: .harness(.evaluate)) {
                    Text("Evaluate  ·  Runtime")
                }
            }
            Divider()
            TimelineRow(time: "9:15 AM", tint: .closure) {
                ActivityRow("Context assembled", icon: .closure) {
                    HStack(spacing: Style.Spacing.label) {
                        Button {} label: {
                            Label { Text("Outline") } icon: { Iconography.Icon(.material) }
                        }
                        Button {} label: { SpaceTag("Runtime", intent: .evaluate) }
                        Button {} label: { SpaceTag("Dew", intent: .dispatch) }
                        Button("+ 3 artifacts") {}
                            .buttonStyle(.plain)
                            .foregroundStyle(Style.Tint.artifact.bright)
                            .padding(.leading, 6)
                    }
                    .buttonStyle(.soft)
                    .foregroundStyle(Style.Foreground.primary)
                    .lineLimit(1)
                }
            }
            Divider()
            TimelineRow(time: "9:16 AM", tint: .artifact) {
                ActivityRow("Read Context.swift", icon: .artifact(.file)) {
                    FileRow("Context.swift", path: "Scint / Runtime", handler: .script) {
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(Style.Foreground.primary)
                    .padding(10)
                    .surface()
                }
            }
            Divider()
            TimelineRow(time: "9:17 AM", tint: .task) {
                ActivityRow("Task updated", icon: .task(done: false)) {
                    Text("Define the terminal condition → In progress")
                }
            }
            Divider()
            TimelineRow(time: "9:18 AM", tint: .evaluate) {
                HStack(alignment: .top) {
                    ActivityRow("Checkpoint", icon: .space(.evaluate, state: .completed)) {
                        Text("The outline defines Runtime’s scope, current work, and linked spaces. I’ve derived the current state and updated the task.")
                    }
                    Button("View details") {}
                        .buttonStyle(.soft)
                }
            }
        }
    }

    private var document: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Style.Spacing.section) {
                    PageHeader("Runtime as a Place", subtitle: "Runtime is where structure, memory, and agency live together. It gives an agent a stable place to work, a clear scope, and the context it needs to make progress over time.")

                    Divider()

                    DisclosureSection("Current work") {
                        VStack(spacing: 4) {
                            TaskRow("Review existing runtime implementation", isDone: $done[0])
                            TaskRow("Identify key state and lifecycle events", isDone: $done[1])
                            TaskRow("Define the terminal condition", isDone: $done[2],
                                    activity: "Runtime working", activityTint: .evaluate)
                            TaskRow("Document integration points with other spaces", isDone: $done[3])
                        }
                    }

                    Divider()

                    DisclosureSection("Context") {
                        VStack(spacing: 10) {
                            FileRow("Context.swift", path: "Scint / Runtime", handler: .script) { Text("Updated 9:02 AM") }
                            Divider()
                            FileRow("Runtime Architecture", path: "Scint / Studio") { Text("Sep 15, 2026") }
                            Divider()
                            FileRow("Agent Lifecycle Notes", path: "Scint / Docs") { Text("Sep 14, 2026") }
                        }
                    }
                }
                .frame(maxWidth: Style.Prose.readableWidth, alignment: .leading)
                .lineLimit(1)
                .buttonStyle(.soft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Style.Background.canvas)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .padding(Style.Spacing.page)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: Style.Spacing.label) {
                Text("\(done.filter { $0 }.count) of \(done.count) tasks complete")
                    .font(Typography.footnote)
                Spacer()
                Image(systemName: "link")
                    .foregroundStyle(Style.Foreground.secondary)
                    .help("Linked spaces")
                Button {} label: { SpaceTag("Dew", intent: .dispatch) }
                Button {} label: { SpaceTag("Studio") }
            }
            .frame(height: 30)
        }
    }
}

