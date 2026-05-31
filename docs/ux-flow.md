# 明思 UX Flow

## UX Principles

- App 应该像一个安静的思考工作台，而不是聊天窗口。
- 用户不应该先被迫整理大段口述文本，AI 先做低风险结构化。
- AI 负责整理、追问和建议，用户负责确认、取舍和验证。
- Daily loop 需要能在 10-15 分钟内完成。
- 进步应通过前后对照和真实证据展示，而不是通过虚假的分数。

## Primary Navigation

MVP 底部 Tab：

- 今日：完整日常闭环。
- 历史：过去记录、卡片、任务、验证和证据。
- 项目：抽象项目和当前阻塞。
- 成长：周/月报告、趋势和原则资产入口。
- 设置：隐私、GLM API Key、数据和通知。

导航规则：

- Tab 是功能区，不是流程步骤。
- Today 拥有完整状态机。
- 用户可随时切换 Tab。
- 未完成闭环自动保存，并在其他 Tab 显示 Resume Today banner。

## First-Time Setup

1. Welcome
   - 展示产品名：明思。
   - 展示 slogan：不替你思考，而是训练你把事情想清楚。

2. Privacy Boundary
   - 用户确认不输入公司文档、代码、客户名或内部数据。
   - App 建议用 Project A、Team B 这类抽象命名。

3. GLM API Key
   - 用户输入自己的 GLM API Key。
   - Key 存入 Keychain。
   - 设置页可更新或清除。

4. Training Goal
   - 选择 1-2 个目标：清晰度、价值判断、执行可靠性、项目判断、反思深度。

5. Active Projects
   - 创建抽象项目卡。

6. Baseline
   - 五项指标自评。

7. Default Mode
   - 默认 Standard。
   - 用户可改成 Quick 或 Deep。

## Today State Machine

```text
VerifyYesterday
Capture
Organizing
ReviewCards
SelectMode
SelectLens
AnswerQuestions
ReviewQuests
ExtractPrinciple
SessionComplete
```

### VerifyYesterday

条件：

- 昨天存在 active main quest。

界面：

- 昨日主线任务。
- 完成状态：完成、部分、未完成。
- 实际价值：高、中、低、不明确。
- 未完成原因。

完成后进入 Capture。

### Capture

界面：

- 日期和当前状态。
- 大文本输入。
- Quick / Standard / Deep 分段控件。
- 隐私提醒。
- Save Draft。
- Organize。

输入方式：

- 键盘。
- iOS dictation。
- 第三方输入法语音输入。

### Organizing

界面：

- 轻量进度状态。
- 不展示聊天流。
- 如 GLM Key 缺失，引导去设置。

### ReviewCards

界面：

- 按类型分组的卡片。
- 每张卡片显示标题、正文、类型、重要度、敏感性。
- 操作：编辑、删除、合并、标记重要、标记敏感。

完成条件：

- 用户点击 Confirm Cards。

### SelectMode

如果用户在 Capture 已选择模式，此步骤仅作为确认。

模式差异：

- Quick：最少追问，快速生成主线任务。
- Standard：完整卡片、透镜、任务和原则候选。
- Deep：更多追问和反方质疑，用于重要事件。

### SelectLens

界面：

- 推荐透镜卡。
- 可手动切换。
- 简短说明：为什么推荐。

MVP 透镜：

- First Principles。
- Occam's Razor。
- Opposing View。
- Opportunity Cost。
- Leverage Analysis。
- Evidence Check。
- Execution Bias Check。

### AnswerQuestions

界面：

- 3-5 个问题卡。
- 用户至少回答一个。
- 问题必须具体、克制、不指责。

Quick 模式：

- 1-2 个问题。

Standard 模式：

- 3 个问题。

Deep 模式：

- 4-5 个问题，并至少包含一个反方问题。

### ReviewQuests

界面：

- Main Quest。
- Side Quest。
- Observation Quest。
- 每个任务包含为什么重要、完成标准、预期阻力、反思问题。

操作：

- 确认。
- 编辑。
- 删除次要任务。
- 设置本地提醒。

规则：

- Main Quest 必须有 completion criteria。
- 本地通知默认使用简洁标题，避免暴露敏感细节。

### ExtractPrinciple

界面：

- AI 最多提出 1 条行动准则候选。
- 用户可保存、修改或忽略。

原则卡内容：

- 标题。
- 适用场景。
- 具体做法。
- 成功标准。
- 来源日期。

### SessionComplete

界面：

- 明日主线任务。
- 今天训练的思维能力。
- 已保存的原则。
- 返回 Today 或查看历史。

## History Flow

目的：

- 作为成长和校准的证据层。

入口：

- History tab。
- Growth 证据卡。
- Project 相关记录。
- Verification 历史。

列表：

- 按日期分组。
- 展示状态、主线任务、透镜和验证状态。

详情：

- 原始输入默认折叠。
- 确认后的卡片。
- 透镜和回答。
- 明日任务。
- 次日验证。
- 原则候选或已保存原则。

## Growth Flow

展示：

- 周度校准。
- 月度成长。
- 五项趋势指标。
- 前后对照。
- 证据链接。
- 原则库入口。

Growth 不能展示没有证据来源的结论。

## Settings Flow

设置项：

- GLM API Key。
- 默认模式。
- 本地通知。
- 隐私边界。
- 数据导出。
- 数据清除。
- 外观密度。

## Guardrails

- 用户可以离开流程，但不能跳过关键确认。
- 未确认卡片不能作为最终事实源。
- 敏感卡片默认不进入后续模型调用。
- AI 生成任务必须由用户确认才激活。
- 原则候选必须由用户确认才进入原则库。
