import AppKit
import Carbon
import SwiftUI

/// Follows the menu bar sliding in and out in full screen, the way Chrome does on Mac.
/// Reports progress from 0 (hidden) to 1 (fully shown), and whether it is a live step of the slide.
@MainActor
final class MenuBarTracker {

    /// Undocumented menu bar reveal event and its progress parameter, as used by Chrome.
    private static let revealEventKind: UInt32 = 2004
    private static let revealFraction: OSType = 0x72766C66 // 'rvlf'

    /// Progress, and true when it is a step of the slide rather than a jump to shown or hidden.
    var onProgress: ((CGFloat, Bool) -> Void)?
    private var handler: EventHandlerRef?

    func start() {
        guard handler == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: Self.revealEventKind),
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarShown)),
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuBarHidden))
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { next, event, userData in
                if let event, let userData {
                    let kind = GetEventKind(event)
                    var progress: CGFloat?
                    var isLive = false

                    if kind == MenuBarTracker.revealEventKind {
                        var fraction: CGFloat = 0
                        GetEventParameter(
                            event,
                            MenuBarTracker.revealFraction,
                            OSType(typeCGFloat),
                            nil,
                            MemoryLayout<CGFloat>.size,
                            nil,
                            &fraction
                        )
                        // Reveal events from other Spaces report only 0 or 1, so those are skipped.
                        if fraction > 0, fraction < 1 {
                            progress = fraction
                            isLive = true
                        }
                    } else if kind == UInt32(kEventMenuBarShown) {
                        progress = 1
                    } else {
                        progress = 0
                    }

                    if let progress {
                        let tracker = Unmanaged<MenuBarTracker>.fromOpaque(userData).takeUnretainedValue()
                        let live = isLive
                        Task { @MainActor in
                            tracker.onProgress?(progress, live)
                        }
                    }
                }
                return CallNextEventHandler(next, event)
            },
            specs.count,
            &specs,
            context,
            &handler
        )
    }

    func stop() {
        if let handler {
            RemoveEventHandler(handler)
        }
        handler = nil
    }

    /// Height of the menu bar on the window's screen, including the camera notch area.
    static func height(for window: NSWindow?) -> CGFloat {
        let menu = NSApp.mainMenu?.menuBarHeight ?? 24
        let notch = window?.screen?.safeAreaInsets.top ?? 0
        return max(menu, notch, 24)
    }

    /// True when the pointer is on this window's screen.
    static func isMouseOnScreen(of window: NSWindow?) -> Bool {
        guard let screen = window?.screen else { return false }
        return NSMouseInRect(NSEvent.mouseLocation, screen.frame, false)
    }
}

extension EnvironmentValues {
    /// How far the menu bar pushes the top section down in full screen.
    @Entry var menuBarInset: CGFloat = 0
}