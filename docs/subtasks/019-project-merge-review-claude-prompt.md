You are implementing Subtask 019 for the MingSi iOS app.

Read these files first:

- `docs/subtasks/019-project-merge-review-prd.md`
- `docs/subtasks/019-project-merge-review-progress.md`
- `docs/spec-consistency-audit.md`
- `docs/implementation-gap-audit.md`
- `Sources/Services/ProjectAIService.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIResponseParser.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Tests/Services/ProjectAIServiceContextTests.swift`

Update `docs/subtasks/019-project-merge-review-progress.md` at the required checkpoints. Keep changes scoped to Subtask 019.

Implement exactly this slice:

1. Prompt and service
   - Add `PromptID.suggestProjectMerges`.
   - Add a local prompt template that asks for strict JSON:
     `{ "merge_candidates": [{ "source_project_id": "...", "target_project_id": "...", "reason": "...", "overlapping_evidence_refs": ["..."] }] }`
   - Add merge context types to `ProjectAIService`.
   - Add `ProjectAIService.suggestProjectMerges(context:)`.
   - Request sourceRecordIDs must include overlapping project evidence ids.
   - Request contextRecordIDs must include active project ids.

2. AppStore
   - Inject `ProjectMergeCandidateRepository`.
   - Add published state:
     - `pendingProjectMergeCandidates: [ProjectMergeCandidate]`
     - `isGeneratingProjectMerges: Bool`
     - `projectMergeMessage: String`
   - Add `loadPendingProjectMergeCandidates()`.
   - Add `suggestProjectMerges(projectAIService:)`.
   - Add `acceptProjectMergeCandidate(_:)`.
   - Add `rejectProjectMergeCandidate(_:)`.
   - Add `dismissProjectMergeCandidate(_:)`.
   - Save generated candidates only when:
     - both project ids exist
     - both projects are active
     - source and target differ
     - every overlappingEvidenceRef belongs to confirmed links of either project
   - Accepting a candidate:
     - archives source project
     - appends a readable merge audit line to target project's `mergeHistory`
     - saves both projects
     - marks candidate `.accepted`
     - refreshes projects and pending candidates
   - Reject/dismiss only update candidate status and refresh pending candidates.

3. Projects UI
   - Add a compact evidence-backed merge review section in Projects UI.
   - The section must call AppStore actions only.
   - Display source/target names, reason, evidence count, and accept/reject/dismiss controls.
   - Keep style aligned with existing DS surfaces, no purple, no fake data.

4. Tests
   - Use TDD. Add failing tests before implementation.
   - Add ProjectAIService context test for prompt id, source refs, and context refs.
   - Add AppStore tests for:
     - valid generation saves candidates
     - invalid unknown project/unresolved refs are dropped
     - accepting archives source and updates target mergeHistory
     - rejecting/dismissing does not alter projects
   - Update in-memory repositories in tests as needed.

Run targeted tests:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/ProjectAIServiceContextTests \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  test
```

Do not run destructive git commands. Do not commit. Report DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED at the end.
