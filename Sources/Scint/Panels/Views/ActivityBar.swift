import SwiftUI


struct ActivityBar: View {
    @Environment(ScintModel.self) var model
    var ref: Reference { model.studio.session.selected.structure ?? model.studio.session.workspace }

    var state: Composition.State {
        guard let context = model.studio.session.origin.context
        else { return Composition.State.inactive }
        return context.state
    }

    var body: some View {
        HStack {
            Button { } label: {
                Iconography.icon(for: ref, size: 11)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

            Spacer().frame(width: 16)

            VStack {
                Text(ref.descriptor.name)
                    .foregroundStyle(Style.Foreground.base)
                    .font(.system(size: 11.5))
                Text(state.label)
                    .foregroundStyle(Style.Foreground.faint)
                    .font(.system(size: 9))
            }

            Spacer().frame(width: 16)

            Button { } label: {
                switch state {
                    case .active: Image(systemName: "pause.fill")
                    case .working: Image(systemName: "stop.fill")
                    case .inactive: Image(systemName: "play.fill")
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .foregroundStyle(Style.Foreground.base)
        }
    }
}
