# Subtask 014 Claude Progress: Project AI Candidate Review

This file is the progress handshake for Claude Code delegation.

## Protocol

- Claude Code must update this file at task start.
- Claude Code must update this file after each checklist step.
- Claude Code must follow TDD for production behavior changes: write failing tests first, then implement.
- Codex uses this file for low-frequency progress checks instead of polling Claude output.
- If Claude Code is blocked, write the blocker here with the last completed step.

## Status

- State: completed_after_codex_review
- Started at: 2026-06-02
- Last update: 2026-06-02 03:03 CST
- Owner: Claude Code implementation, Codex review/fixes/verification

## Checklist

- [x] Read `docs/subtasks/014-project-ai-candidate-review-prd.md`.
- [x] Inspect existing Project models, repositories, parser tests, AppStore project creation methods, and Projects UI.
- [x] Add failing service/context test for typed Project suggestion context and source ids.
- [x] Add failing AppStore tests for persist, accept, dismiss, and link acceptance flows.
- [x] Implement new Project suggestion PromptID/template and service boundary.
- [x] Wire AppStore repositories, published review state, and intent methods.
- [x] Add minimal candidate review UI without large redesign.
- [x] Update docs for current Project AI candidate status.
- [x] Run targeted tests.
- [x] Run full test suite.
- [x] Record changed files and verification result below.

## Changed Files

- `Sources/Services/ProjectAIService.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/prompt-spec.md`
- `docs/prompt-context-engineering-prd.md`
- `docs/implementation-gap-audit.md`

## Verification

Claude Code did not complete this progress file, so Codex treated the implementation as untrusted and verified independently.

Codex red/green checks:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testAcceptProjectCandidate_createsProjectAndConfirmedLink test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_restoresOnlyPendingProjectCandidates test
```

Targeted verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/ProjectAIServiceContextTests -only-testing:MingSiTests/AppStoreStateMachineTests -only-testing:MingSiTests/TodayAIResponseParserTests -only-testing:MingSiTests/TodayAIServiceContextTests test
```

Result:

- 123 tests, 0 failures.

Full verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Result:

- 203 tests, 0 failures.

## Notes

- Keep implementation scoped to Project candidate/link review.
- Do not auto-create Projects from AI output.
- Do not touch Growth implementation unless required for compile compatibility.
- Codex accepted the service boundary, prompt template, pending candidate review state, Today/Projects minimal UI, and parser reuse.
- Codex fixed two issues after review:
  - Accepted new Project candidates now preserve the real evidence source type instead of always writing `daily_entry`.
  - Pending Project candidates are restored from persistence during `loadPersistedState()` while dismissed candidates remain hidden from review UI.
