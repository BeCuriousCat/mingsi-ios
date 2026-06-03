# Subtask 018 PRD: Project Insight Review

## Goal

让 Projects 不只展示证据时间线，还能在证据足够时生成“待确认项目洞察”，帮助用户看见长期议题中的进展、阻塞变化、开放问题和思考变化。

## Product Principle

Project insight 不是 AI 总结，也不是自动结论。它是 evidence-backed candidate：

- AI 可以提出洞察候选。
- 每条洞察必须带 `sourceRefs`。
- `thinking_change` 必须有 before/after 文本。
- 用户确认后才进入项目详情的已接受洞察。
- 用户忽略/标记不准确后，洞察不再作为项目事实展示。

## Scope

MVP slice includes:

- Add Project AI service method for `parseProjectInsights`.
- Build insight context from a selected project and its confirmed evidence links.
- Persist generated `ProjectInsight` candidates with `.none` feedback.
- Show pending/accepted insights in Project Detail.
- Allow user feedback:
  - accept -> `ProjectFeedback.accepted`
  - inaccurate -> `ProjectFeedback.inaccurate`
  - dismiss -> `ProjectFeedback.dismissed`
- Display accepted insights only as project narrative.
- Keep insufficient evidence visible when AI returns no insights with reason.

## Non-Goals

- No Project merge acceptance flow.
- No automatic project rename/archive.
- No auto-created ProjectLink.
- No insight without source refs.
- No fake progress score.
- No schema-driven dynamic UI.

## UX

Project Detail adds:

- A compact action row: “生成项目洞察”.
- Loading state: “正在根据历史证据生成洞察”.
- If insufficient: show reason as muted evidence note.
- Pending insights section:
  - title, type, summary, source count
  - accept / inaccurate / dismiss controls
- Accepted insights section:
  - progress/blocker/thinking-change/open-question cards
  - thinking-change shows before/after pair when available
  - each source ref remains traceable through existing evidence timeline.

## Data / Architecture

- Uses existing `ProjectInsightRepository`.
- Add `projectInsightRepository` and published state to `AppStore`.
- `ProjectAIService` gets a separate `generateProjectInsights(context:)`.
- No new migration.
- UI does not call GLM or repositories directly.

## Acceptance Tests

- Generating insights with enough confirmed project evidence saves candidates and exposes them in AppStore state.
- Insufficient evidence result saves no insight and exposes a readable message.
- Accepting an insight updates feedback to accepted and keeps it visible.
- Marking inaccurate or dismissed removes it from accepted narrative.
- Service request includes project id, project fields, source evidence refs, and typed context payload.
