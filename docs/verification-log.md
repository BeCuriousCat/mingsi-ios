# MingSi Verification Log

This file records verification evidence for MVP slices. Each entry should include date, scope, commands, result, and residual risk.

## 2026-06-04: Manual Principle Creation And Delegation Dogfood

Scope:

- Add direct manual Principle creation from Growth.
- Dogfood the reusable Codex-to-Claude Code delegation framework on a real MingSi business slice.
- Preserve long-lived active principles separately from Today's resettable principle candidates.
- Add dynamic delegation wait backoff to the wrapper and generic skill prototype.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `scripts/claude_delegate.sh`
- `delegation-framework/claude-code-managed-delegation/SKILL.md`
- `delegation-framework/claude-code-managed-delegation/references/conclusion-first-monitoring.md`
- `docs/subtasks/034-manual-principle-creation-*`
- `docs/subtasks/logs/034-manual-principle-creation-*`

Commands run:

```bash
scripts/claude_delegate.sh prepare 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00 scripts/claude_delegate.sh launch 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-claude-prompt.md docs/subtasks/034-manual-principle-creation-progress.md
scripts/claude_delegate.sh status 034-manual-principle-creation docs/subtasks/034-manual-principle-creation-progress.md
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testAddManualPrinciple_persistsActivePrincipleAndLinksToToday -only-testing:MingSiTests/AppStoreStateMachineTests/testAddManualPrinciple_rejectsMissingRequiredText -only-testing:MingSiTests/AppStoreStateMachineTests/testResetTodayLoop_keepsActiveManualPrinciplesVisibleInGrowthState test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl launch booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/034-manual-principle-creation/02-launch-after-wait.png
```

Result:

- Claude Code reached `HANDOFF/DONE`.
- Codex accepted the worker direction but fixed the long-lived principle source after the worker flagged it as a concern.
- Focused manual principle tests passed: 3 tests, 0 failures.
- Full `AppStoreStateMachineTests` passed: 98 tests, 0 failures.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- App installed/launched on the booted iPhone 17 simulator and a nonblank launch screenshot was captured:
  - `docs/subtasks/screenshots/034-manual-principle-creation/02-launch-after-wait.png`

Residual risk:

- Growth manual principle sheet has build/test coverage and app launch verification, but still needs a direct Growth-tab interaction screenshot in a later visual QA pass.
- Flow logs for this dogfood run are stored as evidence and should not be routinely consumed.

## 2026-06-04: Claude Conclusion-First Delegation Pipeline And Settings Audit Visual Check

Scope:

- Reconcile the user's Claude Code utilization concern with a two-layer delegation log model.
- Verify that Claude Code can run from an isolated worker worktree, write worker progress, and reach `HANDOFF`.
- Ensure flow logs are retained but not routinely consumed by the manager.
- Raise the default print-mode Claude budget guard so ordinary GLM coding tasks are not starved before `HANDOFF`.
- Build the app after Settings audit flicker and safe-area/floating-tab source changes.
- Capture Settings audit expand/collapse evidence and Settings bottom scroll evidence.

Changed areas:

- `.gitignore`
- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `docs/subtasks/032-claude-code-worker-fallback-smoke-*`
- `docs/subtasks/033-claude-code-conclusion-log-smoke-*`
- `docs/subtasks/logs/032-*`
- `docs/subtasks/logs/033-*`
- `docs/subtasks/claude-code-current-status.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/project-continuation-context.md`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/05-today-light-after-build.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/06-settings-light-after-build.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/07-settings-light-scrolled.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light-frame-*.png`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/09-settings-audit-collapsed-after-toggle-light.png`

Commands run:

```bash
bash -n scripts/claude_delegate.sh
bash -n scripts/claude_event_bridge.sh
CLAUDE_DELEGATE_MAX_BUDGET_USD=1.00 scripts/claude_delegate.sh launch 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-claude-prompt.md docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md
scripts/claude_delegate.sh wait 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md 0 1
scripts/claude_delegate.sh status 032-claude-code-worker-fallback-smoke docs/subtasks/032-claude-code-worker-fallback-smoke-progress.md
CLAUDE_DELEGATE_MAX_BUDGET_USD=1.00 scripts/claude_delegate.sh launch 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-claude-prompt.md docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md
scripts/claude_delegate.sh wait 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md 0 1
scripts/claude_delegate.sh status 033-claude-code-conclusion-log-smoke docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md
ls -l docs/subtasks/logs/033-claude-code-conclusion-log-smoke-events.jsonl docs/subtasks/logs/033-claude-code-conclusion-log-smoke-claude-run.jsonl
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl launch booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/05-today-light-after-build.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/06-settings-light-after-build.png
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/07-settings-light-scrolled.png
xcrun simctl io booted recordVideo --codec h264 docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov
ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov
ffmpeg -y -i docs/subtasks/screenshots/029-safe-area-floating-tab/08-settings-audit-toggle-light.mov ...
```

