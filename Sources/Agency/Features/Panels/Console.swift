import AgencyRuntime
import Foundation
import SwiftUI


struct ProcessesOverview: View {
    private let states: [Composition.State] = [.active, .running, .blocked, .failed]

    private var compositions: [Composition] {
        Runtime.shared.context()
            .filter { $0.origin.type is Space.Type }
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(states, id: \.consoleName) { state in
                ProcessCount(name: state.consoleName, count: count(state), tint: state.consoleTint)
            }
        }
        .font(.system(size: 11))
    }

    private func count(_ state: Composition.State) -> Int {
        compositions.filter { $0.state == state }.count
    }
}

private struct ProcessCount: View {
    let name: String
    let count: Int
    let tint: Color

    private var foreground: Color {
        count == 0 ? Color.secondary.opacity(0.45) : tint
    }

    var body: some View {
        HStack {
            Text("\(count)")
                .foregroundStyle(count == 0 ? Color.secondary.opacity(0.45) : .primary.opacity(0.9))
            Text(name)
                .foregroundStyle(foreground)
        }
    }
}

struct ConsoleToolbar: View {
    @Binding var presented: Bool

    var body: some View {
        HStack(alignment: .center) {
            ProcessesOverview()
            Spacer()
            ConsoleToggle()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
        .background(Design.Background.console)
        .overlay(alignment: .top) {
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 0.5)
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(height: 1)
            }
        }
    }
}

@Observable final class Console: Panel {
    var model: Model = .processes
    var layout: Layout = .table
    var position: CGFloat = 0
    var presented: Bool = false
    var expanded: Set<AnyHashable> = []

    enum Model: CaseIterable { case processes }

    func closures(_ agency: AgencyModel) -> Closures { ProcessesMap.closures(agency, self) }
    func params(_ agency: AgencyModel) -> Params { ProcessesMap.params(agency, self) }

    @MainActor func build(_ agency: AgencyModel) -> some View {
        @Bindable var console = self
        return VStack(spacing: 0) {
            ConsoleToolbar(presented: $console.presented)
                .background(Design.Background.console)
            Builder.build(self, closures(agency), params(agency))
                .padding(.horizontal, 12)
        }
        .background(Design.Background.console)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
