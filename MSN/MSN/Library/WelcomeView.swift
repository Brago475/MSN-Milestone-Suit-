import SwiftUI

extension Notification.Name {
    nonisolated static let msnFocusSearch = Notification.Name("msnFocusSearch")
}

/// Shown when no file is selected: today, recent notes as a paper stack, and shortcuts.
struct WelcomeView: View {

    @Environment(LibraryStore.self) private var library
    @Environment(VaultSession.self) private var vault

    @State private var hovered: String?
    @State private var previewID: String?
    @State private var excerpts: [String: String] = [:]
    @State private var isDropTarget = false

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: Data

    private var files: [FileNode] {
        library.index.values.filter { !$0.isFolder }
    }

    private var folderCount: Int {
        library.index.values.filter(\.isFolder).count
    }

    private var editedToday: Int {
        files.filter { Calendar.current.isDateInToday($0.modified) }.count
    }

    /// Six most recently edited notes, oldest first so the newest sits on top.
    private var recent: [FileNode] {
        let notes = files
            .filter { $0.kind != .pdf }
            .sorted { $0.modified > $1.modified }
            .prefix(6)
        return Array(notes.reversed())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        let first = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? part : "\(part), \(first)"
    }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Text("Recent")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 28)
                        .padding(.bottom, 10)
                    recentSection
                    shortcuts
                        .padding(.top, 20)
                    dropHint
                        .padding(.top, 16)
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 40)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.accent, lineWidth: 2)
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls)
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        .background {
            Button("") { vault.lock() }
                .keyboardShortcut("l", modifiers: .command)
                .opacity(0)
        }
        .onAppear { excerpts = [:] }
    }

    // MARK: Today

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(greeting)
                    .font(.system(size: 24, weight: .semibold))
            }
            Spacer(minLength: 16)
            HStack(spacing: 16) {
                stat("pencil", count(editedToday, "edited today", "edited today"))
                stat("doc", count(files.count, "note", "notes"))
                stat("folder", count(folderCount, "folder", "folders"))
            }
            .padding(.bottom, 4)
        }
    }

    private func stat(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func count(_ value: Int, _ one: String, _ many: String) -> String {
        "\(value) \(value == 1 ? one : many)"
    }

    // MARK: Recent

    @ViewBuilder
    private var recentSection: some View {
        if recent.isEmpty {
            emptyStack
        } else {
            HStack(alignment: .bottom, spacing: 20) {
                paperStack
                    .frame(width: 310, height: 210, alignment: .bottomLeading)
                previewPanel
            }
        }
    }

    private var paperStack: some View {
        let notes = recent
        let hoverIndex = notes.firstIndex { $0.id == hovered }
        let mid = Double(notes.count - 1) / 2

        return ZStack(alignment: .bottomLeading) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, node in
                let active = hovered == node.id
                let spread = Double(index) - mid
                let shift: CGFloat = hoverIndex.map { index < $0 ? -14 : (index > $0 ? 14 : 0) } ?? 0

                PaperCard(title: title(of: node), isActive: active)
                    .rotationEffect(.degrees(active ? 0 : spread * 5), anchor: .bottom)
                    .scaleEffect(active ? 1.06 : 1, anchor: .bottom)
                    .offset(x: 20 + CGFloat(index) * 34 + shift, y: active ? -22 : abs(spread) * 3)
                    .zIndex(active ? 20 : Double(index))
                    .onHover { inside in
                        if inside { hover(node) }
                    }
                    .onTapGesture { open(node) }
                    .help("Open \(title(of: node))")
            }
        }
        .animation(.spring(duration: 0.28), value: hovered)
        .onHover { inside in
            if !inside { hovered = nil }
        }
    }

    private var previewPanel: some View {
        let node = previewID.flatMap { library.index[$0] }

        return VStack(alignment: .leading, spacing: 0) {
            if let node {
                Text(title(of: node))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(meta(for: node))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                Text(excerpt(for: node))
                    .font(.custom("Times New Roman", size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .lineLimit(6)
                Spacer(minLength: 0)
                Text("Click the paper to open")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Hover a paper")
                    .font(.system(size: 14, weight: .semibold))
                Text("Preview shows here")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                Text("Your most recent notes sit in the stack. Click one to open it.")
                    .font(.custom("Times New Roman", size: 13))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var emptyStack: some View {
        HStack(spacing: 20) {
            Button(action: newNote) {
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                    Text("Create your\nfirst note")
                        .font(.system(size: 11, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .frame(width: 120, height: 156)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Notes you edit show up here as a stack.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Shortcuts

    private var shortcuts: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                ShortcutRow(symbol: "doc.badge.plus", title: "New note", keys: "⌘N", action: newNote)
                ShortcutRow(symbol: "folder.badge.plus", title: "New folder", keys: "⇧⌘N", action: newFolder)
            }
            GridRow {
                ShortcutRow(symbol: "magnifyingglass", title: "Search vault", keys: "⌘K") {
                    NotificationCenter.default.post(name: .msnFocusSearch, object: nil)
                }
                ShortcutRow(symbol: "lock", title: "Lock vault", keys: "⌘L") {
                    vault.lock()
                }
            }
        }
        .padding(8)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var dropHint: some View {
        Label("Drop Markdown files or folders here to add them to the vault", systemImage: "square.and.arrow.down")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func title(of node: FileNode) -> String {
        node.url.deletingPathExtension().lastPathComponent
    }

    private func meta(for node: FileNode) -> String {
        let folder = library.relativePath(of: node.url.deletingLastPathComponent())
        let when = Self.relative.localizedString(for: node.modified, relativeTo: .now)
        return "\(folder), edited \(when)"
    }

    private func excerpt(for node: FileNode) -> String {
        let text = excerpts[node.id] ?? ""
        return text.isEmpty ? "This note is empty." : text
    }

    private func hover(_ node: FileNode) {
        hovered = node.id
        previewID = node.id
        if excerpts[node.id] == nil {
            excerpts[node.id] = Self.excerpt(of: node.url)
        }
    }

    /// Opens a note and expands its folders in the sidebar.
    private func open(_ node: FileNode) {
        if let rootKey = library.rootURL?.fileKey {
            var parent = node.url.deletingLastPathComponent()
            while parent.fileKey.hasPrefix(rootKey + "/") {
                library.expanded.insert(parent.fileKey)
                parent = parent.deletingLastPathComponent()
            }
        }
        library.selection = node.id
    }

    private func newNote() {
        do {
            _ = try library.createNote(in: library.rootURL)
        } catch {
            library.lastError = error.localizedDescription
        }
    }

    private func newFolder() {
        do {
            _ = try library.createFolder(in: library.rootURL)
        } catch {
            library.lastError = error.localizedDescription
        }
    }

    /// Moves vault items to the top level and copies outside items in.
    private func handleDrop(_ urls: [URL]) -> Bool {
        isDropTarget = false
        guard let root = library.rootURL else { return false }

        for url in urls where library.isInsideVault(url) {
            do {
                _ = try library.move(url, into: root)
            } catch {
                library.lastError = error.localizedDescription
            }
        }

        let outside = urls.filter { !library.isInsideVault($0) }
        if !outside.isEmpty {
            let result = library.importItems(outside, into: root)
            if result.skipped > 0 {
                library.lastError = "\(result.imported) added. \(result.skipped) skipped. MSN adds Markdown, text and PDF files, and folders."
            }
        }
        return !urls.isEmpty
    }

    // MARK: Excerpt

    /// Reads the start of a note and returns plain readable text.
    private static func excerpt(of url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        return clean(String(decoding: data, as: UTF8.self))
    }

    private static func clean(_ raw: String) -> String {
        var text = raw

        if text.hasPrefix("---"),
           let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) {
            text = String(text[end.upperBound...])
        }

        let replacements: [(String, String)] = [
            ("<!--[\\s\\S]*?-->", ""),
            ("<[^>]+>", ""),
            ("\\[\\[([^\\]|]+)(\\|[^\\]]+)?\\]\\]", "$1"),
            ("\\[([^\\]]+)\\]\\([^)]*\\)", "$1"),
            ("\\*\\*|__|~~|`", ""),
            ("\\\\(.)", "$1")
        ]
        for (pattern, template) in replacements {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }

        let lines = text
            .split(separator: "\n")
            .map { line in
                line.replacingOccurrences(
                    of: "^\\s*(#{1,6}\\s+|>\\s?|[-*+]\\s+(\\[[ xX]\\]\\s+)?|\\d+[.)]\\s+)",
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespaces)
            }
            .filter { line in
                !line.isEmpty && !line.allSatisfy { "-|: ".contains($0) }
            }

        return lines.prefix(8).joined(separator: " ")
    }
}

/// One sheet in the recent stack.
private struct PaperCard: View {

    let title: String
    let isActive: Bool

    private static let lines: [CGFloat] = [0.9, 0.7, 0.95, 0.6, 0.85, 0.5, 0.75]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.bottom, 4)
            ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, width in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 100 * width, height: 3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .frame(width: 120, height: 156, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? Theme.accent : Color.secondary.opacity(0.35), lineWidth: isActive ? 1.5 : 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .contentShape(Rectangle())
    }
}

/// A clickable shortcut with its key combination.
private struct ShortcutRow: View {

    let symbol: String
    let title: String
    let keys: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.system(size: 13))
                Spacer(minLength: 8)
                Text(keys)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                isHovered ? Color.secondary.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}