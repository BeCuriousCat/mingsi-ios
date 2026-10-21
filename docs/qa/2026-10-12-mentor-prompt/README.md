# 导师 Prompt 与首发内容验收 · 2026-10-12

2026-10-16 更正：用户已完成模型配置，固定模拟器内真实 GLM-5.3 调用可用。下文“Keychain 记录为 0”的旧检查只比较明文索引，未识别当前模拟器的 SHA-1 索引，不能证明当时未保存密钥；历史 opt-in 测试跳过仍是当次事实。当前预检与真实输出复核见[最新报告](../2026-10-16-mentor-live/README.md)。

## 本轮发现

明思导师原有规则擅长约束来源、输出格式和用户自主性，但对“此刻先怎样帮到用户”约束不足。它容易把“我很累”“直接讲”“别再问了”处理成材料缺口，也可能把 AI 的解释写成用户已经认可的理解。

## 已交付

- 首次交付 `mentorRespond` / `mentorDraftUnderstanding` 1.2.0；截至 2026-10-14，回应为 2.7.0，理解草稿为 2.6.0，历史模板继续保留。
- 1.2.0 增加明确的帮助路由：最新诉求优先，倾听和拒绝追问不被改写成训练任务，每轮只选一个思考动作，先回应再决定是否追问。
- 先识别倾听、理解、比较、建议或纠正诉求；一轮只推进一个有价值的思考动作。
- 追问只在会改变帮助时出现，最多一项并放入 `question`；direct teaching 强制没有问题。
- 最新自然语言纠正优先；旧 assistant 解释不成为事实；理解草稿保留用户的不确定、否定和未决定。
- OpenAI 兼容 `choices/message/content` 响应包严格解包，禁止靠代码围栏清理或截取“看起来像 JSON”的片段；已验证协议正文用于时间线回放。
- 24 篇正式教材包 `mingsi-mentor-m1 / 1.1` 已进入 Release，AI 审核身份和授权记录可追溯。

## 验证

环境为固定 iPhone 17 模拟器 `9F93EE80-68DF-4922-8A73-B0590F5143D4` / iOS 26.5。

| 范围 | 结果 |
| --- | --- |
| 全量 MingSiCoreHelpAcceptance 单元／集成 | 1303 通过，0 失败，3 个 live BYOK 测试跳过 |
| 生产根页面离线教材、启动恢复失败重试、深色最大字号 | 3 条 UI 通过 |
| Release 未签名真机构建 | 通过；包含 `mentor-lessons-m1.json`，不包含 draft 资源 |
| AI 编辑内容包 | 24 篇、6 主题、哈希与版本校验通过 |

最初装配的 5 个合成语义场景覆盖疲劳不想总结、直接比较入口、自然语言纠正、尚未认可的方法、两次补问后拒绝继续；现有 9 个，另覆盖明确求建议、找漏洞、第二个可见回合仍缺少回看材料，以及普通交流中用户补充事实后继续请求建议。它们会校验请求材料、Prompt 版本、纠正顺序、轮次上下文和问题预算；真正调用模型的验收需要本机 BYOK Key，并保存原始合成响应供人工复核。

已补充 `scripts/run_live_glm_acceptance.sh --mentor-semantic`，会在固定 iPhone 17 的 XCTest 环境注入专用 opt-in 标记，并使用模拟器 Keychain 中的 BYOK 配置运行这 9 个场景；普通探针和职业 golden 入口不受影响。
完整 Alpha 验收也可通过 `scripts/run_alpha_acceptance.sh --live-mentor-semantic` 选择该场景，并在 summary JSON 中记录 `live_mentor_semantic=true`。

本轮回归证据：固定 iPhone 17 上 `LocalPromptProviderTests`、`MentorContextBuilderTests`、`MentorResponseParserTests` 共 73 项通过；活动交流大字号 UI 用例通过，验证多轮提示、输入、语音入口和结束操作同时可达。当前 Alpha 预检仍报告 `live_glm: missing_key`。

随后固定设备全量 `MingSiTests` 为 1306 项通过、0 失败、3 项 live BYOK 跳过；`git diff --check` 通过。跳过项仍是需要真实 BYOK 的语义验收，不计为模型效果通过。

## 尚未完成

此前检查时固定模拟器设置页显示“尚未配置 GLM API Key”，因此那次真实模型语义验收被明确跳过。此后用户已开始配置，但配置完成和真实模型输出尚未记入验收。不能把 Prompt 文本、结构解析通过或模型自评当成真实语义质量证据。约 14 天真实试用、真机／VoiceOver 和长期价值也仍需单独记录。

2026-10-14 补充：普通交流多轮场景装配、验收断言与 Prompt 规格相关测试在固定 iPhone 17 上共 21 项通过；它验证上下文中确有上一轮问题、第二个可见回合和最新用户表达。测试没有调用模型，不改变真实模型语义验收仍待执行的状态。结果：`/tmp/mingsi-prompt-multiturn-dd/Logs/Test/Test-MingSi-2026.10.14_12-09-58-+0800.xcresult`。

### 2026-10-14 当前问题与修正

当前核心风险是对导师帮助质量缺少真实模型输出证据。结构通过、来源 ID 合法、教材可读，都不能证明导师接住了用户的新事实并改变建议。已确认生产 `MentorFeatureStore.submitTask` 在保存回应前执行 `MentorResponseQualityPolicy.validate`；它可拦无来源和明显泛泛回应，不能判定所有语义问题。

