# MingSi Verification Log

This file records verification evidence for MVP slices. Each entry should include date, scope, commands, result, and residual risk.

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
