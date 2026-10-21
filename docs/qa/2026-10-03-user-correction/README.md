# 已提交原话更正验收 · 2026-10-03

## 范围与行为

对应 F08 / F09 / F11、T05 的本地纠正与 X13 来源边界。当前可编辑交流的用户条目提供“更正这条原话”，编辑器复用共享语音输入组件。取消不改原文；保存追加带 supersedesItemID 的新版本，原版本仍可回看，不覆盖未发送草稿、已确认理解或借入闪念的原始记录。

更正不调用模型，允许 draft 状态的借入材料与 active 会话。事务同时写入纠正关系、递增 semantic revision / request epoch，并取消旧版本请求。保存失败保留编辑文字、原文和重试入口；旧请求迟到回调不能改变当前回应或时间线。只读历史、已被更正的条目及会话转换中不能继续更正。

后续上下文使用最新更正版本；更正之前的 assistant 内容保留为历史来源，拒绝重新引用为当前事实。旧语义版本未呈现的结果不阻止新版本提交，不伪造旧 presented_at；当前语义版本仍要求真实呈现回执。

## 实际验证

固定 iPhone 17 / iOS 26.5 模拟器，设备 ID `9F93EE80-68DF-4922-8A73-B0590F5143D4`。隔离内存库、可控 transport 与 DEBUG 写入故障夹具，无真实用户数据。

| 验证 | 结果 |
| --- | --- |
| MentorFeatureStoreTests | 122 项通过 |
| MentorPersistenceTests | 56 项通过 |
| MentorContextBuilderTests | 7 项通过 |
| MentorResponseParserTests | 12 项通过 |
| UI：取消、保存、版本展示、结束与历史恢复 | 通过 |
| UI：故障保存、再次保存、保留编辑文字及取消 | 通过 |

单元／集成共 197 项、实际 UI 共 2 项，均 0 失败、0 跳过，xcodebuild 退出码 0。

- `/tmp/mingsi-correction-unit-20261003.xcresult`
- `/tmp/mingsi-correction-unit-20261003.log`
- `/tmp/mingsi-correction-ui-20261003.xcresult`
- `/tmp/mingsi-correction-ui-20261003.log`

单元用完整替换文字验证多次纠正与实际发送 context；UI 在编辑器原文后追加纠正，以实际编辑值核对保存及恢复，避免假设系统光标位置。仓储回归确认旧未呈现结果不会阻塞当前修订，且新结果仍需呈现。Store 回归覆盖零额外网络、草稿保护、写入回滚、重试、闪念原记录保护及旧请求迟到。

## 截图复核

[保存失败保留文字](save-failure.png) · [更正前后版本](versions.png) · [只读历史恢复](history.png)

三张截图已人工查看：编辑器有右下角麦克风，故障提示与重试可见；新旧原话与未发送草稿均保留；结束后的历史没有编辑入口。

## 验收边界

这里证明本地事务、上下文装配与来源验证约束，不证明真实模型不会重复旧判断。真实语义评估、真机／VoiceOver、教材审核及约 14 天试用仍未完成；M1 保持推进中。本轮没有新增 Release 构建或安装包发布。
