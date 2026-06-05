# Subtask 041 PRD: Project Detail Hierarchy Cleanup

Date: 2026-06-05

## Goal

Improve Project Detail scanability using the accepted Subtask 040 audit findings.

This is a display-only cleanup. It must keep Projects evidence-backed and must not change Project semantics, persistence, AppStore actions, prompt behavior, parser behavior, LLM clients, or repository contracts.

## Source

Authoritative source for this slice:

- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`

Accepted findings to implement:

1. `thinkingChangeSection` currently shows `证据不足` even when before/after evidence exists.
2. `overviewSection` shows too many equal-weight fallback rows.
3. Project Detail has a flat section stack with weak grouping.
4. Empty progress signals should not take the same visual weight as real signals.

## Scope

Allowed source files:

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`

Allowed documentation file:

- `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`

Do not edit:

- AppStore
- Domain models except already-existing display helper usage in the allowed file
- Persistence
- GRDB / migrations
- Repositories
- PromptProvider
- Prompt text
- Parser
- LLM clients
- Keychain
- Today / History / Growth / Settings behavior
- Project creation, merge, insight generation, or feedback semantics
- Assets or screenshots

## Required Behavior

1. Add small display helper functions in `FeatureTabs.swift` if needed so behavior can be unit-tested.
2. Fix Project Detail thinking-change copy:
   - If `digest.hasBeforeAfterEvidence == false`, keep a conservative insufficient-evidence message.
   - If `digest.hasBeforeAfterEvidence == true`, do not label the section as `证据不足`; use a copy that says evidence exists but needs a confirmed ProjectInsight before any thinking-change narrative appears.
3. Reduce overview placeholder noise:
   - Real project fields should remain visible.
   - Missing optional project fields should not all appear as equal-weight fact lines.
   - Keep evidence-derived `下一步押注` and `证据缺口` when they have real digest values.
   - Do not invent fallback progress or unsupported summaries.
4. Hide the progress signals section when `digest.progressSignals` is empty.
5. Group Project Detail sections into clearer visual tiers while staying in the existing design system:
   - Primary: header, overview, non-empty progress signals.
   - Secondary: Project insights, thinking change.
   - Tertiary: merge audit, evidence timeline.
   - Do not add new decorative card containers or nested cards.

## Copy Guidance

Suggested thinking-change copy:

- Without before/after evidence:
  - Headline: `证据不足`
  - Body: `当前只有零散项目证据。没有 before / after 来源时，不生成项目洞察，也不编造思考变化。`
- With before/after evidence but no accepted insight:
  - Headline: `等待确认洞察`
  - Body: `已有多条项目证据，可以生成候选洞察；在你确认之前，明思不会自动写入思考变化叙事。`

Worker may adjust wording slightly for native UI fit, but must preserve the semantic distinction.

## Tests

Use TDD. Add focused helper tests before implementation.

Required test coverage:

- Thinking-change headline/copy helper returns an insufficient-evidence headline when there is no before/after evidence.
- The same helper returns a non-`证据不足` headline when before/after evidence exists.
- Overview fact-line helper includes real project fields and omits missing optional placeholders as primary fact lines.
- Overview helper still includes evidence-derived rows when `ProjectEvidenceDigest` has real `nextBet` or `evidenceGapMessage`.

Preferred test file:

- `Tests/Features/HistoryFeatureTests.swift`

If helpers must be internal for testing, keep them small and display-only.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
git diff --check
```

If worker worktree `xcodebuild` is blocked by the known GRDB worktree issue, report `DONE_WITH_CONCERNS` with the exact error and still run `git diff --check`.

## Handoff Criteria

Handoff is acceptable only when:

- Progress file reaches `HANDOFF`.
- Changed files stay inside the allowed write set.
- Required tests exist.
- Worker verification is run or the exact worker infrastructure blocker is recorded.
- No Project semantics or data flow changes are introduced.
