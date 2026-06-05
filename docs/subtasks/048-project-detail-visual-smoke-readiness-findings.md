# Subtask 048 Findings: Project Detail Visual-Smoke Readiness Audit

Date: 2026-06-06

All observations are `source-inferred` unless stated otherwise. No runtime screenshots were produced.

## Summary

Project Detail has a solid evidence foundation: progress signals, evidence timeline, project insights, and merge audit all link to real History records and require user confirmation. Subtask 041 successfully restructured the hierarchy into three visual tiers and fixed the thinking-change headline accuracy. However, several visual risks remain before the page is ready for confident alpha use: the thinking-change section always renders as a card surface even when it only explains the absence of data; the status chip in the detail header uses the English raw value when no persisted project exists; the evidence timeline has no count limit for long-lived projects; and no iPhone 17 screenshots exist yet for any populated Project Detail state. Codex should screenshot 8-10 distinct states in light/dark mode before deciding whether to implement any of the 3 narrow follow-up candidates identified below.

## Screenshot Matrix

The following states must be captured on iPhone 17 simulator in both light and dark mode:

| # | State | Why | Key Visual Concerns |
|---|-------|-----|---------------------|
| 1 | Project Detail with nil `project` (only board item, no persisted Project record) | Tests fallback behavior when only `ProjectEvidenceBoardItem` exists | Status chip shows "active" in English instead of "活跃"; overview section hidden; thinkingChangeSection shows "证据不足" |
| 2 | New active project with populated goal/successCriteria but 0-1 evidence links | Minimal populated state | overviewSection shows 2-3 fact lines; progressSignalsSection hidden; thinkingChangeSection card visible with "证据不足" |
| 3 | Active project with 3-5 evidence links and derived progress signals | Normal usage state | progressSignalsSection shows signal rows; overviewSection includes nextBet; evidence timeline shows entries |
| 4 | Active project with accepted `ProjectInsight` records | Insight narrative state | projectInsightSection shows "已确认叙事" with `ProjectAcceptedInsightCard`; thinkingChangeSection shows "等待确认洞察" |
| 5 | Active project with pending `ProjectInsight` awaiting review | Review affordance state | projectInsightSection shows "待你判断" with accept/inaccurate/dismiss buttons |
| 6 | Active project with non-empty `mergeHistory` | Merge audit state | mergeAuditSection visible with trimmed history lines |
| 7 | Active project with 10+ evidence links | Long timeline state | evidenceTimeline dominates the page; no pagination or "show more" affordance |
| 8 | Active project with very long name (>20 chars) | Text overflow | Header serif 28 bold wraps; left accent bar fixed at height 62 may not match wrapped text height |
| 9 | Project with all overview fields nil except digest-derived nextBet | Sparse-but-derivced state | overviewSection shows only nextBet line; rest is hidden |
| 10 | AI insight generation in progress (isGeneratingProjectInsights == true) | Loading state | ProgressView + "正在根据历史证据生成洞察" text |

Light/dark double for all 10 states = 20 screenshots.

## Evidence-Backed States

### Strongly Evidence-Backed

1. **progressSignalsSection**: Each `ProjectProgressSignalRow` has `sourceId`, `sourceType`, `dailyEntryId` and deep-links to History. Signal kinds are derived from `ProjectLink.linkType`. Hidden when `digest.progressSignals.isEmpty`. Source: `FeatureTabs.swift:3526-3547`.

2. **evidenceTimeline**: Every `ProjectEvidenceLine` links to a real History record via `store.navigateToHistoryDeepLink`. Entry title resolved from actual card/quest/verification/principle in the record. Source: `FeatureTabs.swift:3563-3581`.

3. **projectInsightSection**: Insights generated from confirmed project evidence, stored with `sourceRefs`, require user feedback (accepted/inaccurate/dismissed) before entering narrative. Generation message, loading state, accepted, pending, and empty states are all conditionally rendered. Source: `FeatureTabs.swift:3447-3523`.

4. **mergeAuditSection**: Only shown when `project.mergeHistory` has non-empty trimmed lines. Data from confirmed merges. Source: `FeatureTabs.swift:3431-3445`.

### Weakly Evidence-Backed

