import OSLog
import SwiftUI
import ScintRuntime


struct ActionMenu: View {
    let model: any Model
    let items: [ActionParams]

    var body: some View {
        ForEach(items) { item in
            Button(role: item.role) { item.action(model) } label: {
                if item.image.isEmpty { Text(item.label) }
                else { Label(item.label, systemImage: item.image) }
            }
            .disabled(!item.enabled(model))
        }
    }
}
