# Claude Code Delegation Prompt: Subtask 018 Project Insight Review

You are implementing a bounded coding task in the MingSi iOS project. Codex remains the architect and will review your diff and rerun tests. Follow the PRD exactly:

- `docs/subtasks/018-project-insight-review-prd.md`
- Update progress in `docs/subtasks/018-project-insight-review-progress.md`

## Rules

- Use TDD. Add failing tests before production code.
- Keep the slice narrow. Do not implement project merge acceptance, rename/archive, migrations, or schema-driven UI.
- Do not let SwiftUI call GLM or repositories directly.
- Use existing patterns in `AppStore`, `ProjectAIService`, repositories, and `FeatureTabs`.
- Do not add fake project insight data.
- Every `ProjectInsight` must be evidence-backed by `sourceRefs`.
- `thinking_change` insights require before/after text; parser/repository already enforces this, do not weaken it.

## Desired Behavior

1. `ProjectAIService`
   - Add a context type for project insights.
   - Add `generateProjectInsights(context:)`.
   - It should call prompt `.suggestProjectLinks` only if no better prompt id exists? Inspect `PromptID` and `LocalPromptProvider` first. If a project insights prompt already exists, use it. If not, add/choose the most appropriate existing project prompt boundary without creating unrelated prompt ids.
   - It must call `TodayAIResponseParser.parseProjectInsights(from:)`.
   - It must send typed `PromptContextPayload.project` or an equivalent structured payload plus legacy key/value payload.
   - It must include source/context record ids.

2. `AppStore`
   - Inject/store `ProjectInsightRepository`.
   - Publish pending/accepted insight state needed by UI.
   - Add a method to generate insights for a selected project from existing `historyRecords` + confirmed `ProjectLink` evidence.
   - Save generated insights using `ProjectInsightRepository`.
   - Load project insights for details.
   - Add feedback methods for accepted/inaccurate/dismissed.
   - Expose readable messages for loading, success, insufficient evidence, and failure.

3. UI
   - In `ProjectDetailView`, add a restrained “生成项目洞察” action and insight sections.
   - Show pending insights with Accept / Inaccurate / Dismiss controls.
   - Show accepted insights as project narrative.
   - If insufficient evidence, show the reason without pretending a conclusion exists.
   - Keep current Project evidence timeline intact.

4. Tests
   - Add service/context test proving project insight request includes project id, source evidence refs, and typed context.
   - Add AppStore tests for:
     - successful insight generation saves candidates
     - insufficient evidence saves none and shows message
     - feedback update changes visible insight state
   - Run targeted tests at minimum:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/ProjectAIServiceContextTests \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/TodayAIResponseParserTests \
  test
```

## Progress File

Update `docs/subtasks/018-project-insight-review-progress.md` at each checkpoint. Do not claim success without command output.
