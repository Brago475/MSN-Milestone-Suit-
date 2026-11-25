import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Setup step 2. Shows the recovery key once, with print, save and copy.
struct RecoveryStep: View {

    let recoveryKey: String
    var onContinue: () -> Void

    @State private var saved = false
    @State private var copied = false

    private var groups: [String] {
        recoveryKey.split(separator: "-").map(String.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Save your recovery key")
                    .font(.system(size: 20, weight: .bold))
                Text("If you forget your master password, this key is the only way to open your locked folders and secrets. MSN can't reset it for you, and there is no account or server to recover from.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            keyBlocks

            HStack(spacing: 8) {
                actionButton("Print", systemImage: "printer", action: printKey)
                actionButton("Save as PDF", systemImage: "doc.richtext", action: saveKey)
                actionButton(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc", action: copyKey)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12, weight: .semibold))
                Text("Keep it somewhere safe and off this Mac, like printed in a drawer. Anyone with this key can open your locked folders.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
            .lineSpacing(3)
            .foregroundStyle(Color(red: 0xA8 / 255, green: 0x4B / 255, blue: 0x00 / 255))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1, green: 0xF2 / 255, blue: 0xE3 / 255), in: RoundedRectangle(cornerRadius: 9))

            Toggle("I saved my recovery key", isOn: $saved)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))

            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!saved)
            }
        }
    }

    // MARK: Pieces

    private var keyBlocks: some View {
        HStack(spacing: 8) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Text(group)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(1.3)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    // MARK: Actions

    private func copyKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recoveryKey, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func saveKey() {
        guard let data = RecoveryKeyPage.pdfData(for: recoveryKey) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "MSN Recovery Key.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func printKey() {
        guard let data = RecoveryKeyPage.pdfData(for: recoveryKey),
              let document = PDFDocument(data: data),
              let operation = document.printOperation(
                for: NSPrintInfo.shared,
                scalingMode: .pageScaleNone,
                autoRotate: false
              ) else { return }
        operation.run()
    }
}

/// Printable page for the recovery key. Always black on white.
struct RecoveryKeyPage: View {

    let recoveryKey: String

    static let pageSize = CGSize(width: 612, height: 792)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MSN Milestone Suit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
            Text("Recovery key")
                .font(.system(size: 26, weight: .bold))
            Text(recoveryKey)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .padding(16)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black, lineWidth: 1))
            Text("Created \(Date.now.formatted(date: .long, time: .omitted))")
                .font(.system(size: 12))
            Text("Use this key to open your locked folders and secrets if you forget your master password. Keep this page somewhere safe and off your Mac. Anyone with this key can open your locked folders.")
                .font(.system(size: 12))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .foregroundStyle(.black)
        .padding(56)
        .frame(width: Self.pageSize.width, height: Self.pageSize.height, alignment: .topLeading)
        .background(.white)
    }

    /// Renders the page as a one-page US Letter PDF.
    @MainActor
    static func pdfData(for key: String) -> Data? {
        let renderer = ImageRenderer(content: RecoveryKeyPage(recoveryKey: key))
        let data = NSMutableData()
        var success = false

        renderer.render { _, draw in
            var box = CGRect(origin: .zero, size: pageSize)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            success = true
        }
        return success ? data as Data : nil
    }
}