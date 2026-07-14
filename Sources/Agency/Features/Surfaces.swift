import AgencyRuntime
import Foundation
import SwiftUI


struct Browser: Surface {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        Builder.build(agency.studio.canvas, BrowserMap.parameters(agency), BrowserMap.controls(agency))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct Composer: Surface {
    @Environment(AgencyModel.self) private var agency
    var ref: Reference { agency.session.selected.space ?? agency.session.workspace }

    var body: some View {
        let entries = agency.context(ref)
            .map { Transcript.with($0.transcript, { $0.entries })! } ?? []

        ZStack(alignment: .bottom) {
            ScrollView {
                VStack {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            TranscriptEntry(entry: entry)
                        }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: 680, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            ComposerInput()
                .frame(maxWidth: 680, alignment: .bottom)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }
}

struct Editor: Surface {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        ScrollView {
            VStack {
                if let sheet = agency.session.active {
                    AgencyEditor(sheet)
                        .id(sheet)
                        .frame(maxWidth: 680, alignment: .topLeading)
                } else {
                    Text("Nothing Open")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 16)
            .padding(.horizontal, 24)
        }
    }
}
