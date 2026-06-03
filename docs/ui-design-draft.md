# 明思 UI Design Draft

## Design Intent

The interface should feel like a calm thinking workspace: structured, focused, and quietly premium. It should not look like a chatbot, a generic todo list, or a decorative RPG app.

Design language:

```text
Calm Native Intelligence
```

This means calm enough for daily private reflection, native enough to feel like a first-class iOS app, and intelligent through structure rather than visual noise.

The design goal is:

```text
Free input, structured thinking, coach-like feedback, lightweight quest motivation.
```

## Product Surface

Primary tabs:

- Today: daily loop and current state.
- History: past entries, cards, quests, verifications, and evidence search.
- Projects: abstract project contexts and bottlenecks.
- Growth: before/after evidence and trend indicators.
- Settings: privacy, model, and data controls.

Today is the primary complete flow. History, Projects, and Growth can be minimal in MVP, but they cannot be decorative placeholders: each must render real evidence-backed records and must support jumping back to source history where relevant. Tabs are not workflow steps; Today owns the active state machine.

Global layout rule:

- Page backgrounds must extend full bleed to screen edges.
- Content may use horizontal padding, but the app must not show accidental white gutters on the left or right.
- Repeated objects can be cards; whole pages should not look like nested cards.

App icon rule:

- The icon should carry the meaning of `明` rather than an arbitrary abstract glyph.
- MVP icon uses explicit `日` and `月` forms on warm paper with deep ink and a small cinnabar thought mark.
- Avoid purple AI gradients, random initials, or decorative symbols that do not explain the product.

## Today Screen Structure

Default hierarchy:

```text
Header
- Date
- Current loop status
- Optional yesterday verification prompt

Primary panel
- Capture input or current active step

Secondary panel
- Cards, lens, questions, or quest draft depending on state

Bottom action bar
- One primary action
- One secondary action
```

Today is state-driven. It should not show every control at once.

States:

- VerifyYesterday
- Capture
- Organizing
- ReviewCards
- SelectMode
- SelectLens
- AnswerQuestions
- ReviewQuests
- ExtractPrinciple
- SessionComplete

Each state has one clear primary action.

## Navigation and Flow Guardrails

Users can switch tabs at any time. The app should guide the loop through state and context, not by locking navigation.

Rules:

- Today owns the active daily loop.
- History, Projects, and Growth are review/reference surfaces.
- If the user leaves Today mid-flow, progress is autosaved.
- Other tabs show a compact Resume Today banner when a loop is incomplete.
- Invalid actions are disabled with short explanations.
- Skipped steps are explicit states, not silent failures.

Example banner:

```text
今日复盘未完成
已整理 5 张卡片，尚未生成明日主线任务。

[继续今日复盘]
```

## Component System

### ThinkingCard

Semantic source:

- ThinkingCard record.

Presentation variants:

- Compact card.
- Detail card.
- Timeline card.
- Report evidence card.
- Quest-linked card.

Required visible elements:

- Type label.
- Title.
- Short body.
- Importance marker.
- Sensitivity marker when relevant.

Optional controls:

- Edit.
- Merge.
- Delete.
- Mark important.
- Mark sensitive.
- Change type.

The persisted card data must not depend on one visual card shape.

## Fixed Components First, Schema-Driven UI Later

The MVP should use fixed, hand-designed components. This protects taste, consistency, accessibility, and implementation speed.

MVP fixed components:

- ThinkingCard.
- LensCard.
- QuestionCard.
- QuestCard.
- GrowthEvidenceCard.
- MetricTrendCard.
- BeforeAfterCard.

Future versions may support schema-driven UI, but only through a constrained component registry. The model should never generate arbitrary executable UI. It may only propose declarative component recipes that the client validates and renders through approved native components.

AI generation states follow the same rule. The MVP renders temporary card placeholders from the controlled `MINGSI_STREAM_V1` XML-like stream. These temporary cards are presentation state only and must be revalidated before becoming editable `ThinkingCard` candidates.

