import SwiftUI

/// 网格中的单个应用图标单元。
struct AppIconCell: View {
    let app: AppItem

    @UIState private var isHovering = false

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            Text(app.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 96)
        }
        .padding(.vertical, 8)
        .frame(width: 104)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            AppLauncher().open(app)
        }
    }
}
