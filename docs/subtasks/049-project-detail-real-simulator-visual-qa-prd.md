# Subtask 049 PRD: Project Detail Real Simulator Visual QA

Date: 2026-06-06

## Goal

Capture and review real iPhone 17 simulator screenshots for Project Detail using the Subtask 048 screenshot matrix, then decide whether a narrow display-only Project Detail polish slice is justified.

This subtask is verification-first. It must not claim a visual risk is confirmed until a real screenshot exists.

## Source

- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`

## Non-Delegation Rationale

This slice is not delegated to Claude Code by default because:

- final visual judgment belongs to Codex;
- simulator operation and screenshot review are acceptance work, not bounded implementation;
- if fixture data is needed, Codex must decide whether the data source is acceptable and clearly label it.

Claude Code may be used later only for a separate read-only screenshot inventory or a bounded implementation follow-up after Codex accepts concrete screenshot findings.

## Scope

Allowed write files:

- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/*`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/agent-delegation-log.md`

Allowed commands:

- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`
- `xcrun simctl boot`, `install`, `launch`, `io screenshot`, `ui appearance`
- read-only SQLite inspection of the simulator app container

Do not modify:

- Swift source files
- Swift tests
- persistence schema or migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- product semantics

## Screenshot Matrix

Minimum target before implementation follow-up:

1. Projects top-level light and dark, to confirm a Project Detail target exists.
2. At least one Project Detail populated state in light and dark.
3. One long-text or long-timeline stress state if real/fixture data exists.
4. One empty or sparse Project Detail state if reachable.

Full Subtask 048 matrix remains the ideal target:

- 10 states x light/dark = 20 screenshots.

## Data Source Rules

Preferred:

1. Existing simulator data created through normal app usage.
2. Data created through the real app UI during the QA session.
3. Explicit Visual QA fixture data inserted into the simulator database, only if labeled as fixture evidence.

Rules:

- Do not use fixture data to claim real-user behavior.
- Do not hide that fixture data was used.
- Do not change production code solely to improve screenshots.
- If a fixture harness is needed, open a separate implementation subtask and keep it Debug/UITest-only.

## Acceptance Evidence

Subtask 049 can be accepted only when:

- screenshot files exist under `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/`;
- findings identify which Subtask 048 risks are confirmed, not confirmed, or still untested;
- `git diff --check` passes;
- if source changes were made later, the iPhone 17 build passes again.

