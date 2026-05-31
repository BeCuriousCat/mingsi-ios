# Subtask 006: History Evidence PRD

## Owner

Worker agent: history evidence layer.

## Context

The History tab currently shows preview thinking cards. MVP needs history to become a real evidence layer that can show previous daily entries and their linked cards/quests/principles.

## Scope

Allowed write scope:

- `Sources/Features/FeatureTabs.swift`
- new files under `Sources/Features/History/`
- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift` only for read-only repository methods needed by history

Do not edit:

- Today UI
- GLM files
- notification files
- vendor code

## Requirements

1. Add repository support to list recent daily entries, newest first.
2. Add AppStore state/methods for loading history summaries.
3. History tab should show entries by date with:
   - loop state
   - raw text preview
   - confirmed card count if available
   - main quest title if available
4. Selecting an entry should show a simple detail view with:
   - raw input collapsed or visually secondary
   - cards
   - quests
   - principles
5. Keep this as evidence review, not a second place to mutate active Today loop.
6. Do not expose deleted/soft-deleted records.

## Architecture Constraints

- History UI reads through AppStore/repository boundaries.
- It must not directly import GRDB.
- Persisted data remains semantic; do not store UI-only history cards.

## Acceptance Criteria

- Build succeeds.
- History no longer depends only on current `store.thinkingCards` preview data.
- User can inspect at least the latest persisted daily entry and its evidence chain.
- No direct GRDB references in feature views.

## Final Response Required

List:

- files changed
- history data flow
- commands run and pass/fail
- remaining risks
