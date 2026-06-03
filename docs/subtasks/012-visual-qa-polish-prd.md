# Subtask 012: Visual QA Polish PRD

## Goal

把当前明思 MVP 做一次窄范围视觉 QA 和页面结构硬化，优先修复会直接破坏使用感的界面问题：

- 页面左右白边或背景露白。
- Tab 栏与内容遮挡。
- Projects / Growth / Settings 页面过于模板化或像占位页。
- History 日历 sheet 顶部拥挤、内容需要拖动后才能完整读。
- 视觉语言偏 AI 模板化：紫色、居中大字、同质卡片、装饰多于信息。

本任务不是重做设计系统，也不是新增大功能。

## Product Context

明思的 MVP 不是营销页，也不是普通日记。它是一个工作型思维训练工具：

```text
输入 -> 卡片 -> 透镜 -> 追问 -> 明日任务 -> 次日验证 -> 原则沉淀 -> 历史证据
```

Today 是主流程。History / Projects / Growth 是证据和复盘表面，不能显得像空泛 dashboard。

## Design Language

使用 `Calm Native Intelligence`：

- warm paper background
- off-black ink
- restrained green/brick/note accents
- dense but quiet working surface
- cards only for repeated evidence objects
- no purple-blue gradient
- no glassmorphism
- no centered hero / startup template composition
- no fake decorative charts
- no nested cards

Reference files:

- `docs/ui-design-draft.md`
- `docs/prd.md`
- `docs/implementation-gap-audit.md`
- `Sources/DesignSystem/Theme.swift`

## Scope

### In Scope

1. Full-bleed background hardening
   - Every root tab must cover full safe area with `DS.background`.
   - No accidental white gutters on Projects / Growth / History / Settings.
   - Tab bar must not visually collide with page content.

2. History calendar sheet
   - Sheet content must be readable immediately after opening.
   - Top controls must not overlap or require dragging before they become visible.
   - Keep week/month/year navigation.
   - Preserve evidence dots for cards, task/verification, principle/summary.

3. Projects visual polish
   - Keep the evidence-backed meaning of Project.
   - Project list should read as a working surface, not a generic table.
   - Empty state should be calm and specific.
   - No unsupported progress claims.
   - Keep deep link and evidence timeline behavior intact.

4. Growth visual polish
   - Growth must not show unsupported numbers.
   - When evidence is insufficient, make that state look intentional and useful.
   - Metric rows should show why a value exists or why evidence is missing.
   - Preserve contribution detail sheet and History deep links.

5. Settings visual polish
   - Keep paste/test-connection behavior.
   - Reduce button bulk around API Key / Base URL.
   - Make connection test status visible without dominating the page.
   - Preserve Keychain / Base URL / model behavior.

## Out of Scope

- New data models.
- New migrations.
- New GLM prompts.
- New Growth AI weekly/monthly report generation.
- Project candidate / merge / insight AI use cases.
- Custom lenses or marketplace.
- New app icon redesign.
- Complex animation.

## Required Progress File

Claude Code must update:

`docs/subtasks/012-visual-qa-polish-claude-progress.md`

Required updates:

- Mark task start.
- Maintain a checklist of files inspected.
- Maintain a checklist of files changed.
- Record every verification command and result.
- If blocked, write the blocker and the last completed checklist item.

## Implementation Rules

- Do not modify persistence, domain models, prompt logic, GLM client, or repositories unless a compile error forces it.
- Prefer local view/component changes in:
  - `Sources/Features/FeatureTabs.swift`
  - `Sources/DesignSystem/Theme.swift`
  - `Sources/App/AppRootView.swift`
- Keep Today flow behavior intact.
- Do not remove existing tests.
- Do not introduce external packages.
- Use SwiftUI-native components.
- Keep accessibility labels where existing.

## Acceptance Criteria

- App builds for iPhone simulator.
- Existing test suite still passes, or any failure is clearly unrelated and documented with evidence.
- Projects, Growth, History, and Settings root views use full-bleed `DS.background`.
- Main scroll content has bottom padding or safe area spacing so Tab bar does not cover actionable content.
- History calendar sheet opens without top content overlap.
- Projects page does not use unsupported progress, fake charts, or table-like placeholder rows.
- Growth page does not show scores when `canDisplayScores == false`.
- Settings API configuration area remains usable but visually calmer than separate large paste buttons.

## Verification Commands

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Optional simulator visual verification if time permits:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```