回应 Prompt 2.6.0 从 2.0.0 起叠加六版行为段落，使新证据更新、默认收束和回看续问分散。2.7.0 保留独立合同和一份当前多轮规则，明确每轮只做一步、补材料预算不限制整个对话轮数、新事实更新旧判断，以及有条件的建议。历史 2.6.0 保持原文可回放；理解草稿的版本和行为本轮不调整。Prompt 长度与版本检查通过只证明装配正确，不代表新版本效果胜过旧版本。

固定 iPhone 17 / iOS 26.5 上，定向 Prompt、上下文、解析器、规格、生产 Store 版本与质量门、Live 场景装配检查：最终代码 122 项通过、0 失败、3 项 opt-in live 测试跳过。证据：`/tmp/mingsi-prompt-v270-final.xcresult`。

随后显式运行导师 Live 入口：模拟器内 XCTest 报告 `No BYOK API key available`，1 项跳过、0 项通过；这次检查直接来自设备测试进程，不是宿主 Keychain 预检。未发送模型请求。发现原 runner 会把 XCTest 的跳过退出码当成验收成功，现已要求结果中恰有 1 项通过、0 项跳过、0 失败，拒绝零测试或无效摘要；Alpha runner 同时在在线步骤失败时覆盖摘要为 `failed_live_glm`。六种结果门分支与 Alpha 摘要覆盖检查均通过。真实跳过路径复验退出码为 3，报告 `live_glm: not_accepted`；证据：`/tmp/mingsi-prompt-v270-live-gated.xcresult`。

配置完成后继续运行九场景的真实输出验收，再逐项复核来源、建议理由、纠正、停止边界和多轮更新，注明复核身份。评测采用[官方 OpenAI evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices)中任务专用样本、原始日志与人工反馈校准的原则；词项规则仅用于辅助检查。

### 2026-10-14 多轮执行与验收一致性

修正 Live 多轮验收的上下文：HTTP 响应包先经过生产解析器，再把协议正文写入 assistant 时间线，确保第二轮能读到上一问和正文。命令行 endpoint/model 配置优先于设备配置。普通交流中已呈现的材料问题计入第二轮预算；空白回看开场保留两次补材料机会。响应包、配置优先级与生产保存恢复的定向回归为 13 项通过、0 失败、3 项 live 跳过，证据为 `/tmp/mingsi-live-harness-canonical-regression.xcresult`。

生产存储修正了空白回看开场误占预算的问题：只有首条无用户材料的 review 开场豁免，后续 review 请求和带材料的首次请求仍计数。Store 回归覆盖开场、两次补问和此后继续交流的四次请求，发送的计数依次为 0、0、1、2；达到上限后仍能解释，但不再索要材料。重复呈现保持幂等。

固定 iPhone 17 / iOS 26.5 上，`MentorFeatureStoreTests`、`MentorPersistenceTests`、`MentorContextBuilderTests`、`LiveGLMAcceptanceTests` 共 211 项通过、0 失败、3 项 opt-in live 跳过；`git diff --check` 通过。证据为 `/tmp/mingsi-mentor-review-budget-verified.xcresult`。上一轮 `/tmp/mingsi-mentor-review-budget-regression.xcresult` 因磁盘不足无法保存完整结果，不作为通过证据。设备目标 BYOK Keychain 记录仍为 0，真实模型语义验收尚未执行。

长对话复查随后修正了轮次受压缩窗口影响、当前追问丢失相邻老师回应的缺陷。完整时间线的可见轮次在裁减前确定；普通追加表达保留上一段老师回应所在交流组，放不下则进入材料选择。九轮会话、显式材料选择和超限拒绝静默丢失指代的回归通过；上下文、Store 和 Live 装配合计 155 项通过、0 失败、3 项 opt-in live 跳过。证据：`/tmp/mingsi-mentor-context-continuity.xcresult`。本次未执行真实模型语义验收。

### 2026-10-14 实际多轮页面死路修复

无教材的普通交流曾因 `MentorReadingGeometry` 停止采样，无法确认已显示的回应，因此“发送”一直禁用。已将回应呈现检测与教材阅读位置采样解耦，页面退出或后台仍停止采样。另接通既有的显式“继续回忆”本地命令：预算耗尽后用户可主动开新段，保留草稿和历史，失败可重试，点击本身不发模型请求。

最终 Store、仓储、真实 UIKit 几何和两条 UI 共 198 项通过、0 失败、0 跳过。UI 覆盖无教材回应后的发送资格、继续回忆后草稿保留与退出、长教材阅读恢复；前后截图已人工检查。证据：`/tmp/mingsi-recall-continuation-final.xcresult`，截图目录：`/tmp/mingsi-recall-continuation-final-shots`。此前两次失败用于发现并修正缺陷，没有计为通过。固定模拟器的目标 BYOK Keychain 记录仍为 0；未发送真实模型请求。

证据结果：

- `/tmp/mingsi-core-help-unit-final-20261011.xcresult`
- `/tmp/mingsi-core-help-ui-final-20261011.xcresult`
- `/tmp/mingsi-core-help-release-20261011.log`
