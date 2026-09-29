# tool/device/ — 真机 QA 辅助脚本

本目录存放用于 Android 真机/模拟器 UI 自动化测试的 Python 辅助脚本。它们**不是** `flutter test` 用例，不参与 CI 的 Dart 测试阶段。

## 前置依赖

- Python 3.8+（仅使用标准库 `re`、`sys`、`pathlib`，无需 `pip install`）
- 已连接的设备/模拟器：`adb devices` 可见
- 已导出 UI 层级 XML（通过 `adb shell uiautomator dump`）

## 脚本说明

### dump_nodes.py

解析 `uiautomator dump` 输出的 XML，提取所有可点击节点（或带有 `text`/`content-desc` 的节点），以单行形式打印其类名、可点击状态、文本、描述和边界坐标。

```bash
# 导出 UI 层级
adb shell uiautomator dump > ui.xml

# 解析并列出可交互节点
python tool/device/dump_nodes.py ui.xml
```

### dump_text.py

从 `uiautomator dump` 的 XML 中提取所有非空 `text` 属性值，每行一个。适用于快速查看页面上出现的所有文本。

```bash
python tool/device/dump_text.py ui.xml
```

## 典型工作流

```bash
# 1. 在设备上打开目标页面
adb shell am start -n com.dc16.sms/.MainActivity

# 2. 导出 UI 层级
adb shell uiautomator dump > ui.xml

# 3. 分析可交互元素
python tool/device/dump_nodes.py ui.xml

# 4. （可选）提取所有文本用于 i18n 核对
python tool/device/dump_text.py ui.xml
```

> **注意**：导出的 `ui.xml` 可能包含用户短信内容等隐私信息，已配置 `.gitignore` 忽略 `test/device/*.xml` 和 `test/device/shots/`。请勿将 UI dump 文件提交到版本库。
