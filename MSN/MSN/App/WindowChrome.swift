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

/// Reports when the window enters or leaves full screen.
struct FullScreenReader: NSViewRepresentable {

    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = { value in
            if value != isFullScreen { isFullScreen = value }
        }
        return view
    }

    func updateNSView(_ nsView: ReaderView, context: Context) {}

    final class ReaderView: NSView {

        var onChange: ((Bool) -> Void)?
        private var observers: [NSObjectProtocol] = []

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
                let token = NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.report() }
                }
                observers.append(token)
            }
            Task { @MainActor [weak self] in
                self?.report()
            }
        }

        private func report() {
            onChange?(window?.styleMask.contains(.fullScreen) ?? false)
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