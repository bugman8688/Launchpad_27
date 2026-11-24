import AppKit

/// 铺满屏幕、层级高于系统屏蔽层的无边框窗口，复刻旧版 Launchpad 的覆盖式呈现。
final class LaunchpadWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // 提升到屏蔽层：三/四指上滑触发 Mission Control 时，本窗口仍覆盖在其上方。
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }

    /// Esc：隐藏窗口，进程继续常驻。
    override func cancelOperation(_ sender: Any?) {
        (delegate as? AppDelegate)?.hideLaunchpad()
    }
}
