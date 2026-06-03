# Subtask 009: Growth Attribution Layer PRD

## Goal

Make Growth explain why a metric changed instead of displaying unsupported numbers.

Growth is an attribution ledger backed by evidence.

## Write Scope

- `Sources/Domain/Models.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/MockLLMClient.swift`
- `Sources/Services/TodayAIResponseParser.swift` or a new parser file
- `Sources/Features/FeatureTabs.swift`

Do not change Settings or GLM API storage in this subtask.

## Requirements

- Expand `MetricSnapshot` to include previous values, deltas, reasons, evidence refs, and insufficient-evidence state.
- Add `MetricContribution` domain model and persistence.
- Add repository methods for latest snapshot and snapshot contributions.
- Growth overview must not display scores when:
  - complete daily loops < 3
  - snapshot has no contributions
  - contribution source ids are missing
- Metric detail must show:
  - current value
  - previous value
  - delta
  - reason
  - positive contributions
  - negative contributions
  - source links
  - next training focus
- Metric current value must be reconstructable from previous value plus accepted contribution deltas.
- User can mark a contribution inaccurate/dismissed.

## Acceptance Criteria

- Growth no longer shows preview metric values as real data.
- Every displayed metric delta has at least one contribution with source id.
- Contribution detail can navigate to the source evidence path.
- User can answer why a metric changed by inspecting the contribution ledger.
- Insufficient evidence state is clear and visually calm.
- Build succeeds.
