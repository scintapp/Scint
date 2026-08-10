import SwiftUI


struct SpacePreviewCard: Surface {
    var model: any Model
    var host: any Host
    var ref: Reference

    var context: Composition? { ref.context }
    var running: Bool {
        guard let context else { return false }
        if context.state == .inactive { return false }
        else { return true }
    }

    var body: some View {
        let intents = context?.intents.count ?? 0
        let status = running ? "Running" : context == nil ? "Ready" : "Paused"
        let statusTint = running ? Design.Tint.active : context == nil ? Design.Tint.info : Design.Tint.inactive

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(ref.descriptor.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Design.Foreground.primary)
                    .lineLimit(1)

                Spacer()

                SwiftUI.Menu {
                    Button { model.select(ref) } label: {
                        Label("Open", systemImage: "folder")
                    }
                    if let transcript = context?.transcript {
                        Button { model.open(transcript) } label: {
                            Label("Open Transcript", systemImage: "text.bubble")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Design.Foreground.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }

            SpaceContent(ref: ref, host: host, model: model)
                .frame(width: 500, height: 144, alignment: .topLeading)
                .scaleEffect(0.72, anchor: .topLeading)
                .frame(width: 360, height: 104, alignment: .topLeading)
                .clipped()

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(statusTint)
                    Text(status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Design.Foreground.primary)

                    Spacer()

                    Text("\(intents) active")
                        .font(.system(size: 12))
                        .foregroundStyle(Design.Foreground.secondary)
                }

                Text(context?.intentTranscript?.descriptor.name ?? (ref.descriptor.description.isEmpty ? "No recent activity" : ref.descriptor.description))
                    .font(.system(size: 12))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index < min(intents, 3) ? statusTint : Color.primary.opacity(0.12))
                                .frame(width: 62, height: 6)
                        }
                    }

                    Spacer()

                    if let harness = context?.harness {
                        HStack(spacing: 6) {
                            Iconography.icon(for: harness, size: 11)
                            Text(harness.descriptor.name)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 10) {
                Button { model.select(ref) } label: {
                    Label("Open", systemImage: "folder")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75))

                Button {
                    if running { let _ = Runtime.shared.stop(ref) }
                    else { let _ = model.start(ref) }
                } label: {
                    Label(running ? "Pause" : "Run", systemImage: running ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.055)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75))

                SwiftUI.Menu {
                    if let transcript = context?.transcript {
                        Button { model.open(transcript) } label: {
                            Label("Open Transcript", systemImage: "text.bubble")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.055)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75))
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(Design.Foreground.primary)
        }
        .padding(20)
        .frame(width: 400, height: 360, alignment: .topLeading)
        .background(Design.Shape.block.fill(Color.primary.opacity(0.035)))
        .overlay(
            Design.Shape.block.strokeBorder(
                running == true ? Design.Tint.compose.opacity(0.72) : Color.primary.opacity(0.12),
                lineWidth: running == true ? 1.25 : 0.75
            )
        )
        .contentShape(Design.Shape.block)
    }
}

struct WorkspaceSurface: Surface {
    var host: any Host
    let model: any Model

    var spaces: [Reference] {
        var pending = Array(Workspace.with(model.session.workspace, { $0.spaces }) ?? [])
        var visited: Set<Reference> = []
        var result: [Reference] = []

        while let ref = pending.popLast() {
            guard visited.insert(ref).inserted else { continue }
            if ref.descriptor.published != false { result.append(ref) }
            pending.append(contentsOf: Space.with(ref, { $0.spaces }) ?? [])
        }

        return result.sorted {
            $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
        }
    }

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 20, alignment: .top)]
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(spaces) { space in
                    SpacePreviewCard(model: model, host: host, ref: space)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

