# Subtask 021: History Advanced Filters

Date: 2026-06-02

## Goal

Make History useful as an evidence archive, not only a date archive.

Users should be able to narrow historical records by project, thinking lens, card type, and quest status, while preserving the existing keyword search, evidence type filter, calendar navigation, and deep-link behavior.

## Product Context

The product loop depends on History as the source of truth:

- Projects need to link back to concrete historical evidence.
- Growth needs to explain metric changes from concrete historical evidence.
- Users need to review whether a thinking mode, behavior standard, or project is actually improving over time.

The existing History screen supports keyword search and broad evidence-type filters. This slice adds second-level filters so the user can answer:

- “Show me all records related to this project.”
- “Show me days where I used leverage analysis.”
- “Show me decision cards from the last batch of records.”
- “Show me records where main quests were missed, partial, or completed.”

## Scope

### In Scope

- Extend `HistorySearchQuery` with optional advanced filters:
  - `projectId: UUID?`
  - `lens: ThinkingLens?`
  - `cardType: ThinkingCardType?`
  - `questStatus: QuestStatus?`
- Derive filter options from currently loaded `HistoryRecord` values and `store.projectNames`.
- Add a compact advanced filter UI in History:
  - visually restrained, native, and readable
  - no purple/AI-dashboard style
  - clear active-filter count
  - clear-all action
- Preserve existing broad `HistoryEvidenceFilter` behavior.
- Preserve existing keyword search intersection semantics.
- Add tests proving advanced filters compose as intersections.
- Update relevant docs and delegation/progress records.

### Out of Scope

- No database migration.
- No saved filter persistence.
- No AI or semantic search.
- No server-side query.
- No fake counts or fabricated project names.
- No redesign of the full History page.

## Functional Requirements

### FR1 Query Model

`HistorySearchQuery.apply(to:)` must return records matching all active filters:

- keyword text
- broad evidence type
- project id
- thinking lens
- card type
- quest status

If no advanced filters are selected, existing behavior must remain unchanged.

### FR2 Project Filter

A record matches a project filter when it contains at least one `ProjectLink` with the selected `projectId`.

Project filter options must be derived from loaded history records. Display names should come from `store.projectNames`; if missing, use a short stable fallback based on the UUID prefix.

### FR3 Lens Filter

A record matches a lens filter when:

- `record.lensSession?.selectedLens == selectedLens`

If no lens session exists, it must not match a lens filter.

### FR4 Card Type Filter

A record matches a card type filter when it contains at least one card with the selected `ThinkingCardType`.

Card type filtering is about finding historical records. It may include pending/excluded cards as historical material, but `hasCardEvidence` and evidence counts must still only treat confirmed non-excluded cards as evidence.

### FR5 Quest Status Filter

A record matches a quest status filter when it contains at least one quest with the selected `QuestStatus`.

This supports reviewing whether active, completed, partial, failed, or archived tasks cluster around certain projects or periods.

### FR6 History UI

The History search section should include:

- existing search field
- existing broad evidence filter chips
- advanced filter affordance or compact filter strip
- active filter count and clear action when active

The UI should remain quiet and working-surface oriented:

- warm surface
- small controls
- no card nesting
- no large centered template blocks
- no fake examples

### FR7 Calendar and Selection Behavior

When advanced filters are active:

- visible record count must reflect the filtered results.
- calendar sheet should receive filtered records, same as existing keyword/evidence filters.
- selected date should move to the first matching record if the current date no longer matches.
- deep links should still open the source day even if a filter is active; the user can clear filters if the highlighted evidence is hidden.

## Test Plan

### RED Tests

Add tests before implementation:

- project filter matches only records linked to the selected project.
- lens filter matches only records with the selected lens session.
- card type filter matches only records containing the selected card type.
- quest status filter matches only records containing the selected status.
- filters compose as an intersection with keyword and broad evidence type.

### Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

Then run related regression:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/HistoryFeatureTests \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/PersistenceCoreTests \
  test
```

Finally:

```bash
git diff --check
```

## Acceptance Criteria

- History advanced filters are derived from local records and do not require migrations.
- All active filters compose by intersection.
- Existing search/filter behavior remains covered by tests.
- UI does not introduce fake data or decorative dashboard blocks.
- Project/Growth/History deep-link behavior is not broken.
- Documentation and delegation log reflect the work.
