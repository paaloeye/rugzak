import AppKit
import SwiftUI

@MainActor
struct DropTargetView: NSViewRepresentable {
    @Binding var isTargeted: Bool

    func makeNSView(context: Context) -> ArchiveDropView {
        let view = ArchiveDropView()
        view.isTargetedBinding = $isTargeted
        return view
    }

    func updateNSView(_ nsView: ArchiveDropView, context: Context) {}
}

final class ArchiveDropView: NSView {
    var isTargetedBinding: Binding<Bool>?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasValidArchive(sender) else { return [] }
        isTargetedBinding?.wrappedValue = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargetedBinding?.wrappedValue = false
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasValidArchive(sender) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargetedBinding?.wrappedValue = false
        let urls = archiveURLs(from: sender)
        guard !urls.isEmpty else { return false }
        for url in urls {
            ArchiveManager.shared.mount(url)
        }
        return true
    }

    private func hasValidArchive(_ sender: NSDraggingInfo) -> Bool {
        !archiveURLs(from: sender).isEmpty
    }

    private func archiveURLs(from sender: NSDraggingInfo) -> [URL] {
        guard
            let items = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [
                    .urlReadingFileURLsOnly: true
                ]) as? [URL]
        else { return [] }
        return items.filter { ArchiveManager.supportedExtensions.contains($0.pathExtension.lowercased()) }
    }
}