Result:

- `bash -n` passed for both delegation scripts.
- Subtask 032 reached worker-progress `HANDOFF` with final token `DONE`; Codex accepted it with follow-up because it exposed raw-stream and script-sync gaps.
- Subtask 033 reached worker-progress `HANDOFF` with final token `DONE`; Codex accepted it.
- Default print fallback now keeps raw model JSONL in the raw flow log instead of streaming it to the manager terminal.
- `status` / `wait` consume worker progress as the conclusion source and show retained flow-log paths without tailing event/raw logs by default.
- The wrapper syncs `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` into worker worktrees.
- Flow logs for 033 were retained on disk: raw log 247799 bytes, event log 75787 bytes.
- Default `CLAUDE_DELEGATE_MAX_BUDGET_USD` was raised from `0.50` to `30.00`; large delegated tasks should explicitly use `60.00` or higher.
- `git diff --check` passed.
- iPhone 17 simulator build passed.
- Settings bottom scroll screenshot shows bottom content can rest above the floating Tab bar.
- Settings audit expanded screenshot frames show stable expanded content with no visible overlapping row residue; the source fix removes group-level animation/transition and disables implicit transaction animation for the audit group.

Residual risk:

- Settings audit collapse was exercised, but the short video's second click did not capture a collapsed frame reliably; a separate collapsed screenshot was captured afterward.
- Full Subtask 029 visual acceptance is still incomplete: Today/History/Growth/Settings must still be recaptured in both light and dark modes after final scroll positions.
- The newly reported manual Principle creation feature is not implemented in this slice and should be handled as a separate atomic product task.

## 2026-06-04: Claude Delegation Pipeline Hardening And Settings Audit Flicker Fix

Scope:

- Set the active Codex pursuit goal in repo-owned documentation.
- Harden Claude Code delegation pipeline after Subtask 029 non-delivery and unreliable GLM usage telemetry.
- Fix Settings AI audit success/failure group expand-collapse flicker.
- Continue Subtask 029 safe-area/floating-tab work with build and partial simulator screenshot verification.

Changed areas:

- `scripts/claude_delegate.sh`
- `scripts/claude_event_bridge.sh`
- `.claude/delegation/030-claude-code-pipeline-hardening-settings.json`
- `docs/subtasks/030-claude-code-pipeline-hardening-prd.md`
- `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
- `docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl`
- `docs/mvp-current-goal.md`
- `docs/project-continuation-context.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `Sources/DesignSystem/Theme.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`
- `docs/subtasks/screenshots/029-safe-area-floating-tab/04-settings-audit-after-toggle-light.png`

Commands run:

```bash
git status --short
claude --help
claude agents --help
scripts/claude_delegate.sh --help
scripts/claude_delegate.sh prepare 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md
scripts/claude_delegate.sh status 030-claude-code-pipeline-hardening docs/subtasks/030-claude-code-pipeline-hardening-progress.md
scripts/claude_delegate.sh wait 029-safe-area-floating-tab docs/subtasks/029-safe-area-floating-tab-progress.md 0 1
scripts/claude_delegate.sh wait 027-history-repair-ui docs/subtasks/027-history-repair-ui-progress.md 0 1
printf '{"probe":"bridge"}' | scripts/claude_event_bridge.sh docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl manual_probe
bash -n scripts/claude_delegate.sh
bash -n scripts/claude_event_bridge.sh
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
xcrun simctl io booted screenshot docs/subtasks/screenshots/029-safe-area-floating-tab/04-settings-audit-after-toggle-light.png
```

Result:

