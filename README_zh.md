![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# 短信清理

简体中文 | [繁體中文](README_zh_TW.md) | [English](README.md)

- 短信清理是Flutter框架编写的在Android上读取、批量删除短信的短信清理工具。
- 虽然UI框架Flutter支持跨平台，但仅实现了Android短信删除功能。

## 功能描述

- 获取短信权限
- 复制短信到剪切板
- 设置/恢复默认短信应用
- 关键字过滤短信信息
- 同号码短信搜索
- 从搜索结果移除/直接删除短信
- 一键批量删除查询结果短信
- 一键导出所有短信到csv文件

## 界面截图
![UI](assets/screenshot/ui.jpg)


## 开发环境
### [Flutter](https://docs.flutter.cn/get-started/install)
- flutter stable 3.29.3
- dart 3.7.2
- gradle 8.12
- gradle-plugin 8.7.3
- kotlin 1.8.22

### 编译命令
- 安装 flutter_distributor
- `dart pub global activate flutter_distributor`
- 打包release
- `flutter_distributor release --name apk`
