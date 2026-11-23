# 1. Launchpad MVP 技术选型

日期：2026-11-23

## 状态（Status）

已接受（Accepted）

> 注：决策 2「工程形态：Xcode 工程」已被 [ADR-0002](./0002-swiftpm-instead-of-xcodeproj.md) 取代（本机未安装完整 Xcode，改用 SwiftPM + 手工 app bundle）。其余决策仍然有效。

## 上下文（Context）

macOS 27 移除了 Launchpad，需要自写一个 macOS 原生 App 还原其「全屏图标网格 + 点击启动」体验。MVP 范围为：图标网格、点击启动、顶部搜索框。

关键前提：

- 开发者熟悉 Swift / SwiftUI。
- 第三方替代品无法「原汁原味」还原网格体验：键盘搜索型（Raycast / Alfred）形态不符；网格型开源项目存在系统级联动缺失、权限隐私、签名分发、维护不稳定等缺陷。

需要就以下技术选型做出决策：工程形态、App 形态、沙盒、图标读取方式、部署目标。

## 决策（Decision）

1. **语言**：Swift + SwiftUI。
2. **工程形态**：Xcode 工程（`.xcodeproj`）。GUI App 的标准路径，具备 preview / 调试 / 签名 / entitlements 完整支持；相较 Swift Package 省去手动组装 app bundle、Info.plist、entitlements 与签名的复杂度。
3. **App 形态**：Dock 图标 App + 全屏窗口。MVP 最贴近原版 Launchpad（打开后全屏网格、点击启动、Esc 退出）；菜单栏常驻与全局快捷键唤起留到迭代阶段。
4. **沙盒**：不启用 App Sandbox。自用学习项目，直接用 NSWorkspace / FileManager 枚举应用目录，避免文件访问 entitlement 复杂度；代价是无法上 Mac App Store（自用可接受）。
5. **图标读取**：`NSWorkspace.shared.icon(forFile:)`，读取 `.app` 图标。
6. **部署目标**：macOS 27。

## 后果（Consequences）

**正面**

- 工程与运行路径简单，无沙盒与 entitlements 负担，MVP 可快速落地。
- 分层清晰（Views → Services → Models），后续迭代（分组、手势、动画）可平滑叠加。

**负面 / 权衡**

- 不开沙盒 → 无法提交 Mac App Store，仅限自用 / 内部分发。
- Dock 图标 + 全屏窗口形态 → 全局快捷键 / 触控板手势唤起需后续迭代，且涉及辅助功能权限，只能近似系统级流畅度。
- 部署目标 macOS 27 → 无法在更低版本运行，如需兼容需另行调整。