Streaming card interaction:

- New card appears when `<CARD>` arrives.
- Title fades in when `<TITLE>` content arrives.
- Body text appends in small batches, not per-character jitter.
- `</CARD>` adds a small completion mark.
- If the stream stalls, show the latest received card and a concise status line.
- Respect Reduce Motion: disable movement and keep opacity-only updates.

Future flow:

```text
Confirmed semantic data
-> AI suggests presentation schema
-> Client validates schema
-> Client maps schema to approved SwiftUI components
-> Unknown or invalid schema falls back to standard cards
```

Example component recipe:

```json
{
  "schemaVersion": 1,
  "component": "before_after_card",
  "variant": "compact",
  "dataRefs": ["card_early_001", "card_later_014"],
  "emphasis": "clarity_improvement",
  "fallback": "thinking_card_list"
}
```

Design rule:

- Semantic records remain the source of truth.
- UI schemas only describe presentation.
- UI schemas must reference existing data; they should not invent user facts.
- The renderer must be allowlisted and versioned.
- Invalid schema must degrade gracefully.

This gives the product a future path for more expressive AI-generated visualizations without sacrificing reliability or taste.

### LensCard

Purpose:

- Explain a thinking lens and why it is recommended.

Visible elements:

- Chinese lens name.
- Short tag, such as `事实` / `反证` / `杠杆`.
- One-line purpose.
- Concrete method hint: the first question this lens asks.
- Distinct icon/accent treatment per lens.
- Select action.

Tone:

- Direct and intellectual, not mystical or motivational.
- No English-only lens names in MVP.

Current MVP lens cards:

- `证据校验`：graphite accent, checklist mark, separates fact/judgment/assumption.
- `反方视角`：brick accent, opposing-arrows mark, searches for disconfirming evidence.
- `杠杆分析`：green ink accent, leverage path mark, identifies the highest-impact next move.

### QuestionCard

Purpose:

- Ask one specific question and collect a short answer.

Visible elements:

- Question.
- Why this matters.
- Answer field.
- Optional skip action.

Rule:

- At least one answered question is required before quest generation.

### QuestCard

Purpose:

- Present a tomorrow action with clear value and completion criteria.

Visible elements:

- Quest type: Main, Side, Observation.
- Title.
- Why it matters.
- Completion criteria.
- Expected resistance.
- Reflection question.

Style:

- Slightly more energetic than thinking cards, but not game-heavy.

### GrowthEvidenceCard

Purpose:

- Show visible user progress through before/after examples.

Visible elements:

- Earlier example.
- Later example.
- What changed.
- Linked metric.

## Visual Taste

Recommended direction:

- Native iOS patterns.
- Light background.
- Compact cards with 8px corner radius unless native platform conventions require otherwise.
- Subtle dividers and low-contrast borders.
- Strong typography hierarchy.
- Small color accents by semantic type.
- No decorative orbs, heavy gradients, or fantasy UI.
- No chat bubble as the primary interface.

Color role examples:

- Fact: neutral.
- Problem: amber.
- Decision: blue.
- Risk: red.
- Idea: green.
- Communication: purple accent only, not dominant.
- Task/Quest: indigo or teal accent.

The palette should not become one-note. Accents should clarify meaning, not dominate the product.

Apple-like direction:

- Minimal surface, rich interaction.
- Quiet default state, precise detail on expansion.
- Subtle depth through spacing, typography, and motion rather than decoration.
- Smooth transitions that explain hierarchy changes.
- Haptics for important confirmations only, not every tap.
- No visual gimmicks that compete with thinking.

Card and lens surfaces should feel simple at rest, but reveal structure when the user interacts:

- Tap to expand evidence.
- Long press or menu for edit, merge, and sensitive actions.
- Swipe only for low-risk actions.
- Use progressive disclosure for advanced controls.

## Layout Extensibility

The UI should be built around semantic view models:

```text
Semantic record -> View model -> Component variant
```

This supports future shifts:

