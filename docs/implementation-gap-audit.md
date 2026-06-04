# Implementation Gap Audit

Date: 2026-06-01

Purpose: record the gap between the agreed product spec and the current SwiftUI implementation before more UI work continues.

## Decision

Do not continue polishing Projects and Growth as visual pages unless each new UI element is backed by an evidence model.

The original UI issues were symptoms of a product/data gap:

- Projects looked decorative when the app lacked a user-facing evidence loop.
- Growth looked like a fake dashboard before `MetricContribution` attribution existed.
- History needed to expose source evidence so Projects and Growth could deep-link back to facts.

Current implementation now has the minimum evidence foundation:

- `Project`, `ProjectLink`, `ProjectInsight`, `ProjectMergeCandidate` data concepts exist in the domain and persistence layer.
- History tasks and principles can be manually saved as long-term Project evidence.
- AI can propose project candidates and project links, with user review before durable semantic changes.
- ProjectInsight can be generated from confirmed project evidence and reviewed by the user.
- AI can propose project merge candidates, with user review and confirmed source refs before durable project changes.
- Project metadata can be edited from Project Detail, and active projects can be archived/restored without deleting evidence links.
- Projects list rows navigate to Project Detail with Overview, Evidence Timeline, and explicit insufficient-evidence state for thinking changes.
- `MetricContribution` exists and Growth metric detail can show positive/negative accepted contributions.
- History can deep-link to source evidence for Projects and Growth.
- Today supports returning to Capture to supplement raw input after cards have been generated, then regenerating derived artifacts.
- Design tokens now support system dark mode instead of forcing unreadable fixed light-theme colors.

## Product Answers

### What Does Project Mean?

Project means a user-confirmed long-running topic, workflow, goal, blocker, or behavior standard.

It is not:

- A company project name.
- A folder.
- A keyword cluster.
- A one-day event.
- A raw AI category.

AI may propose a project candidate, but the user confirms whether it is meaningful.

### How Are Projects Extracted?

AI can suggest candidates from confirmed daily evidence only:

- confirmed thinking cards
- main quests
- verifications
- saved principles

The candidate must include source ids and explain why the evidence points to a recurring goal, blocker, decision pattern, or action standard.

### How Are Projects Constrained And Merged?

Project creation constraints:

- at least one source id
- user confirmation
- privacy-safe abstract name
- goal or current bottleneck

Merge constraints:

- name similarity is not enough
- merge requires overlapping goal, bottleneck, success criteria, or repeated action pattern
- user confirms merge
- original project ids, names, goals, blockers, and merge reason are retained

### How Is Project Progress Shown?

Progress is not a percentage.

MVP progress signals:

- Done: completed quest or verified action
- Learned: assumption confirmed or disproved
- Unblocked: blocker removed or reduced
- Newly Blocked: new risk or blocker found
- Next Bet: next high-value question to verify

Every signal must link back to History.

### How Is Thinking Change Shown In A Project?

Use before/after evidence:

- before source: older wording, task, or verification
- after source: newer wording, task, or verification
- change claim: what changed in problem definition, judgment, evidence use, or execution
- training implication: what the user should practice next

If before/after evidence does not exist, UI shows evidence is insufficient.

### How Is Growth Explained?

Growth is an attribution ledger, not a personality score.

Each metric must show:

- current value
- previous value
- delta
- why it changed
- positive contribution events
- negative contribution events
- source links

If there are fewer than 3 complete daily loops or no `MetricContribution`, Growth must not show numeric scores.

## Current Implementation Gaps

| Area | Current State | Required State | Severity |
| --- | --- | --- | --- |
| Project domain | Models, repositories, migrations, manual creation, AI candidate/link review, ProjectInsight generation/review, merge candidate generation/review, metadata editing, archive/restore, evidence detail, and strict Project prompt output parsers exist | Continue evidence-backed visual/taste polish without changing merge semantics | Low |
| Project UI | Evidence-backed list/detail, History creation entry, candidate/link review, generated insight review, merge review, edit sheet, archive/restore controls, and accepted merge audit display exist | Polish project overview hierarchy; merge audit display has Subtask 037 coverage and can receive later visual QA | Medium |
| Growth domain | MetricSnapshot/MetricContribution exist; local attribution, detail feedback, weekly/monthly AI report triggers, and accepted report-review contribution loading exist | Add deeper longitudinal comparison later | Medium |
| Growth UI | Hides metric scores when evidence is insufficient, exposes weekly/monthly report actions, and shows recent report review from accepted evidence | Continue hardening evidence drilldown and report explanation polish | Medium |
| Verification | Quest-linked `Verification` fact source exists and History loads it on the original quest day | Add richer verification reason capture later | Low |
| Lens questions | Persisted `LensSession` exists and questions are restored from storage | Add longitudinal lens effectiveness analysis later | Low |
| History detail | Shows daily source evidence, project links, growth contributions, calendar navigation, deep links, local evidence search/filter, and local advanced filters by project, lens, card type, and quest status | Add saved filter persistence later only if repeated usage proves it is needed | Low |
| BYOK GLM path | Missing API Key now records a GLM failure and uses visible local fallback instead of silent mock success | Continue improving Settings guidance and repair history | Low |
| Prompt tracing | PromptRun write path, unresolved-failure repair recovery, missing-key failure recording, and Settings audit list exist | Add deeper repair history, retrieval reasons, and user feedback later | Low |
| UI dark mode | Core design tokens support system dark mode | Run simulator visual QA across all tabs and replace remaining ad hoc black/white colors | Medium |
| UI gutters | Some pages may still show side gutters or dense panels | Full safe-area background, constrained inner content | Medium |
| Today supplement | ReviewCards and later steps can return to Capture for supplementary input and regeneration | Later design a true incremental-card merge flow with explicit old/new evidence conflict review | Low |
| Resume banner | Non-Today tabs expose return-to-loop affordance and AI repair banner exists | Continue visual tuning only as needed | Low |

## Implementation Order

Completed foundation:

1. Verification and lens fact sources.
2. Project evidence layer.
3. Growth attribution layer.
4. History evidence drilldown and deep-link routing.
5. AI failure retry, background repair, and editable Today flow.

Remaining implementation order:

1. Harden visual QA for Today / History / Projects / Growth on simulator.
2. Polish Project overview hierarchy; keep merge audit display evidence-backed after Subtask 037.
3. Add deeper Growth longitudinal comparison and report explanation polish.
4. Extract AppStore orchestration into smaller use cases if complexity continues to grow.

This order avoids building another UI layer over missing facts.
