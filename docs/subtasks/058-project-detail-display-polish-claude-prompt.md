# Claude Code Prompt: Subtask 058 Project Detail Display Polish

You are Claude Code working as a bounded implementation worker. Codex is the MingSi product owner, architect, manager, reviewer, and final verifier.

## Task

Implement the narrow Project Detail display-polish slice described in:

- `docs/subtasks/058-project-detail-display-polish-prd.md`
- `docs/subtasks/049-project-detail-real-simulator-visual-qa-findings.md`

Do not broaden scope.

## Required First Action

Before reading broad source ranges, update:

- `docs/subtasks/058-project-detail-display-polish-progress.md`

Add checkpoint:

```text
START
```

Then inspect only targeted source ranges around:

- `ProjectDetailView`
- `detailHeader`
- `overviewSection`
- `projectInsightSection`
- `thinkingChangeSection`
- `evidenceTimeline`
- `summarySurface`
- `ProjectStatus.chineseTitle`

Use `rg` and `sed` targeted ranges. Do not read all of `FeatureTabs.swift` up front.

## Allowed Files

You may edit:

- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift` only if strictly needed
- `Tests/App/HistoryFeatureTests.swift` or `Tests/App/AppStoreStateMachineTests.swift` only if a focused display-helper regression fits existing patterns
- `docs/subtasks/058-project-detail-display-polish-progress.md`

You may not edit:

- AppStore orchestration
- Persistence, migrations, repositories, GRDB
- PromptProvider, prompt text, parser, LLM clients, Keychain
- Project domain models or semantics
- ProjectInsight generation or feedback behavior
- Screenshot files
- Unrelated docs

## Implementation Requirements

1. Change Project Detail status chip to Chinese labels:
   - Use `project?.status.chineseTitle ?? "活跃"`.

2. Improve Project Detail dark card surface:
   - Prefer a local Project Detail surface modifier or local helper if possible.
   - Do not globally alter every `.summarySurface()` across the app unless the change is clearly safe and tested.
   - Preserve light-mode calm paper tone and dark-mode readability.

3. Hide or demote pure empty thinking-change state:
   - Do not show a prominent card when there is no accepted ProjectInsight and no before/after evidence.
   - Do not invent a thinking-change narrative.
   - Keep evidence-backed or accepted-insight cases visible.

4. Bound long evidence timeline:
   - Show an initial limited set.
   - Provide an explicit local expand affordance to show all evidence links.
   - Preserve History deep-link behavior for every visible item.

5. Bottom spacing:
   - Ensure Project Detail scroll content has enough bottom reserve for the floating tab bar.
   - Do not create large double gaps above the tab.

## Suggested Verification

Run:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

If you add focused tests, also run the focused test command.

If the worker worktree cannot run xcodebuild because vendored GRDB resources are unavailable, record that as `DONE_WITH_CONCERNS` and include the exact error. Do not claim build success without evidence.

## Handoff

At the end, update the progress file with:

```text
TARGETED_VERIFIED
HANDOFF
Status: DONE
```

or:

```text
HANDOFF
Status: DONE_WITH_CONCERNS
```

Include:

- changed files
- implementation summary
- commands run
- results
- residual concerns
