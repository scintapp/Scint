import Foundation
import SwiftUI
import AgencyRuntime


//struct InspectorPicker: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        @Bindable var inspector = agency.studio.inspector
//        Picker("Layout", selection: $inspector.context) {
//            Group {
//                Image(systemName: "list.bullet")
//                    .tag(Inspector.Context.processing)
//                Image(systemName: "sidebar.squares.trailing")
//                    .tag(Inspector.Context.authoring)
//
//            }
//            .buttonSizing(.automatic)
//            .buttonStyle(.automatic)
//            .pickerStyle(.segmented)
//            .labelsHidden()
//        }
//    }
//}

struct LayoutPicker: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content


        Picker("Layout", selection: $content.layout) {
            Group {
                Image(systemName: "square.grid.2x2")
                    .tag(Layout.grid)

                Image(systemName: "list.bullet")
                    .tag(Layout.table)
            }
        }
        .buttonSizing(.automatic)
        .buttonStyle(.automatic)
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct TranscriptPicker: View {
    @Environment(AgencyModel.self) var agency
    let inspector: Inspector

    private var space: Reference? {
        agency.session.space ?? agency.session.workspace
    }
    
    private var transcripts: [Reference] {
        guard let space else { return [] }
        return Runtime.shared.transcripts(for: space)
    }

    private var current: String {
        guard let transcript = agency.session.transcript else { return "Transcripts" }
        return Transcript.with(transcript, { $0.name }) ?? "Transcripts"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Menu {
                ForEach(transcripts, id: \.self) { ref in
                    let name = Transcript.with(ref, { $0.name }) ?? "Transcript"
                    Button { agency.select(ref) } label: {
                        if agency.session.selected(ref) {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
                if transcripts.isEmpty { Text("No transcripts").foregroundStyle(.secondary) }
            } label: {
                HStack(spacing: 4) {
                    Text(current)
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding([.horizontal, .bottom], 8)
        .frame(maxWidth: .infinity, maxHeight: 89, alignment: .bottom)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.gray.opacity(0.05)).blur(radius: 0.1).frame(height: 1)
        }
    }
}
