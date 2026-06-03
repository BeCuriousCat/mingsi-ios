# Subtask 023: Visual Smoke Audit PRD

Date: 2026-06-03

## Goal

Run a read-only visual and interaction smoke audit for MingSi on iPhone 17 simulator across the five MVP tabs:

- Today
- History
- Projects
- Growth
- Settings

The audit should find user-facing visual or interaction defects that block a credible personal alpha, especially issues already called out in project docs:

- dark-mode unreadability
- tab bar or safe-area overlap
- awkward side gutters
- dense or template-like panels
- History dropdown/filter clipping
- Project and Growth evidence presentation that still feels unsupported or visually weak
- Settings AI audit scalability and GLM configuration clarity

## Why This Slice Is Read-Only

Visual taste and final UI decisions remain Codex-owned. Claude Code should only gather evidence, screenshots if possible, reproduction steps, and severity-ranked findings. It must not edit code.

## Source Documents

Claude Code must read:

- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`
- `docs/ux-flow.md`
- `docs/verification-log.md`

## Expected Write Set

Only these files may be modified:

- `docs/subtasks/023-visual-smoke-audit-progress.md`
- `docs/subtasks/023-visual-smoke-audit-findings.md`

No Swift, Xcode project, asset, test, or source file edits are allowed.

## Audit Scope

Inspect the current app through build/run evidence where possible:

1. Confirm app builds for iPhone 17 simulator.
2. Launch the app if available in the environment.
3. Inspect each tab in light mode and dark mode where feasible.
4. Exercise the highest-risk visible interactions:
   - Today input and step area.
   - History date/calendar and advanced filters.
   - Projects list and detail/overview areas.
   - Growth metric/report areas.
   - Settings GLM configuration and AI audit list.

If simulator control is unavailable, perform a code-informed audit and clearly mark which findings are not visually confirmed.

## Acceptance Evidence

The final findings file must include:

- Audit environment: Xcode/simulator availability and whether app was visually launched.
- Per-tab status: `PASS`, `CONCERN`, or `BLOCKED`.
- Severity-ranked findings with reproduction steps.
- Whether each finding is visually confirmed or code-inferred.
- Suggested owner decision for each finding:
  - fix now
  - backlog
  - needs product decision
  - unable to verify
- A short list of the top 3 fixes Codex should consider next.

## Non-Goals

- Do not modify UI code.
- Do not change DesignSystem tokens.
- Do not change tests.
- Do not add screenshots unless the environment makes it straightforward.
- Do not invent product requirements beyond the source docs.
