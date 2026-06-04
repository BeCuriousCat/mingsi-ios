# Subtask 037 PRD: Project Merge Audit Display

## Goal

Make Project merge review and accepted merge history easier to audit from the Projects UI without changing merge semantics.

This is a display-only hardening slice. The user should be able to see:

- what accepting a pending merge candidate will do;
- which evidence ids caused the candidate;
- where an accepted merge is retained as target-project audit history.

## Product Principle

Projects are evidence-backed long-running topics. Merge review must not look like an automatic AI cleanup action.

The UI must preserve these current semantics:

- AI only proposes `ProjectMergeCandidate`.
- The user confirms before durable project state changes.
- Accepting a merge archives the source project and appends an audit line to the target project's `mergeHistory`.
- Existing `ProjectLink` rows are not moved or rewritten in this slice.
- Source projects are not deleted.

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/037-project-merge-audit-display-progress.md`

Expected implementation:

1. Add small display helpers for Project merge audit copy, such as:
   - candidate evidence summary;
   - candidate consequence line;
   - normalized merge-history audit lines.
2. Use the helpers in `ProjectMergeCandidateReviewRow`.
3. Add a `合并审计` section in `ProjectDetailView` only when the target project has non-empty `mergeHistory`.
4. Keep the UI evidence-backed:
   - show existing `mergeHistory` strings;
   - show existing `overlappingEvidenceRefs`;
   - do not invent source titles, dates, or claims not present in data.
5. Add focused tests for the helpers.

## Non-Goals

- No AppStore merge behavior changes.
- No persistence, migration, repository, parser, prompt, LLM, Keychain, or GLM changes.
- No automatic merge.
- No moving/relinking `ProjectLink` records.
- No new Project/Growth product semantics.
- No simulator screenshot requirement for the worker.

## UX Requirements

Pending merge candidate row:

- Still shows source project -> target project.
- Shows reason.
- Shows evidence count and a compact ref preview.
- Adds a short consequence line equivalent to:
  - target stays active;
  - source is archived;
  - evidence links are kept as existing records.

Project detail:

- If `project.mergeHistory` is empty, do not show an audit section.
- If non-empty, show a compact `合并审计` section near Overview or project insights.
- The section must show each retained audit line as stored, trimmed for whitespace.
- Long audit lines must wrap and remain readable in light/dark mode.

## Acceptance Criteria

- `ProjectMergeCandidateReviewRow` exposes clearer consequence/evidence copy without changing button actions.
- `ProjectDetailView` shows accepted merge history only when the project has real `mergeHistory`.
- Tests cover:
  - empty merge history produces no visible audit lines;
  - whitespace-only merge history is ignored;
  - non-empty merge history is trimmed and preserved;
  - candidate evidence summary includes count and compact refs;
  - candidate consequence copy does not claim links are moved or source is deleted.
- `git diff --check` passes.
- Focused tests pass.

## Verification

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If the worker worktree cannot run `xcodebuild` because vendored GRDB test resources are missing, report `NEEDS_CONTEXT` with the exact error instead of modifying dependencies.
