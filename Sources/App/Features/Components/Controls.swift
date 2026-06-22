import SwiftUI
import AgencyRuntime


struct NavigationControls: View {
    @Environment(AgencyModel.self) var agency
    private var sheet: Reference? { agency.session.selected.content }
    private var space: Reference? { agency.session.selected.space }
    private var workspace: Reference { agency.session.workspace }
    
    var body: some View {
        ControlGroup {
            Button { agency.backward() } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button { agency.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
    }
}

struct ProcessControls: View {
    @Environment(AgencyModel.self) var agency
    private var space: Reference { agency.session.selected.space ?? agency.session.workspace }
    private var workspace: Reference { agency.session.workspace }
    private var composition: Composition? { Runtime.shared.context(for: space) }
    private var running: Bool { composition?.state == .running }
    
    var body: some View {
        HStack {
            ControlGroup {
                Button { } label: {
                    Iconography.icon(for: workspace)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.trailing, 6)
                    Text(workspace.descriptor.name)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 11))
                }
                
                Button { } label: {
                    Iconography.icon(for: space)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.trailing, 6)
                    Text(space.descriptor.name)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 11))
                }
            }
            .controlGroupStyle(.navigation)
            Button { agency.backward() } label: { Image(systemName: "chevron.backward") }
                .disabled(!agency.session.navigation.canGoBack)
            Button { agency.forward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!agency.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
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
