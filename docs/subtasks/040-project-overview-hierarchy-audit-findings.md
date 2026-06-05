# Subtask 040 Findings: Project Overview Hierarchy Audit

Date: 2026-06-05

## Summary

The Projects tab and Project Detail are evidence-backed and structurally sound, but the current hierarchy has three classes of usability problems: (1) Project Detail shows too many flat sections with equal visual weight, making the page hard to scan for new or casual users; (2) Projects top-level lacks the status segment filter specified in the UX spec; (3) several sections display permanent placeholder text that risks looking decorative rather than clearly conditional. The recommended next slice is a display-only hierarchy restructure of Project Detail that groups related sections into collapsible/conditional regions without changing any data semantics, AppStore actions, or evidence logic.

## Current Projects Top-Level Map

File: `Sources/Features/FeatureTabs.swift`, struct `ProjectsView` (line 1230)

### Structure

```
ProjectsView
  projectHeader (line 1294)
    - "项目" title with subtitle about evidence-backed topics
  ProjectCurrentFocus (line 1262)
    - Shows main quest title + completion criteria
    - "保存为长期议题" button if canCreateProject
  projectsCandidateReviewSection (line 1340)
    - Conditional: pending project candidates + link candidates
    - SectionLabel "待确认候选"
    - ProjectCandidateReviewRow / ProjectLinkCandidateRow
  projectMergeReviewSection (line 1381)
    - Conditional: shown when >=2 items or pending merge candidates
    - SectionLabel "议题治理" with "检查合并" button
    - ProjectMergeCandidateReviewRow
  projectBoard (line 1311)
    - SectionLabel "项目工作台" + count
    - ProjectEvidenceBoardRow for each item
    - ProjectEmptyEvidenceState when empty
```

### Data Flow

- `projectItems` computed property (line 1233): groups `store.historyRecords` by `ProjectLink.projectId`, builds `ProjectEvidenceBoardItem` array, sorted by latest date descending.
- `.task` modifier (line 1285): calls `store.loadHistoryRecords()` and `store.loadPendingProjectMergeCandidates()`.
- No status segment filter exists (active/watching/paused/archived). All projects appear in one flat list.

### Key Types

- `ProjectEvidenceBoardItem` (line 3075): groups entries, computes digest, dominantType, statusLabel, typeSummary.
- `ProjectCurrentFocus` (line 3137): displays main quest as project focus.
- `ProjectEmptyEvidenceState` (line 3184): empty state with guidance.
- `ProjectEvidenceBoardRow` (line 3210): card showing name, status chips, next bet, up to 3 evidence lines.

## Current Project Detail Hierarchy Map

File: `Sources/Features/FeatureTabs.swift`, struct `ProjectDetailView` (line 3274)

### Section Order (all in one flat VStack, spacing: 18)

```
ProjectDetailView
  detailHeader (line 3324)
    - Project name (serif 28 bold)
    - Status chip, evidence count chip, latest date chip
  overviewSection (line 3345)
    - SectionLabel "Overview"
    - ProjectDetailFactLine: 目标, 成功标准, 当前阻塞, 下一步押注, 开放问题, 证据缺口
    - Always shows all 5-6 fact lines (fallbacks: "证据不足", "后续需要用任务和验证补齐成功标准")
  mergeAuditSection (line 3364)
    - Conditional: only when project has mergeHistory with non-empty trimmed lines
    - SectionLabel "合并审计"
  projectInsightSection (line 3380)
    - SectionLabel "项目洞察" with "生成" button
    - Shows generation state, accepted insights, pending insights
    - Empty state: "还没有经过确认的项目洞察..."
  progressSignalsSection (line 3458)
    - SectionLabel "进展信号"
    - Up to 5 ProjectProgressSignalRow, each deep-links to History
    - Empty state: "还没有可解释的项目证据。"
  thinkingChangeSection (line 3485)
    - SectionLabel "思考变化"
    - Always shows "证据不足" as headline
    - Different body text depending on hasBeforeAfterEvidence
    - Never shows actual before/after comparison directly (relies on ProjectInsight)
  evidenceTimeline (line 3501)
    - SectionLabel "Evidence Timeline"
    - All sorted entries as ProjectEvidenceLine, each deep-links to History
```

### Navigation

- `ProjectDetailView` receives `ProjectEvidenceBoardItem` and optional `Project`.
- Edit sheet via toolbar button (ProjectEditorSheet, line 3562).
- `.task(id:)` loads project insights on appear.

## Evidence-Backed Sections and Source Records

