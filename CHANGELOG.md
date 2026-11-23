# 变更日志

## 变更总览

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|---------|------|---------|
| v1.0.1 | 新增 README 项目说明文档 | hanbing | 2026-11-23 |
| v1.0.0 | 项目初始化：Launchpad27（macOS 27 启动台替代）MVP 与一键安装脚本 | hanbing | 2026-11-23 |

## v1.0.1 (2026-11-23)

### 变更内容

- 新增 `README.md`：项目定位、功能清单、环境要求、构建与安装命令、项目结构、设计说明、已知限制与许可证
- 文档内补充 ADR 与 LICENSE 索引链接

## v1.0.0 (2026-11-23)

### 新增

- Launchpad27 macOS 应用：全屏应用图标网格，展示系统应用目录下的全部应用
- 顶部搜索框：按应用名不区分大小写实时过滤，含空结果提示
- 点击图标启动应用（`NSWorkspace`），启动失败仅记录日志不崩溃
- 全屏展示，按 Esc 关闭窗口
- `scripts/build-app.sh`：SwiftPM release 构建 + 组装 `.app` bundle + ad-hoc 签名，并内置系统启动台图标
- `scripts/install.sh`：一键构建、覆盖安装到 `/Applications`、重签名、LaunchServices 注册、Dock 首位集成（幂等）

### 说明

- 开发环境仅有 Command Line Tools（无完整 Xcode），工程形态采用 SwiftPM + 手工 app bundle，详见 `docs/adr/0002-swiftpm-instead-of-xcodeproj.md`
- 未启用 App Sandbox，仅本机自用，不做公证与 App Store 分发
