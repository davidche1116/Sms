![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# 短信清理

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
- flutter beta 3.24.0
- dart 3.5.0
- gradle 7.6.3
- gradle-plugin 7.4.2
- kotlin 1.8.22

### 编译命令
- 安装 flutter_distributor
- `dart pub global activate flutter_distributor`
- 打包release
- `flutter_distributor release --name apk`
