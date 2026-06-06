# Subtask 060 Progress: Fresh Data Alpha Root Visual Pass

Status: CODEX_ACCEPTED

Owner: Codex manager
Delegated implementer: not delegated

PRD: `docs/subtasks/060-fresh-data-alpha-root-visual-prd.md`
Claude prompt: none
Event log: none
Raw log: none

## Manager Setup

- Timestamp: 2026-06-06
- Source state: Subtask 059 root-tab selector is committed in `820e73f Add root tab visual QA selector`.
- Reason: Subtask 059 screenshot review found the booted simulator still had prior visual QA project evidence. This pass removes that residual risk by reinstalling the app before capture.
- Worktree state at setup: clean.
- Implementation path: Codex local simulator verification only; no Swift source changes planned.

## Planned Verification

Commands:

```bash
git status --short
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcrun simctl uninstall booted com.codex.mingsi
xcrun simctl install booted /Users/chenzewei/Library/Developer/Xcode/DerivedData/MingSi-erjzdsaapaoobtcrmiwnfyqrwdqr/Build/Products/Debug-iphonesimulator/MingSi.app
SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=<tab> xcrun simctl launch --terminate-running-process booted com.codex.mingsi MINGSI_VISUAL_QA_TAB
xcrun simctl io booted screenshot docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/<index>-<tab>-<appearance>.png
git diff --check
```

## Results

- `git status --short` before setup showed a clean worktree.
- Debug iPhone 17 simulator build passed with `BUILD SUCCEEDED`.
- Codex uninstalled the app from the booted iPhone 17 simulator before reinstalling the Debug app, clearing the previous app data container.
- Debug app reinstall succeeded.
- Root-tab visual QA launches worked through `SIMCTL_CHILD_MINGSI_VISUAL_QA_TAB=<tab>`.
- Captured Today, History, Projects, Growth, and Settings in light/dark mode.
- Projects root shows a fresh empty/evidence-gated state with `0 个证据项目` and `尚无长期议题证据`; no `Visual QA` fixture project remains.
- History root shows the clean current day with no stale visual QA project evidence.
- Growth dark mode remains readable and evidence-gated.
- Settings dark mode remains readable, and the fresh state shows `还没有 AI 调用记录。`
- No Swift source, test, persistence, prompt, parser, LLM, Keychain, or product semantic changes were made.

## Screenshot Evidence

- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/01-today-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/02-history-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/03-projects-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/04-growth-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/05-settings-light.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/06-today-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/07-history-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/08-projects-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/09-growth-dark.png`
- `docs/subtasks/screenshots/060-fresh-data-alpha-root-visual/10-settings-dark.png`

## Residual Risk

- First-viewport screenshots do not replace a complete interactive Today core-loop walkthrough.
- This pass does not confirm a live GLM failure/retry path; that remains a separate MVP hardening slice.
- Growth/Settings first-viewport screenshots show the floating tab over lower content, but shared scroll reserve was previously accepted in Subtask 029; bottom-scroll evidence was not repeated in this 060 fresh-data pass.

## Manager Acceptance

- Accepted by Codex after fresh screenshot review of Projects, History, Today, Growth dark, and Settings dark.
- Claude Code was not delegated and produced no worker handoff.
- This subtask closes the Subtask 059 residual risk that root-tab screenshots were contaminated by prior visual QA fixture evidence.