- `claude --help` confirmed `--worktree`, `--tmux`, `--agent`, `--settings`, `--allowedTools`, `--permission-mode`, and `--effort` are available.
- `claude agents --help` confirmed JSON status support through `claude agents --json`.
- `scripts/claude_delegate.sh --help` passed.
- `prepare` passed and generated task-local hook settings without changing global Claude settings.
- `status` passed and showed one idle interactive Claude agent; no Subtask 030 implementation worker was launched.
- `wait` correctly rejected Subtask 029 `HANDOFF: pending` with exit 75.
- `wait` correctly accepted Subtask 027 real handoff with exit 0 by reading `.claude/worktrees/subtask-027-history-repair-ui/docs/subtasks/027-history-repair-ui-progress.md`.
- Wrapper now creates/reuses the worker worktree on launch and syncs matching `docs/subtasks/<id-topic>*` files so untracked PRD/prompt/progress docs are available to the worker.
- `status` now prints active, manager, and worker progress paths so Codex can see which truth source is being monitored.
- `bash -n` passed for both wrapper scripts.
- Event bridge manual probe appended JSONL evidence with base64 payload.
- Initial pipeline verification exposed a macOS `date -Is` incompatibility; wrapper and bridge were fixed to use portable timestamps.
- Settings AI audit flicker root cause was removed by deleting the group-wide SwiftUI animation and row transition while keeping chevron-only animation.
- App build passed after source changes.
- `git diff --check` passed after final source/script/documentation updates.
- Screenshot `04-settings-audit-after-toggle-light.png` captured the Settings audit group expanded stable state.

Residual risk:

- Settings flicker was verified by code-level root cause removal and stable screenshots, but not yet by recorded video of the transient animation.
- Subtask 029 safe-area/floating-tab visual acceptance is incomplete; Settings audit content still appears close to the floating Tab bar boundary in partial screenshots.
- No new Claude Code worker was launched through the wrapper yet, so actual worker utilization improvement is ready to test but not proven on an implementation slice.

## 2026-06-03: Context Preservation And Subtask 029 Delegation Audit

Scope:

- Preserve current thread/project context into repository-owned docs.
- Record Subtask 029 Claude Code launch attempts and non-delivery status.
- Ensure no active Claude worker remains running.
- Do not accept any Subtask 029 implementation because no worker `HANDOFF` occurred.

Changed areas:

- `docs/project-continuation-context.md`
- `docs/subtasks/029-safe-area-floating-tab-prd.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/subtasks/029-safe-area-floating-tab-claude-prompt.md`
- `docs/subtasks/claude-code-current-status.md`
- `docs/subtasks/logs/README.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`

Commands run:

```bash
git status --short
git worktree add -b worker-subtask-029-safe-area-floating-tab .claude/worktrees/subtask-029-safe-area-floating-tab HEAD
claude -p --output-format stream-json --verbose --include-hook-events --permission-mode dontAsk --model glm-5.1 ...
ps -axo pid,etime,command | rg 'subtask-029-safe-area-floating-tab|029-claude-run-focused|claude -p'
kill 13981
kill 18237
```

Result:

- Subtask 029 delegation package was created.
- First Claude launch failed before `START` due CLI prompt parsing.
- Second Claude launch was stopped after no `START`.
- Focused Claude launch reached `START` but did not reach `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF`.
- No Subtask 029 source implementation was accepted.
- Current status file records no active Claude worker.

Residual risk:

- Subtask 029 remains unimplemented.
- No build or simulator verification was run for Subtask 029 because there is no accepted implementation yet.
- Further Claude Code implementation attempts should use a stronger wrapper or a different launch mode.

## 2026-06-03: AI Language, Busy State, Recoverable GLM Retry, And History Repair Helpers

Scope:

- Enforce Chinese-first prompt language behavior while preserving input-language following.
- Add bounded retry for recoverable GLM 429/529/5xx responses in normal and SSE streaming calls.
- Expose AppStore AI busy state and disable duplicate Today/background retry actions while a request is running.
- Bring Subtask 027 local History repair helper tests to green so the worktree is testable again.

Changed areas:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/DirectGLMClient.swift`
- `Sources/App/AppStore.swift`
- `Sources/App/AppRootView.swift`
- `Sources/Features/Today/TodayView.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Services/LocalPromptProviderTests.swift`
- `Tests/Services/DirectGLMClientTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests/testEveryPromptTemplate_hasCommonThinkingCoachGuardrails -only-testing:MingSiTests/DirectGLMClientTests/testComplete_retriesRecoverableRateLimitStatus -only-testing:MingSiTests/DirectGLMClientTests/testStream_retriesRecoverableRateLimitStatusBeforeYieldingTokens -only-testing:MingSiTests/AppStoreStateMachineTests/testAIGenerationBusyStateBlocksDuplicateRetryRequests -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairCardPreview_decodesValidCandidatePayload -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairCardPreview_invalidPayloadReturnsEmpty -only-testing:MingSiTests/HistoryFeatureTests/testHistoricalRetryCandidateStatus_historyRepairTitleCoversReviewStates -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRepairPromptSupport_onlyOrganizeCardsCanStartHistoricalRetry test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/DirectGLMClientTests -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Targeted tests passed: 8 tests, 0 failures.
- DirectGLMClientTests + LocalPromptProviderTests + HistoryFeatureTests passed: 41 tests, 0 failures.
- AppStoreStateMachineTests passed: 95 tests, 0 failures.
- App build succeeded.
- `git diff --check` passed.

