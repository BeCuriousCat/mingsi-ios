# Subtask 023: Visual Smoke Audit Findings

Date: 2026-06-03

Worker: Claude Code, delegated by Codex.

## Audit Environment

- Audit type: code-informed visual and interaction review.
- Simulator visual launch: not performed by Claude Code.
- Evidence type: all findings are `code-inferred`.
- Claude command mode: `claude -p --output-format stream-json --verbose --permission-mode dontAsk --model glm-4.6`.
- Notes: Claude was instructed not to write in the dirty manager worktree. Codex copied the handoff into this file after Claude returned `DONE_WITH_CONCERNS`.

## Per-Tab Status

| Tab | Status | Notes |
| --- | --- | --- |
| Today | PASS | Bottom padding and state-machine layout appear to avoid tab bar overlap. |
| History | CONCERN | Advanced filter animation suppression exists, but real simulator interaction should still verify dropdown and calendar clipping. |
| Projects | CONCERN | Evidence foundations exist, but merge audit and project evidence hierarchy still need visual/taste review. |
| Growth | PASS | Metric detail and evidence attribution paths appear present. Dark-mode contrast still needs simulator visual confirmation. |
| Settings | CONCERN | AI audit list is flat and not scalable for many prompt runs. |

## Severity-Ranked Findings

### High: Settings AI Audit List Scalability

- Evidence type: `code-inferred`
- Location: `Sources/Features/FeatureTabs.swift`, `promptAuditCard`
- Issue: AI audit rows are rendered in one flat list with `ForEach(store.recentPromptRuns)`. This is acceptable at small counts, but does not scale when the user has many failed or retryable calls.
- Reproduction steps:
  1. Create enough PromptRun records to exceed a comfortable visible list.
  2. Open Settings.
  3. Inspect the AI call audit section.
  4. Observe that successful and failed runs are not grouped or collapsible.
- Suggested owner decision: `fix now`
- Codex acceptance: accepted as the next best bounded implementation slice. Keep the implementation local to Settings UI and AppStore query limits; do not change PromptRun persistence schema.

### Medium: Project Merge Audit Display Hierarchy

- Evidence type: `code-inferred`
- Location: `Sources/Features/FeatureTabs.swift`, project merge review section and row components.
- Issue: Merge candidates expose source/target and evidence counts, but the visual hierarchy may not clearly communicate rationale, confidence, and overlapping evidence significance.
- Reproduction steps:
  1. Generate or load at least two active projects with a merge candidate.
  2. Open Projects.
  3. Inspect the merge review UI.
  4. Check whether the user can quickly answer why these projects should or should not merge.
- Suggested owner decision: `needs product decision`
- Codex acceptance: partially accepted. This needs visual review and product judgment before implementation, so it is not the next delegated coding slice.

### Medium: History Advanced Filter Chip Truncation

- Evidence type: `code-inferred`
- Location: `Sources/Features/FeatureTabs.swift`, `historyFilterMenu`
- Issue: The stable chip frame intentionally truncates long project names. This fixes bounce but can hide meaningful context for long project names.
- Reproduction steps:
  1. Create a project with a long abstract name.
  2. Link history evidence to it.
  3. Open History advanced filters.
  4. Select that project and inspect the selected chip label.
- Suggested owner decision: `backlog`
- Codex acceptance: accepted as backlog. The bounce/clipping fix is higher priority; full long-name handling can wait unless user reports it.

### Low: Growth Metric Bar Range Assumption

- Evidence type: `code-inferred`
- Location: `Sources/Features/FeatureTabs.swift`, `TappableMetricRow`
- Issue: Progress bar display appears to clamp against a 5-point metric range. This is likely correct if the metric spec is 0-5, but should be kept aligned with metric definitions.
- Reproduction steps:
  1. Review metric scale definitions.
  2. Load a metric value outside 0...5 if possible.
  3. Inspect Growth row rendering.
- Suggested owner decision: `unable to verify`
- Codex acceptance: keep as low-risk verification item. Do not change until metric model/spec says the range differs.

### Low: Project Evidence Text Truncation

- Evidence type: `code-inferred`
- Location: `Sources/Features/FeatureTabs.swift`, project evidence line components.
- Issue: Long evidence titles are limited to two lines. This is reasonable for list density but may hide some context.
- Reproduction steps:
  1. Link a long daily input or long card title to a project.
  2. Open Project detail.
  3. Inspect evidence timeline rows.
- Suggested owner decision: `backlog`
- Codex acceptance: backlog. It is acceptable for MVP if History drilldown remains available.

## Positive Observations

- Design tokens use dynamic colors for dark mode.
- Main scrolling views use bottom padding intended to avoid tab bar overlap.
- History advanced filter animations were disabled in the recent fix.
- Project and Growth views are intended to be evidence-backed rather than fake dashboards.
- Backgrounds and interior padding generally follow the calm native design direction.

## Top 3 Recommended Next Fixes

1. Add collapsible grouping to Settings AI audit list.
2. Improve Project merge candidate visual hierarchy after a product-level display decision.
3. Run real simulator dark-mode visual confirmation, especially Growth detail and Settings.

## Handoff Status

Final token: `DONE_WITH_CONCERNS`

Claude summary:

- The app has solid visual foundations for MVP.
- The main accepted concern is Settings AI audit scalability.
- Project merge display remains a product/taste decision.
- The audit was code-informed, not simulator-confirmed.
