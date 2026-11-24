import AppKit

/// 图标缓存：按需读取并做进程内缓存，未就绪时提供占位图。
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var cache: [String: NSImage] = [:]

    /// 图标未加载时展示的占位图。
    lazy var placeholder: NSImage = {
        NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
    }()

    /// 已缓存的图标；未命中返回 nil。
    func cachedIcon(for bundleURL: URL) -> NSImage? {
        cache[bundleURL.path]
    }

    /// 读取图标（命中缓存直接返回），结果按 bundle 路径缓存。
    func icon(for bundleURL: URL) -> NSImage {
        let key = bundleURL.path
        if let cached = cache[key] { return cached }

        let image = NSWorkspace.shared.icon(forFile: key)
        image.size = NSSize(width: 128, height: 128)
        cache[key] = image
        return image
    }
}
