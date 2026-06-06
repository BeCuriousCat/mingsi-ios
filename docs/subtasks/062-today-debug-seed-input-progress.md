# Subtask 062 Progress: Today Debug Seed Input

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not delegated

PRD: `docs/subtasks/062-today-debug-seed-input-prd.md`
Claude prompt: none
Event log: none
Raw log: none

## Manager Setup

- Timestamp: 2026-06-06
- Source state: Subtask 061 committed in `a906843 Record today walkthrough testability gap`.
- Reason: the rendered Today walkthrough needs stable input seeding before Codex can verify input -> organize -> card review on iPhone 17.
- Worktree state at setup: clean.
- Implementation path: direct Codex TDD; no Claude Code worker.

## Implementation

- 在 `#if DEBUG` 边界内新增 Today seed 解析和应用：
  - `MINGSI_VISUAL_QA_TODAY_INPUT`
  - `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT`
  - `MINGSI_VISUAL_QA_TODAY_MODE`
  - `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE`
- 有非空输入时，Debug store 会进入 Today tab、`Capture` 状态，写入 `todayDraft.rawText`，标记模式已选择，并关闭本次启动的 persisted-state load。
- 未知 mode 在有输入时回落到 `standard`。
- 空输入不改变普通启动状态。
- Today seed 会像 root-tab selector 一样阻止 stale Project Detail marker 劫持启动。
- `MingSiApp` 的 Debug 初始化和 `.task` 加载前都会应用 Today seed；Release 构建不读取这些变量。

## Planned Verification

Commands:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/<focused tests> test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT=<text> SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/062-today-debug-seed-input/<state>.png
git diff --check
```

## Results

- RED verified:
  - 新增测试先失败，失败原因为 `AppStore` 缺少 `applyVisualQATodaySeed`。
- Focused GREEN:
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_appliesCaptureTextModeAndSkipsPersistedLoad -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_withoutInputDoesNotChangeNormalLaunchState -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_readsSimctlChildEnvironmentAndDefaultsUnknownMode -only-testing:MingSiTests/AppStoreStateMachineTests/testVisualQATodaySeedInput_preventsProjectDetailFixtureMarker test`
  - Result: 4 tests, 0 failures.
- Broader AppStore verification:
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
  - Result: 166 tests, 0 failures.
- Build verification:
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - Result: `BUILD SUCCEEDED`.
  - `xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build`
  - Result: `BUILD SUCCEEDED`.
- Diff hygiene:
  - `git diff --check`
  - Result: exit 0, no output.
- Real iPhone 17 simulator verification:
  - Installed Debug app on booted iPhone 17 simulator.
  - Launched with `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_INPUT`, `SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_MODE=standard`, and `SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=today`.
  - Confirmed seeded Today input renders in `今日输入`.
  - Clicked the main Today action and reached `整理中` with visible local fallback / repair banner because no API Key is configured.
  - Clicked `查看卡片` and reached `思考卡片` review.

## Screenshot Evidence

- `docs/subtasks/screenshots/062-today-debug-seed-input/01-seeded-capture.png`
  - Today opens directly in `今日输入`, mode is `Standard`, seeded raw input is visible.
- `docs/subtasks/screenshots/062-today-debug-seed-input/02-organizing-fallback.png`
  - Main action advances into `整理中`; AI failure is visible as missing API Key, local fallback is clearly marked, repair banner is shown.
- `docs/subtasks/screenshots/062-today-debug-seed-input/03-review-cards-fallback.png`
  - Rendered app reaches `思考卡片` review with local fallback cards and confirmation controls.

## Residual Risk

- This slice does not prove live GLM success in the rendered app because no API Key is configured in the simulator.
- This slice does not complete the full Today -> lens -> quest -> principle -> History/Projects/Growth closed-loop screenshot walkthrough.
- Coordinate-based button clicks remain less stable than a real UI Test target, but the highest-friction blocker from Subtask 061, repeatable raw-text entry, is removed by Debug seed launch.
