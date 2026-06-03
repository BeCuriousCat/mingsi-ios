# Subtask 028: Real Simulator Visual QA

Date: 2026-06-03

Owner: Codex manager

## Goal

Run a real iPhone 17 simulator visual smoke QA for MingSi after Subtask 027, using actual app screenshots instead of code-only inspection.

The output is a prioritized visual/interaction findings list and a decision on the next bounded implementation slice.

## Source Documents

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/ux-flow.md`
- `docs/agent-delegation-log.md`
- `docs/verification-log.md`

## In Scope

- Build, install, and launch the app on iPhone 17 simulator.
- Capture screenshots for Today, History, Projects, Growth, and Settings.
- Check both light and dark appearance if simulator tooling allows it.
- Inspect tab safe areas, scroll behavior, card density, contrast, text sizing, and empty/error states visible with current local data.
- Pay special attention to:
  - History repair UI from Subtask 027.
  - Settings AI audit readability and long-list behavior.
  - Projects and Growth evidence-first presentation.
  - Dark mode readability.

## Out Of Scope

- No broad UI redesign during QA.
- No schema, prompt, LLM, or persistence changes.
- No App Store, server proxy, or account work.
- No fake data injection into production persistence to make screenshots look better.
- No visual acceptance based only on source-code reading.

## QA Method

1. Confirm working tree status and do not touch unrelated dirty files.
2. Build app for iPhone 17 simulator.
3. Install and launch the app.
4. Capture screenshots for the five tabs.
5. If possible, switch simulator appearance to dark mode and recapture key tabs.
6. Record findings in `docs/subtasks/028-real-simulator-visual-qa-findings.md`.
7. Update progress, stage progress, verification log, and delegation log as needed.

## Acceptance Evidence

- Screenshot paths are recorded.
- Findings classify each issue as:
  - `P0`: blocks usable alpha testing
  - `P1`: materially hurts core loop
  - `P2`: polish or follow-up
- Each P0/P1 finding references the visible screen and expected correction.
- The next implementation slice is explicitly chosen or rejected.

## Delegation Policy

Claude Code may be used only for read-only source inspection or a bounded follow-up implementation after Codex reviews screenshots.

Codex owns final visual taste decisions and screenshot acceptance.
