# Subtask 049 Progress: Project Detail Real Simulator Visual QA

Status: STARTED
Timestamp: 2026-06-06

Owner: Codex manager
Delegated implementer: none

PRD: `docs/subtasks/049-project-detail-real-simulator-visual-qa-prd.md`
Expected findings: `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`
Screenshot directory: `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/`

## Current Goal

Use real iPhone 17 simulator screenshots to verify Project Detail visual risks from Subtask 048 before implementing any Project Detail polish.

## Current Goal Brief

- MVP stop condition remains a coherent personal alpha with evidence-backed Today, History, Projects, Growth, Settings, AI failure audit, and simulator verification.
- Current priority from `docs/mvp-stage-progress.md`: Project Detail real iPhone 17 visual-smoke screenshots using the Subtask 048 matrix.
- Startup prompt and repo docs do not conflict. Repo docs are authoritative for slice selection.
- This slice is verification-first and not delegated because final visual judgment and screenshot acceptance belong to Codex.
- Current worktree was clean at start.

## Initial Resource Check

- iPhone 17 simulator was available but shutdown.
- No simulator device was booted.
- `git status --short` was clean.
- System zombie count was 5: 2 under `DoubaoIme`, 3 under Codex, below the wrapper launch guard threshold.

## Data Source Check

Current findings:

- There is no existing Project Detail screenshot automation script.
- There is no current deep link or launch argument to open Project Detail directly.
- `AppStore.preview` seeds Today/Growth preview data but does not seed Project Detail states.
- Current app launch uses live persistence through `AppDatabase.defaultURL()`.

Manager classification:

- Real Project Detail screenshot verification probably needs either existing simulator data, normal in-app creation, or a clearly labeled Visual QA fixture in the simulator database.
- Do not modify Swift source until the simulator data path is confirmed insufficient.

## Build And Simulator Check

Timestamp: 2026-06-06

Commands:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl boot 'iPhone 17'
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
xcrun simctl launch booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/01-launch-initial-light.png
```

Result:

- iPhone 17 simulator build succeeded.
- App installed and launched with bundle id `com.codex.mingsi`.
- Initial screenshot was captured, but simulator appearance was dark at first despite the filename.
- Projects tab was reachable once via macOS System Events coordinate click.

Screenshots captured:

- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/01-launch-initial-light.png`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/02-projects-top-dark.png`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/03-projects-top-light-empty.png`

Finding:

- Current simulator data has no evidence-backed projects, so Project Detail is not reachable through normal UI state.
- Projects empty state is visually captured in light/dark, but Subtask 048 Project Detail risks remain unverified.

## Visual QA Fixture Attempt

Timestamp: 2026-06-06

Simulator database inspection found:

- `daily_entries`: 12
- `thinking_cards`: 9
- `quests`: 4
- `projects`: 0
- `project_links`: 0
- `project_insights`: 0

Codex inserted one explicitly labeled Visual QA fixture Project into the simulator database, linked only to existing simulator cards and quests:

- Project id: `B4E5CE57-03E6-45C8-89EF-27D8B1CA56D1`
- No new DailyEntry, ThinkingCard, Quest, Verification, Principle, PromptRun, or Growth data was inserted.
- This fixture is not real-user evidence and must not be used to claim production behavior.

Follow-up screenshots:

- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/04-launch-after-fixture-light.png`

Blocker:

- `simctl` has no tap command.
- macOS System Events initially clicked the Projects tab successfully, but later Simulator exposed no foreground window to System Events, so coordinate navigation became unreliable.
- Without a stable deep link, UI test, or Debug/UITest-only launch entry, Codex cannot reliably navigate to Project Detail for the screenshot matrix.

Manager classification:

- 049 can document top-level Projects empty state and the navigation/data blocker.
- A separate implementation slice is needed for a Debug/UITest-only visual QA entry that can launch directly into Project Detail fixture states without changing production behavior.

## Fixture Launch Reliability Acceptance

Timestamp: 2026-06-06

Subtasks 054 and 055 added and hardened a Debug-only launch fixture path for Project Detail visual QA.

Runtime verification sequence:

- `05-projects-fixture-top-light.png` through `12-projects-fixture-top-light-marker.png`: fixture activation attempts still showed live Projects empty state.
- `13-projects-fixture-top-light-task-activation.png`: marker-file launch still failed after task-stage fixture apply.
- `14-projects-fixture-top-light-argument-after-task-activation.png`: launch-argument control also failed, proving the issue was not the marker file path.
- Root cause: Projects tab `.task` called `store.loadHistoryRecords()` after fixture startup and replaced fixture evidence with live empty history.
- Codex added `testVisualQAFixture_loadHistoryRecordsKeepsFixtureProjectEvidence`, observed it fail, then fixed `AppStore.loadHistoryRecords()` for Debug fixture stores.
- `15-projects-fixture-top-light-load-guard.png`: accepted iPhone 17 light screenshot. Projects shows `1 个证据项目` and `Visual QA - 会议机制优化`.

Commands:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project MingSi.xcodeproj -scheme MingSi -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-fzvxdxbuzzkbvfctglvogodxewmw/Build/Products/Debug-iphonesimulator/MingSi.app
CONTAINER=$(xcrun simctl get_app_container booted com.codex.mingsi data) && mkdir -p "$CONTAINER/Documents" && touch "$CONTAINER/Documents/.visual_qa_project_detail"
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/15-projects-fixture-top-light-load-guard.png
```