- Card list to timeline.
- Card list to board.
- Quest card to compact checklist.
- Growth dashboard to report view.
- Lens selector to carousel.

The data model should not need to change when the layout changes.

## Motion and Animation Readiness

MVP does not need rich animation, but the structure should support it later.

Animation principles:

- Motion clarifies state changes.
- Motion should never be the only way information is communicated.
- Respect reduce-motion settings.
- Keep transitions short and functional.
- Avoid playful effects that reduce trust.

Future animation opportunities:

- Raw input gently separates into cards after organization.
- Cards expand into detail views.
- Recommended lens slides into focus.
- Quest card activates with a subtle state change.
- Verification creates a small completion transition.
- Growth before/after examples crossfade or slide.
- Lens selection can use a focused carousel or stacked transition.
- Card grouping can animate by semantic type after organization.

Implementation readiness:

- Use stable ids for all cards, questions, quests, and reports.
- Keep component variants compatible with SwiftUI transitions.
- Avoid layout structures that require fixed heights for dynamic text.
- Use state machines so transitions are predictable.
- Keep animation tokens centralized.

Suggested motion tokens:

```text
motion.fast = 120ms
motion.normal = 220ms
motion.slow = 360ms
curve.standard = easeInOut
curve.emphasis = spring(response: 0.32, dampingFraction: 0.86)
```

Animation constraints:

- Avoid long celebratory animations for task completion.
- Do not animate large text blocks in a way that hurts readability.
- Do not make dynamic schema-rendered UI depend on custom animation code from the model.
- Schema-driven components may request predefined motion roles only, such as `expand`, `focus`, `confirm`, or `compare`.

## Daily Flow UI Draft

### Verify Yesterday

Top card:

```text
Yesterday's Main Quest
Confirm the real bottleneck in the current project

Completed / Partially / Not completed
Actual value: High / Medium / Low / Unclear
```

Primary action:

- Save verification.

### Capture

Primary panel:

```text
What happened today?

[Large text editor]

Prompt starters:
- What felt unclear?
- What decision did you avoid?
- What should tomorrow not ignore?
```

Primary action:

- Organize into cards.

### Review Cards

Primary panel:

```text
7 thinking cards found
```

Grouped cards:

- Problems.
- Decisions.
- Risks.
- Tasks.

Primary action:

- Confirm cards.

### Select Lens

Primary panel:

```text
Recommended Lens
Opportunity Cost

Why: today's cards show multiple execution actions but unclear value tradeoffs.
```

Primary action:

- Use this lens.

### Answer Questions

Question cards:

```text
If tomorrow only allows one meaningful action, what would change the project state most?
```

Primary action:

- Generate tomorrow quest.

### Review Quests

Quest cards:

```text
Main Quest
Clarify the real bottleneck in the current project

Completion criteria:
Identify whether the bottleneck is requirement, collaboration, or technical.
```

Primary action:

- Accept main quest.

## History UI Draft

Purpose:

- Let users revisit past sessions and see proof of change.

List view:

```text
历史

5月31日
主线任务：确认项目当前真实瓶颈
状态：已验证 · 高价值
透镜：机会成本

5月30日
主线任务：整理项目边界问题
状态：部分完成
透镜：证据检查
```

Detail view:

```text
5月31日复盘

状态：已验证
透镜：机会成本

思考卡片
- 问题：项目边界不清
- 决策：短期先兼容旧逻辑
- 任务：明天确认接口归属

明日主线任务
确认项目当前真实瓶颈

验证结果
已完成 · 高价值

相关成长证据
清晰度提升：完成条件比上周更明确
```

History should feel like an evidence archive, not a file browser. Raw input should be collapsed by default, with confirmed cards and verified outcomes more prominent.

## Projects UI Draft

Projects should answer why a project exists, what changed, and what evidence supports that view.

Project is a working surface, not a folder list. The page should use a quiet split rhythm:

- A narrow status rail for Active / Watching / Paused / Archived.
- A dense project list with goal, bottleneck, and last evidence date.
- A detail surface driven by timeline and before/after evidence.

