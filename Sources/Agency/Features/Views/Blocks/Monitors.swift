import AgencyRuntime
import SwiftUI


struct MonitorCountPill: View {
    let title: String
    let count: Int
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(selected ? 0.98 : 0.72))
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(selected ? 0.9 : 0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(selected ? Color.primary.opacity(0.08) : Color.primary.opacity(0.055)))
            .overlay {
                Capsule()
                    .stroke(selected ? Color.primary.opacity(0.26) : Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MonitorToken: View {
    let title: String
    let tint: Color
    var outlined: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(tint.opacity(outlined ? 0.95 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(outlined ? 0.10 : 0.07)))
            .overlay {
                Capsule()
                    .stroke(tint.opacity(outlined ? 0.8 : 0), lineWidth: 1)
            }
    }
}

struct MonitorStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

struct MonitorStateMark: View {
    let state: Composition.State

    var body: some View {
        Group {
            switch state {
            case .running:
                ProgressView()
                    .controlSize(.small)
                    .tint(state.consoleTint)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state.consoleTint)
            default:
                Circle()
                    .fill(state.consoleTint)
                    .frame(width: 9, height: 9)
            }
        }
    }
}

struct MonitorSparkline: View {
    let active: Bool
    let tint: Color
    let seed: Int

    private var bars: [CGFloat] {
        (0..<9).map { index in
            let value = abs((seed >> (index % 8)) + index * 17) % 18
            return CGFloat(6 + value)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, height in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(active ? tint : Color.secondary.opacity(0.12))
                    .frame(width: 3, height: active ? height : 2)
            }
        }
        .opacity(active ? 1 : 0.35)
    }
}

struct MonitorDetailLine: View {
    let systemImage: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint.opacity(0.9))
                .lineLimit(1)
        }
    }
}

struct MonitorActionButton: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .frame(minWidth: 86, minHeight: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? Color.primary.opacity(0.92) : Color.secondary.opacity(0.7))
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(enabled ? 0.035 : 0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
        }
        .disabled(!enabled)
    }
}

struct MonitorEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(.secondary.opacity(0.55))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
