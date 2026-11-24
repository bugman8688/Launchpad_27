import AppKit

/// 窗口级键盘监听：把按键翻译为应用内动作通知，供界面层响应。
@MainActor
final class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private var monitor: Any?

    /// 安装按键监听（只允许安装一次）。
    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 监听回调固定在主线程，这里同步切到主 actor 处理，避免跨隔离传递 NSEvent。
            var consumed = false
            MainActor.assumeIsolated {
                consumed = KeyboardMonitor.handle(event)
            }
            return consumed ? nil : event
        }
    }

    /// 返回 true 表示事件已被消费，不再下发到响应链。
    private static func handle(_ event: NSEvent) -> Bool {
        let editor = NSApp.keyWindow?.firstResponder as? NSTextView
        // 输入法组合中（有候选串）不干预，Esc 交给输入法取消候选。
        if editor?.hasMarkedText() == true { return false }
        let isEditingText = editor != nil

        if event.modifierFlags.contains(.command) {
            guard event.charactersIgnoringModifiers?.lowercased() == "f" else { return false }
            NotificationCenter.default.post(name: .appFocusSearch, object: nil)
            return true
        }

        switch event.keyCode {
        case 53: // Esc
            NotificationCenter.default.post(name: .appEscape, object: nil)
            return true
        case 123, 124: // ← / →
            guard !isEditingText else { return false }
            let delta = event.keyCode == 123 ? -1 : 1
            NotificationCenter.default.post(name: .appChangePage, object: nil, userInfo: ["delta": delta])
            return true
        default:
            break
        }

        // Option / Control 组合键不当作搜索输入。
        guard event.modifierFlags.intersection([.option, .control]).isEmpty else { return false }
        guard let characters = event.characters, !characters.isEmpty,
              let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar) else { return false }

        // 光标已在输入框中时交给输入框，避免字符重复注入。
        guard !isEditingText else { return false }

        NotificationCenter.default.post(name: .appAppendSearchText, object: nil, userInfo: ["text": characters])
        return true
    }
}
