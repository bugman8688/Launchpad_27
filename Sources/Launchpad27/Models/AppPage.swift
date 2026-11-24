import Foundation

/// 分页网格中的一页：id 为页索引，apps 为该页应用（末页可能不足整页）。
struct AppPage: Identifiable {
    let id: Int
    let apps: [AppItem]
}
