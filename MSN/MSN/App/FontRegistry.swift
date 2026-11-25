import CoreText
import Foundation

/// Loads the fonts shipped inside the app. They are available to MSN only.
enum FontRegistry {

    static func registerBundledFonts() {
        guard let root = Bundle.main.resourceURL,
              let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return }

        var urls: [URL] = []
        for case let url as URL in items {
            let ext = url.pathExtension.lowercased()
            if ext == "ttf" || ext == "otf" {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}