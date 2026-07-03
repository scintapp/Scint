import AgencyRuntime
import SwiftUI


@Observable final class Console: Panel {
    var model: Model = .processes
    var layout: Layout = .table
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case processes }

    func toolbar() -> some View {
        return HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 8) {
                Group {
                    Button { } label: {
                        HStack {
                            Text("0")
                                .font(.system(size: 11))
                            Text("Inactive")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Design.Tint.inactive)
                        }
                    }
                    Button { } label: {
                        HStack {
                            Text("0")
                                .font(.system(size: 11))
                            Text("Active")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Design.Tint.active)
                        }
                    }
                    Button { } label: {
                        HStack {
                            Text("0")
                                .font(.system(size: 11))
                            Text("Running")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Design.Tint.running)
                        }
                    }
                    Button { } label: {
                        HStack {
                            Text("0")
                                .font(.system(size: 11))
                            Text("Blocked")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Design.Tint.blocked)
                        }
                    }
                    Button { } label: {
                        HStack {
                            Text("0").font(.system(size: 11))
                            Text("Failed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Design.Tint.failed)
                        }
                    }
                }
                .buttonSizing(.automatic)
                .buttonStyle(.plain)
            }
            Spacer()
            ConsoleToggle()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)
        .background(Design.Background.console)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(height: 0.5)
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(height: 1)
        }

    }

    func view(_ agency: AgencyModel) -> some View {
        @Bindable var console = self

        return VStack(spacing: 0) {
            toolbar()
            Processes()
        }
        .background(Design.Background.console)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
