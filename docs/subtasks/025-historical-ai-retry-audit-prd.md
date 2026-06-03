# Subtask 025: Historical AI Retry Audit PRD

Date: 2026-06-03

## Goal

Audit the current implementation for historical AI failure retry and candidate review.

The product requirement is that AI failures are visible, retryable, and auditable. The app already has current-day retry, background repair, PromptRun audit, and History repair rows, but historical cross-day retry is intentionally constrained. Before implementation, Codex needs a precise map of what exists, what is missing, and which next implementation slice can be safely delegated.

## Scope

This is a read-only audit plus document output.

Allowed write set:

- `docs/subtasks/025-historical-ai-retry-audit-progress.md`
- `docs/subtasks/025-historical-ai-retry-audit-findings.md`

Do not edit Swift source files, tests, project files, assets, or product docs.

## Required Questions

Answer these questions from current repo evidence:

1. What current-day AI retry paths exist?
2. What historical PromptRun failure discovery paths exist?
3. What History UI is currently shown for repairable old records?
4. Why is cross-day direct retry currently blocked or unsafe?
5. Which Prompt IDs are repairable today, and under what guards?
6. What data is available to reconstruct a historical retry request?
7. What data is missing for a safe historical retry request?
8. If historical retry succeeds, what output should be produced first: immediate overwrite, candidate draft, or reviewable proposal?
9. Which implementation slice is the safest next step?
10. Which tests should prove that slice?

## Product Constraints

- Historical input must not become permanent dirty data just because an AI call failed.
- Retrying old AI failures must not overwrite confirmed cards, questions, quests, principles, project links, or growth evidence without user review.
- Any AI-generated historical repair result should be reviewable before it becomes durable evidence.
- PromptRun audit must remain visible and source-linked.
- History remains the evidence archive.
- No fake repair success or mock historical data.

## Architecture Constraints

- SwiftUI views must not call `LLMClient` directly.
- SwiftUI views must not import GRDB.
- Repository abstractions must not leak database details.
- Do not introduce a migration in this audit.
- Do not change prompt strategy in this audit.

## Expected Output

Create `docs/subtasks/025-historical-ai-retry-audit-findings.md` with:

- Current implementation map with file and function references.
- Gap list ordered by severity.
- Recommended next bounded implementation slice.
- Proposed acceptance tests for the next slice.
- Risks and non-goals.
- Final recommendation: delegate implementation, Codex-owned implementation, or document/product decision first.

## Verification

This audit does not require xcodebuild unless the worker wants to confirm referenced tests exist.

Required command:

```bash
git diff --check -- docs/subtasks/025-historical-ai-retry-audit-progress.md docs/subtasks/025-historical-ai-retry-audit-findings.md
```

## Handoff Criteria

Handoff is acceptable only when:

- Progress file has `HANDOFF`.
- Findings file exists.
- The findings cite concrete files/functions/tests.
- The recommendation is scoped enough for Codex to accept or reject.
