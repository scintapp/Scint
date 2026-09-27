import SwiftUI


public struct ItemToggle: View {
    public let isOn: Bool
    public let onChange: () -> Void

    public var body: some View {
        Toggle("", isOn: Binding(get: { isOn }, set: { _ in onChange() }))
            .toggleStyle(.switch)
            .scaleEffect(0.8)
    }
}
