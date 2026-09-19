import ScintComponents
import SwiftUI
import Foundation


struct ActivityHeader: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var composition: Composition? { ref.context }

    var state: (label: String, tint: Color) {
        switch composition?.state {
            case .active: ("Active", Style.Tint.accent.bright)
            case .working: ("Working", Style.Tint.accent.bright)
            case .completed: ("Complete", Style.Tint.space.bright)
            case .failed: ("Needs attention", Style.Tint.alert.bright)
            case .inactive, .none: ("Ready", Style.Foreground.secondary)
        }
    }

    var intent: String? {
        guard let harness = Space.with(ref, { $0.harness }) ?? nil else { return nil }
        return Harness.with(harness, { $0.intent.rawValue.capitalized }) ?? nil
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let harness = Space.with(ref, { $0 })?.harness { Iconography.icon(for: harness, size: 23) }
                    else { Iconography.icon(for: ref, size: 23) }
                }
                .frame(maxHeight: 52)

                VStack(alignment: .leading) {
                    Text(ref.descriptor.name)
                        .frame(alignment: .leading)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(intent ?? "")
                        .frame(alignment: .leading)
                        .foregroundStyle(Style.Foreground.secondary)
                }
                .font(Typography.detail)
                .lineLimit(1)
            }
            .frame(maxHeight: 52)

            HStack(alignment: .center) {
                TranscriptPicker(model: model)
                Button { } label: {
                    Image(systemName: "pause.fill")
                        .frame(width: 23, height: 23)
                }
                .buttonStyle(.accessoryBarAction)
                .buttonBorderShape(.circle)

                Button { } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 23, height: 23)
                }
                .buttonStyle(.accessoryBarAction)
                .buttonBorderShape(.circle)
            }
            .frame(maxHeight: 52)
        }
        .padding(.horizontal, 10)
    }
}

struct ActivitySurface: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DisclosureSection("Needs Attention", detail: "2 outlines") {
                    VStack(spacing: 0) {
                        OutlineRow(
                            "Runtime as a Place",
                            status: .alert,
                            completed: 2,
                            total: 6,
                            nextAction: "Approve terminal condition",
                            isSelected: true
                        ) { SpaceTag("Runtime", intent: .evaluate) }

                        OutlineRow(
                            "Voice Audit",
                            status: .alert,
                            completed: 4,
                            total: 7,
                            nextAction: "Choose three samples"
                        ) { SpaceTag("Voice Study", intent: .compose) }

                        Divider()
                    }
                }

                DisclosureSection("Working", detail: "2 outlines") {
                    VStack(spacing: 0) {
                        Divider()

                        OutlineRow(
                            "Persistence Review",
                            status:.evaluate,
                            completed: 5,
                            total: 9,
                            nextAction: "Evaluating store boundaries"
                        ) { SpaceTag("Runtime", intent: .evaluate) }

                        Divider()

                        OutlineRow(
                            "Dew as the Scheduler",
                            status:.dispatch,
                            completed: 3,
                            total: 8,
                            nextAction: "Running recurrence tests") { SpaceTag("Dew", intent: .dispatch) }

                        Divider()
                    }
                }

                DisclosureSection("Watching", detail: "1 outline") {
                    VStack(spacing: 0) {
                        Divider()

                        OutlineRow(
                            "Agency Essay",
                            status: .neutral,
                            completed: 7,
                            total: 7,
                            nextAction: "Watching references") { SpaceTag("Writing", intent: .compose) }

                        Divider()
                    }
                }
            }
            .padding(Style.Spacing.page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Style.Background.canvas)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaBar(edge: .top) {
            if let ref { ActivityHeader(ref: ref, panel: panel, model: model) }
        }
    }
}
