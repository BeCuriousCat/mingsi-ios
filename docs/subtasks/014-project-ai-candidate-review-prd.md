# Subtask 014: Project AI Candidate Review

## Goal

把 Project 从“用户手动从任务/原则创建长期议题”推进到 MVP 的 AI 候选确认闭环：

```text
confirmed daily evidence
-> typed Project context
-> suggestProjectLinks Prompt
-> strict parser
-> pending ProjectCandidate / ProjectLinkCandidate review
-> user accept / dismiss
-> confirmed Project + ProjectLink evidence
```

这个切片的目标不是做漂亮项目管理工具，而是证明“项目”是由用户确认的长期议题，且每个项目候选和关联都能回到 History 证据。

## Product Rules

- AI 只能提出项目候选或关联候选，不能自动创建正式 Project。
- 每个候选必须包含 source evidence；没有 source id 的候选必须被 parser 或 service 丢弃。
- 一个 DailyEntry 最多建议 0-2 条 project link candidates 和 0-1 条 new project candidate。
- Project 不是关键词聚类；候选理由必须说明它为什么是长期目标、阻塞、决策模式或行动标准。
- 用户接受后才创建 Project 或 ProjectLink。
- 用户拒绝/忽略的候选必须持久记录为 dismissed/rejected，不能在同一轮重复出现。
- 不要保存公司敏感名称作为项目名；候选进入 UI 时必须可编辑或至少在接受前保留抽象命名。

## In Scope

1. Prompt ID and prompt template
   - Add a new `PromptID` for project suggestion, e.g. `suggestProjectLinks`.
   - Add `LocalPromptProvider` template based on `docs/prompt-spec.md` Prompt 7.
   - Keep output JSON only and use current `TodayAIResponseParser.parseProjectSuggestions(from:)`.

2. Service/use case boundary
   - Add `ProjectAIService` or equivalent service boundary.
   - Use `PromptProvider` and `LLMClient`; no SwiftUI view may call GLM directly.
   - Create typed context object for current confirmed cards, quests, principles, active projects, and existing project links.
   - Send both typed `PromptContextPayload.project` (or a dedicated typed section) and legacy `jsonPayload` compatibility keys.
   - Do not inject Project context into Growth or Today prompts except this project suggestion prompt.

3. Persistence and AppStore integration
   - Add `projectCandidateRepository` to `AppStore.live()` and init.
   - Add published review state, e.g. `projectLinkCandidates`, `projectCandidates`, `pendingProjectCandidateCount`, `projectSuggestionMessage`, `isGeneratingProjectSuggestions`.
   - Add intent methods:
     - `suggestProjectsForToday()` or equivalent.
     - `acceptProjectCandidate(_:)`
     - `dismissProjectCandidate(_:)`
     - `acceptProjectLinkCandidate(_:)`
     - `dismissProjectLinkCandidate(_:)`
   - Accepting a new ProjectCandidate creates a Project + ProjectLink with confirmed source evidence, updates candidate status, and refreshes Projects/History.
   - Accepting a link candidate creates a confirmed ProjectLink to an existing Project.

4. Minimal UI
   - In Projects tab, add a compact candidate review entry/card when pending candidates exist.
   - In Today after confirmed cards or after quest save, expose a restrained “建议长期议题” action if there is enough confirmed evidence.
   - Candidate UI must show:
     - candidate name
     - reason
     - source type / source id short form or source title if available
     - confidence
     - accept / dismiss controls
   - Keep style consistent with current warm paper / graphite design. No purple gradient, no fake dashboard.

5. Tests
   - Service/context test proving ProjectAIService sends typed project context and source ids.
   - AppStore tests:
     - AI project suggestions persist pending candidates with source refs.
     - accepting a ProjectCandidate creates Project and confirmed ProjectLink.
     - dismissing candidate updates status and does not create Project.
     - accepting a ProjectLinkCandidate to an existing Project creates confirmed ProjectLink.
   - Existing parser tests should remain green.

## Out of Scope

- Project insights generation.
- Project merge candidate UI.
- Rename/archive full project editing UI.
- Search/filter in History.
- Large visual redesign of Projects tab.
- Server PromptProvider.

## Suggested Files

Likely touched:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/ProjectAIService.swift` (new)
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/TodayAIServiceContextTests.swift` or new Project service tests
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/prompt-spec.md`
- `docs/prompt-context-engineering-prd.md`
- `docs/implementation-gap-audit.md`

Avoid touching:

- Growth UI/service unless compile errors require import/type compatibility.
- Persistence migrations unless an existing repository truly cannot represent the review state.
- Today streaming card assembler.

## Acceptance Criteria

- Project suggestions use protocol/service boundaries and Prompt tracing can record the new prompt.
- No Project is created until the user accepts a candidate.
- Accepted candidates and links always preserve source ids and can appear in History/Project evidence.
- Invalid candidates with no source evidence are rejected before persistence.
- Project UI no longer depends only on manual project creation; there is a visible pending candidate review path.
- Full test suite passes:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```
