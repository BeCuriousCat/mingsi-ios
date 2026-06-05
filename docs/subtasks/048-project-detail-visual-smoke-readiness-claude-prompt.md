# Claude Prompt: Subtask 048 Project Detail Visual-Smoke Readiness Audit

You are a bounded read-only audit worker for Codex. Codex owns product judgment, visual taste, final acceptance, and any later implementation.

Invoke and follow the Claude skill `codex-delegated-worker` if it is available.

## Workspace

You are running in the isolated worker worktree created by `scripts/claude_delegate.sh`.

## Read Before Auditing

Read these files first:

- `docs/subtasks/048-project-detail-visual-smoke-readiness-prd.md`
- `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`

Then inspect only narrow relevant source/doc ranges using `rg` and `sed`:

- `Sources/Features/FeatureTabs.swift`
- `Sources/App/AppStore.swift`
- `Sources/Domain/Models.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/037-project-merge-audit-display-progress.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`
- `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`

Do not read unrelated large files end to end.

## Hard Constraints

- This is a read-only audit of Project Detail visual-smoke readiness.
- Do not edit Swift source files.
- Do not edit Swift tests.
- Do not edit persistence, migrations, repositories, PromptProvider, prompt text, parser, LLM clients, or Keychain.
- Do not invent screenshot evidence.
- If a finding is inferred from code, label it `source-inferred`.
- Keep the diff scoped to:
  - `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md`
  - `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- Do not commit.
- Leave unrelated dirty changes alone and report them.

## Progress Contract

Update `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md` at exactly these checkpoints:

- `START`: before broad source inspection.
- `RED`: list the audit questions and expected findings coverage before writing findings.
- `IMPLEMENTED`: findings file written.
- `TARGETED_VERIFIED`: `git diff --check -- ...` passed or exact failure recorded.
- `HANDOFF`: final status token and summary.

## Required Findings

Create `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md` with:

- `## Summary`
- `## Screenshot Matrix`
- `## Evidence-Backed States`
- `## Visual Risks`
- `## Recommended Follow-Ups`
- `## Non-Goals`
- `## Acceptance Notes`

Answer:

1. Which Project Detail states must Codex screenshot next?
2. Which states are already evidence-backed and which risk looking decorative or unsupported?
3. What source-inferred visual risks should Codex inspect on iPhone 17 light/dark?
4. What are the top 1-3 narrow follow-up implementation candidates if screenshots confirm the risk?
5. What should Codex not change in the next implementation slice?

## Required Verification

Run:

```bash
git diff --check -- docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md
```

## Final Handoff Format

Append `## HANDOFF` to the progress file with exactly one status token:

- `Status: DONE`
- `Status: DONE_WITH_CONCERNS`
- `Status: NEEDS_CONTEXT`
- `Status: BLOCKED`

Also summarize:

- files changed
- audit summary
- verification commands and results
- concerns or follow-ups

