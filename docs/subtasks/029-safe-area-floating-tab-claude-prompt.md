# Claude Code Prompt: Subtask 029 Safe Area And Floating Tab Layout Fix

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns architecture, product judgment, and final simulator visual verification. You own only this scoped implementation slice.

## Read First

Before reading large source files, update `docs/subtasks/029-safe-area-floating-tab-progress.md` to mark `START`.

Then read these small docs:

- `docs/subtasks/029-safe-area-floating-tab-prd.md`
- `docs/subtasks/029-safe-area-floating-tab-progress.md`
- `docs/subtasks/028-real-simulator-visual-qa-findings.md`

For source files, do not use whole-file `Read` on `Sources/Features/FeatureTabs.swift` unless a targeted search proves it is necessary. Use `Grep` or `Bash(sed -n ...)` for these ranges first:

- `Sources/App/AppRootView.swift` lines 1-90
- `Sources/Features/FeatureTabs.swift` lines 120-220
- `Sources/Features/FeatureTabs.swift` lines 1210-1295
- `Sources/Features/FeatureTabs.swift` lines 2132-2170
- `Sources/Features/Today/TodayView.swift` lines 1-70
- `Sources/DesignSystem/Theme.swift` lines 1-90

Only inspect additional narrow ranges after a `Grep` result identifies a relevant line.

Do not read these whole files up front:

- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`

## Progress Contract

Update `docs/subtasks/029-safe-area-floating-tab-progress.md` at exactly these checkpoints:

- `START`: first action after reading this prompt, before broad source inspection;
- `RED`: after identifying the current failing layout pattern and, if possible, adding a small testable helper or documenting why this visual slice has no automated RED test;
- `IMPLEMENTED`: after applying the layout fix;
- `TARGETED_VERIFIED`: after running required verification commands;
- `HANDOFF`: final report with one status token.

Do not use additional checkpoint names.

At `HANDOFF`, include one of:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Scope

Fix only safe-area / floating-tab layout issues identified by Subtask 028.

Primary expected write set:

- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`

Optional only if it clearly reduces duplicated magic numbers:

- `Sources/DesignSystem/Theme.swift`

Allowed documentation write:

- `docs/subtasks/029-safe-area-floating-tab-progress.md`

Do not edit any other files unless a build error proves it is necessary. If another file appears necessary, write `NEEDS_CONTEXT` instead of broadening scope.

## Required Behavior

- History content must not render beneath the status bar or Dynamic Island.
- Growth and Settings bottom content must be readable above the floating system Tab bar.
- Projects must keep full-width background and avoid side gutters.
- Today must keep its bottom action row behavior.
- The fix should reduce magic-number bottom padding where practical.
- Do not create obvious double bottom spacing.

## Explicit Non-Goals

Do not change:

- cards;
- colors;
- typography;
- tab icons;
- app icon;
- Today workflow states;
- History evidence semantics;
- Projects or Growth data semantics;
- Prompt, GLM, parser, Keychain, migration, repository, or AppStore orchestration behavior.

## Architecture Rules

- SwiftUI views must not import GRDB.
- SwiftUI views must not call `LLMClient`.
- Repository and persistence abstractions must not be touched.
- No fake data, fake screenshots, or fake history.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

If xcodebuild fails due missing local infrastructure or simulator availability, report `NEEDS_CONTEXT` and include the exact error. Do not modify dependencies.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- changed files;
- root cause;
- implementation summary;
- verification commands and results;
- any remaining visual risk for Codex simulator review.
