# Subtask 028 Findings: Real Simulator Visual QA

Date: 2026-06-03

## Screenshot Evidence

- `docs/subtasks/screenshots/028-real-simulator-visual-qa/01-today-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/02-history-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/03-projects-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/04-growth-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/05-settings-light.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/07-today-dark.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/08-history-dark.png`
- `docs/subtasks/screenshots/028-real-simulator-visual-qa/09-settings-dark-after-tab.png`

## Findings

### P1: History Can Appear Under The Status/Dynamic-Island Area

Evidence:

- `02-history-light.png`

Observed:

- The History detail content is scrolled such that `原始输入` is partially under the status bar area.
- This is visually jarring and makes History feel unreliable as an evidence archive.

Expected:

- History content should never render beneath the status bar or Dynamic Island.
- Returning to History should preserve scroll position only inside a safe content area.

### P1: Floating Tab Bar Can Cover Bottom Content

Evidence:

- `04-growth-light.png`
- `05-settings-light.png`
- `09-settings-dark-after-tab.png`

Observed:

- Growth bottom content and Settings AI audit rows extend underneath the floating Tab bar.
- The content is technically scrollable, but the visible resting state makes rows look clipped or obscured.

Expected:

- Each tab should reserve enough bottom scroll inset for the floating Tab bar and home indicator.
- The last visible content should be readable above the Tab bar without awkward overlap.

### P2: Settings Dark Mode Placeholder/Disabled Text Contrast Is Low

Evidence:

- `09-settings-dark-after-tab.png`

Observed:

- API Key, Base URL, and model placeholder text is very dim on black input fields.
- This does not block use but feels unfinished.

Expected:

- Placeholder and disabled values should remain legible in dark mode without becoming high-emphasis body text.

### P2: Today Dark Mode Starts From A Mid-Flow Scroll Position

Evidence:

- `07-today-dark.png`

Observed:

- Today screenshot captured after tab switching starts mid-page around the input field and training depth rather than page header.
- This may be expected scroll preservation, but it should be confirmed after the safe-area fix.

Expected:

- Scroll preservation should not hide essential step context when returning to the primary Today flow.

## Next Slice Decision

Proceed with a bounded safe-area/floating-tab layout fix before deeper visual polish.

Candidate Subtask 029:

- Ensure every primary tab's scroll content respects top safe area and floating Tab bar bottom inset.
- Keep the existing visual language.
- Do not redesign cards, colors, or app flow in the same slice.
- After implementation, repeat simulator screenshots for Today, History, Growth, and Settings in light/dark mode.