| Section | Evidence Source | Source Code Reference |
| --- | --- | --- |
| overviewSection - 目标, 成功标准, 阻塞 | `Project` fields from persistence | `project?.goal`, `project?.successCriteria`, `project?.currentBottleneck` (line 3348-3350) |
| overviewSection - 下一步押注 | `ProjectEvidenceDigest.nextBet` derived from evidence | `digest.nextBet` (line 3351), computed in `Models.swift:1549` |
| overviewSection - 证据缺口 | `ProjectEvidenceDigest.evidenceGapMessage` derived from evidence count/type | `digest.evidenceGapMessage` (line 3357-3358), computed in `Models.swift` |
| progressSignalsSection | `ProjectEvidenceDigest.progressSignals` from ordered evidence | `digest.progressSignals.prefix(5)` (line 3466), each signal has `sourceId`, `dailyEntryId` |
| projectInsightSection | `ProjectInsight` records from persistence, filtered by projectId | `store.acceptedProjectInsights`, `store.pendingProjectInsights` (line 3415-3416) |
| mergeAuditSection | `Project.mergeHistory` from persistence | `mergeAuditDisplayLinesIfNonEmpty(from: project.mergeHistory)` (line 3366) |
| evidenceTimeline | `ProjectEvidenceBoardItem.sortedEntries` from History records | `item.sortedEntries` (line 3504), each entry has `(link, record)` |
| thinkingChangeSection | No direct evidence display; text is always a placeholder | Hardcoded strings (line 3488-3493) |

### Strongly Evidence-Backed

1. **progressSignalsSection**: Each `ProjectProgressSignalRow` has `sourceId`, `sourceType`, `dailyEntryId`, and deep-links to History. Signal kinds (Done, Learned, Newly Blocked, Risk, Next Bet) are derived from `ProjectLink.linkType`. This is well-gated.

2. **evidenceTimeline**: Every entry links to a real History record. `ProjectEvidenceLine` resolves title from the actual card/quest/verification/principle in the record.

3. **projectInsightSection**: Insights are generated from confirmed project evidence, stored with `sourceRefs`, and require user feedback (accepted/inaccurate/dismissed) before entering the narrative.

4. **mergeAuditSection**: Only shown when `mergeHistory` has non-empty trimmed lines. Data comes from confirmed merges.

### Weakly Evidence-Backed

1. **overviewSection**: Shows `digest.nextBet` which is derived from evidence but could show "证据不足" fallback alongside real project fields. The mix of real data and fallback text in the same visual format may confuse scanning.

2. **thinkingChangeSection**: Always shows "证据不足" as a headline, regardless of actual evidence state. For projects with >=2 evidence entries (`hasBeforeAfterEvidence == true`), the body text explains that before/after exists but no confirmed insight has been generated yet. For projects with <2 entries, it explains there is no evidence. However, the headline "证据不足" is the same in both cases, which is misleading when evidence does exist but just hasn't been turned into insights yet.

## Usability Hierarchy Problems (Ordered by Severity)

### P1: thinkingChangeSection always shows "证据不足" headline

- **Location**: `ProjectDetailView.thinkingChangeSection` (line 3485-3499)
- **Problem**: The headline "证据不足" appears even when `hasBeforeAfterEvidence == true`. This is inaccurate and looks like a decorative placeholder.
- **Impact**: Confuses users who have accumulated evidence but haven't generated insights yet. Violates ADR-006 principle that project claims must be evidence-linked.
- **Fix**: Conditional rendering: when `hasBeforeAfterEvidence == true`, show a different headline ("可生成洞察" or similar) and encourage insight generation. When false, show the current placeholder.

### P2: overviewSection always shows 5-6 fact lines with fallback text

- **Location**: `ProjectDetailView.overviewSection` (line 3345-3362)
- **Problem**: All fact lines (目标, 成功标准, 当前阻塞, 下一步押注, 开放问题, 证据缺口) are always visible. When project fields are nil, they show fallback copy like "证据不足" or "后续需要用任务和验证补齐成功标准". This creates visual noise and makes it hard to distinguish which fields have real user-provided data vs. which are placeholders.
- **Impact**: Reduces scanability. A user with 2 real fields and 4 placeholders sees 6 equal-weight lines.
- **Fix**: Only show fact lines where the value differs from the fallback placeholder. Alternatively, visually differentiate placeholder lines (lighter weight, italic) from real data.

### P3: Projects top-level lacks status segment filter

- **Location**: `ProjectsView` (line 1230)
- **Problem**: UX spec (`docs/ux-flow.md`, "Project tab 信息架构") specifies "顶部：Active / Watching / Paused / Archived 分段筛选". Current implementation shows all projects in one flat list with no filtering.
- **Impact**: As project count grows, users cannot quickly find active projects vs. archived ones.
- **Fix**: Add a segment picker filtering `projectItems` by `project?.status`.

### P4: progressSignalsSection empty-state message is weak

- **Location**: `ProjectDetailView.progressSignalsSection` (line 3458-3483)
- **Problem**: When `digest.progressSignals.isEmpty`, shows "还没有可解释的项目证据。" This is fine content but has the same visual weight as real signals.
- **Impact**: Minor. The conditional already works correctly.
- **Fix**: Consider hiding the entire section when empty, or using a lighter visual treatment.

### P5: Project Detail has 7 sections with equal spacing

