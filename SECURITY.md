# 安全政策

## 支持版本

只维护最新的发布版本（见仓库 Releases）。旧版本不再修。

## 报告漏洞

请通过 [GitHub Issues](https://github.com/davidche1116/Sms/issues) 报告，
或直接发邮件给维护者。请附上：影响范围、复现步骤、Android 版本与机型。
涉及短信数据泄露或丢失的，请标注紧急程度，会优先处理。

## 签名密钥

**密钥不入库**。`android/key.properties`、`*.jks` / `*.keystore` 均已在
`.gitignore` 中；release 签名材料只放在维护者本机或 CI Secrets
（`RELEASE_STORE_FILE` / `RELEASE_STORE_PASSWORD` / `RELEASE_KEY_ALIAS` /
`RELEASE_KEY_PASSWORD`）。

若两者均不存在，`flutter build apk --release` 会**回退 debug 签名**并在
Gradle 日志打印警告——仅方便本地自测。**debug 签名的包禁止上架商店、禁止
作为正式升级包分发。**

请勿提交任何密钥文件；若误提交请立即轮换密钥并开 Issue 告知。

## 应用的数据边界

- 应用不联网，所有短信 / 彩信数据只留在本机。
- 导出功能会把短信写入应用私有目录并通过系统分享面板交给你选择的目标。
- 导入 CSV 只新增写入系统短信库，绝不覆盖或删除已有短信。
- 删除短信 / 彩信不可恢复；所有删除入口均先确认。
- 移出列表只是本地隐藏，不删系统数据。
