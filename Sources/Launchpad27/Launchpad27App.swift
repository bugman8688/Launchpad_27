import AppKit
import SwiftUI

/// 当前工具链（Command Line Tools）未附带 SwiftUI 宏插件，`@State` 宏无法展开；
/// 这里直接别名其底层属性包装器，行为与 `@State` 完全一致。
typealias UIState<Value> = SwiftUICore.State<Value>

/// 应用入口：全屏窗口承载图标网格。
@main
struct Launchpad27App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
                .task {
                    await enterFullScreenWhenReady()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
    }

    /// 等窗口真正创建后再切换全屏，避免窗口尚未就绪时 toggle 无效。
    @MainActor
    private func enterFullScreenWhenReady() async {
        try? await Task.sleep(for: .milliseconds(500))

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else {
            print("未找到可用窗口，跳过全屏切换")
            return
        }

        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
}