- **Location**: `ProjectDetailView.body` (line 3284-3298)
- **Problem**: All 7 sections use the same VStack spacing of 18. No visual grouping or hierarchy. The page is a long flat scroll.
- **Impact**: Users must scan the entire page to find relevant information. Overview and progress signals should be visually prominent; merge audit and evidence timeline can be secondary.
- **Fix**: Group sections into visual tiers: primary (overview, progress), secondary (insights, thinking changes), tertiary (merge audit, timeline). Use larger spacing between groups, or collapsible sections for tertiary content.

### P6: Evidence Timeline has no count limit

- **Location**: `ProjectDetailView.evidenceTimeline` (line 3501-3519)
- **Problem**: Shows all `item.sortedEntries` without pagination or "show more" affordance. For projects with many evidence links, this section dominates the page.
- **Impact**: Long projects produce very long detail pages.
- **Fix**: Show first N entries with a "查看全部证据" expansion. This is lower priority because evidence is always correct and linked.

## Recommended Next Bounded Implementation Slice

**Focus**: Restructure Project Detail section hierarchy and fix the thinkingChangeSection headline accuracy issue.

**Rationale**: This is the highest-impact, lowest-risk change. It addresses P1 and P2 (most severe) and partially P5, without changing any data models, AppStore actions, persistence, or evidence logic. It is purely a display hierarchy restructure.

### Specific Changes

1. **Fix thinkingChangeSection headline** (P1): Change "证据不足" to a conditional that reflects actual evidence state:
   - When `hasBeforeAfterEvidence == true`: show "可生成项目洞察" and link to the insight generation button.
   - When `hasBeforeAfterEvidence == false`: show "证据不足" (current behavior).

2. **Conditional overviewSection fact lines** (P2): Only show `ProjectDetailFactLine` rows where the project field is non-nil, OR visually differentiate placeholder rows (muted/italic treatment).

3. **Group sections into visual tiers** (P5 partial):
   - Tier 1 (always visible, prominent): `detailHeader`, `overviewSection`, `progressSignalsSection`
   - Tier 2 (always visible, standard): `projectInsightSection`, `thinkingChangeSection`
   - Tier 3 (conditional, less prominent): `mergeAuditSection`, `evidenceTimeline`
   - Add larger spacing between tiers.

4. **Hide progressSignalsSection when empty** (P4): Only show the section when `digest.progressSignals.isEmpty` is false.

### Do NOT include in this slice

- P3 (status segment filter): Requires adding a state variable and filtering logic. Separate slice.
- P6 (evidence timeline pagination): Lower priority, separate slice.
- Any changes to AppStore, persistence, migrations, PromptProvider, LLMClient, or Project domain models.
- Any changes to evidence computation logic in `ProjectEvidenceDigest`.
- Any new UI components beyond restructuring existing ones.

## Proposed Write Set

| File | Change | Risk |
| --- | --- | --- |
| `Sources/Features/FeatureTabs.swift` | Restructure `ProjectDetailView.body` section grouping; fix `thinkingChangeSection` headline; add conditional fact line display; hide empty progress signals section | Low - display only |
| `Tests/Features/HistoryFeatureTests.swift` | Add tests for any extracted display helper functions (e.g., fact line visibility predicate, thinking change headline logic) | Low |

## Proposed Tests

1. **Test thinkingChangeSection headline logic**: Extract a helper function `projectThinkingChangeHeadline(hasBeforeAfterEvidence:)` and test:
   - Returns "证据不足" when `hasBeforeAfterEvidence == false`
   - Returns non-placeholder text when `hasBeforeAfterEvidence == true`

2. **Test overviewSection fact line filtering**: Extract a helper `projectOverviewFactLines(project:digest:)` that returns only the fact lines with real data, and test:
   - Returns all lines when project has all fields populated
   - Returns only populated lines when some fields are nil
   - Returns minimal set for nil project

3. **Existing tests remain green**: Run `HistoryFeatureTests` to confirm no regressions.

## Delegation Recommendation

**Claude Code implementation is appropriate for this slice.**

Reasons:
- The change is purely display-layer: restructuring existing SwiftUI sections and fixing conditional rendering logic.
- No product taste judgment is needed: the hierarchy grouping follows from the existing evidence strengths already documented above.
- The headline fix is a clear accuracy issue (showing "证据不足" when evidence exists is factually wrong).
- Tests can be written for extracted helper functions.
- No AppStore, persistence, or domain model changes are required.

Codex should review the final diff for visual taste (spacing, grouping feel) but does not need to design the approach.

## Explicit Non-Goals

- Adding Active/Watching/Paused/Archived segment filter to Projects top-level (separate slice, requires state management).
- Changing ProjectEvidenceDigest computation or signal derivation logic.
- Changing AppStore actions, persistence, or migrations.
- Adding evidence timeline pagination or "show more".
- Changing ProjectInsight generation, review, or feedback flow.
- Changing merge audit display logic (already improved in Subtask 037).
- Adding new domain models or data types.
- Any changes to Today, History, Growth, or Settings tabs.
- Any changes to prompts, LLM clients, or parser logic.
