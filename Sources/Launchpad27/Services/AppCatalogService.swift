import AppKit

/// 应用枚举服务：只读扫描系统应用目录，收集可启动的 .app。
@MainActor
final class AppCatalogService {
    private let fileManager = FileManager.default

    /// 扫描常见应用目录（仅一级子目录），按名称排序返回。
    func loadApplications() -> [AppItem] {
        let directories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var seenPaths = Set<String>()
        var apps: [AppItem] = []

        for directory in directories {
            // 目录不存在或无权限时静默跳过。
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: []
            ) else { continue }

            for entry in entries where entry.pathExtension.lowercased() == "app" {
                // 手动排除点号开头的隐藏条目；不整体跳过隐藏项，否则会漏掉 Safari 这类 hidden 符号链接。
                guard !entry.lastPathComponent.hasPrefix(".") else { continue }
                let bundleURL = entry.resolvingSymlinksInPath().standardizedFileURL
                guard seenPaths.insert(bundleURL.path).inserted else { continue }

                apps.append(AppItem(
                    id: bundleURL.path,
                    name: displayName(for: bundleURL),
                    bundleURL: bundleURL,
                    icon: NSWorkspace.shared.icon(forFile: bundleURL.path)
                ))
            }
        }

        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 优先取系统显示名，取不到时回退文件名去掉 .app 后缀。
    private func displayName(for bundleURL: URL) -> String {
        let display = fileManager.displayName(atPath: bundleURL.path)
        if !display.isEmpty {
            return display
        }
        return bundleURL.deletingPathExtension().lastPathComponent
    }
}
