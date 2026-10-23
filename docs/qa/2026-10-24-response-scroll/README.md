# 回答后继续输入：原生手势隔离验证

关联 G2/G3/G8。目标是定位[真实网络批次](../2026-10-24-network-ui/README.md)中 CUA 滚动、拖动和 PageDown 未能到达下一轮输入的问题。自动化操作没有移动页面，不足以判断是产品缺陷。

## 验证边界

- 固定 iPhone 17 / iOS 26.5 模拟器，不切换设备、不卸载或清空数据。
- 使用 DEBUG 隔离数据库和离线传输，原样重放 N01 已保存的 213 字符合成回答。重放正文已与 `n01-response.json` 的 `response.body` 逐字符比较一致。
- 不读取模型凭据、不访问模型、不发送真实 N02、不填具体获益反馈。键盘语音夹具仅避免真实麦克风权限路径；本轮不验收语音。
- 两个原生 XCTest：普通字号/浅色、最大辅助字号/深色。实际点击入口、输入首轮、重放回答、原生滑动至下一轮、输入预登记 N02 原话、收起键盘、检查发送可操作，但不点击第二次发送。
- 记录回答、键盘输入、发送就绪截图。测试通过只证明该布局和原生手势能够到达编辑与发送；不证明 CUA 滚动有效、供应商多轮效果、真实流式增长、真人理解或实际获益。
- 首轮测试后追加了生产草稿状态修复和键盘可见区处理，已同步用户发布说明。

## 结果

首轮原生测试 **0 通过 / 2 失败 / 0 跳过**。两种字号都能原生滑动到下一轮输入，但原输入未清空，导致 N02 与 N01 原话拼接；没有发送拼接后的内容。该问题属于可复现的产品草稿生命周期问题，不能据此断定 CUA 滚动失败的原因。

已准备修复：回复提交事务只清空与本次提交文字、草稿版本及用户来源均匹配的输入；等待时的新草稿、讲解按钮未提交的草稿、失败请求保留。清空不递增用户编辑版本，作为该版本的已消费状态；旧版本同内容写入不能复活草稿，下一次用户编辑正常递增版本。重复保存回复也不能清空后来输入。

第一轮回归：1535 单元通过 / 1 失败 / 24 跳过；3 UI 通过 / 1 失败。单元失败来自新增竞态测试把“事务内取消并回滚”误当作“已经提交后取消”，保留原输入实际符合规则；已将这两个时序分别验证。UI 失败确认最大字号下键盘出现后编辑器不可见，普通字号继续输入和流式完成/中断通过。原失败保存在 `first-regression-result.json`。

中间候选：1537 单元通过 / 0 失败 / 24 跳过，4 UI 通过，42 脚本通过。但截图审读发现最大字号键盘场景只露出编辑器末行，原几何检查只检查底部，未检查顶部。**自动化通过不等于视觉通过**，该候选的视觉验收不通过。保留 `intermediate-regression-result.json`、源文件/二进制哈希与截图，不将其宣布为完成。

随后修正：取消输入区随辅助字号放大的外层最小高度，保留正文 Dynamic Type 与原生可滚动 TextEditor；焦点/键盘安全区变化时把完整输入控件滚到可见区。测试新增编辑器顶部必须位于导航栏下、底部必须位于键盘上，同时检查收起键盘操作可达。

第一次加严键盘专项：初始键盘测试通过，两种重放测试失败；原生 caret 调整后顶部仍进入导航栏遮挡。结果收集时本机磁盘写满，Xcode 退出 -5，结果包未完成；不把日志当作完整结果包。`keyboard-attempt-result.json` 保留这次失败及采集限制，原始日志和未完成 Staging 留本机。清理了可重建的编译缓存/旧 Release 产物，原始数据库、签名 App 和旧验收包均保留；失败的临时压缩副本已移除，原包未删除。后续使用 `-collect-test-diagnostics never` 限制额外诊断体积。

第二次键盘专项：最大字号和初始键盘测试通过，普通字号在收起键盘时持续占用 CPU 并最终超过测试执行时限，整批失败。采样显示主线程持续进行 SwiftUI graph/layout 更新，不能宣称流畅可用；结果保存在 `settled-keyboard-attempt-result.json`。测试进程之后自行终止，没有重启仍在运行的测试以凑成功。

后续尝试保留在 `keyboard-notification-attempt-result.json`、`fixed-editor-attempt-result.json`、`accessibility-only-attempt-result.json`：移除视口高度依赖、固定编辑器高度、只在辅助字号显式定位，都未同时满足稳定退出与完整可见。确认卡顿后停止相应隔离测试，保留退出与失败；不以缩短或放宽几何检查得到通过。

最终候选改为原生底部输入区：输入与发送使用安全区避让键盘，长时间线和反馈保持在独立阅读区，不再在打字时程序化滚动整页。可展开的语音审阅区域有独立滚动空间，发送始终位于其外；只有交流页指定编辑器高度，其他共享输入调用保持默认行为。

底部初版：普通字号继续输入、初始键盘均通过；最大字号新回复仍在长原话之后的未展开区域，测试未找到回答，因此整批 **2 通过 / 1 失败**，保留 `bottom-composer-attempt-result.json`。补充只在新回复保存后定位阅读区，并以输入内容自然高度限制底部区域，移除无意义空白。新增最大字号语音取消、重录、审阅与追加回归，避免输入区重排把识别操作挡住。

**当前最终候选尚待干净 CI 构建、受影响原生测试和截图审读。** `test-source.json` 绑定最终源文件哈希，不声称存在对应的已验收二进制；中间版本单元与 UI 结果分别绑定自己的哈希，不拼接为最终候选全量通过。本轮没有新增模型调用，真实网络 N02/N03、手机与真人价值均未验收。Mac 再次锁屏，真实网络界面操作仍需本人解锁；未绕过锁屏。

## 如何复验

使用本仓库 `MingSi` scheme 构建后，在同一已有模拟器运行下列 `-only-testing` 项。夹具仅 DEBUG 可用，使用隔离的内存数据库及离线传输，不需要模型 Key。

```text
MingSiTests/MentorFeatureStoreTests
MingSiTests/MentorPersistenceTests
MingSiUITests/MentorNavigationUITests/testSavedNetworkResponseAllowsNextInputWithoutBenefitFeedback
MingSiUITests/MentorNavigationUITests/testSavedNetworkResponseAllowsNextInputAtLargestDarkText
MingSiUITests/MentorNavigationUITests/testActiveConversationKeyboardKeepsInputAndExitReachable
MingSiUITests/MentorNavigationUITests/testBottomComposerReviewsSpeechWithoutLosingTypedDraftAtLargestText
```

公开 CI 已加入两种重放、初始键盘、底部语音审阅和两种流式状态测试，继续保留原来的权限 UI 验证，共八条隔离 UI。具体远端结果另行绑定提交，不由 workflow 文件存在推断通过。
