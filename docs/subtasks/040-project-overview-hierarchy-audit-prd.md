# Subtask 040 PRD: Project Overview Hierarchy Audit

Date: 2026-06-05

## Goal

Audit the current Projects overview and Project Detail hierarchy before any new UI polish.

The repo documents say Projects must be evidence-backed long-running topics, not decorative dashboards. The next product slice should improve alpha usability, but the correct implementation must be chosen from current code evidence rather than broad taste instructions.

This subtask is a read-only audit plus a findings document. It should identify the smallest bounded implementation slice that can make Projects clearer while preserving evidence constraints.

## Product Questions

Answer from current repo evidence:

1. What does the Projects tab currently show at the top level?
2. What does Project Detail currently show, in what hierarchy?
3. Which existing sections already have strong source evidence?
4. Which sections are hard to scan, duplicated, or visually over-weighted?
5. Which project progress or thinking-change claims are correctly gated by evidence?
6. Which UI text risks sounding like unsupported summary or decorative dashboard copy?
7. Which next implementation slice would improve Project overview hierarchy without changing Project semantics?
8. Which files and helpers would that slice touch?
9. Which tests can prove the display/helper behavior?
10. Does this slice fit Claude Code implementation, or should Codex own it because it requires product taste?

## Scope

Allowed write files:

- `docs/subtasks/040-project-overview-hierarchy-audit-progress.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`

Do not edit Swift source files, tests, project files, assets, screenshots, migrations, repositories, prompt files, or product docs.

## Required Evidence Sources

Read current repo files with targeted ranges, not full-file dumps:

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`
- `docs/prd.md`
- `docs/ux-flow.md`
- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/037-project-merge-audit-display-progress.md`

Use `rg` first to locate:

- `ProjectsView`
- `ProjectDetailView`
- `ProjectEvidenceBoardRow`
- `ProjectProgressSignalRow`
- `ProjectMergeCandidateReviewRow`
- `ProjectInsight`
- `projectEvidence`
- `mergeAudit`

## Architecture Constraints

- History remains the evidence archive.
- Project claims must link back to real source evidence.
- Do not invent progress percentages or unsupported summaries.
- Do not propose persistence migrations for this polish slice.
- Do not change PromptProvider, LLMClient, parser, Keychain, Repository, AppStore orchestration, or Project semantics.
- SwiftUI views must not import GRDB.
- SwiftUI views must not call LLM clients directly.

## Expected Findings File

Create `docs/subtasks/040-project-overview-hierarchy-audit-findings.md` with:

- Summary.
- Current Projects top-level map with file/function references.
- Current Project Detail hierarchy map with file/function references.
- Evidence-backed sections and their source records.
- Usability hierarchy problems ordered by severity.
- Recommended next bounded implementation slice.
- Proposed write set for that slice.
- Proposed tests for that slice.
- Delegation recommendation: Claude Code implementation, Codex direct implementation, or product/design decision first.
- Explicit non-goals.

## Verification

Run:

```bash
git diff --check -- docs/subtasks/040-project-overview-hierarchy-audit-progress.md docs/subtasks/040-project-overview-hierarchy-audit-findings.md
```

This read-only audit does not require `xcodebuild`.

## Handoff Criteria

Handoff is acceptable only when:

- Progress file reaches `HANDOFF`.
- Findings file exists.
- Findings cite concrete files, symbols, and tests where relevant.
- Recommended implementation slice is narrow enough for Codex to accept, reject, or convert into a Subtask 041 PRD.
