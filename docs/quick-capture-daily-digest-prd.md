# 闪念快速捕获与按日聚合 PRD

## 问题与目标

用户在走路、开会间隙或切换任务时会有短暂想法，却不愿打开完整训练流程；这些素材容易丢失，也不应在未经确认时变成事项或行动。目标是在明思中提供“闪念”：可快速保存原始文字，并在同一**本地自然日**有至少两条待整理素材时，由用户主动请求一次按日聚合。聚合帮助用户回到今日原始输入，但不取代 vNext 的证据闭环。

## 非目标

- 不持续录音、不保存或声称保存原始音频。
- 不自动创建 `TrainingCase`、`Quest`、`Principle`、`MetricContribution`，不自动开始训练、复盘或通知。
- 不自动替换、润色或覆盖原始闪念，也不在无模型或失败时伪造本地 AI 结论。
- Action Button 由用户在系统中自行绑定 App Shortcut；相机控制键不在范围。

## 核心旅程与状态

1. 用户在 App sheet 输入文字，或通过“记录到明思”Siri/App Shortcut 传入非空文字。
2. 数据库事务成功后显示“已保存到明思/今日闪念”；失败不显示成功。
3. `CaptureFragment` 初始为 `pending`，可归档为 `archived`；原文不可由 AI 改写。
4. 两条以上 `pending` 时，用户点击“整理今天的闪念”。模型成功返回受限 JSON 后，事务写入一个 `DailyCaptureDigest` 并将被引用来源改为 `included`。
5. digest 状态为 `current`、`accepted` 或 `ignored`。同一自然日只允许一个 `current` digest；新生成会在同一事务中使旧 current 失效。
6. 用户“带入今日整理”只把确认后的聚合文本追加到 Today 原始输入，不启动 organize/training；“暂不处理”归档 digest。

## 数据与一致性

`capture_fragments` 保存 ID、原始文字、来源、状态、日键、可选来源 ID、创建/更新时间。`daily_capture_digests` 保存日键、状态、summary、themes、至多一个推荐问题、来源 fragment IDs 快照和时间戳。v48 migration 建表和唯一索引；导出包含两表，继续排除 Keychain/API key。repository 的保存按来源 ID 幂等；digest 写入与来源 included 标记同事务，任一步失败都保留 pending 原文。

## LLM 边界

调用必须通过 `CentralLLMDecisionCenter` 和 PromptRun tracing，PromptID 为 `digestCaptures`、route 为 `capture`，PromptRun source IDs 是实际 fragment IDs。输入只包含同日 pending 原文。输出仅允许 `summary`、1-3 个非空 `themes`、最多一个 `recommended_question`、`source_refs`；source refs 必须无重复且恰好覆盖全部输入来源。无 API key、传输失败或 schema 失败时保持 pending，界面显示可重试。

## 系统入口、恢复与隐私

AppIntent 不打开 App，使用 `AppDatabase.defaultURL` 和 repository 直接落盘，成功才返回系统对话“已保存到明思”。App 回到 active 时刷新今日闪念。任何保存、聚合或归档失败都不给成功反馈，不删除原始素材。原始文字仅保存在本地 SQLite，随用户数据导出；API key 仍只在 Keychain，PromptRun 不包含 Keychain 内容。用户应避免记录不必要的机密信息。

## 验收

- 手动输入、Siri/Shortcut 入口均只在事务成功后确认保存。
- 一条闪念不能触发聚合；两条可生成且来源引用可追溯。
- 接受 digest 只追加 Today raw input；不产生训练、事项、行动或通知。
- migration、导出、幂等、失败回滚、Prompt schema/source refs、AppStore 和 UI automation 都有测试覆盖。
