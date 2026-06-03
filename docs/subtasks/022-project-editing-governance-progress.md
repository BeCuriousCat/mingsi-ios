# Subtask 022 Progress: Project Editing Governance

Owner: Codex

Delegated implementer: Claude Code via `/opt/homebrew/bin/claude`

Required PRD: `docs/subtasks/022-project-editing-governance-prd.md`

## Status

- [x] PRD created
- [x] Claude Code started
- [x] RED tests observed
- [x] Implementation completed
- [x] Codex diff review completed
- [x] Targeted verification completed
- [ ] Related regression completed
- [ ] Full verification completed
- [x] Docs updated

## Progress Log

### 2026-06-02 05:00

Codex created the subtask PRD and progress file.

Scope constraints:

- No migration.
- No project deletion.
- No evidence link mutation.
- Project edits must go through AppStore and existing `ProjectRepository.saveProject`.
- Codex remains responsible for review and verification.

### 2026-06-03 00:03

Claude Code was treated as non-delivery for this slice:

- The expected progress checkpoints and handoff were not written.
- The Claude log did not contain usable implementation evidence.
- Codex implemented and reviewed the slice directly.

RED observed:

- `AppStore.updateProjectDetails(...)` missing.
- `AppStore.archiveProject(_:)` missing.
- `AppStore.restoreProject(_:)` missing.
- SwiftUI `ProjectEditorSheet` initially failed to compile because of a `Section` overload; Codex fixed the initializer.

Accepted implementation:

- Added AppStore project metadata editing with trimmed fields and empty-name rejection.
- Added archive/restore actions while preserving project ids and evidence links.
- Added Project Detail edit sheet with archive/restore controls.
- Added regression tests for edit, empty-name rejection, archive evidence safety, and restore.

Targeted verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Result:

- Passed: 87 tests, 0 failures before the later P0 usability tests were added.
- Passed again after P0 usability fixes: 88 tests, 0 failures.

Additional P0 fixes completed during cleanup:

- Fixed dark-mode unreadability by making design tokens dynamic instead of fixed light-theme colors.
- Added a visible Today “补充材料” path and a state-machine method for appending supplementary input, returning to Capture, and regenerating derived cards.
- Added regression tests for both behaviors.
