# Claude Code Task: Subtask 022 Project Editing Governance

You are a bounded implementation worker for Codex. Codex owns architecture and final review.

## Workspace

`/Users/chenzewei/Documents/Codex/2026-05-30/image-2`

## Read Before Editing

- `docs/subtasks/022-project-editing-governance-prd.md`
- `docs/subtasks/022-project-editing-governance-progress.md`
- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `Sources/Services/PersistenceCore.swift`

## Hard Constraints

- Use TDD.
- Update `docs/subtasks/022-project-editing-governance-progress.md` at:
  - start
  - after RED tests are observed
  - after implementation
  - after targeted verification
  - final handoff
- Do not commit.
- Do not run destructive git commands.
- Keep diff scoped.
- No database migration.
- No project deletion.
- No moving or deleting ProjectLink rows.
- No AI rewriting of project fields.
- Preserve visual language: quiet native working surface, warm paper/graphite, restrained accents, no purple/AI dashboard.

## Implementation Requirements

Implement the PRD exactly.

1. Add AppStore actions:
   - `updateProjectDetails(projectId:name:goal:successCriteria:currentBottleneck:openQuestions:) async`
   - `archiveProject(_ projectId: UUID) async`
   - `restoreProject(_ projectId: UUID) async`
2. Behavior:
   - reject empty project names with a user-visible message.
   - trim strings.
   - update `updatedAt`.
   - append lightweight field revision notes for changed fields.
   - save through `ProjectRepository.saveProject`.
   - update `projectNames` and `projectsById`.
   - never mutate evidence links.
3. Tests first in `Tests/App/AppStoreStateMachineTests.swift`:
   - editing name/goal/success criteria/bottleneck/open questions persists and updates dictionaries.
   - empty name is rejected and previous name remains.
   - archive preserves project and linked evidence.
   - restore archived project to active.
4. UI in `Sources/Features/FeatureTabs.swift`:
   - add Project Detail edit affordance.
   - use a sheet or compact edit surface.
   - include fields for name, goal, success criteria, bottleneck, open questions.
   - include archive or restore action based on current status.
   - no nested card layouts.
5. Docs:
   - update `docs/ux-flow.md` Project Flow.
   - update `docs/implementation-gap-audit.md`.
   - update `docs/agent-delegation-log.md`.

## Required Verification

Run targeted tests:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

If targeted tests pass and time allows, also run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/PersistenceCoreTests \
  -only-testing:MingSiTests/HistoryFeatureTests \
  test
```

Do not claim success unless you ran and read verification output.

## Final Response Format

End with exactly one status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

Also summarize:

- files changed
- tests run and result
- any concerns
