import SwiftUI


struct OutlineSurface: Surface, ProcessSurfaceRoot {
    var panel: any Panel
    var model: any Model

    var body: some View {
        let content = ProcessContent(model: model)

        ProcessLayout(
            content: content,
            selectedMaterial: model.session.opened.material,
            activeInput: model.session.selected.content,
            compact: true,
            onOpenTranscript: {
                if let transcript = content.transcript { model.open(transcript) }
            },
            onOpenMaterial: { model.open($0) },
            onFocusInput: {
                guard let input = content.input else { return }
                selectProcessInput($0, input: input)
            },
            onSubmit: { submitProcess(content) }
        )
    }
}
