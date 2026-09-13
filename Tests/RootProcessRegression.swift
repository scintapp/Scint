import Foundation
import SwiftUI
@testable import Scint

@main struct RootProcessRegression {
    @MainActor static func main() {
        let alpha = Space.new("Alpha")
        let alphaChild = Space.new(alpha, name: "Alpha child")
        let alphaLeaf = Space.new(alphaChild, name: "Alpha leaf")
        let beta = Space.new("Beta")
        let betaChild = Space.new(beta, name: "Beta child")
        let alphaMaterial = Material.new(alphaChild, name: "Alpha document")
        let betaMaterial = Material.new(betaChild, name: "Beta document")
        let alphaTranscript = Transcript.new(alphaChild)
        let betaTranscript = Transcript.new(betaChild)
        let studio = StudioModel(Session(alpha))
        let editor = EditorModel(Session(alpha))

        precondition(studio.roots == [alpha, beta], "Only parentless spaces belong in the root list")
        precondition(studio.root(for: alphaLeaf) == alpha, "Nested selection must resolve its root through the existing path model")
        let items = SpacesList.parameters(studio).sections.flatMap(\.items)
        precondition(Set(items.compactMap(\.ref)) == Set([alpha, beta]))
        precondition(items.first(where: { $0.ref == alpha })?.items.first?.ref == alphaChild)
        precondition(items.first(where: { $0.ref == beta })?.items.first?.ref == betaChild)

        studio.select(alphaChild)
        studio.open(alphaMaterial)
        studio.select(betaChild)
        precondition(studio.session.space == beta)
        precondition(studio.session.selection.structure == betaChild)
        precondition(studio.session.opened.material == nil, "Root switching must close the previous root's editor")
        precondition(editor.session.space == alpha, "A different model must retain its own root")
        precondition(studio.session.navigation.path(for: studio.session.selection, in: studio.session.space) == [beta, betaChild])
        studio.session.back()
        precondition(studio.session.selection.structure == beta)
        studio.session.forward()
        precondition(studio.session.selection.structure == betaChild)
        studio.select(alphaLeaf)
        precondition(studio.session.space == alpha)
        precondition(studio.session.navigation.path(for: studio.session.selection, in: studio.session.space) == [alpha, alphaChild, alphaLeaf])

        let alphaCard = SpaceSurface(ref: alphaChild, panel: studio.canvas, model: studio)
        let betaCard = SpaceSurface(ref: betaChild, panel: studio.canvas, model: studio)
        studio.select(betaChild)
        precondition(alphaCard.ref == alphaChild && betaCard.ref == betaChild)
        precondition(alphaCard.materials == [alphaMaterial] && betaCard.materials == [betaMaterial])
        precondition(alphaCard.transcripts == [alphaTranscript] && betaCard.transcripts == [betaTranscript])
        precondition(!alphaCard.selected && betaCard.selected)
        precondition(SpaceHeader(ref: alphaCard.ref, panel: studio.canvas, model: studio).name == "Alpha child")
        precondition(SpaceHeader(ref: betaCard.ref, panel: studio.canvas, model: studio).name == "Beta child")
        print("PASS: root discovery, nested root switching, independent sessions, back/forward paths, and per-node canvas content")
    }
}
