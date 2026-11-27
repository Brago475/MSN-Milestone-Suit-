import AppKit
import SwiftUI

/// Measures the window buttons so the pocket behind them fits with even padding.
struct WindowButtonsReader: NSViewRepresentable {

    @Binding var size: CGSize

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onMeasure = { newSize in
            if newSize != size { size = newSize }
        }
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {}

    final class ReaderView: NSView {

        var onMeasure: ((CGSize) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            Task { @MainActor [weak self] in
                self?.measure()
            }
        }

        private func measure() {
            guard let window,
                  !window.styleMask.contains(.fullScreen),
                  let content = window.contentView,
                  let close = window.standardWindowButton(.closeButton),
                  let zoom = window.standardWindowButton(.zoomButton) else { return }

            let first = close.convert(close.bounds, to: content)
            let last = zoom.convert(zoom.bounds, to: content)

            let top = content.isFlipped ? first.minY : content.bounds.height - first.maxY
            let bottom = content.isFlipped ? first.maxY : content.bounds.height - first.minY

            let width = (last.maxX + first.minX).rounded()
            let height = (bottom + top).rounded()
            guard width > 0, height > 0 else { return }
            onMeasure?(CGSize(width: width, height: height))
        }
    }
}

/// Reports full screen changes, and in full screen how far the menu bar pushes the top section down.
/// Live steps of the slide are followed exactly; jumps to shown or hidden are animated.
/// In full screen the system title strip is hidden, since the pocket shows its own buttons.
struct FullScreenReader: NSViewRepresentable {

    @Binding var isFullScreen: Bool
    @Binding var menuBarInset: CGFloat

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onFullScreen = { value in
            if value != isFullScreen { isFullScreen = value }
        }
        view.onMenuBarInset = { value, animated in
            guard abs(value - menuBarInset) > 0.25 else { return }
            if animated {
                withAnimation(.smooth(duration: 0.28)) {
                    menuBarInset = value
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    menuBarInset = value
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {}

    final class ReaderView: NSView {

        var onFullScreen: ((Bool) -> Void)?
        var onMenuBarInset: ((CGFloat, Bool) -> Void)?
        private var observers: [NSObjectProtocol] = []
        private let menuBar = MenuBarTracker()
        private var progress: CGFloat = 0

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            menuBar.stop()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            menuBar.onProgress = { [weak self] value, isLive in
                self?.setProgress(value, isLive: isLive)
            }

            observe(NSWindow.didEnterFullScreenNotification, on: window) { view in
                view.setSystemTitleStripHidden(true)
                view.menuBar.start()
                view.report()
            }
            observe(NSWindow.willExitFullScreenNotification, on: window) { view in
                view.menuBar.stop()
                view.progress = 0
                view.onMenuBarInset?(0, false)
                view.setSystemTitleStripHidden(false)
            }
            observe(NSWindow.didExitFullScreenNotification, on: window) { view in
                view.setSystemTitleStripHidden(false)
                view.report()
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.window?.styleMask.contains(.fullScreen) == true {
                    self.setSystemTitleStripHidden(true)
                    self.menuBar.start()
                }
                self.report()
            }
        }

        /// Same checks as Chrome: full screen only, this screen only when revealing, active Space only.
        private func setProgress(_ value: CGFloat, isLive: Bool) {
            guard let window, window.styleMask.contains(.fullScreen) else { return }
            if value > progress && !MenuBarTracker.isMouseOnScreen(of: window) { return }
            guard window.isOnActiveSpace else { return }
            progress = value
            onMenuBarInset?((MenuBarTracker.height(for: window) * value).rounded(), !isLive)
        }

        private func observe(_ name: Notification.Name, on window: NSWindow, action: @escaping @MainActor (ReaderView) -> Void) {
            let token = NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if let self { action(self) }
                }
            }
            observers.append(token)
        }

        /// In full screen macOS keeps the title strip in a separate window that slides down
        /// with the menu bar. Hiding its content removes the strip, as Chrome does.
        private func setSystemTitleStripHidden(_ hidden: Bool) {
            guard let screen = window?.screen else { return }
            for candidate in NSApp.windows
            where candidate.className == "NSToolbarFullScreenWindow" && candidate.screen == screen {
                candidate.contentView?.isHidden = hidden
            }
        }

        private func report() {
            onFullScreen?(window?.styleMask.contains(.fullScreen) ?? false)
        }
    }
}

/// Gray pocket for the window buttons. Its right and bottom edges curve into the window edges.
struct PocketShape: Shape {

    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let width = rect.width - radius
        let height = rect.height - radius
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: width + radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: width, y: radius), control: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height - radius))
        path.addQuadCurve(to: CGPoint(x: width - radius, y: height), control: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: radius, y: height))
        path.addQuadCurve(to: CGPoint(x: 0, y: height + radius), control: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}