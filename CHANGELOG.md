# 变更日志

## 变更总览

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|---------|------|---------|
| v1.1.0 | 分页网格 + 毛玻璃背景 + 键盘流增强 | hanbing | 2026-11-24 |
| v1.0.1 | 新增 README 项目说明文档 | hanbing | 2026-11-23 |
| v1.0.0 | 项目初始化：Launchpad27（macOS 27 启动台替代）MVP 与一键安装脚本 | hanbing | 2026-11-23 |

## v1.1.0 (2026-11-24)

### 新增

- 分页网格：以 1440×900 = 7×5 为基准等比映射行列（3–12 列 / 2–8 行），图标尺寸随格子自适应放大，屏幕参数变化后重算并重铺窗口
- 触控板水平滑动跟手翻页（位移放大 4 倍、速度与位移双阈值吸附），左右方向键翻页，首尾橡皮筋阻尼回弹不循环
- 底部页码圆点指示当前页，页数 ≤ 1 时隐藏
- 毛玻璃背景：读取桌面壁纸做 CoreImage 高斯模糊并叠加 0.25 黑色压暗，读取失败回退暗色渐变
- 搜索框改为按需浮现浮层（顶部热区或敲字母触发），忽略大小写与重音，Cmd+F 聚焦，Esc 两段式（先清空收起再退出）
- 图标按需加载：新增 `AppIconCache`（128pt + 进程内缓存 + 占位图），不再同步读图标阻塞首屏
- 每次唤起窗口重扫应用目录，新装应用无需重启即可出现
- 新增 `docs/adr/0003-window-level-and-wallpaper-blur.md`，记录窗口层级、模糊方案、自适应网格与手势能力边界

### 改进

- 窗口改为无边框全屏 `LaunchpadWindow`（`CGShieldingWindowLevel` + `canJoinAllSpaces`），切换 Space 后自动重新置顶
- 移除齿轮、缩放滑块与保存按钮，行列与图标尺寸完全由屏幕推算
- `.gitignore` 增加 `logs/`，AI 工作日志不入库

### 涉及文件

- 新增：`Models/AppPage.swift`、`Services/AppIconCache.swift`、`Services/AppNotifications.swift`、`Services/DesktopWallpaperService.swift`、`Services/KeyboardMonitor.swift`、`Services/ScrollMonitor.swift`、`Views/BlurredWallpaperBackground.swift`、`Views/LaunchpadWindow.swift`、`docs/adr/0003-window-level-and-wallpaper-blur.md`
- 修改：`Launchpad27App.swift`、`Models/AppItem.swift`、`Services/AppCatalogService.swift`、`Views/AppIconCell.swift`、`Views/ContentView.swift`、`.gitignore`

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
