# Subtask 067 PRD: Production History Persistence Proof

Date: 2026-06-07

## Goal

Prove the production Today completion path persists the completed daily loop into SQLite and that a fresh `AppStore` can reload the same evidence into History through repository abstractions.

This closes the main residual risk from Subtask 066: the rendered History screenshot was powered by a Debug-only in-memory visual QA seed, not by production persistence.

## Scope

Allowed files:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/067-production-history-persistence-proof-prd.md`
- `docs/subtasks/067-production-history-persistence-proof-progress.md`
- Process docs after acceptance

Production source edits are allowed only if the RED test proves a real persistence bug and the fix stays scoped to:

- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`

Do not modify:

- Persistence migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- SwiftUI views
- Project or Growth product semantics
- Debug visual QA launch behavior

## Acceptance Criteria

- A production-path test drives Today through the normal state machine:
  - VerifyYesterday
  - Capture
  - Organizing
  - ReviewCards
  - SelectLens
  - AnswerQuestions
  - ReviewQuests
  - ExtractPrinciple
  - SessionComplete
- The test uses SQLite repositories backed by `AppDatabase(dbQueue: DatabaseQueue())`, not Debug in-memory fixture state.
- A fresh `AppStore` created with the same repositories can call `loadHistoryRecords()` and reload:
  - raw input
  - `sessionComplete` loop state
  - 3 confirmed cards
  - first-principles lens session
  - at least one answered lens question
  - main quest
  - principle
  - source id containing the completed `DailyEntry` id
- Rapid local persistence writes from the Today flow are ordered so older snapshots cannot overwrite newer confirmed evidence.
- Focused test passes.
- Full `AppStoreStateMachineTests` pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes.

## Non-Goals

- Do not claim live GLM success.
- Do not capture new simulator screenshots for this slice.
- Do not change production schema or migrations.
- Do not make Project/Growth evidence-chain claims beyond the persisted Today -> History proof.

## Delegation Decision

Claude Code is not delegated.

Reason:

- The user requested fast local implementation for the current window.
- The slice is a narrow proof test over existing repository boundaries.
- Codex already had the RED/diagnostic evidence and owns final production-path acceptance.
