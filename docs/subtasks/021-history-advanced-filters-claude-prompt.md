# Claude Code Task: Subtask 021 History Advanced Filters

You are a bounded implementation worker for Codex. Codex owns architecture and final review.

## Required Context

Workspace:

`/Users/chenzewei/Documents/Codex/2026-05-30/image-2`

Read before editing:

- `docs/subtasks/021-history-advanced-filters-prd.md`
- `docs/subtasks/021-history-advanced-filters-progress.md`
- `Sources/Domain/Models.swift`
- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

## Hard Constraints

- Use TDD.
- Update `docs/subtasks/021-history-advanced-filters-progress.md` at:
  - start
  - after RED tests are observed
  - after implementation
  - after targeted verification
  - final handoff
- Do not commit.
- Do not run destructive git commands.
- Keep the diff scoped.
- No database migration.
- No saved filter persistence.
- No AI/search service.
- No fake data.
- Do not rewrite the whole History page.
- Preserve the existing visual language: quiet native working surface, warm paper/graphite, restrained accents, no purple/AI-dashboard look.

## Implementation Requirements

Implement the PRD exactly:

1. Extend `HistorySearchQuery` with optional advanced filters:
   - `projectId: UUID?`
   - `lens: ThinkingLens?`
   - `cardType: ThinkingCardType?`
   - `questStatus: QuestStatus?`
2. Query semantics:
   - all active filters compose as intersection.
   - existing keyword + broad `HistoryEvidenceFilter` semantics must remain unchanged.
3. Add tests in `Tests/Features/HistoryFeatureTests.swift` first:
   - project filter matches only selected project.
   - lens filter matches selected lens.
   - card type filter matches selected type.
   - quest status filter matches selected status.
   - advanced filters compose with keyword and broad evidence type.
4. Update History UI in `Sources/Features/FeatureTabs.swift`:
   - add compact advanced filters for project, lens, card type, quest status.
   - options must be derived from loaded `HistoryRecord` values.
   - project labels should use `store.projectNames`, fallback to an 8-char UUID prefix.
   - show active advanced filter count and a clear-all action.
   - calendar sheet should continue using filtered records when any query/filter is active.
5. Update docs:
   - `docs/ux-flow.md` History Flow
   - `docs/implementation-gap-audit.md`
   - `docs/agent-delegation-log.md`

## Required Verification

Run targeted tests:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

If targeted tests pass and time allows, also run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MingSiTests/HistoryFeatureTests \
  -only-testing:MingSiTests/AppStoreStateMachineTests \
  -only-testing:MingSiTests/PersistenceCoreTests \
  test
```

Do not claim success unless you ran and read the verification output.

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
