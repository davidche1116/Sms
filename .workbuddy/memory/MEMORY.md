# Sms 项目长期备忘

- 提交身份：`git -c user.name="davidche" -c user.email="davidche@qq.com" commit`（qq.com 邮箱，AGENTS.md 已同步修正）；一律不主动 push。
- 本机 Flutter SDK 位于 `/Users/fang/fvm/versions/stable`（fvm 管理，Flutter 3.47.5 / Dart 3.13.4，即官方当前最新 stable）；AGENTS.md 已指向 fvm 路径。prefix PATH 用该 fvm 路径。
- 提交前流程：`dart format lib test` → `flutter analyze` → `flutter test`；Gradle 改动追加 `flutter build apk --debug`。format 改动的 l10n/generated 文件与 main.dart 格式重排**一并提交**（用户确认，仓库保持"已格式化"状态；注意 `flutter pub get`/gen-l10n 会重新生成未格式化的 l10n 文件，需再跑一次 format 对齐）；build 会改 gradlew 权限位，收尾还原。
- sms_advanced 1.1.0 是全部 Android 构建 hack 的根因（lint 禁用 / compileSdk 37 硬编码+CI 软链 / namespace 回填），替换它需自写 platform channel，属大工程。
- keystore + key.properties 入库是所有者明确决策，严禁擅自清理/轮换（审查时可提示风险，但不得动手）。
- **本机 git 要用 `/Applications/Xcode.app/Contents/Developer/usr/bin/git`**：`/usr/bin/git` 是 Xcode shim，未接受许可时会卡在交互输入并 SIGTERM。同理 dart/flutter 在许可未接受前全部不可用。
- 批量删除 >3000 条的产品行为是"提示后继续删除"（用户确认保留）。
