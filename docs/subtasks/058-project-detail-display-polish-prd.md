# Subtask 058 PRD: Project Detail Display Polish

Date: 2026-06-06

## Goal

Implement a narrow display-only Project Detail polish slice based on Subtask 049 real iPhone 17 screenshots.

The page must remain evidence-backed. The task is not to redesign Projects or change Project semantics; it is to fix confirmed visual issues before MVP alpha acceptance.

## Source Evidence

- `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `docs/mvp-stage-progress.md`
- `docs/architecture-decisions.md`

## Confirmed Issues

1. Project Detail status chip shows English `active` instead of Chinese labels.
2. Dark Project Detail summary surfaces are too close to pure black against the warm dark background.
3. Empty `思考变化` state looks like real evidence content in sparse/nil states.
4. Long evidence timelines dominate the first viewport.
5. Some lower first-viewport content appears under the floating tab; bottom-scroll evidence is missing.

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift` only if a local Project Detail surface treatment cannot be kept cleanly in `FeatureTabs.swift`

Allowed test files:

- `Tests/App/HistoryFeatureTests.swift` or `Tests/App/AppStoreStateMachineTests.swift` only for display helper regressions if existing test patterns fit

Allowed docs:

- `docs/subtasks/058-project-detail-display-polish-progress.md`

Do not modify:

- AppStore orchestration
- Persistence, migrations, repositories, GRDB
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Project domain semantics
- ProjectInsight generation, review, or feedback behavior
- Screenshot files

## Acceptance Criteria

- Project Detail status chip uses `ProjectStatus.chineseTitle` and uses `活跃` when there is no persisted Project.
- Project Detail dark-mode surfaces use the MingSi warm card tone instead of a cool near-black system surface.
- Pure explanatory `思考变化 / 证据不足` card is hidden or demoted when there is no accepted ProjectInsight and no before/after evidence.
- Long evidence timeline renders only an initial bounded set, with an explicit affordance to show all evidence links.
- Project Detail retains enough bottom padding for content to scroll above the floating tab bar.
- No Project/Growth evidence semantics change.
- Focused tests pass if tests are added.
- `git diff --check` passes.
- iPhone 17 simulator build passes.

## Delegation Rationale

This is a bounded SwiftUI display-only slice with concrete screenshot findings, a narrow write set, and no product-semantic decisions. It is suitable for Claude Code once resource health allows a worker launch. Codex remains responsible for final visual acceptance on iPhone 17 screenshots.