Result:

- Project top fixture activation is accepted.
- Subtask 049 remains open for the actual Project Detail screenshot matrix: top row navigation is now possible because the fixture project is visible.

## Project Detail Direct Entry Acceptance

Timestamp: 2026-06-06

Subtask 056 added a Debug-only direct-entry path for the existing visual QA fixture.

Verification:

- Claude Code worker reached `HANDOFF/DONE_WITH_CONCERNS`.
- Codex reviewed and accepted the worker diff without manager source fixes.
- `git diff --check` passed.
- `AppStoreStateMachineTests` passed with 132 tests and 0 failures.
- iPhone 17 Debug simulator build passed.
- iPhone 17 Release simulator build passed.
- Real iPhone 17 marker launch screenshot:
  - `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/16-project-detail-direct-entry-light.png`

Result:

- The screenshot shows Project Detail (`长期议题`) for `Visual QA - 会议机制优化`, proving the direct-entry navigation blocker is removed.
- Subtask 049 remains open for the full Subtask 048 Project Detail light/dark screenshot matrix.
- The screenshot confirms a known Subtask 048 follow-up candidate: Project Detail status chip still displays English `active`.

## Current Fixture Project Detail Light/Dark Top Screens

Timestamp: 2026-06-06

Screenshots:

- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/16-project-detail-direct-entry-light.png`
- `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/17-project-detail-direct-entry-dark.png`

Commands:

```bash
xcrun simctl ui booted appearance dark
xcrun simctl launch --terminate-running-process booted com.codex.mingsi
xcrun simctl io booted screenshot docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/17-project-detail-direct-entry-dark.png
```

Coverage:

- Confirms Project Detail can be captured in both light and dark mode for the current fixture.
- Current fixture top screen covers a populated active project with overview data, derived progress signals, accepted/pending insight data in the store, and merge history in the store.
- This does not yet cover the full 10-state Subtask 048 matrix.

Visual observations:

- Header and top content are below the Dynamic Island/status area.
- Bottom floating tab overlaps the lower edge of the viewport, but the detail page is scrollable; bottom-scroll evidence still needs dedicated screenshots if used for final visual acceptance.
- The status chip still displays English `active`, confirming Subtask 048 VR-2.
- Dark mode text is readable, but `summarySurface()` appears close to pure black against the warm dark background, confirming Subtask 048 VR-6 as worth a narrow follow-up after the matrix.
- `ProjectTinyChip` text/icon contrast is readable in dark mode, though the chip fill is subtle.

Manager classification:

- Existing direct-entry fixture is enough to verify normal populated Project Detail top state in light/dark.
- Completing the remaining matrix states likely requires a new Debug-only fixture variant selector or screenshot harness; repeated coordinate clicking is not a reliable path because `simctl` has no tap/scroll command and System Events access has already proven unstable.

## Fixture Variant Selector Acceptance

Timestamp: 2026-06-06

Subtask 057 added Debug-only Project Detail visual QA fixture variants for the Subtask 048 matrix.

Variant ids:

- `nil_project`
- `minimal`
- `normal`
- `accepted_insight`
- `pending_insight`
- `merge_history`
- `long_timeline`
- `long_name`
- `sparse_next_bet`
- `generating_insight`

Verification:

- Claude Code worker reached `HANDOFF/DONE`.
- Codex accepted after manager fixes so fixture ProjectLinks resolve to real History sources and `sparse_next_bet` actually derives a next bet from quest/task evidence.
- `git diff --check` passed.
- `AppStoreStateMachineTests` passed with 153 tests and 0 failures.
- iPhone 17 Release simulator build passed.

Result:

- Subtask 049 can now proceed to real iPhone 17 screenshot capture using fixture variants.
- Subtask 049 is still open until the real light/dark Project Detail screenshot matrix is captured and reviewed.
