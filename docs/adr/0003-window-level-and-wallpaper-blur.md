# 3. 覆盖式高层窗口、桌面壁纸毛玻璃与自适应网格

日期：2026-11-23

## 状态（Status）

已接受（Accepted）

取代（Supersedes）：[ADR-0001](./0001-launchpad-mvp-tech-stack.md) 决策「App 形态：Dock 图标 + 全屏窗口」中「进入系统全屏 Space」的实现方式。

## 上下文（Context）

MVP 阶段通过 `window.toggleFullScreen(nil)` 进入系统全屏 Space。要在体验上贴近旧版 Launchpad，存在三个硬约束：

- **手势锁定**：旧版 Launchpad 是 Dock.app 进程内的功能，与 Mission Control、App Exposé 同源，本身就是系统手势宿主，可以直接吞掉三/四指上滑与左右滑动。第三方 App 没有该特权，`NSEvent` 收不到 Space 切换手势，也无法拦截。
- **切换不可见**：系统 Space 切换动画由 WindowServer 播放，第三方无法关闭；只能让覆盖窗口在切换期间保持不动、且出现在所有 Space 上，使切换在视觉上不可见。
- **背景观感**：旧版是「桌面壁纸高斯模糊 + 压暗」，不是纯色或普通毛玻璃材质。

## 决策（Decision）

1. **窗口形态**：放弃 `toggleFullScreen`，改用 AppKit 生命周期（`NSApplication` + `AppDelegate`）自建 `LaunchpadWindow`：
   - `styleMask = [.borderless]`，`canBecomeKey` / `canBecomeMain` 返回 `true`（SwiftUI `WindowGroup` 产出的窗口无法变成可聚焦的无边框窗口）
   - `level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))`
   - `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`
   - `isOpaque = false`、`backgroundColor = .clear`、铺满主屏
2. **Dock / 菜单栏**：展示期间 `NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]`，隐藏时恢复 `[]`（不禁用 Cmd+Tab）。
3. **退出语义**：点击空白 / Esc 仅 `orderOut(nil)`（半退出，进程常驻，Dock 图标点击可重新唤起）；`Cmd+Q` 仍直接终止进程。
4. **Space / 屏幕变化兜底**：监听 `NSWorkspace.activeSpaceDidChangeNotification` 后 `orderFrontRegardless()` 重新置顶；监听 `NSApplication.didChangeScreenParametersNotification` 后按 `NSScreen.main` 重铺窗口并重算网格。
5. **背景**：`DesktopWallpaperService` 用 `NSWorkspace.shared.desktopImageURL(for:)` 取壁纸 → `CIGaussianBlur`（radius 40，先 `clampedToExtent` 再裁回原边界）→ 按「壁纸路径 + 屏幕尺寸 + 半径」缓存；取不到时回退深色渐变。背景统一叠加 `black 0.25` 压暗保证图标可读。
6. **网格**：以 1440×900 = 7 列 × 5 行为基准，按屏幕宽高等比映射行列（限制 3–12 列 / 2–8 行）；图标按「格子宽高 ÷ 基准单元 104×101」取较小比例放大，刚好填满且不溢出。
7. **手势能力边界**：三/四指左右切 Space 由系统消费，第三方无法拦截；只能依靠高层级 + `stationary` 让切换不可见。

## 后果（Consequences）

**正面**

- 三/四指上滑与左右切 Space 时，界面仍覆盖在最上层且不跟随移动，视觉上接近旧版「锁定」。
- 背景为真实桌面壁纸的模糊版本，换壁纸后重新唤起即跟随。
- 外接屏、竖屏下自动变为少列多行，不溢出。

**负面 / 权衡**

- 窗口层级高于系统屏蔽层，理论上会盖住 Mission Control 的预览层与部分系统弹窗。
- 系统 Space 实际仍会切换，只是用户看不见；切回后依赖 `activeSpaceDidChange` 兜底重新置顶。
- `Cmd+Q` 直接退出，未做防误触确认。
- 手动缩放（齿轮 + 滑块 + 保存）方案已评估并弃用：交互热区与 SwiftUI hover 反复互相影响导致抖动，且与「按屏幕固定推算」的目标冲突，最终改为完全由屏幕尺寸推导。

## 未来优化点（本次未实现）

- 打开界面时图标按行依次缩放淡入（stagger 入场动画）。
- 重扫目录发现新增/变更应用后，图标短暂高亮或弹跳提示。
- 应用更新中的环形进度与图标变暗：由 App Store / Dock 内部驱动，第三方无公开 API，不可行。
