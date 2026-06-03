# Subtask 029: Safe Area And Floating Tab Layout Fix

Date: 2026-06-03

## Problem

Subtask 028 real simulator screenshots show two P1 layout defects:

- History content can appear under the status / Dynamic Island area.
- Growth and Settings content can rest underneath the floating system Tab bar.

These issues make the app feel visually unreliable even though the underlying features exist.

## Source Evidence

Use `docs/subtasks/028-real-simulator-visual-qa-findings.md` as the source report.

Screenshot evidence:

- `docs/subtasks/screenshots/028-real-simulator-visual-qa/02-history-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/04-growth-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/05-settings-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/09-settings-dark-after-tab.png`

## Goal

Ensure all primary tabs keep scroll content inside readable safe areas:

- top content must not render under the status bar or Dynamic Island;
- bottom content must remain readable above the floating Tab bar and home indicator;
- empty states, long AI audit rows, Growth bottom cards, and History detail content must all have enough resting-space at the bottom.

## Non-Goals

Do not redesign:

- cards;
- colors;
- typography;
- app icon;
- tab icons;
- Today workflow;
- History evidence semantics;
- Project or Growth data semantics;
- Prompt, GLM, or AI retry behavior.

Do not touch:

- GRDB imports or repositories;
- migrations;
- `PromptProvider`;
- `LLMClient`;
- parser logic;
- state-machine behavior.

## Current Root-Cause Hypothesis

The app uses several fixed bottom paddings:

- `FeatureContainer` uses `.padding(.bottom, 120)` for History / Growth / Settings.
- `ProjectsView` uses a separate `.padding(.bottom, 120)`.
- `TodayView` uses `.padding(.bottom, 112)` plus a bottom `safeAreaInset`.
- Secondary screens use lower fixed padding values.

Fixed padding is not robust enough across simulator safe-area combinations and floating Tab bar behavior. The shared layout should reserve bottom space in a consistent way, preferably through shared layout constants or safe-area-aware bottom insets. The fix should reduce duplicated magic numbers.

## Expected User Behavior

1. User opens Today.
   - Header and current step are readable.
   - Bottom action row and tab bar do not make the last content look clipped.

2. User opens History.
   - The day detail never starts under the status / Dynamic Island area.
   - Search, filters, repair rows, raw input, and bottom evidence sections remain readable.

3. User opens Projects.
   - The project board keeps its full-width background and does not regain side gutters.
   - Last project card is readable above the Tab bar.

4. User opens Growth.
   - Growth bottom cards are not hidden by the Tab bar.
   - Empty or insufficient-evidence states remain readable.

5. User opens Settings.
   - AI audit rows are readable above the Tab bar.
   - Dark mode keeps the same safe layout.

## Expected Write Set

Preferred write set:

- `Sources/Features/FeatureTabs.swift`
- `Sources/Features/Today/TodayView.swift`

Optional only if it clearly reduces duplication:

- `Sources/DesignSystem/Theme.swift`

Documentation updates are allowed only for:

- `docs/subtasks/029-safe-area-floating-tab-progress.md`

Do not edit any persistence, prompt, parser, or test fixture files.

## Acceptance Criteria

- App builds for iPhone 17 simulator.
- Primary tabs no longer show content under the status / Dynamic Island area in normal entry states.
- Primary tabs no longer show bottom content obscured by the floating Tab bar in resting scroll positions.
- The fix is centralized enough that `FeatureContainer` users do not each need local magic-number bottom padding.
- Projects keeps its full-width page background and does not introduce side gutters.
- Today keeps its bottom action row behavior and does not create double bottom spacing that makes the flow feel detached.
- No prompt, persistence, or AppStore orchestration behavior changes.

## Verification Commands

Worker should run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

Codex manager will perform fresh verification after handoff, including simulator screenshot review.

## Handoff Requirements

At `HANDOFF`, report:

- final status token;
- files changed;
- root-cause explanation;
- exact build command result;
- exact diff-check result;
- any visual state that still needs Codex simulator confirmation.
