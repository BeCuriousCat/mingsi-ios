# Claude Code Prompt: Subtask 040 Project Overview Hierarchy Audit

You are Claude Code working as a bounded read-only audit worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and any future implementation decision. You own only this scoped audit and findings document.

## Read First

Read:

- `docs/subtasks/040-project-overview-hierarchy-audit-prd.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-progress.md`
- `docs/mvp-current-goal.md`
- `docs/mvp-stage-progress.md`
- `docs/implementation-gap-audit.md`
- `docs/architecture-decisions.md`
- `docs/prd.md`
- `docs/ux-flow.md`

Then update `docs/subtasks/040-project-overview-hierarchy-audit-progress.md` with `START` before broad source inspection.

## Source Inspection Rules

Use `rg` before reading source ranges. Do not read all of `FeatureTabs.swift` at once.

Start with:

```bash
rg -n "struct ProjectsView|ProjectDetailView|ProjectEvidenceBoardRow|ProjectProgressSignalRow|ProjectMergeCandidateReviewRow|ProjectInsight|projectEvidence|mergeAudit" Sources/Features/FeatureTabs.swift Sources/App/AppStore.swift Tests
```

Then read only targeted ranges around relevant symbols.

## Progress Contract

Update `docs/subtasks/040-project-overview-hierarchy-audit-progress.md` at exactly:

- `START`: after reading PRD/progress and before broad source inspection.
- `RED`: for this audit, record the suspected product gap or missing clarity that requires the findings document. If no tests are run, say `not run - read-only audit`.
- `IMPLEMENTED`: after creating the findings document.
- `TARGETED_VERIFIED`: after running the required `git diff --check`.
- `HANDOFF`: final report with one status token.

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Allowed Writes

Only write:

- `docs/subtasks/040-project-overview-hierarchy-audit-progress.md`
- `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`

Do not edit Swift source files, tests, project files, assets, screenshots, migrations, repositories, prompt files, product docs, or git configuration.

Do not commit.

## Audit Questions

Answer from current repo evidence:

1. What does the Projects tab currently show at the top level?
2. What does Project Detail currently show, in what hierarchy?
3. Which existing sections already have strong source evidence?
4. Which sections are hard to scan, duplicated, or visually over-weighted?
5. Which project progress or thinking-change claims are correctly gated by evidence?
6. Which UI text risks sounding like unsupported summary or decorative dashboard copy?
7. Which next implementation slice would improve Project overview hierarchy without changing Project semantics?
8. Which files and helpers would that slice touch?
9. Which tests can prove the display/helper behavior?
10. Does this slice fit Claude Code implementation, or should Codex own it because it requires product taste?

## Required Findings File

Create `docs/subtasks/040-project-overview-hierarchy-audit-findings.md` with:

- Summary.
- Current Projects top-level map with file/function references.
- Current Project Detail hierarchy map with file/function references.
- Evidence-backed sections and their source records.
- Usability hierarchy problems ordered by severity.
- Recommended next bounded implementation slice.
- Proposed write set for that slice.
- Proposed tests for that slice.
- Delegation recommendation.
- Explicit non-goals.

## Required Verification

Run:

```bash
git diff --check -- docs/subtasks/040-project-overview-hierarchy-audit-progress.md docs/subtasks/040-project-overview-hierarchy-audit-findings.md
```

Do not claim success unless you ran and read the command output.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- files changed;
- verification command and result;
- recommended next implementation slice;
- concerns or non-goals.
