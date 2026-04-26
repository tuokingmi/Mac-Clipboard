# ClipboardMenuBar

一款轻量级 macOS 菜单栏剪贴板历史管理工具，基于 SwiftUI 和 SwiftData 构建。

## 功能

- **剪贴板历史** — 自动捕获复制的文本和图片，永久保存，直到你手动清除或删除
- **快捷呼出** — 按 `Option + V` 随时打开浮动面板
- **置顶** — 将重要条目置顶，不会被清除或覆盖
- **键盘操作** — `↑↓` 选择、`Enter` 粘贴、`Esc` 关闭
- **开机启动** — 支持设置随 macOS 自动启动

## 系统要求

- macOS 15.0+
- Xcode 16+
- 辅助功能权限（用于自动粘贴）

## 构建

用 Xcode 打开 `ClipboardMenuBar.xcodeproj` 直接运行，或通过命令行构建：

```bash
xcodebuild -project ClipboardMenuBar.xcodeproj -scheme ClipboardMenuBar build
```

## 使用方法

1. 启动应用，菜单栏出现剪贴板图标
2. 正常复制文本或图片，会自动保存
3. 按 `Option + V` 打开剪贴板面板
4. 点击条目或用键盘选择后粘贴
5. 右键条目可置顶或删除

## 许可证

MIT