Residual risk:

- Simulator/manual visual QA was not run in this slice.
- Detailed per-run background repair progress/result presentation remains a follow-up.

## 2026-06-03: Historical AI Retry AppStore Guard

Scope:

- Add AppStore/use-case orchestration for historical `organizeCards` retry.
- Keep retry output as a reviewable `HistoricalRetryCandidate` payload.
- Ensure historical retry does not mutate current-day cards.
- Reject unsupported historical prompt types.
- Block candidate acceptance when confirmed cards already exist.

Changed areas:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testStartHistoricalOrganizeCardsRetry_createsCandidateWithoutChangingCurrentCards test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testStartHistoricalOrganizeCardsRetry_rejectsUnsupportedPrompt -only-testing:MingSiTests/AppStoreStateMachineTests/testAcceptHistoricalRetryCandidate_blocksWhenConfirmedCardsExist test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Historical retry success test passed: 1 test, 0 failures.
- Unsupported prompt and confirmed-card guard tests passed: 2 tests, 0 failures.
- AppStoreStateMachineTests passed: 94 tests, 0 failures.
- PersistenceCoreTests passed on rerun: 55 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Notes:

- The first PersistenceCoreTests attempt failed before tests loaded due to a simulator test bundle loading error; rerunning the same command succeeded with 55 tests and 0 failures.
- `repairPromptRunId` is attached only when a real PromptRun can be discovered from prompt tracing. Tests do not require a fake repair PromptRun id.

Residual risk:

- No History UI entry point or candidate sheet exists yet for this AppStore action.
- Acceptance guards currently cover confirmed cards only; PRD still requires future checks for lens sessions, questions, quests, principles, project links, project insights, and growth contributions sourced from the entry.

## 2026-06-03: HistoricalRetryCandidate Migration And Repository

Scope:

- Add `HistoricalRetryCandidate` domain status/model.
- Add v8 SQLite migration for `historical_retry_candidates`.
- Add `HistoricalRetryCandidateRepository` and `SQLiteHistoricalRetryCandidateRepository`.
- Add persistence tests for create/query, attach repair run, status update, soft delete, PromptRun preservation, and migration indexes.

Changed areas:

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests/testHistoricalRetryCandidate_createAttachAndQueryByEntry test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PersistenceCoreTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- RED confirmed before implementation: build failed because `SQLiteHistoricalRetryCandidateRepository` and `HistoricalRetryCandidate` did not exist.
- First target GREEN passed: 1 test, 0 failures.
- Full PersistenceCoreTests passed: 55 tests, 0 failures.
- AppStoreStateMachineTests passed: 91 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This only establishes durable candidate storage.
- Historical retry still needs AppStore/use-case orchestration, acceptance guards against downstream evidence, GLM retry execution, and History candidate review UI.
- Two parallel single-test xcodebuild runs hit simulator bootstrapping early-exit; the same coverage passed in the serial full PersistenceCoreTests run.

## 2026-06-03: Historical AI Retry Candidate Review PRD

Scope:

- Convert the Subtask 025 audit into a product and architecture decision for historical AI retry.
- Specify candidate review semantics, first-prompt scope, data model, migration requirement, guards, UI states, and delegatable follow-up slices.
- Align `docs/data-architecture.md` with the new `HistoricalRetryCandidate` entity.

Changed areas:

- `docs/subtasks/026-historical-ai-retry-candidate-review-prd.md`
- `docs/data-architecture.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
git status --short
git diff --check
```

Result:

- `git diff --check` passed.

Residual risk:

- This is a PRD/architecture alignment slice, not an implementation.
- The next code slice still needs migration, repository, AppStore guard, and History UI tests.

## 2026-06-03: Historical AI Retry Read-Only Audit

Scope:

- Delegate a read-only audit of current historical AI retry capability.
- Identify existing retry infrastructure, blockers, and the safest next slice without changing Swift source or tests.
- Record Codex acceptance and rejection of Claude Code findings.

Changed areas:

- `docs/subtasks/025-historical-ai-retry-audit-prd.md`
- `docs/subtasks/025-historical-ai-retry-audit-progress.md`
- `docs/subtasks/025-historical-ai-retry-audit-claude-prompt.md`
- `docs/subtasks/025-historical-ai-retry-audit-findings.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`

Commands run:

```bash
git diff --check -- docs/subtasks/025-historical-ai-retry-audit-progress.md docs/subtasks/025-historical-ai-retry-audit-findings.md
```

Result:

