import SwiftUI

struct ZippoCommands: Commands {
    @AppStorage("rowFontSize") private var fontSize: Double = RowFontSizeKey.defaultValue

    private static let defaultSize: Double = RowFontSizeKey.defaultValue
    private static let range: ClosedRange<Double> = 10...24
    private static let step: Double = 1

    var body: some Commands {
        CommandMenu("View") {
            Button("Make text bigger") {
                fontSize = min(fontSize + Self.step, Self.range.upperBound)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Make text smaller") {
                fontSize = max(fontSize - Self.step, Self.range.lowerBound)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Reset text size") {
                fontSize = Self.defaultSize
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}
