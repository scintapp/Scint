import SwiftUI
import AgencyRuntime


struct CanvasControls: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var canvas = agency.studio.canvas

        Picker("Model", selection: $canvas.model) {
            Group {
                Image(systemName: "interface.window.stack")
                Image(systemName: "tablecells")
            }
        }
        .glassEffect(.regular)
        .pickerStyle(.segmented)
        .buttonStyle(.automatic)
        .buttonSizing(.automatic)
        .labelsHidden()
    }
}

struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var sheet: Reference? { agency.session.selected.content }
    private var space: Reference? { agency.session.selected.space }
    private var workspace: Reference { agency.session.workspace }

    var body: some View {
        ControlGroup {
            Button {
                if let selection = agency.session.back() {
                    if let content = selection.content, content.type is Sheet.Type {
                        agency.focus(content)
                        agency.studio.canvas.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                        agency.studio.canvas.model = .browser
                        agency.studio.browser.model = .single
                    }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button {
                if let selection = agency.session.forward() {
                    if let content = selection.content, content.type is Sheet.Type {
                        agency.focus(content)
                        agency.studio.canvas.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                        agency.studio.canvas.model = .browser
                        agency.studio.browser.model = .single
                    }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
        .glassEffect(.regular)
    }
}

struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    private var space: Reference { agency.session.selected.space ?? agency.session.workspace }

    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: space, size: 16)
                        .padding(.trailing, 6)
                }

                Button { } label: {
                    VStack(alignment: .center) {
                        Text(space.descriptor.name)
                            .foregroundStyle(.primary.opacity(0.9))
                            .font(.system(size: 11))
                        Text("Ready")
                            .foregroundStyle(.secondary.opacity(0.9))
                            .font(.system(size: 9, weight: .medium))
                    }
                }

                Button { } label: {
                    Image(systemName: "text.bubble.badge.sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.trailing, 6)
                }
            }
            .controlGroupStyle(.navigation)
        }
        .glassEffect(.regular)
    }
}

struct TranscriptControls: View {
    @Environment(AgencyModel.self) var agency
    let inspector: Inspector

    private var space: Reference? { agency.session.selected.space ?? agency.session.workspace }

    private var transcripts: [Reference] { [] }

    private var current: String {
        guard let transcript = agency.session.selected.content, transcript.type is Transcript.Type else { return "Transcripts" }
        return Transcript.with(transcript, { $0.name }) ?? "Transcripts"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Menu {
                ForEach(transcripts, id: \.self) { ref in
                    let name = Transcript.with(ref, { $0.name }) ?? "Transcript"
                    Button { agency.select(ref) } label: { Label(name, systemImage: "checkmark") }
                }
                if transcripts.isEmpty { Text("No transcripts").foregroundStyle(.secondary) }
            } label: {
                HStack { Text(current) }
            }
            .menuStyle(.borderlessButton)
        }
        .padding([.horizontal, .bottom], 8)
        .frame(maxWidth: .infinity, maxHeight: 90, alignment: .bottom)
    }
}

struct PathControls: View {
    @Environment(AgencyModel.self) var agency
    var refs: [Reference] { agency.session.navigation.path(for: agency.session.selected, in: agency.session.workspace) }

    var body: some View {

        HStack(alignment: .center) {
            ForEach(Array(refs.enumerated()), id: \.element) { index, ref in
                Button {
                    agency.focus(ref)
                    agency.select(ref)
                    if ref.type is Sheet.Type {
                        agency.open(ref)
                        agency.studio.canvas.model = .editor
                    } else if ref.type is Workspace.Type {
                        agency.studio.canvas.model = .browser
                        agency.studio.browser.model = .single
                    } else if ref.type is Space.Type {
                        agency.studio.canvas.model = .browser
                        agency.studio.browser.model = .single
                    }
                } label: {
                    Iconography.icon(for: ref, size: 15)

                    Group {
                        Text(ref.descriptor.name)
                            .font(.system(size: 11, weight: .medium))
                        if index < refs.count - 1 {
                            Image(systemName: "chevron.compact.forward")
                                .font(.system(size: 15, weight: .light))
                                .opacity(0.8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(maxHeight: 32, alignment: .center)
            }
        }
        .padding(.bottom, 6)
    }
}
