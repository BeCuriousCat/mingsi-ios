# Subtask 022: Project Editing Governance

Date: 2026-06-02

## Goal

Let users maintain long-running projects after creation without losing evidence.

Projects are now evidence-backed long-term topics. The user can create projects, link historical evidence, generate insights, and review merge candidates, but cannot yet cleanly edit the project record itself. This makes the Projects tab feel less like a durable thinking surface.

This slice adds conservative project editing:

- rename project
- edit goal, success criteria, bottleneck, and open questions
- archive active/watching/paused projects
- restore archived projects
- retain field revision audit text

## Product Context

Project means a user-confirmed long-running topic, workflow, goal, blocker, or behavior standard.

Editing must not rewrite history. Historical `ProjectLink` evidence remains linked to the same `projectId`. Edits only change the current project metadata and append lightweight revision notes.

## Scope

### In Scope

- Add AppStore actions:
  - `updateProjectDetails(...)`
  - `archiveProject(_:)`
  - `restoreProject(_:)`
- Persist changes through existing `ProjectRepository.saveProject`.
- Update `projectNames` and `projectsById` after every successful change.
- Add tests for:
  - rename and field edit persistence.
  - empty name rejection.
  - archive preserves project and evidence links.
  - restore changes archived project back to active.
- Add Project Detail UI:
  - compact edit button.
  - editable fields for name, goal, success criteria, bottleneck, open questions.
  - archive/restore action based on status.
  - no destructive evidence deletion.
- Keep UI restrained and native:
  - no fake dashboards.
  - no nested cards.
  - no purple/AI visual language.

### Out of Scope

- No database migration.
- No deleting projects.
- No moving project links.
- No project merge UI redesign.
- No full project status management beyond archive/restore.
- No AI rewriting of project fields in this slice.

## Functional Requirements

### FR1 Project Detail Update

`updateProjectDetails` must:

- reject empty or whitespace-only names.
- trim editable string fields.
- preserve `id`, `createdAt`, `createdBy`, `confidence`, `mergeHistory`, and existing links.
- update `updatedAt`.
- append revision notes to `fieldRevisions` when a field changes.
- save through repository.
- refresh `projectNames` and `projectsById`.

Editable fields:

- `name`
- `goal`
- `successCriteria`
- `currentBottleneck`
- `openQuestions`

### FR2 Archive

`archiveProject` must:

- set status to `.archived`.
- preserve all evidence links and project metadata.
- save through repository.
- refresh in-memory dictionaries.

Archived projects may remain visible if they still have evidence; UI should clearly label them as archived.

### FR3 Restore

`restoreProject` must:

- set status to `.active`.
- preserve all evidence links and project metadata.
- save through repository.
- refresh in-memory dictionaries.

### FR4 UI

Project Detail should expose editing as a controlled sheet or compact edit surface:

- Fields should be editable only after user taps edit.
- Save validates name.
- Cancel discards local draft edits.
- Archive/restore actions should be explicit and near project metadata, not hidden in History evidence rows.

### FR5 Evidence Safety

No editing action may:

- delete `ProjectLink`.
- mutate historical `HistoryRecord`.
- remove `ProjectInsight`.
- clear merge history.

## Test Plan

Use TDD.

Targeted command:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Related regression:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/PersistenceCoreTests \
  -only-testing:MingSiTests/HistoryFeatureTests \
  test
```

Final verification:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
git diff --check
```

## Acceptance Criteria

- Project metadata can be edited from Project Detail.
- Archive and restore are available and persisted.
- Project evidence remains intact.
- Tests prove state-machine behavior.
- Docs and delegation records are updated.
