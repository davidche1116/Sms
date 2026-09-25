## 改动说明

<!-- 做了什么，为什么要做 -->

## 影响范围

- [ ] 仅 Dart 代码
- [ ] 原生代码 / Gradle / Manifest（已在真机验证）
- [ ] 文案（三语 ARB 已同步，并已跑 `flutter gen-l10n`）
- [ ] CI / 构建配置
- [ ] 文档

## 验证

<!-- 贴上实际执行过的命令与结果 -->

```bash
dart format lib test
flutter analyze
flutter test
# 涉及原生改动时：
flutter build apk --debug
```

## 说明

- 若新增了启动阶段的平台通道调用，是否已在 `test/widget_test.dart` 补 mock？
- 是否涉及短信删除路径？若是，请说明失败时的表现。
