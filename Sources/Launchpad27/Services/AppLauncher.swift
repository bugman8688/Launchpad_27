import AppKit
import os

/// 应用启动服务：封装 NSWorkspace 打开逻辑，失败仅记录日志，并告知调用方是否启动成功。
@MainActor
struct AppLauncher {
    /// 启动超时：回调迟迟不来时按失败处理，避免界面卡在启动中无法操作。
    private static let timeout: Duration = .seconds(8)
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Launchpad27",
        category: "AppLauncher"
    )

    /// 打开应用，返回是否启动成功。
    func open(_ app: AppItem) async -> Bool {
        let gate = ResumeGate()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            NSWorkspace.shared.openApplication(
                at: app.bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { runningApp, error in
                let succeeded = error == nil

                guard gate.resume(continuation, with: succeeded) else {
                    // 已按超时处理，这里只补一条迟到日志便于排障。
                    let reason = succeeded
                        ? "实际已启动"
                        : "仍失败：\(error?.localizedDescription ?? "未知错误")"
                    Self.logger.notice(
                        "启动回调迟到：\(app.name, privacy: .public) - 超时后\(reason, privacy: .public)"
                    )
                    return
                }

                if succeeded, runningApp == nil {
                    Self.logger.error("启动异常：\(app.name, privacy: .public) - 未返回应用且无错误")
                }
                if let error {
                    Self.logger.error(
                        "启动失败：\(app.name, privacy: .public) - \(error.localizedDescription, privacy: .public)"
                    )
                }
            }

            Task {
                try? await Task.sleep(for: Self.timeout)
                if gate.resume(continuation, with: false) {
                    Self.logger.error("启动超时：\(app.name, privacy: .public) - \(Self.timeout, privacy: .public) 未返回")
                }
            }
        }
    }
}

/// 保证 continuation 只 resume 一次（系统回调与超时竞速），并告知本次是否生效。
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    @discardableResult
    func resume(_ continuation: CheckedContinuation<Bool, Never>, with value: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        continuation.resume(returning: value)
        return true
    }
}
