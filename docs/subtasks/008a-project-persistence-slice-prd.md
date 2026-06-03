# Subtask 008A: Project Evidence Persistence Slice PRD

## Goal

Implement the local fact sources for evidence-backed Projects without changing the Project UI yet.

This slice exists to prevent the Project tab from becoming a decorative dashboard. UI can only be rebuilt after these records exist.

## Write Scope

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Tests/Services/PersistenceCoreTests.swift`
- Optional: `docs/agent-delegation-log.md` only if recording implementation notes is necessary.

Do not edit:

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/Today/TodayView.swift`
- Design assets or theme files.

## Requirements

Add domain models:

- `Project`
- `ProjectCandidate`
- `ProjectLink`
- `ProjectMergeCandidate`
- `ProjectInsight`

Add supporting enums:

- `ProjectStatus`: `active | watching | paused | archived`
- `ProjectCandidateStatus`: `pending | accepted | renamedAndAccepted | dismissed | rejected`
- `ProjectCreatedBy`: `user | aiSuggested`
- `ProjectSourceType`: `dailyEntry | thinkingCard | quest | verification | principle`
- `ProjectLinkType`: `evidence | blocker | decision | task | principle | risk`
- `ProjectMergeStatus`: `pending | accepted | rejected | dismissed`
- `ProjectInsightType`: `progress | blockerChange | thinkingChange | openQuestionClosed | principlePracticed | nextBet`
- `ProjectFeedback`: `accepted | inaccurate | dismissed | none`

Add repository protocols:

- `ProjectRepository`
- `ProjectCandidateRepository`
- `ProjectLinkRepository`
- `ProjectMergeCandidateRepository`
- `ProjectInsightRepository`

Add SQLite migration:

- `v4_project_evidence_layer`

Add tables:

- `projects`
- `project_candidates`
- `project_links`
- `project_merge_candidates`
- `project_insights`

Persistence rules:

- Project candidates require at least one source ref.
- Project links require `sourceType` and `sourceId`.
- Project insights require at least one source ref.
- `thinkingChange` insights require both `beforeText` and `afterText`.
- Accepting or rejecting candidates/links/insights should preserve records for audit instead of deleting.
- Project merge candidates must retain source project id, target project id, reason, and overlapping evidence refs.

## Tests

Add or update persistence tests proving:

- Migration creates the five new tables.
- Save/load Project preserves goal, success criteria, bottleneck, status, merge history, and field revision JSON.
- Save/load ProjectCandidate preserves source refs and rejection/accepted status.
- ProjectCandidate with empty source refs is rejected by repository validation.
- Save/load ProjectLink preserves source type, source id, link type, confidence, and confirmation flag.
- Save/load ProjectMergeCandidate preserves overlapping evidence refs and status updates.
- Save/load ProjectInsight preserves source refs and feedback.
- `thinkingChange` ProjectInsight without before/after is rejected.

## Acceptance Criteria

- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test` succeeds.
- No UI files are modified.
- Project data can support future Project list/detail UI without fake rows.
