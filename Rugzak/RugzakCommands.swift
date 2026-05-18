import SwiftUI

struct RugzakCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("rowFontSize") private var fontSize: Double = RowFontSizeKey.defaultValue

    private static let defaultSize: Double = RowFontSizeKey.defaultValue
    private static let range: ClosedRange<Double> = 10...24
    private static let step: Double = 1

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button {
                openWindow(id: "about")
            } label: {
                Label("About Rugzak", systemImage: "info.circle")
            }
        }

        CommandMenu("View") {
            Button {
                fontSize = min(fontSize + Self.step, Self.range.upperBound)
            } label: {
                Label("Make text bigger", systemImage: "textformat.size.larger")
            }
            .keyboardShortcut("+", modifiers: .command)

            Button {
                fontSize = max(fontSize - Self.step, Self.range.lowerBound)
            } label: {
                Label("Make text smaller", systemImage: "textformat.size.smaller")
            }
            .keyboardShortcut("-", modifiers: .command)

            Button {
                fontSize = Self.defaultSize
            } label: {
                Label("Reset text size", systemImage: "textformat.size")
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}
