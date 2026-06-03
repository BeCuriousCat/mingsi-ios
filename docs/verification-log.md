# MingSi Verification Log

This file records verification evidence for MVP slices. Each entry should include date, scope, commands, result, and residual risk.

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
