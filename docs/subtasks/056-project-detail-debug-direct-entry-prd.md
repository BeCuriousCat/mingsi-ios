# Subtask 056 PRD: Project Detail Debug Direct Entry

Date: 2026-06-06

## Purpose

Subtask 049 still needs real iPhone 17 Project Detail screenshots from the Subtask 048 matrix. Subtasks 050/054/055 made the Debug-only visual QA fixture project visible on the Projects top screen, but coordinate navigation into Project Detail remains unreliable in the simulator host.

Add a narrow Debug-only direct-entry path so the existing visual QA fixture can launch straight into the fixture Project Detail screen. This is a visual QA utility, not a production product feature.

## User / Manager Need

Codex must be able to launch the iPhone 17 simulator, activate the existing `.visual_qa_project_detail` fixture marker, and capture Project Detail screenshots without manual taps or macOS System Events coordinate clicks.

## Scope

Allowed source/test files:

- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- this progress file: `docs/subtasks/056-project-detail-debug-direct-entry-progress.md`

Allowed doc/log files:

- `docs/subtasks/056-project-detail-debug-direct-entry-progress.md`
- `docs/subtasks/logs/056-project-detail-debug-direct-entry-events.jsonl`

Do not edit screenshots, 049 findings, persistence, migrations, PromptProvider, parser, LLM clients, Keychain, project files, or unrelated docs.

## Requirements

1. The existing Debug-only visual QA fixture must expose one direct-entry target project id.
2. Normal stores and normal launches must not auto-open Project Detail.
3. Release builds must not reference Debug-only direct-entry APIs or fixture-only symbols.
4. Projects top-level behavior must remain unchanged when no fixture direct-entry target exists.
5. The direct-entry path must preserve the existing evidence-backed fixture data: `Project`, `ProjectLink`, `HistoryRecord`, accepted `ProjectInsight`, and pending `ProjectInsight`.
6. The implementation must not create fake production data or write fixture data into persistence.
7. SwiftUI views must not import GRDB or call `LLMClient`.

## Suggested Implementation Shape

This is guidance, not a mandate:

- Add a Debug-only optional property on `AppStore`, for example `visualQAProjectDetailDirectEntryProjectID`.
- Set that property in `AppStore.visualQAProjectDetail()` to the fixture project id.
- In `ProjectsView`, use a local `NavigationStack(path:)` or equivalent local navigation state.
- When the Debug-only direct-entry id exists and the matching `ProjectEvidenceBoardItem` is present, push that id once into the navigation path.
- Use `NavigationLink(value:)` / `navigationDestination(for:)` or an equivalent pattern that keeps normal manual navigation intact.

## Acceptance Criteria

- Focused AppStore tests prove:
  - fixture store has a non-nil direct-entry project id
  - the id exists in `projectsById`
  - normal store has no direct-entry id
  - applying the fixture to a normal store preserves the direct-entry id
- Existing visual QA fixture tests still pass.
- `git diff --check` passes.
- iPhone 17 Debug build passes in the manager checkout after Codex acceptance.
- iPhone 17 Release build passes in the manager checkout after Codex acceptance, proving Debug-only fixture code does not leak into Release.
- Codex can capture at least one real Project Detail screenshot after launching with the marker file.

## Non-Goals

- Do not implement the full 10-state screenshot fixture matrix in this slice.
- Do not change Project semantics, ProjectInsight generation, merge behavior, or evidence digest computation.
- Do not implement Project Detail visual polish from Subtask 048 follow-ups.
- Do not add deep link routing as a production feature.
- Do not add persistence, migrations, prompt/context changes, parser changes, LLM changes, or Keychain changes.

## Delegation Rationale

This is a bounded local UI/state fixture slice with named source/test files and clear acceptance tests. Claude Code can implement it in an isolated worktree while Codex stays responsible for architecture, final simulator screenshots, and visual acceptance.
