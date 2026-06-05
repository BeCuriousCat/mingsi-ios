# Subtask 049 Findings: Project Detail Real Simulator Visual QA

Date: 2026-06-06

## Summary

Codex captured the full Subtask 048 Project Detail fixture matrix on a real iPhone 17 simulator using the Debug-only variant selector added in Subtask 057.

Coverage:

- 10 Project Detail states.
- Light and dark mode for each state.
- 20 new screenshots, `18` through `37`, under `docs/subtasks/screenshots/049-project-detail-real-simulator-visual-qa/`.

The screenshots confirm that the Debug-only fixture path can open Project Detail directly for all variants. They also confirm several source-inferred visual risks from Subtask 048. The next implementation slice should be narrow and display-only.

## Screenshot Matrix Captured

- `18-project-detail-nil_project-light.png`
- `19-project-detail-nil_project-dark.png`
- `20-project-detail-minimal-light.png`
- `21-project-detail-minimal-dark.png`
- `22-project-detail-normal-light.png`
- `23-project-detail-normal-dark.png`
- `24-project-detail-accepted_insight-light.png`
- `25-project-detail-accepted_insight-dark.png`
- `26-project-detail-pending_insight-light.png`
- `27-project-detail-pending_insight-dark.png`
- `28-project-detail-merge_history-light.png`
- `29-project-detail-merge_history-dark.png`
- `30-project-detail-long_timeline-light.png`
- `31-project-detail-long_timeline-dark.png`
- `32-project-detail-long_name-light.png`
- `33-project-detail-long_name-dark.png`
- `34-project-detail-sparse_next_bet-light.png`
- `35-project-detail-sparse_next_bet-dark.png`
- `36-project-detail-generating_insight-light.png`
- `37-project-detail-generating_insight-dark.png`

## Confirmed Findings

### F1: Status chip still uses English raw value

Confirmed in all inspected states. The Project Detail header shows `active` while the Projects board uses Chinese status labels. This is a visible localization mismatch and should be fixed with a display-only change.

Severity: Low.

Recommended fix: use `ProjectStatus.chineseTitle` in Project Detail header, with `活跃` as the nil-project fallback.

### F2: Dark summary surfaces are too close to pure black

Confirmed in dark screenshots, especially `23-project-detail-normal-dark.png`, `33-project-detail-long_name-dark.png`, and `37-project-detail-generating_insight-dark.png`.

The page background is warm dark, while `summarySurface()` reads as near-black. Text remains readable, but the surface tone feels heavier and cooler than the rest of MingSi's dark design system.

Severity: Medium.

Recommended fix: add a Project Detail surface treatment using `DS.cardBackground` or adjust `summarySurface()` only where Project Detail uses it. Avoid broad theme changes until other tabs are rechecked.

### F3: Thinking-change empty state still looks like real content

Confirmed in sparse and nil/minimal states. The copy is accurate, but the permanent card surface makes `证据不足` look like a dashboard result rather than absence of evidence.

Severity: Medium.

Recommended fix: hide the thinking-change card when there is no accepted insight and no before/after evidence, or demote it to a quieter inline evidence note.

### F4: Long timeline dominates the first viewport

Confirmed in `30-project-detail-long_timeline-light.png` and `31-project-detail-long_timeline-dark.png`. The page renders many progress rows with no first-viewport count limit or expansion affordance.

Severity: Medium for long-lived projects.

Recommended fix: cap the first render to a small number of entries and provide an explicit expand affordance.

### F5: Long project name wraps and remains readable, but header becomes visually heavy

Confirmed in `32-project-detail-long_name-light.png` and `33-project-detail-long_name-dark.png`.

The long name wraps without clipping. The fixed left accent bar no longer aligns with the full multi-line title height, but this is less severe than the status/surface/timeline findings.

Severity: Low.

Recommended fix: defer unless a broader Project Detail polish pass is already touching header layout.

### F6: Floating tab overlaps lower first-viewport content in some states

Visible in several first-viewport captures, especially loading and long-timeline states. This does not prove bottom content is trapped, because the page may still scroll above the tab bar, but 049 has not yet captured bottom-scroll evidence for Project Detail.

Severity: Medium until bottom-scroll evidence exists.

Recommended next step: either capture Project Detail bottom-scroll evidence or include Project Detail bottom padding in the narrow display-only follow-up if the implementation is already scoped to `FeatureTabs.swift`.

## Not Confirmed Or Lower Priority

- Project Tiny Chip contrast appears readable in inspected dark screenshots. The fill is subtle, but text and icon contrast are acceptable for alpha.
- Long title does not clip or overlap the Dynamic Island/status area.
- Pending/accepted/merge states are reachable, but some lower sections are below the first fold, so first-viewport screenshots alone do not fully verify those lower sections.

## Recommended Follow-Up Slice

Create a narrow Project Detail display-polish subtask. Candidate scope:

- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift` only if a local Project Detail surface modifier cannot be done cleanly in `FeatureTabs.swift`

Acceptance target:

- Status chip uses Chinese labels.
- Dark Project Detail card surfaces align with MingSi warm dark tone.
- Pure empty thinking-change card is hidden or demoted.
- Long timeline does not overwhelm the first viewport.
- Project Detail bottom content can scroll above the floating tab bar.

Do not change:

- AppStore orchestration
- Persistence, migrations, repositories
- PromptProvider, parser, LLM clients, Keychain
- Project domain semantics
- ProjectInsight generation or feedback behavior
