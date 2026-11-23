# Launchpad27

macOS 27 移除了系统 Launchpad，本项目用 SwiftUI 还原它的核心体验：**全屏应用图标网格 + 点击启动 + 顶部搜索**。

## 功能

- 全屏图标网格，展示 `/Applications`、`/System/Applications`、`/System/Applications/Utilities`、`~/Applications` 下的全部应用
- 点击图标启动应用（`NSWorkspace`）
- 顶部搜索框，按应用名不区分大小写实时过滤
- 按 `Esc` 关闭窗口

## 环境要求

- macOS 27
- Swift 6.x + Command Line Tools（无需完整 Xcode）

## 构建与安装

```bash
# 仅打包，产物在 build/Launchpad27.app
bash scripts/build-app.sh

# 构建并安装到 /Applications，自动加入 Dock
bash scripts/install.sh
```

安装脚本是幂等的：重复执行会覆盖旧版本，Dock 中不会产生重复条目，且只在 Dock 实际有变更时才重启 Dock。

## 项目结构

```
├── Package.swift              # SwiftPM 工程定义
├── Sources/Launchpad27/
│   ├── Launchpad27App.swift   # App 入口
│   ├── Models/                # AppItem 等数据模型
│   ├── Services/              # 应用枚举、启动
│   └── Views/                 # 主界面与图标单元
├── Support/Info.plist         # 打包用 Info.plist 模板
├── scripts/
│   ├── build-app.sh           # 编译 + 组装 app bundle + ad-hoc 签名
│   └── install.sh             # 安装到 /Applications + Dock 集成
└── docs/adr/                  # 架构决策记录
```

## 设计说明

- 分层为 `Views → Services → Models`，系统调用（`NSWorkspace` / `FileManager`）统一收敛在 Services 层
- 部署目标 macOS 27，**不启用 App Sandbox**，仅本机自用，不做公证与 App Store 分发
- 本机未安装完整 Xcode，工程采用 SwiftPM + 手工 app bundle，详见 [ADR-0002](docs/adr/0002-swiftpm-instead-of-xcodeproj.md)
- 技术选型详见 [ADR-0001](docs/adr/0001-launchpad-mvp-tech-stack.md)

## 已知限制

- 图标复用系统启动台图标（`/System/Applications/Apps.app`），系统更新后若路径变化会跳过内置图标
- 暂不支持文件夹分组、分页、长按卸载抖动、全局快捷键与触控板手势唤起、毛玻璃转场动画

## 许可证

[MIT](LICENSE)
