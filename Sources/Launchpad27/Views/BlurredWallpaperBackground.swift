import AppKit
import SwiftUI

/// 背景层：桌面壁纸高斯模糊并压暗；取不到壁纸时回退为深色渐变。
struct BlurredWallpaperBackground: View {
    var blurRadius: CGFloat = 40

    @UIState private var wallpaper: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                fallbackGradient

                if let wallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

                // 压暗保证图标与文字在任意壁纸上都有足够对比度。
                Color.black.opacity(0.25)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .task {
            guard wallpaper == nil, let screen = NSScreen.main else { return }
            wallpaper = DesktopWallpaperService.shared.blurredWallpaper(for: screen, radius: blurRadius)
        }
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [Color(red: 0.10, green: 0.12, blue: 0.20), Color(red: 0.02, green: 0.03, blue: 0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
