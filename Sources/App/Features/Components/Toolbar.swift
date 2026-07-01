import SwiftUI
import AgencyRuntime


struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var sheet: Reference? { agency.session.selected.content }
    private var space: Reference? { agency.session.selected.space }
    private var workspace: Reference { agency.session.workspace }
    
    var body: some View {
        ControlGroup {
            Button { agency.session.back() } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button { agency.session.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    private var space: Reference { agency.session.selected.space ?? agency.session.workspace }
    private var workspace: Reference { agency.session.workspace }
    private var composition: AgencyRuntime.Process? { Runtime.shared.context(for: space) }
    private var running: Bool { composition?.state == .running }
    
    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: workspace)
                        .font(.system(size: 11, weight: .semibold))
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
    
    private var transcripts: [Reference] {
        guard let space else { return [] }
        return Runtime.shared.transcripts(for: space)
    }
    
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
                Button { agency.select(ref) } label: {
                    Group { Iconography.icon(for: ref) }
                        .font(.system(size: 13, weight: .light))
                    Text(ref.descriptor.name)
                    if index < refs.count - 1 {
                        Image(systemName: "chevron.compact.forward").font(.system(size: 15, weight: .light))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ModalityControls: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var detail = agency.studio.detail

        Picker("Modality", selection: $detail.model) {
            Group {
                Image(systemName: "square.3.stack.3d")
                    .tag(Detail.Model.browser)
                Image(systemName: "doc.append")
                    .tag(Detail.Model.editor)
                Image(systemName: "circle.grid.2x2.topleft.checkmark.filled")
                    .tag(Detail.Model.composer)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
