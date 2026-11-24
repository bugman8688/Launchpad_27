import AppKit

/// 触控板横向滑动监听：广播横向位移与松手速度，驱动自绘跟手翻页。
/// 有 `phase` 的设备在 `ended` 时立即通知；无阶段信息时用极短静默兜底。
@MainActor
final class ScrollMonitor {
    static let shared = ScrollMonitor()

    /// 无阶段信息（鼠标滚轮）时的静默兜底时长。
    private static let fallbackSettleDelay: Int = 80

    private static var pendingSettle: Task<Void, Never>?
    private static var lastTimestamp: TimeInterval = 0
    private static var velocity: CGFloat = 0

    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            var consumed = false
            MainActor.assumeIsolated {
                consumed = ScrollMonitor.handle(event)
            }
            return consumed ? nil : event
        }
    }

    private static func handle(_ event: NSEvent) -> Bool {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        // 手势结束必须最先处理：ended / cancelled 事件的位移通常为 0，
        // 若先做方向判断会被直接丢弃，导致松手后永不吸附。
        if event.phase == .ended || event.phase == .cancelled {
            postEnded()
            return true
        }

        // 纵向为主的滚动不接管。
        guard abs(deltaX) > abs(deltaY) else { return false }

        if event.phase == .began {
            velocity = 0
            lastTimestamp = 0
        }

        // 惯性阶段吞掉，避免一次手势多次翻页。
        guard event.momentumPhase.isEmpty else { return true }

        updateVelocity(deltaX, timestamp: event.timestamp)

        postDrag(deltaX)

        // 无阶段信息（鼠标滚轮）时用极短静默兜底吸附。
        if event.phase.isEmpty {
            pendingSettle?.cancel()
            pendingSettle = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(fallbackSettleDelay))
                guard !Task.isCancelled else { return }
                postEnded()
            }
        }
        return true
    }

    /// 以相邻事件间隔估算横向速度（pt/s），供轻扫判定使用。
    private static func updateVelocity(_ deltaX: CGFloat, timestamp: TimeInterval) {
        let dt = timestamp - lastTimestamp
        if dt > 0, dt < 0.2 {
            velocity = deltaX / CGFloat(dt)
        }
        lastTimestamp = timestamp
    }

    private static func resetVelocity() {
        velocity = 0
        lastTimestamp = 0
    }

    private static func postDrag(_ deltaX: CGFloat) {
        NotificationCenter.default.post(
            name: .appPageDrag,
            object: nil,
            userInfo: ["delta": Double(deltaX), "velocity": Double(velocity)]
        )
    }

    private static func postEnded() {
        NotificationCenter.default.post(
            name: .appPageDragEnded,
            object: nil,
            userInfo: ["velocity": Double(velocity)]
        )
    }
}
