import SwiftUI
import AgencyRuntime


struct FilterControls: View {
    @State var text: String = ""
    @FocusState var isFocused: Bool
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .circular)
        
        VStack {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .padding(.leading, 8)
                    .foregroundStyle(.secondary.opacity(0.9))
                    .font(.system(size: 13))
                
                TextField("Filter", text: $text)
                    .focused($isFocused)
                    .frame(maxWidth: .infinity, maxHeight: 26, alignment: .leading)
                    .foregroundStyle(.primary.opacity(0.9))
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: 26, alignment: .leading)
            .background(.primary.opacity(0.1))
            .clipShape(shape)
        }
        .frame(maxWidth: .infinity, maxHeight: 26)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

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
                    Image(systemName: Design.Component.icon(for: workspace))
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.trailing, 6)
                    Text(workspace.descriptor.name)
                        .foregroundStyle(.primary.opacity(0.9))
                        .font(.system(size: 11))
                }
                
                Button { } label: {
                    Image(systemName: Design.Component.icon(for: space))
                        .foregroundStyle(.primary.opacity(0.9))
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

struct FocusControls: View {
    @Environment(AgencyModel.self) var agency
    private var focused: Reference? {
        agency.session.selected.content
        ?? agency.session.selected.interface
        ?? agency.session.selected.space
        ?? agency.session.workspace
    }
    
    var body: some View {
        ControlGroup {
            Button { } label: {
                if let focused {
                    Iconography.icon(for: focused)
                        .frame(maxWidth: 17, maxHeight: 17)
                        .font(.system(size: 12))
                    Text(focused.descriptor.name)
                }
            }
            .disabled(agency.session.selected.workspace == nil && agency.session.selected.space == nil)
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
