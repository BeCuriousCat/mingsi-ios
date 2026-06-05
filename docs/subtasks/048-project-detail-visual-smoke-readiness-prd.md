# Subtask 048 PRD: Project Detail Visual-Smoke Readiness Audit

Date: 2026-06-05

## Goal

Produce a read-only Project Detail visual-smoke readiness audit that tells Codex exactly which Project states should be screenshot-tested next and which narrow UI follow-ups, if any, should be implemented after real screenshots.

This is a MingSi product-hardening slice, but it is audit-only. It should improve the app's path toward a usable alpha without changing product source.

## Context

`docs/mvp-stage-progress.md` records that Project Detail hierarchy cleanup is implemented and build/test verified, but populated Project Detail states still need visual QA. Projects must remain evidence-backed long-running topics, not decorative dashboards.

The audit should focus on whether Project Detail is ready for real iPhone 17 screenshot verification and what states Codex should inspect.

## Scope

Allowed write files:

- `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`

Read-only source areas:

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Sources/Domain/Models.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- relevant existing Project subtask docs 037, 040, 041

Do not edit:

- Swift source files
- Swift tests
- Persistence / migrations / repositories
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Existing screenshots
- Unrelated docs

## Required Audit Questions

1. Which Project Detail states must Codex screenshot next for visual smoke confidence?
2. Which states are already evidence-backed and which risk looking decorative or unsupported?
3. Are there obvious code-level visual risks before screenshotting, such as empty placeholders, nested cards, tab-bar overlap, dark-mode contrast, long-text overflow, or evidence-link affordance confusion?
4. What are the top 1-3 narrow follow-up implementation candidates, if screenshots confirm the risk?
5. What should Codex explicitly not change in the next slice to avoid product semantics drift?

## Required Findings Format

Create `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md` with:

- `## Summary`
- `## Screenshot Matrix`
- `## Evidence-Backed States`
- `## Visual Risks`
- `## Recommended Follow-Ups`
- `## Non-Goals`
- `## Acceptance Notes`

Keep findings concise and actionable. Do not invent runtime screenshot evidence. If something is inferred from source, label it as source-inferred.

## Acceptance Evidence

Worker must run:

```bash
git diff --check -- docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md
```

Expected:

- Progress file reaches `HANDOFF` with a final status token.
- Findings file exists and answers the required audit questions.
- No Swift source or tests are modified.
- Raw/event logs are retained but not required for normal manager consumption.

