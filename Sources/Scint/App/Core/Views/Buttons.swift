import SwiftUI
import ScintRuntime
import ScintComponents


struct CountButton: View {
    let count: Int?
    var label = "Load"
    let onLoad: () -> Void

    var body: some View {
        HStack {
            if let count {
                Text(count == 0 ? "None" : count == 1 ? "1 Loaded" : "\(count) Loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(count == 0 ? .tertiary : .secondary)
            }
            Button(label, action: onLoad)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct NavigationButtons: View {
    let model: any Model

    var body: some View {
        ControlGroup {
            Button { model.session.back() } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!model.session.navigation.canGoBack)

            Button { model.session.forward() } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!model.session.navigation.canGoForward)
        }
        .controlGroupStyle(.navigation)
        .overlay {
            Style.Background.canvas
                .opacity(0.4)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        }
    }
}

struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle")
                .font(.system(size: 14))
                .foregroundStyle(Style.Foreground.secondary)
        }
        .buttonStyle(.plain)
    }
}

//struct SpaceButtonStyle: ViewModifier {
//    func body(content: Self.Content) -> some View {
//        content
//            .font(.system(size: 24))
//            .foregroundStyle(Style.Foreground.primary)
//            .frame(width: 24, height: 24, alignment: .center)
//            .controlSize(.extraLarge)
//            .buttonBorderShape(.circle)
//            .buttonStyle(.glass)
//    }
//}
