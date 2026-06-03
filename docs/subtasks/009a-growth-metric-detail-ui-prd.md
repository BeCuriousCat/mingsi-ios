# Subtask 009A: Growth Metric Detail UI PRD

## Goal

Make Growth explain a metric change in the UI.

The user must be able to answer:

- Why is this metric the current value?
- What changed versus the previous period?
- Which events increased it?
- Which events decreased it?
- Which evidence can I inspect?
- What should I train next?

## Write Scope

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift` only if needed for view state or loading contributions.
- `Sources/DesignSystem/Theme.swift` only if a small reusable semantic color/surface is needed.
- `Tests/Services/PersistenceCoreTests.swift` only if repository behavior needs additional coverage.
- `docs/subtasks/009a-growth-metric-detail-claude-progress.md`

Do not change:

- Settings.
- GLM client/API key storage.
- Persistence migration schemas unless absolutely required.
- Today flow.
- Vendor code.

## Product Requirements

- Growth Overview lists the five metrics as tappable rows when `snapshot.canDisplayScores == true`.
- Tapping a metric opens Metric Detail.
- Metric Detail shows:
  - metric title
  - current value
  - previous value
  - delta
  - metric reason
  - positive contribution events
  - negative contribution events
  - source type/source id/source day
  - next training focus
- If a metric has no accepted contributions, detail must show a calm insufficient-evidence state, not a blank chart or fake number.
- Contribution events must separate positive and negative signals.
- Contribution events with `.inaccurate` or `.dismissed` feedback must not be presented as accepted evidence.
- The UI may show source ids as local evidence references in this slice; deep navigation to highlighted History detail can be a follow-up.

## Data Rules

- Use existing `MetricSnapshot` and `MetricContribution`.
- Use `snapshot.metricReasons[metric.rawValue]` as the primary reason.
- Current/previous/delta values come from `MetricSnapshot`.
- Positive/negative grouping comes from `MetricContribution.direction`.
- Accepted evidence means:
  - `candidateStatus == .accepted`
  - `userFeedback != .inaccurate`
  - `userFeedback != .dismissed`
  - non-empty `sourceId`

## Design Requirements

- Use a working-surface layout: dense, quiet, evidence-first.
- No purple/blue gradient, neon glow, glassmorphism, or generic AI visual effects.
- No giant centered score.
- No equal three-card dashboard composition.
- Use restrained ink/paper surfaces and one accent at a time.
- Metric rows should feel like ledger rows, not achievement badges.
- Detail view should read as an explanation path:

```text
Metric -> Change -> Why -> Positive evidence -> Negative evidence -> Next training focus
```

## Acceptance Criteria

- Build succeeds.
- Growth Overview does not show metric rows when evidence is insufficient.
- Growth Overview metric rows open a detail sheet or navigation destination.
- Metric Detail shows current, previous, delta, reason, positive events, negative events, and next focus.
- Metric Detail has an insufficient-evidence fallback for metrics without accepted contributions.
- UI remains full-width within the existing `FeatureContainer`; no white side gutters or Tab bar overlap.
- Claude Code progress is recorded in `docs/subtasks/009a-growth-metric-detail-claude-progress.md`.
