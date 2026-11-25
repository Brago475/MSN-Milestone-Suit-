import Foundation
import Observation

/// An open Markdown file with autosave.
@MainActor
@Observable
final class MarkdownDocument {

    enum SaveState {
        case saved
        case editing
        case failed
    }

    let url: URL
    private(set) var text: String
    private(set) var saveState: SaveState = .saved

    private var loadedDate: Date?
    private var saveTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        self.text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        self.loadedDate = Self.modificationDate(of: url)
    }

    var fileName: String { url.lastPathComponent }

    var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    var characterCount: Int { text.count }

    /// Records an edit and schedules a save.
    func update(_ newText: String) {
        guard newText != text else { return }
        text = newText
        saveState = .editing
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// Writes pending edits. Skips files that were moved or deleted.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        guard saveState != .saved else { return }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            saveState = .saved
            return
        }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            loadedDate = Self.modificationDate(of: url)
            saveState = .saved
        } catch {
            saveState = .failed
        }
    }

    /// Reloads from disk when the file changed outside MSN and nothing is pending.
    @discardableResult
    func reloadIfChangedOnDisk() -> Bool {
        guard saveState == .saved,
              let diskDate = Self.modificationDate(of: url),
              let loadedDate, diskDate > loadedDate,
              let fresh = try? String(contentsOf: url, encoding: .utf8) else { return false }
        text = fresh
        self.loadedDate = diskDate
        return true
    }

    private static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}