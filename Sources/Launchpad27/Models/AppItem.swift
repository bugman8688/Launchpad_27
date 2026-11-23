import AppKit

/// 网格中展示的单个应用条目。
struct AppItem: Identifiable {
    /// 以 bundle 路径作为唯一标识，天然去重。
    let id: String
    let name: String
    let bundleURL: URL
    let icon: NSImage
}
