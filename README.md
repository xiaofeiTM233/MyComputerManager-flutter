# MyComputerManager-flutter

![title.png](https://s2.loli.net/2022/07/07/o9rWHAm6fiZS4pQ.png)

原项目：<https://github.com/1357310795/MyComputerManager>（.NET / WPF）。
本仓库是其 Flutter 重构版，以便在不同版本的 Windows 下仍然轻量化使用。

## 环境要求

| 项目 | 版本 |
| --- | --- |
| Flutter | 3.47.2（stable） |
| Dart | 3.13.2 |
| 平台 | 仅 Windows（`win32_registry` 为 Windows 专用包） |
| C++ 工具链 | Visual Studio 的「C++ 桌面开发」工作负载（含 MSVC 与 Windows 10 SDK） |

## 常用命令

```powershell
flutter pub get      # 拉取依赖
flutter test         # 运行单元测试（纯逻辑，不写注册表）
flutter run -d windows   # 以桌面端运行
flutter build windows --release   # 产出 Release 包
```

## 目录结构

```text
lib/
  main.dart                     应用入口、列表页、全部操作的编排
  models/namespace_item.dart    条目模型（含 JSON 序列化）
  services/
    registry_service.dart       注册表读写（win32_registry）
    reg_exporter.dart           .reg 文本生成与编码（纯逻辑，可单测）
  widgets/item_tile.dart        列表项卡片
  dialogs/item_editor_dialog.dart  新增/编辑表单
test/
  reg_exporter_test.dart        .reg 生成与模型的单元测试
windows/                        Windows 桌面端宿主工程（CMake + Win32）
```

## 注册表布局

程序读写两处：

1. **命名空间链接**（决定图标是否出现）
   `HKCU|HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\<MyComputer|Desktop>\<NameSpace|NameSpaceDisabled>\<CLSID>`

2. **CLSID 定义**（决定名称、描述、图标、打开命令）
   `HKCU|HKLM\SOFTWARE\Classes\CLSID\<CLSID>`（含 `DefaultIcon`、`Shell\Open\Command` 子键）

读取 CLSID 时会同时查找 `SOFTWARE\Classes\CLSID` 与 `SOFTWARE\Classes\WOW6432Node\CLSID`
（32 位视图），与原版行为一致。

## 注意事项

- **HKLM 需要管理员权限。** 若在下拉框中选择「全部用户 (HKLM)」而未以管理员身份运行，
  保存会失败并提示「拒绝访问」。
- **删除操作不可恢复**，会同时删除命名空间链接与 CLSID 定义。
- 修改后通常需要重启资源管理器（或注销重登录）才能在「此电脑」中看到变化。

## 📚 说明

本 README 文档由 AI 辅助生成。如有问题，请提交 Issue 或[与我联系](https://github.com/xiaofeiTM233)！
