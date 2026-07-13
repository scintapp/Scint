import AgencyRuntime
import SwiftUI


struct Editor: Surface {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ScrollView {
            VStack {
                if let sheet = agency.session.active {
                    AgencyEditor(sheet)
                        .id(sheet)
                        .frame(maxWidth: 710, alignment: .topLeading)
                } else {
                    Text("Nothing Open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)
                    Text("")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Design.Foreground.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 24)
        }
    }
}

@MainActor private struct EditorPreview: View {
    @State private var agency = makeAgency()

    var body: some View {
        Editor()
            .environment(agency)
            .frame(width: 860, height: 720)
            .background(Design.Background.editor)
            .preferredColorScheme(.dark)
    }

    private static func makeAgency() -> AgencyModel {
        let workspace = Reference(Workspace.self)
        let sheet = makeSheet(owner: workspace)
        let model = AgencyModel(workspace)
        model.session.open(sheet)
        model.session.select(sheet)
        model.session.focus(sheet)
        return model
    }

    private static func makeSheet(owner: Reference) -> Reference {
        let shell = Artifact.register("zsh", URL(fileURLWithPath: "/bin/zsh"))
        let source = Artifact.register("Design.sketch", URL(fileURLWithPath: "/Users/kaechle/Developer/Agency/Design.sketch"))
        let command = Command.register("Summarize Context", exec: shell, params: [.argument("--brief")])
        Command.update(command) { $0.description = "Condense selected notes into a short design brief" }

        let linked = Sheet.new("Research Notes", owner: owner)
        Sheet.update(linked) { sheet in
            sheet.blocks = [
                .content(UUID(), "# Research Notes"),
                .content(UUID(), "Collect examples for editor block spacing, task grouping, and artifact cards.")
            ]
        }

        let sheet = Sheet.new("Editor Preview", owner: owner)
        Sheet.update(sheet) { sheet in
            sheet.blocks = [
                .content(UUID(), "# Editor Preview"),
                .content(UUID(), "Use this preview to tune the editor surface, text rhythm, selected block treatment, and mixed block spacing."),
                .content(UUID(), "> The panel should feel calm enough for long writing sessions while still making actionable blocks easy to scan."),
                .task(UUID(), "Tighten selected block chrome", false),
                .task(UUID(), "Check multiline text spacing", true),
                .artifact(source),
                .command(command),
                .sheet(linked),
                .content(UUID(), """
                ## Implementation Notes
                - Keep rows stable while editing
                - Make keyboard focus visible but restrained
                - Preserve enough vertical air around cards
                """),
                .content(UUID(), "Try typing / or @ in the active text block to inspect the inline menu placement.")
            ]
        }
        return sheet
    }
}

#Preview("Editor") {
    EditorPreview()
}
