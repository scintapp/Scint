import SwiftUI
import AgencyRuntime


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
                        agency.studio.detail.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                        agency.studio.detail.model = .browser
                        agency.studio.browser.model = structure.type is Workspace.Type ? .workspace : .space
                    }
                }
            } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button {
                if let selection = agency.session.forward() {
                    if let content = selection.content, content.type is Sheet.Type {
                        agency.focus(content)
                        agency.studio.detail.model = .editor
                    } else if let structure = selection.structure {
                        agency.focus(structure)
                        agency.studio.detail.model = .browser
                        agency.studio.browser.model = structure.type is Workspace.Type ? .workspace : .space
                    }
                }
            } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    private var space: Reference { agency.session.selected.space ?? agency.session.workspace }
    private var workspace: Reference { agency.session.workspace }
    private var composition: AgencyRuntime.Process? { agency.session.context }
    private var running: Bool { composition?.state == .running }
    
    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: workspace, size: 13.5)
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
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.trailing, 6)
                }
            }
            .controlGroupStyle(.navigation)
        }
    }
}

struct TranscriptControls: View {
    @Environment(AgencyModel.self) var agency
    let inspector: Inspector
    
    private var space: Reference? {
        agency.session.selected.space ?? agency.session.workspace
    }
    
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
                HStack(spacing: 4) { Text(current) }
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
                        agency.studio.detail.model = .editor
                    } else if ref.type is Workspace.Type {
                        agency.studio.detail.model = .browser
                        agency.studio.browser.model = .workspace
                    } else if ref.type is Space.Type {
                        agency.studio.detail.model = .browser
                        agency.studio.browser.model = .space
                    }
                } label: {
                    Iconography.icon(for: ref, size: 16)
                    Text(ref.descriptor.name)
                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward")
                            .font(.system(size: 15, weight: .light))
                            .opacity(0.8)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxHeight: 25, alignment: .center)
            }
        }
        .padding(.bottom, 6)
    }
}

struct ModalityControls: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var detail = agency.studio.detail

        Picker("Modality", selection: $detail.model) {
            Group {
                Image(systemName: "rectangle.stack")
                    .tag(Detail.Model.browser)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
