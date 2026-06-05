# Claude Prompt: Subtask 050 Project Detail Visual QA Launch Fixture

You are a bounded implementation worker for Codex. Codex owns product judgment, architecture, final acceptance, and screenshot review.

Invoke and follow the Claude skill `codex-delegated-worker` if available.

## Read First

- `docs/subtasks/050-project-detail-visual-qa-launch-fixture-prd.md`
- `docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-progress.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- `docs/architecture-decisions.md`

Then inspect only needed source/test ranges with `rg` and `sed`:

- `Sources/App/MingSiApp.swift`
- `Sources/App/AppStore.swift`
- `Sources/Features/FeatureTabs.swift`
- `Sources/Domain/Models.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

Do not read large files end-to-end unless a narrow range is insufficient.

## Task

Implement a Debug/UITest-only launch fixture argument:

```text
MINGSI_VISUAL_QA_PROJECT_DETAIL
```

Required behavior:

- normal launches still use `AppStore.live()`;
- fixture launches use an in-memory `AppStore`;
- fixture store starts with `selectedTab == .projects`;
- fixture store has at least one project in `projectsById`, matching `projectNames`;
- fixture store has `historyRecords` containing confirmed `ProjectLink` evidence for that project;
- fixture store has accepted and/or pending project insights so Project Detail can render richer states;
- no SQLite writes, no migrations, no repository contract changes.

Keep fixture data clearly labeled as visual QA data in names/raw text where reasonable.

## Allowed Files

- `Sources/App/MingSiApp.swift`
- `Sources/App/AppStore.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md`

## Forbidden

- `Sources/Services/PersistenceCore.swift`
- migrations/schema changes
- PromptProvider or prompt text
- LLM clients
- parser files
- Keychain
- project files
- screenshots
- unrelated docs
- commits

## Test Requirements

Add or update focused tests in `AppStoreStateMachineTests` that prove:

- launch arguments without `MINGSI_VISUAL_QA_PROJECT_DETAIL` choose live startup mode or do not choose fixture mode;
- launch arguments with `MINGSI_VISUAL_QA_PROJECT_DETAIL` produce a fixture store on Projects;
- fixture store includes evidence-backed Project Detail data: at least one `HistoryRecord.projectLinks` entry and matching `projectsById`/`projectNames`.

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
git diff --check
```

If xcodebuild cannot run in the worker worktree because of local infrastructure, record the exact failure and still run any narrower possible test/compile checks.

## Final Handoff

Append `## HANDOFF` with exactly one status token:

- `Status: DONE`
- `Status: DONE_WITH_CONCERNS`
- `Status: NEEDS_CONTEXT`
- `Status: BLOCKED`

Summarize changed files, behavior, tests, and concerns.

