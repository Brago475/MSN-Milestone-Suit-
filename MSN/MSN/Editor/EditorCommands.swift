import Foundation

/// Toolbar actions shared by Page view and Markdown mode.
@MainActor
protocol EditorCommands: AnyObject {
    var isRichText: Bool { get }
    var isPainting: Bool { get }
    var currentStyle: TextStyle { get }
    var currentFont: PageFont { get }
    var currentSize: Double { get }
    var currentAlignment: PageAlignment { get }
    var currentSpacing: Double { get }

    func undo()
    func redo()
    func toggleBold()
    func toggleItalic()
    func toggleUnderline()
    func toggleStrike()
    func toggleSuperscript()
    func toggleSubscript()
    func insertLink()
    func setStyle(_ style: TextStyle)
    func toggleList(_ kind: ListKind)
    func insertTable()
    func insertCodeBlock()
    func insertDivider()
    func insertPageBreak()
    func insertCallout(_ kind: CalloutKind)
    func insertDate()

    func setFont(_ font: PageFont)
    func setSize(_ size: Double)
    func stepSize(_ delta: Double)
    func setTextColor(_ hex: String?)
    func setHighlight(_ hex: String?)
    func clearFormatting()
    func paintFormat()
    func setAlignment(_ alignment: PageAlignment)
    func setLineSpacing(_ spacing: Double)
    func indent(_ delta: Int)
}