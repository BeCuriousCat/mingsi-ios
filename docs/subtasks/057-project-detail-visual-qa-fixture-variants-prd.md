# Subtask 057 PRD: Project Detail Visual QA Fixture Variants

Date: 2026-06-06

## Purpose

Subtask 049 still needs the Subtask 048 Project Detail screenshot matrix on a real iPhone 17 simulator. Subtasks 050/054/055/056 made a Debug-only fixture reliable and directly openable, but the current fixture covers only one normal populated Project Detail state.

Add a narrow Debug-only fixture variant selector so Codex can launch Project Detail into the remaining screenshot states without manual taps, coordinate clicks, persistence writes, or product-semantic changes.

This is a visual QA harness, not a production feature.

## User / Manager Need

Codex must be able to choose a stable Project Detail visual QA state before launching the app, capture light/dark screenshots, and then decide whether any display-only follow-up fixes are actually justified by real screenshots.

## Scope

Allowed source/test files:

- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- this progress file: `docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md`

Allowed only if strictly needed:

- `Sources/Features/FeatureTabs.swift`

Allowed doc/log files:

- `docs/subtasks/057-project-detail-visual-qa-fixture-variants-progress.md`
- `docs/subtasks/logs/057-project-detail-visual-qa-fixture-variants-events.jsonl`

Do not edit screenshots, 049 findings, persistence, migrations, repositories, PromptProvider, parser, LLM clients, Keychain, project files, or unrelated docs.

## Variant Contract

Keep the existing activation flag/marker behavior:

- `MINGSI_VISUAL_QA_PROJECT_DETAIL`
- `.visual_qa_project_detail`

Add a Debug-only selector for the fixture state. The exact implementation can use arguments, environment, UserDefaults, marker-file companion data, or a small helper API, but tests must prove it is stable and normal launches remain unaffected.

Preferred selector ids:

- `nil_project`
- `minimal`
- `normal`
- `accepted_insight`
- `pending_insight`
- `merge_history`
- `long_timeline`
- `long_name`
- `sparse_next_bet`
- `generating_insight`

The default variant should preserve today's behavior and remain suitable for the already accepted direct-entry screenshots. Prefer `normal` as the default.

## Requirements

1. The fixture variant selector must be Debug-only.
2. Normal stores and normal launches must not activate fixture variants.
3. Release builds must not reference Debug-only visual QA variant APIs or symbols.
4. Every variant must start on the Projects tab and expose `visualQAProjectDetailDirectEntryProjectID`.
5. Every variant must produce a `ProjectEvidenceBoardItem` reachable by the direct-entry id.
6. The `nil_project` variant must allow Project Detail to render with a board item but no persisted `Project` record for the direct-entry id.
7. The `minimal` variant must include populated goal/success criteria and 0-1 evidence links.
8. The `normal` variant must preserve the current populated fixture behavior closely enough for existing 056 expectations.
9. The `accepted_insight` variant must include accepted `ProjectInsight` records for the direct-entry project.
10. The `pending_insight` variant must include pending `ProjectInsight` records awaiting review for the direct-entry project.
11. The `merge_history` variant must include non-empty `mergeHistory`.
12. The `long_timeline` variant must include at least 10 confirmed project evidence links.
13. The `long_name` variant must use a long project name suitable for text-wrap screenshot verification.
14. The `sparse_next_bet` variant must keep overview fields sparse while still deriving a next-bet-style display state from fixture evidence.
15. The `generating_insight` variant must set `isGeneratingProjectInsights` so Project Detail shows the loading affordance.
16. Fixture data must remain in memory only and must not write to SQLite.
17. SwiftUI views must not import GRDB or call `LLMClient`.

## Suggested Implementation Shape

This is guidance, not a mandate:

- Add a Debug-only `VisualQAProjectDetailVariant` enum or equivalent local type in `AppStore.swift`.
- Add a Debug-only helper to resolve the variant from arguments/environment/defaults.
- Extend `AppStore.visualQAProjectDetail()` to accept a variant parameter with `.normal` as default.
- Let `applyVisualQAProjectDetailFixture()` apply the selected variant.
- Keep the existing marker-file activation path.
- If runtime launch selection needs an additional environment key, use a stable name such as `MINGSI_VISUAL_QA_PROJECT_DETAIL_VARIANT` and support the `SIMCTL_CHILD_` prefix.

## Acceptance Criteria

Focused AppStore tests must prove:

- the stable variant ids exist and resolve as expected;
- unknown or absent variant selection falls back to `normal`;
- all 10 variants start on Projects and expose a direct-entry project id;
- all 10 variants have a Project Detail board item reachable by the direct-entry id;
- `nil_project` has no persisted project for the direct-entry id;
- `minimal` has no more than 1 confirmed evidence link;
- `long_timeline` has at least 10 confirmed project links;
- `long_name` uses a long name;
- `generating_insight` sets `isGeneratingProjectInsights`;
- normal store behavior remains unaffected.

Required verification:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Codex will rerun verification in the manager checkout after `HANDOFF`, then use the variants to capture real iPhone 17 screenshots for Subtask 049.

## Non-Goals

- Do not implement Project Detail visual polish in this slice.
- Do not modify Project Detail layout, status-chip copy, summary surfaces, or timeline expansion in this slice.
- Do not implement screenshot automation in this slice.
- Do not add migrations, repositories, persistence writes, prompts, parser changes, LLM calls, or Keychain changes.
- Do not add production deep links.
- Do not weaken existing visual QA fixture tests.

## Delegation Rationale

This is a bounded Debug-only local source/test implementation with explicit variants and focused AppStore tests. It is suitable for Claude Code implementation in an isolated worktree while Codex remains responsible for visual judgment, screenshot capture, final acceptance, and deciding later display fixes.
