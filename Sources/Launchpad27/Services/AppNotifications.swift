import Foundation

/// 应用内动作通知：键盘监听与窗口控制通过它驱动界面，避免 Views 直接操作窗口。
extension Notification.Name {
    /// 追加搜索字符，userInfo["text"]: String
    static let appAppendSearchText = Notification.Name("launchpad27.appendSearchText")
    /// 聚焦搜索框
    static let appFocusSearch = Notification.Name("launchpad27.focusSearch")
    /// 清空搜索词
    static let appClearSearch = Notification.Name("launchpad27.clearSearch")
    /// 翻页，userInfo["delta"]: Int
    static let appChangePage = Notification.Name("launchpad27.changePage")
    /// Esc 动作，由界面层决定「清空搜索」还是「退出」
    static let appEscape = Notification.Name("launchpad27.escape")
    /// 隐藏窗口（点击空白处 / Esc 兜底）
    static let appHideWindow = Notification.Name("launchpad27.hideWindow")
    /// 跟手横滑位移，userInfo["delta"]: CGFloat、["velocity"]: CGFloat
    static let appPageDrag = Notification.Name("launchpad27.pageDrag")
    /// 跟手滑动结束，需要吸附
    static let appPageDragEnded = Notification.Name("launchpad27.pageDragEnded")
}