1. **overviewSection**: Now conditionally renders fact lines (Subtask 041 fix). Only real data appears. However, the section is hidden entirely when `projectOverviewFactLines` returns empty — which happens for nil project with no digest data. This is correct behavior but means a board-only project shows a very sparse detail page. Source: `FeatureTabs.swift:3410-3429`.

2. **thinkingChangeSection**: Always renders as a `.summarySurface()` card with headline + body text. The headline now correctly distinguishes "证据不足" from "等待确认洞察" (Subtask 041 fix). However, this section never hides — it always shows a card explaining why there's no real content. For a user scanning the page, this card looks like content but is purely explanatory. Source: `FeatureTabs.swift:3549-3561`.

3. **detailHeader status chip**: Uses `project?.status.title ?? "active"`. The `title` property on `ProjectStatus` returns the English raw value ("active", "watching", "paused", "archived"), while the status filter on the Projects board uses `chineseTitle` ("活跃", "关注中", "暂停", "已归档"). When `project` is nil, the chip shows the English string "active" which is inconsistent with the Chinese UI language everywhere else. Source: `FeatureTabs.swift:3401`, `FeatureTabs.swift:4104-4112`.

## Visual Risks

### VR-1: thinkingChangeSection always renders as a card (source-inferred)

**Location**: `FeatureTabs.swift:3549-3561`

**Risk**: The section always appears with `.summarySurface()` treatment (white/system card with border). On a page that groups real evidence-backed sections into three tiers, having a permanent "no data yet" card in Tier 2 adds visual noise. Users may interpret the card as having real content and then feel the page is decorative.

**Severity**: Medium. The copy is accurate post-Subtask-041, but the always-visible card surface creates a "dashboard with missing data" feel that ADR-008 explicitly warns against.

**Dark-mode concern**: `summarySurface()` uses `Color(.systemBackground)` which is white in light mode and near-black in dark mode. This should be verified on simulator — it may create too-strong contrast against the warm `DS.background` dark tone (RGB 0.080, 0.076, 0.066).

### VR-2: Status chip language inconsistency (source-inferred)

**Location**: `FeatureTabs.swift:3401`

**Risk**: When `project` is nil, the chip shows "active" in English. When `project` exists, it shows the English raw value of the status enum. The Projects board status filter uses `chineseTitle`. This inconsistency means the detail page status is always in English while the board filter is in Chinese.

**Severity**: Low. Only affects users who navigate to a board item that has no persisted Project record. But it's a visible text inconsistency.

### VR-3: evidenceTimeline no count limit (source-inferred)

**Location**: `FeatureTabs.swift:3563-3581`

**Risk**: `ForEach(item.sortedEntries, id: \.link.id)` renders all evidence links. For a project accumulated over weeks or months, this section dominates the page. There is no "show more" affordance or count limit.

**Severity**: Medium for active long-running projects; low for new projects. Subtask 040 identified this as P6 (lower priority), and it was correctly deferred.

### VR-4: Header accent bar fixed height vs. wrapping text (source-inferred)

**Location**: `FeatureTabs.swift:3389-3408`

**Risk**: The left accent bar `RoundedRectangle` has a fixed height of 62pt. The project name uses serif 28 bold with `.fixedSize(horizontal: false, vertical: true)` — so it wraps vertically. For project names longer than ~15 Chinese characters or ~25 Latin characters, the name wraps to 2+ lines while the accent bar stays at 62pt, creating a visual mismatch.

**Severity**: Low. Most project names should be short enough. But worth one screenshot with a long name to verify.

### VR-5: ProjectTinyChip dark-mode contrast (source-inferred)

**Location**: `FeatureTabs.swift:3911-3924`

**Risk**: `ProjectTinyChip` uses `DS.background.opacity(0.85)` as capsule fill. In dark mode, `DS.background` is RGB (0.080, 0.076, 0.066). At 85% opacity, this is a near-black fill on a near-black background. The chip may be barely distinguishable from the page background.

**Severity**: Low. The chip text and icon use `DS.mutedInk` which has sufficient dark-mode contrast. The fill is just subtle background — but worth a screenshot to confirm it's not invisible.

### VR-6: summarySurface vs DS.background tonal mismatch in dark mode (source-inferred)

**Location**: `Theme.swift:215-222`, `FeatureTabs.swift:3364`

