# Subtask 013 Claude Progress: Growth AI Report

This file is the progress handshake for Claude Code delegation.

## Protocol

- Claude Code must update this file at task start.
- Claude Code must update this file after each checklist step.
- Claude Code must follow TDD for production behavior changes: write failing tests first, then implement.
- Codex uses this file for low-frequency progress checks instead of polling Claude output.
- If Claude Code is blocked, write the blocker here with the last completed step.

## Status

- State: done
- Started at: 2026-06-02
- Last update: 2026-06-02
- Owner: Claude Code

## Checklist

- [x] Read `docs/subtasks/013-growth-ai-report-prd.md`.
- [x] Inspect existing Growth models, repositories, parser tests, prompt specs, and AppStore Growth flow.
- [x] Add failing parser/service tests for valid report, insufficient evidence, and missing evidence source rejection.
- [x] Implement strict report-level Growth parser returning `MetricSnapshot` plus `MetricContribution` candidates.
- [x] Add `GrowthAIService` or equivalent service boundary using `PromptProvider` and `LLMClient`.
- [x] Add AppStore intent-style integration without direct UI/GLM calls.
- [x] Update prompt/context docs with exact report schema and context rules.
- [x] Run targeted tests.
- [x] Run full test suite.
- [x] Record changed files and verification result below.

## Changed Files

- `Sources/Services/TodayAIResponseParser.swift` — Added `GrowthReportResult`, `parseGrowthReport(from:period:completeLoopCount:)`, `GrowthReportResponseDTO`, `GrowthMetricsDTO`, `GrowthMetricValueDTO`
- `Sources/Services/GrowthAIService.swift` — New file: `GrowthAIService`, `GrowthReportContext`, `GrowthRecordSummary` types with `generateWeeklyReport`/`generateMonthlyReport`
- `Sources/Services/CoreProtocols.swift` — Hardened `weeklyCalibration` and `monthlyGrowth` prompt text with strict JSON schema, evidence rules, and insufficient evidence output
- `Sources/App/AppStore.swift` — Added `growthAIService` property, `generateWeeklyGrowthReport()`, `generateMonthlyGrowthReport()`, `buildGrowthReportContext()` methods
- `Tests/Services/TodayAIResponseParserTests.swift` — Added 6 growth report parser tests: valid report, insufficient evidence, missing source rejection, delta clamp, missing insufficient flag default, empty metrics baseline
- `docs/prompt-spec.md` — Updated Prompt 10 and 11 with full output schemas, context payload tables, and client validator descriptions
- `project.yml` — Regenerated via xcodegen (no manual edits)

## Verification

- 195 tests passed, 0 failures
- All 6 new Growth report parser tests pass
- All existing tests remain green
- Full suite: `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test`

## Notes

- No persistence migrations needed — existing `MetricSnapshot` and `MetricContribution` schemas fully support the report.
- No UI changes — GrowthAIService and AppStore methods are service-layer only.
- Growth context is not injected into organizeCards/generateQuestions/generateQuests.
- Parser rejects contributions without valid sourceType/sourceId/sourceDailyEntryId UUID.
- Insufficient evidence produces MetricSnapshot(status: .insufficientEvidence) with canDisplayScores=false.
- Generated MetricContribution records persist with sourceDailyEntryId.
- Local fallback snapshot remains available if AI fails (unchanged local generation path).
