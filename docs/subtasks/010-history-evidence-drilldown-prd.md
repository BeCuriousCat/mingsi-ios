# Subtask 010: History Evidence Drilldown PRD

## Goal

Make History the shared evidence layer for Today, Projects, and Growth.

History must answer one product question clearly:

- "This claim changed my project/growth view; what daily evidence caused it?"

## Write Scope

- `Sources/Domain/Models.swift`
- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/Features/FeatureTabs.swift`
- Focused tests under `Tests/Features` or `Tests/Services` when repository behavior changes.

Do not implement new Project/Growth persistence here; consume the repositories if they already exist.
Do not redesign Today.
Do not add decorative Project/Growth mock data.

## Requirements

- History day detail must show:
  - raw input collapsed by default
  - confirmed cards
  - selected lens
  - reflection questions and answers
  - main quest and completion criteria
  - verification result
  - saved principles
  - linked projects
  - linked growth contributions
- Deep-link routing must support:
  - Growth contribution -> History day detail -> specific source
  - Project progress signal -> History day detail -> specific source
  - Project thinking before/after -> History day detail -> specific source
- Non-Today tabs must show a compact Resume Today affordance when the daily loop is incomplete.
- Full page background must cover safe area; inner content can be constrained without white side gutters.

## Data Requirements

- Extend `HistoryRecord` only if needed to include:
  - `projectLinks: [ProjectLink]`
  - `growthContributions: [MetricContribution]`
- Add repository read helpers only when required by the History evidence flow:
  - `ProjectLinkRepository.links(forSourceIds:)`
  - `MetricContributionRepository.contributions(forDailyEntryId:)`
- Source-id matching for a History day should include:
  - `DailyEntryDraft.id`
  - every `ThinkingCard.id`
  - every `Quest.id`
  - `Verification.id` when present
  - every `PrincipleAsset.id`
- Growth contribution day matching must use `MetricContribution.sourceDailyEntryId`.
- Do not infer or fabricate project links if none exist.
- Do not show Growth contributions with `candidateStatus != accepted` or `userFeedback == inaccurate/dismissed`.

## Interaction Requirements

- History top area:
  - date selector remains available through the calendar button
  - show a compact evidence summary count, not a large dashboard score
- Day detail sections:
  - "原始输入" is collapsed by default with a disclosure control
  - "卡片" groups confirmed cards first and marks excluded cards quietly if displayed
  - "透镜与追问" shows selected lens plus answered questions; unanswered questions can be muted
  - "明日任务" shows main quest first, then side/observation quests
  - "昨日验证" shows completion, value rating, calibration note, issue, and recommendation
  - "原则资产" shows saved principles with trigger and criteria
  - "项目证据" shows project links only when real links exist
  - "成长贡献" shows accepted metric contributions only when real contributions exist
- Deep-link highlight:
  - Add a lightweight in-memory route/highlight model if useful.
  - When Growth or Project routes to History, select the source day and visually mark the matching source section.
  - If exact source is unavailable, select the day and show a small "未定位到具体证据" fallback.
- Resume Today affordance:
  - On History, Projects, and Growth, show a compact row/button when `store.hasResumeableLoop` is true.
  - The action switches `store.selectedTab` to `.today`.
  - The affordance must not cover content or tab bar.

## Visual Requirements

- Use the existing warm paper / ink / graphite design language.
- Avoid purple, blue AI gradients, glassmorphism, neon glow, and giant centered metrics.
- History should feel like an evidence notebook:
  - calm date header
  - clear section rhythm
  - small source markers
  - readable body text
- Repeated evidence items can use cards.
- Do not nest cards inside cards.

## Acceptance Criteria

- User can inspect why any Project/Growth claim exists.
- Raw transcript is available but not the dominant visual object.
- History can filter or visually group by cards, quests, verifications, principles, projects, and growth evidence.
- No tab content overlaps the tab bar.
- Build succeeds.
- Existing tests pass.
- New repository helpers have tests proving:
  - project links can be loaded by source ids
  - growth contributions can be loaded by source day and exclude rejected/inaccurate/dismissed items where appropriate
