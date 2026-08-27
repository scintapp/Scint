import SwiftUI


struct ActionsBar: View {
    let model: any Model

    var body: some View {
        HStack {
            Spacer()
            Button { } label: {
                Image(systemName: "plus")
                    .frame(height: 30, alignment: .center)
                    .foregroundStyle(Style.Foreground.muted)
                    .font(.system(size: 13))
            }
            .frame(height: 30, alignment: .center)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: 30, alignment: .leading)
        .padding(.horizontal, 12)
    }
}
