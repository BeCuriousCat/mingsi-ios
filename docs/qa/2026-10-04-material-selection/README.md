# 长材料显式选择 QA

日期：2026-10-04

## 已验证

- `MentorContextBuilderTests`：8 项通过。
- `MentorFeatureStoreTests.testOversizedMaterialWaitsForExplicitSelectionBeforeNetworkRequest`：通过。
- 超过 24,000 字符时不会静默截断用户原话。
- 未选择片段前不会创建 request，也不会调用 transport。
- 选择片段后，只有明确选择的片段进入本轮 request context。
- 完整用户原话仍保留在 timeline 中。
- 空选择会显示错误并阻止发送。

结果：`/tmp/mingsi-material-context-20261004o.xcresult`

- `MentorNavigationUITests.testOversizedConversationOffersExplicitMaterialSelection`：通过。
- iPhone 17 / iOS 26.5 UI 截图已导出并人工检查：字符统计正常显示，片段文字有摘要省略，底部取消和发送按钮可见，未发现遮挡或溢出。

结果：`/tmp/mingsi-material-selection-ui-20261004t.xcresult`