It should not use identical centered cards for every row. Progress is shown as evidence signals, not decorative completion rings.

List view:

```text
项目

[Active] [Watching] [Paused] [Archived]

会议效率
目标：会前明确确认事项，会后形成 Action
当前阻塞：会前材料准备不稳定
最近进展：2 个主线任务完成 · 1 个开放问题关闭

判断质量
目标：把模糊任务转成可验证判断
当前阻塞：任务价值验证不足
最近进展：本周 3 条证据
```

Detail view:

```text
会议效率

当前目标
会前列出要确认的问题，会后发出结论与责任人。

当前阻塞
会前没有稳定准备材料。

最近进展
- 5月31日：完成会前确认清单
- 6月1日：会后摘要减少二次沟通

思考变化
Before: "开会推进一下。"
After: "这次会议必须确认接口责任人、验收标准和下一步。"

开放问题
- 哪类会议需要正式纪要？
- 什么时候只需要同步，不需要完整流程？
```

Project UI rules:

- Every progress item must link to History.
- Merge candidates must show reason, overlapping evidence, and risks before user confirmation.
- Project names should stay abstract and privacy-safe.
- The page should use a dense working layout, not oversized centered cards.
- If there is no ProjectLink evidence, show an empty evidence state instead of sample projects.
- Thinking change uses before/after contrast with source dates; never show a generic insight block without source links.
- Avoid left/right white gutters by letting the page background fill the full safe area, then constraining inner content.

## Growth UI Draft

Growth should prioritize evidence over decoration.

Growth is closer to an attribution ledger than a dashboard. The first screen may summarize trends, but every number must open into why it changed.

Sections:

- This month at a glance.
- Five metric trends.
- Before/after examples.
- Repeated pattern.
- Next training focus.

The most important module:

```text
Before
"Continue pushing the project."

After
"Confirm whether the blocker is requirement boundary or technical design; output three unresolved questions."

What changed
The later task has clearer completion criteria and better validation value.
```

Metric detail:

```text
清晰度 3.8 (+0.4)

为什么变化
本周主线任务的完成标准更具体，且两次主动区分了事实和假设。

加分事件
+ 5月31日：把“推进项目”改成“确认当前真实瓶颈”
+ 6月2日：先列出会议必须确认的问题

减分事件
- 6月3日：输入只有情绪判断，没有可验证事实

下一步训练
继续练习 Evidence Check，在任务生成前先分离事实、判断和假设。
```

Contribution detail:

```text
加分事件
5月31日 · 清晰度 +0.2

为什么加分
把“推进项目”改成“确认当前真实瓶颈”，完成标准从动作变成了验证问题。

来源
History · 5月31日 · 主线任务

[查看来源] [标记不准确]
```

Growth UI rules:

- No metric number appears without a reason.
- Every positive or negative event links to a source record.
- Scores are trend indicators, not labels about the user.
- The first view should show overview; metric detail should handle explanation depth.
- With insufficient evidence, show collection progress and next action instead of fake scores.
- Positive and negative contributions should be visually distinct, but not gamified as rewards or punishments.
- Use off-white paper, off-black text, fine dividers, restrained red for negative deltas, restrained green or ink-blue for positive deltas. Avoid purple AI styling.

## Design Debt to Avoid

- Coupling stored data to current card UI.
- Making a large text editor the whole product.
- Building too many visual states before the loop works.
- Adding full RPG systems before proving the quest loop.
- Using animations that hide unclear information architecture.
- Treating AI output as final truth instead of editable draft.

## MVP UI Acceptance Criteria

- User can complete the full daily loop from Today without switching tabs.
- User never has to clean a full transcript before seeing organized cards.
- Each screen has one obvious primary action.
- Every AI-generated object is editable before it affects later steps.
- UI can render the same ThinkingCard as compact, detail, or report evidence without data migration.
- Future animation can be added through stable ids and explicit state transitions.
