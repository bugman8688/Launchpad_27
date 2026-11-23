# 2. 工程形态改为 SwiftPM + 手工 App Bundle

日期：2026-11-23

## 状态（Status）

已接受（Accepted）

取代（Supersedes）：[ADR-0001](./0001-launchpad-mvp-tech-stack.md) 的决策 2「工程形态：Xcode 工程」。

## 上下文（Context）

ADR-0001 选定 Xcode 工程（`.xcodeproj`）。实施阶段实测发现本机开发环境不具备该前提：

- `xcode-select -p` 指向 `/Library/Developer/CommandLineTools`
- `xcodebuild` 直接报错：`tool 'xcodebuild' requires Xcode, but active developer directory ... is a command line tools instance`
- `/Applications` 下无 `Xcode.app`，即未安装完整 Xcode
- 但 CLT SDK 完整：`MacOSX27.2.sdk` 内含 `SwiftUI.framework`、`AppKit.framework`、`Cocoa.framework`，`swiftc 6.4.2` 可用

结论：`.xcodeproj` 虽可手写，但无法编译验证，等于不可交付。

## 决策（Decision）

1. **工程形态**：改用 Swift Package（`Package.swift`），executable target `Launchpad27`。
2. **构建**：`swift build -c release` 编译可执行文件。
3. **打包**：用脚本 `scripts/build-app.sh` 手工组装 `.app` bundle：
   - 目录：`Launchpad27.app/Contents/{MacOS,Resources}`
   - 可执行文件拷入 `Contents/MacOS/`
   - `Info.plist` 拷入 `Contents/`（`CFBundleExecutable`、`CFBundleIdentifier`、`LSMinimumSystemVersion` 27.0、`NSPrincipalClass` = `NSApplication`）
   - `codesign --force --sign -` 做 ad-hoc 签名，避免 Gatekeeper 拦截本机运行
4. 其余决策（SwiftUI、Dock 图标 + 全屏窗口、不启用沙盒、`NSWorkspace` 读图标、部署目标 macOS 27）沿用 ADR-0001。

## 后果（Consequences）

**正面**

- 无需下载十几 GB 的 Xcode，当前环境即可编译、打包、运行。
- 打包脚本透明可控，后续迭代改 Info.plist / 签名策略成本低。

**负面 / 权衡**

- 失去 Xcode 的 SwiftUI Preview、可视化调试与自动签名，调试依赖 `swift build` 输出与运行时日志。
- 每次改动需手动跑打包脚本，`swift run` 直接跑的 GUI 进程缺少 bundle 上下文（Dock 名称、图标等），验收以打包后的 `.app` 为准。
- 若后续安装完整 Xcode，可再补一份 `.xcodeproj`，不需要推翻现有源码结构。
