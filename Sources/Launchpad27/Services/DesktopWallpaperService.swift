import AppKit
import CoreImage

/// 桌面壁纸毛玻璃服务：读取当前桌面壁纸并做高斯模糊，结果按壁纸与屏幕尺寸缓存。
@MainActor
final class DesktopWallpaperService {
    static let shared = DesktopWallpaperService()

    private let context = CIContext()
    private var cache: [String: NSImage] = [:]

    /// 返回指定屏幕壁纸的模糊版本；取不到壁纸时返回 nil，由调用方回退。
    func blurredWallpaper(for screen: NSScreen, radius: CGFloat = 40) -> NSImage? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }

        let key = "\(url.path)|\(Int(screen.frame.width))x\(Int(screen.frame.height))|\(Int(radius))"
        if let cached = cache[key] { return cached }

        guard let source = NSImage(contentsOf: url),
              let tiff = source.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cgImage = bitmap.cgImage else { return nil }

        // 先向外延展再模糊，避免边缘被透明像素拖暗；模糊后裁回原尺寸。
        let input = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)

        guard let output = filter.outputImage?.cropped(to: input.extent),
              let blurred = context.createCGImage(output, from: input.extent) else { return nil }

        let image = NSImage(cgImage: blurred, size: source.size)
        cache[key] = image
        return image
    }
}
