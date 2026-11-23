import AppKit

/// 应用启动服务：封装 NSWorkspace 打开逻辑，失败仅打印日志。
@MainActor
struct AppLauncher {
    func open(_ app: AppItem) {
        let configuration = NSWorkspace.OpenConfiguration()
        let name = app.name

        NSWorkspace.shared.openApplication(
            at: app.bundleURL,
            configuration: configuration
        ) { _, error in
            if let error {
                print("启动失败：\(name) - \(error.localizedDescription)")
            }
        }
    }
}