**Risk**: `summarySurface()` uses `Color(.systemBackground)` which is pure system black in dark mode. `DS.background` is warm dark (0.080, 0.076, 0.066). `DS.cardBackground` is warm (0.132, 0.126, 0.112). The system black used by `summarySurface` may look cooler/bluer against the warm page background. The page itself uses `DS.background.ignoresSafeArea()`. So in dark mode, cards rendered with `summarySurface` might have a noticeable cool/warm mismatch against the warm background.

**Severity**: Medium. This affects overviewSection, mergeAuditSection, projectInsightSection, and thinkingChangeSection — the majority of the detail page content. A screenshot in dark mode will confirm whether the tonal gap is visible.

## Recommended Follow-Ups

Ranked by impact and narrowness:

### F1: Fix status chip language in detailHeader (narrow, low risk)

**Change**: In `ProjectDetailView.detailHeader`, change `project?.status.title ?? "active"` to `project?.status.chineseTitle ?? "活跃"`.

**Scope**: One line in `FeatureTabs.swift`. No AppStore, persistence, domain, or test changes needed.

**Risk**: Very low. Display-only string change.

### F2: Conditionally hide thinkingChangeSection when no insights and no before/after evidence (narrow, low risk)

**Change**: Wrap `thinkingChangeSection` in a conditional: only show when `digest.hasBeforeAfterEvidence == true` OR when `!store.acceptedProjectInsights.filter({ $0.projectId == item.id }).isEmpty`. When both are false, the section adds no actionable information — the projectInsightSection empty state already explains that evidence accumulation is needed.

**Scope**: `FeatureTabs.swift:3346-3354` (the Tier 2 VStack). One conditional guard.

**Risk**: Low. Display-only. The section content is already correctly conditional in its copy; this just hides the entire card when it's purely explanatory noise.

### F3: Limit evidenceTimeline to first N entries with expansion (narrow, low risk)

**Change**: Show first 5-8 `sortedEntries` in the timeline. If more exist, show a "查看全部 X 条证据" text that expands the list.

**Scope**: `FeatureTabs.swift:3563-3581`. One `@State` variable and a toggle.

**Risk**: Low. Display-only. Does not change evidence data or deep-link behavior.

**Note**: This was P6 in Subtask 040 findings and correctly deferred. Only implement if screenshots confirm it's a real usability issue for long-lived projects.

## Non-Goals

The following are explicitly out of scope for the next implementation slice:

- Any changes to AppStore actions, persistence, migrations, repositories, or Project domain models
- Any changes to `ProjectEvidenceDigest` computation or signal derivation logic
- Any changes to `PromptProvider`, prompt text, parser, LLM clients, or Keychain
- Any changes to Today, History, Growth, or Settings tabs
- Adding new domain models or data types
- Changing ProjectInsight generation, review, or feedback flow semantics
- Changing merge audit display logic (already improved in Subtask 037)
- Adding Active/Watching/Paused/Archived segment filter to Projects top-level (already done in Subtask 044)
- Creating or modifying actual runtime screenshots (this audit is source-inferred only)

## Acceptance Notes

1. This audit is entirely source-inferred. No runtime screenshots were produced or examined. Codex must run real iPhone 17 simulator screenshots in light/dark mode before accepting any visual risk as confirmed.

2. The Subtask 041 hierarchy cleanup is correctly implemented in source: three visual tiers with 28pt inter-tier spacing, conditional overview fact lines, accurate thinking-change headline, and hidden empty progress signals. Visual QA should confirm these look correct on device.

3. The Subtask 044 status filter exists at the Projects board level. It does not affect Project Detail — the detail page always shows the single project regardless of the board filter state. This is correct.

4. `summarySurface()` is the dominant card treatment on Project Detail (used by 5 of 7 sections). Its use of `Color(.systemBackground)` rather than `DS.cardBackground` may create a tonal gap in dark mode. If screenshots confirm this, a follow-up could consider adding a `detailSurface()` modifier that uses `DS.cardBackground` instead.

5. The `projectOverviewFactLines` helper correctly filters nil/empty/whitespace-only values (including the Codex manager fix from Subtask 041). This means the overview section can be completely hidden when no real data exists, which is correct evidence-backed behavior.

6. No unrelated dirty worktree changes were observed during this audit. The worktree status was clean at task start.
