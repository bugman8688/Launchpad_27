import SwiftUI

/// 网格中的单个应用图标单元。
struct AppIconCell: View {
    let app: AppItem
    /// 按格子尺寸推导的等比缩放系数。
    var scale: CGFloat = 1

    @UIState private var icon: NSImage?
    @UIState private var isHovering = false

    private var iconSide: CGFloat { 64 * scale }
    private var labelWidth: CGFloat { 96 * scale }
    private var cellWidth: CGFloat { 104 * scale }

    var body: some View {
        VStack(spacing: 8 * scale) {
            Image(nsImage: icon ?? AppIconCache.shared.placeholder)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSide, height: iconSide)
                .opacity(icon == nil ? 0.35 : 1)

            Text(app.name)
                .font(.system(size: 11 * scale))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: labelWidth)
        }
        .padding(.vertical, 8 * scale)
        .frame(width: cellWidth)
        .background(
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            AppLauncher().open(app)
        }
        .onAppear(perform: loadIconIfNeeded)
    }

    /// 命中缓存立即使用；否则先渲染占位，把实际读取推到下一轮，避免首帧卡顿。
    private func loadIconIfNeeded() {
        guard icon == nil else { return }

        if let cached = AppIconCache.shared.cachedIcon(for: app.bundleURL) {
            icon = cached
            return
        }

        Task { @MainActor in
            icon = AppIconCache.shared.icon(for: app.bundleURL)
        }
    }
}
