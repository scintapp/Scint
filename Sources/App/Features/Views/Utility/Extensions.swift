import AgencyRuntime
import SwiftUI


extension RuntimeEvent {
    var label: String {
        switch self {
            case .request: return "turn.requested"
            case .composing: return "context.composed"
            case .dispatching: return "dispatch.started"
            case .observing: return "observe.started"
            case .processing: return "process.started"
            case .traversing: return "traverse.started"
            case .updated: return "updated"
            case .completed: return "completed"
            case .blocked: return "blocked"
            case .failed: return "failed"
            case .properties(let props): return ModelResponse(props).content
        }
    }
}

extension View {
    func event() -> some View {
        self
            .padding(.vertical, Spacing.blockPaddingV)
            .padding(.horizontal, Spacing.blockPaddingH)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.blockRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.blockRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            }
    }

    func hairline(_ height: CGFloat = 0.5) -> some View {
        Rectangle().fill(Theme.hairline).frame(height: height)
    }
}