- Whitespace check passed for the delegated audit outputs.
- Claude Code reached `HANDOFF` with status `DONE`.
- Codex accepted the implementation map and rejected the direct implementation recommendation because it contradicted migration requirements and touched product-sensitive retry semantics.

Residual risk:

- This was a code/document audit, not a runtime feature implementation.
- Historical retry still needs a Codex-owned PRD/architecture pass before any implementation delegation.

## 2026-06-03: Settings AI Audit Grouping

Scope:

- Make Settings AI audit usable when many PromptRun records exist.
- Group recent calls into failed and successful sections without changing PromptRun persistence or LLM behavior.
- Keep History advanced-filter stability covered because the newest user report mentioned dropdown bounce/clipping.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/024-settings-ai-audit-grouping-progress.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' clean test -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:MingSiTests/AppStoreStateMachineTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:MingSiTests/HistoryFeatureTests
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- RED confirmed: clean test failed before implementation because `PromptRunAuditSummary` was missing.
- AppStoreStateMachineTests passed: 91 tests, 0 failures.
- HistoryFeatureTests passed: 24 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- Settings grouping is code/test verified, not screenshot verified. Manual simulator visual QA should confirm the collapsed success section and expanded failure section with a long audit list.
- History advanced-filter bounce/clipping is covered by fixed chip metrics and disabled implicit animations, but real Menu popover geometry should still be checked manually in the simulator with long option labels.

## 2026-06-03: History Advanced Filter Visual Stability

Scope:

- Fix History advanced filter dropdown selection bounce and partial top clipping.
- Keep change local to History filter UI metrics and animation behavior.

Changed areas:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Commands run:

```bash
## 2026-06-03: Subtask 027 History Repair UI Acceptance

Scope:

- Accept Claude Code worker handoff for fixed-contract History repair UI.
- Add Codex manager fix so historical repair warnings cover confirmed cards and downstream evidence, not only confirmed cards.
- Verify the accepted implementation from the manager worktree.

Changed areas:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Domain/Models.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/027-history-repair-ui-progress.md`
- `docs/mvp-stage-progress.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

Commands run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests/testHistoryRecordRepairBlockingEvidence_includesConfirmedCardsAndDownstreamEvidence test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- New RED/GREEN downstream-evidence guard test passed: 1 test, 0 failures.
- HistoryFeatureTests passed: 29 tests, 0 failures.
- AppStoreStateMachineTests passed: 95 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This was code/test verified. Manual simulator QA should still inspect History repair presentation, dark mode contrast, and long failed/candidate lists.

xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests/testHistoryFilterChipMetrics_keepAdvancedFilterWidthStable test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Result:

- Stable chip metric test passed: 1 test, 0 failures.
- HistoryFeatureTests passed: 24 tests, 0 failures.
- App build succeeded.
- Whitespace check passed.

Residual risk:

- This was build/test verified. Manual visual smoke on simulator should still confirm the dropdown presentation under real interaction, especially with long project names and with the global AI repair banner visible.

## 2026-06-03: Process Document Alignment

Scope:

- Add missing process documents required by the active project operating model.
- Re-align current MVP stop condition, stage progress, architecture decisions, and verification trace.

Changed areas:

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`
- `docs/agent-delegation-log.md`

Commands run:

```bash
git status --short
git diff --check
```

Result:

- Required process files now exist.
- `git diff --check` passed.

Residual risk:

- Process docs summarize current repo evidence but do not replace full runtime visual QA.

## 2026-06-03: Claude Code Visual Smoke Audit

Scope:

- Delegate a read-only visual and interaction smoke audit across Today, History, Projects, Growth, and Settings.
- Identify top user-facing visual/interaction hardening work without modifying source code.

Changed areas:

- `docs/subtasks/023-visual-smoke-audit-prd.md`
- `docs/subtasks/023-visual-smoke-audit-progress.md`
- `docs/subtasks/023-visual-smoke-audit-claude-prompt.md`
- `docs/subtasks/023-visual-smoke-audit-findings.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

Commands run:

```bash
claude -p --output-format stream-json --verbose --permission-mode dontAsk --model glm-4.6 --allowedTools Read,LS,Grep,Glob,Bash -- "Read docs/subtasks/023-visual-smoke-audit-claude-prompt.md ..."
```

Result:

- Claude Code completed with final token `DONE_WITH_CONCERNS`.
- Audit was code-informed only; no simulator visual launch was performed.
- Codex accepted Settings AI audit list scalability as the top actionable next slice.

Residual risk:

- Findings are not visually confirmed. Real simulator smoke QA is still required before claiming MVP visual readiness.
