import AppKit
import SwiftUI

/// 主界面：按需浮现的顶部搜索框 + 按屏幕空间自适应行列的分页图标网格。
struct ContentView: View {
    /// 网格布局：行列按基准屏等比映射，图标按格子尺寸自适应放大。
    private struct GridLayout {
        let columns: Int
        let rows: Int
        let scale: CGFloat
        var pageSize: Int { columns * rows }
    }

    /// 旧版基准：1440×900 对应 7 列 × 5 行。
    private static let baseColumns = 7
    private static let baseRows = 5
    private static let baseScreenSize = CGSize(width: 1440, height: 900)

    @UIState private var apps: [AppItem] = []
    @UIState private var searchText = ""
    @UIState private var pageIndex = 0
    @UIState private var dragOffset: CGFloat = 0
    @UIState private var pageWidth: CGFloat = 0
    @UIState private var isSearchVisible = false
    @UIState private var isTopZoneHovered = false
    @UIState private var dismissTask: Task<Void, Never>?
    /// 当前屏幕尺寸，随显示器配置变化（拔插、旋转、切换主屏）更新。
    @UIState private var screenSize: CGSize = NSScreen.main?.frame.size ?? CGSize(width: 1352, height: 878)
    @FocusState private var isSearchFocused: Bool

    /// 列宽在算出的列数内弹性铺满。
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 24), count: layout.columns)
    }

    /// 行列按基准屏等比映射（当前屏 7×5，大屏更多、竖屏少列多行）；图标按格子尺寸放大到刚好不溢出。
    private var layout: GridLayout {
        let columnSpacing: CGFloat = 24
        let rowSpacing: CGFloat = 28
        // 基准单元 104×101（图标 64 + 标题），仅用于推算放大系数。
        let unitWidth: CGFloat = 104
        let unitHeight: CGFloat = 101

        // 可用空间：左右各留 40pt，顶部偏移 96pt，底部页码区约 50pt。
        let availableWidth = screenSize.width - 80
        let availableHeight = screenSize.height - 96 - 50

        let columns = max(3, min(12, Int((CGFloat(Self.baseColumns) * screenSize.width / Self.baseScreenSize.width).rounded())))
        let rows = max(2, min(8, Int((CGFloat(Self.baseRows) * screenSize.height / Self.baseScreenSize.height).rounded())))

        // 按行列与间距反推每个格子可用的宽高，取两者较小比例作为缩放。
        let cellWidth = (availableWidth - CGFloat(columns - 1) * columnSpacing) / CGFloat(columns)
        let cellHeight = (availableHeight - CGFloat(rows - 1) * rowSpacing) / CGFloat(rows)
        let scale = min(cellWidth / unitWidth, cellHeight / unitHeight)

        return GridLayout(columns: columns, rows: rows, scale: max(0.5, scale))
    }

    private var keyword: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredApps: [AppItem] {
        guard !keyword.isEmpty else { return apps }
        let query = normalized(keyword)
        return apps.filter { normalized($0.name).contains(query) }
    }

    /// 搜索归一化：忽略大小写与重音符号。
    private func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var emptyStateText: String? {
        if apps.isEmpty && keyword.isEmpty {
            return "未找到应用"
        }
        if !keyword.isEmpty && filteredApps.isEmpty {
            return "无结果"
        }
        return nil
    }

    /// 按当前页容量切片；末页不足整页时保持列布局，自然左对齐。
    private var pages: [AppPage] {
        let pageSize = layout.pageSize
        return stride(from: 0, to: filteredApps.count, by: pageSize).map { start in
            let end = min(start + pageSize, filteredApps.count)
            return AppPage(id: start / pageSize, apps: Array(filteredApps[start..<end]))
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 点击图标之外的空白背景即退出，复刻旧版 Launchpad 行为。
            BlurredWallpaperBackground()
                .contentShape(Rectangle())
                .onTapGesture { exitLaunchpad() }

            if let emptyStateText {
                emptyState(emptyStateText)
                    .padding(.top, 96)
            } else {
                pagedGrid
                    .padding(.top, 96)

                pageIndicator
            }

            topHotZone

            if isSearchVisible {
                searchField
                    .padding(.top, 36)
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            if let size = NSScreen.main?.frame.size {
                screenSize = size
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // 每次唤起重扫应用目录，新装应用无需重启即可出现。
            reloadApplications()
        }
        .task {
            // 先让首帧渲染占位，再做首次扫描。
            await Task.yield()
            guard apps.isEmpty else { return }
            apps = AppCatalogService().loadApplications()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appAppendSearchText)) { note in
            presentSearch(focus: true)
            if let text = note.userInfo?["text"] as? String {
                searchText += text
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appFocusSearch)) { _ in
            presentSearch(focus: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appClearSearch)) { _ in
            clearSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appEscape)) { _ in
            handleEscape()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appChangePage)) { note in
            guard let delta = note.userInfo?["delta"] as? Int else { return }
            changePage(by: delta)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPageDrag)) { note in
            guard let delta = note.userInfo?["delta"] as? Double else { return }
            applyDrag(CGFloat(delta))
        }
        .onReceive(NotificationCenter.default.publisher(for: .appPageDragEnded)) { note in
            let velocity = (note.userInfo?["velocity"] as? Double).map { CGFloat($0) } ?? 0
            performSettle(velocity: velocity)
        }
        .onChange(of: isSearchFocused) { _, focused in
            if !focused { scheduleDismiss() }
        }
        .onChange(of: keyword) { _, _ in
            resetToFirstPage()
        }
        .onChange(of: layout.pageSize) { _, _ in
            resetToFirstPage()
        }
    }

    // MARK: - 网格

    /// 当前页索引（夹取到有效范围）。
    private var currentIndex: Int {
        min(max(pageIndex, 0), max(pages.count - 1, 0))
    }

    /// 参与渲染的页：当前页与左右相邻页，跟手滑动时能看到邻页滑入。
    private var visiblePages: [AppPage] {
        guard !pages.isEmpty else { return [] }
        return Array(pages[max(0, currentIndex - 1)...min(pages.count - 1, currentIndex + 1)])
    }

    private var visibleStartIndex: Int {
        max(0, currentIndex - 1)
    }

    /// 自绘跟手分页：滚动位移放大后驱动整排页面平移，松手弹簧吸附整页。
    private var pagedGrid: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(visiblePages) { page in
                        pageGrid(page)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .offset(x: -CGFloat(currentIndex - visibleStartIndex) * proxy.size.width + dragOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
            .onAppear { pageWidth = proxy.size.width }
            .onChange(of: proxy.size.width) { _, newValue in pageWidth = newValue }
        }
    }

    private func pageGrid(_ page: AppPage) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 28) {
            ForEach(page.apps) { app in
                AppIconCell(app: app, scale: layout.scale)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 铺在网格内容之下：图标之间的缝隙与周边空白都会命中它并退出；
        // 图标单元自带手势在上层，仍优先响应，不会误退出。
        .background(exitTapLayer)
    }

    private func emptyState(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(exitTapLayer)
    }

    /// 底部页码圆点：纯指示不可点，仅一页时隐藏。
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages) { page in
                Circle()
                    .fill(Color.white.opacity(currentIndex == page.id ? 0.95 : 0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 18)
        .opacity(pages.count > 1 ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// 网格空白处的退出点击层。
    private var exitTapLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { exitLaunchpad() }
    }

    /// 屏幕顶部热区：鼠标移入即浮现搜索框（不抢焦点）。
    private var topHotZone: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Rectangle())
            .onHover { inside in
                isTopZoneHovered = inside
                if inside {
                    presentSearch(focus: false)
                } else {
                    scheduleDismiss()
                }
            }
            .onTapGesture { exitLaunchpad() }
    }

    // MARK: - 搜索框

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 260, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - 动作

    /// 重扫应用目录；列表有变化时替换并把页码复位。
    private func reloadApplications() {
        let loaded = AppCatalogService().loadApplications()
        guard loaded.map(\.id) != apps.map(\.id) else { return }
        apps = loaded
        resetToFirstPage()
    }

    /// 回到第一页并清掉跟手偏移。
    private func resetToFirstPage() {
        pageIndex = 0
        dragOffset = 0
    }

    /// 翻页；到首尾直接停住，不循环。
    private func changePage(by delta: Int) {
        let count = pages.count
        guard count > 1 else { return }

        let target = min(max(currentIndex + delta, 0), count - 1)
        guard target != currentIndex else { return }
        slide(to: target)
    }

    /// 跟手拖动：位移放大 4 倍；首尾保留橡皮筋阻尼。手指未松开前绝不触发吸附。
    private func applyDrag(_ delta: CGFloat) {
        guard pages.count > 1, pageWidth > 0 else { return }

        let amplified = delta * 4
        var next = dragOffset + amplified

        // 首尾橡皮筋：往边界外拖动时按 0.35 衰减，松手后弹回。
        if (currentIndex == 0 && next > 0) || (currentIndex == pages.count - 1 && next < 0) {
            next = dragOffset + amplified * 0.35
        }

        dragOffset = min(max(next, -pageWidth), pageWidth)
    }

    /// 松手吸附：轻扫（速度够快）直接翻页，否则按 1/12 页阈值判定是否翻页。
    private func performSettle(velocity: CGFloat) {
        guard pages.count > 1, pageWidth > 0 else {
            withAnimation(.easeOut(duration: 0.22)) {
                dragOffset = 0
            }
            return
        }

        // 轻扫：不再看位移，直接翻到手势方向上的邻页。
        if abs(velocity) >= 60 {
            let target = velocity < 0 ? currentIndex + 1 : currentIndex - 1
            let clamped = min(max(target, 0), pages.count - 1)
            if clamped != currentIndex {
                slide(to: clamped, fast: true)
                return
            }
        }

        let threshold = pageWidth / 12
        var target = currentIndex
        if dragOffset <= -threshold { target += 1 }
        if dragOffset >= threshold { target -= 1 }
        target = min(max(target, 0), pages.count - 1)

        guard target != currentIndex else {
            withAnimation(.easeOut(duration: 0.24)) {
                dragOffset = 0
            }
            return
        }

        slide(to: target)
    }

    /// 滑到目标页；`fast` 用于轻扫，动画更短更干脆。
    private func slide(to target: Int, fast: Bool = false) {
        let forward = target > currentIndex
        let response = fast ? 0.14 : 0.3

        withAnimation(.spring(response: response, dampingFraction: 0.95)) {
            dragOffset = forward ? -pageWidth : pageWidth
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(response * 1000) + 20))
            pageIndex = target
            dragOffset = 0
        }
    }

    /// 浮现搜索框；`focus` 为 true 时同时把光标放进去。
    private func presentSearch(focus: Bool) {
        dismissTask?.cancel()
        dismissTask = nil

        if !isSearchVisible {
            withAnimation(.easeOut(duration: 0.15)) {
                isSearchVisible = true
            }
        }
        if focus {
            isSearchFocused = true
        }
    }

    /// 搜索词为空且未聚焦时，延迟淡出，避免鼠标掠过顶部时闪烁。
    private func scheduleDismiss() {
        guard searchText.isEmpty, !isSearchFocused, !isTopZoneHovered else { return }

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, searchText.isEmpty, !isSearchFocused, !isTopZoneHovered else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                isSearchVisible = false
            }
        }
    }

    private func clearSearch() {
        searchText = ""
        isSearchFocused = false
    }

    /// Esc：先清空并收起搜索框，无搜索内容时退出。
    private func handleEscape() {
        if isSearchVisible || !searchText.isEmpty {
            clearSearch()
            withAnimation(.easeIn(duration: 0.15)) {
                isSearchVisible = false
            }
        } else {
            exitLaunchpad()
        }
    }

    private func exitLaunchpad() {
        searchText = ""
        isSearchVisible = false
        isSearchFocused = false
        resetToFirstPage()
        NotificationCenter.default.post(name: .appHideWindow, object: nil)
    }
}
