import AppKit
import SwiftUI

/// 当前工具链（Command Line Tools）未附带 SwiftUI 宏插件，`@State` 宏无法展开；
/// 这里直接别名其底层属性包装器，行为与 `@State` 完全一致。
typealias UIState<Value> = SwiftUICore.State<Value>

/// 应用入口：以 AppKit 生命周期创建覆盖式全屏窗口（SwiftUI WindowGroup 无法产出可聚焦的无边框窗口）。
@main
struct Launchpad27App {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

/// 管理覆盖窗口的显示与隐藏，以及呈现期间 Dock / 菜单栏的自动隐藏。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: LaunchpadWindow?
    private var isObservingSpaceChanges = false
    private var isObservingHideRequests = false
    private var isObservingScreenChanges = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        observeHideRequests()
        observeScreenChanges()
        KeyboardMonitor.shared.start()
        ScrollMonitor.shared.start()
        showLaunchpad()
    }

    /// Dock 图标再次点击时重新唤起（进程常驻，窗口只是被隐藏）。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showLaunchpad()
        }
        return true
    }

    func showLaunchpad() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let window = self.window ?? makeWindow(on: screen)
        self.window = window
        window.setFrame(screen.frame, display: true)

        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        observeSpaceChanges()
    }

    func hideLaunchpad() {
        NSApp.presentationOptions = []
        window?.orderOut(nil)
    }

    private func makeWindow(on screen: NSScreen) -> LaunchpadWindow {
        let window = LaunchpadWindow(contentRect: screen.frame)
        window.delegate = self
        window.contentView = NSHostingView(rootView: ContentView())
        return window
    }

    /// Space 切换后系统可能重置窗口可视状态，这里把窗口重新置顶做兜底。
    private func observeSpaceChanges() {
        guard !isObservingSpaceChanges else { return }
        isObservingSpaceChanges = true

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleActiveSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func handleActiveSpaceChange() {
        guard let window, window.isVisible else { return }
        window.orderFrontRegardless()
        if !window.isKeyWindow {
            window.makeKey()
        }
    }

    /// 界面层请求隐藏窗口（点击空白处 / Esc）。
    private func observeHideRequests() {
        guard !isObservingHideRequests else { return }
        isObservingHideRequests = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHideRequest),
            name: .appHideWindow,
            object: nil
        )
    }

    @objc private func handleHideRequest() {
        hideLaunchpad()
    }

    /// 显示器拔插 / 旋转 / 切换主屏后，把覆盖窗口挪到当前屏幕并重新铺满。
    private func observeScreenChanges() {
        guard !isObservingScreenChanges else { return }
        isObservingScreenChanges = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenParametersChange() {
        guard let window, window.isVisible, let screen = NSScreen.main else { return }
        window.setFrame(screen.frame, display: true)
    }
}
