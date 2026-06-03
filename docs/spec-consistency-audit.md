# 明思 Spec Consistency Audit

Date: 2026-06-01

Update: 2026-06-02

## Purpose

This audit checks whether the product documents are aligned enough to continue implementation without obvious scope or architecture conflict.

## Audited Documents

- `docs/prd.md`
- `docs/ux-flow.md`
- `docs/data-architecture.md`
- `docs/prompt-spec.md`
- `docs/technical-architecture.md`
- `docs/ui-design-draft.md`
- `docs/mvp-task-breakdown.md`

## MVP Scope Alignment

Status: aligned.

- Product name is 明思.
- Platform is iPhone / SwiftUI / iOS 17+.
- Model provider is GLM.
- User brings their own API Key.
- API Key is stored in Keychain.
- App directly calls GLM for MVP.
- Persistence is local-first with SQLite/GRDB, repositories, and migrations.
- Modes are Quick / Standard / Deep.
- Core tabs are Today, History, Projects, Growth, Settings.
- Reminder MVP is local notification.
- `organizeCards` uses GLM SSE with controlled XML-like `MINGSI_STREAM_V1` output for real streaming card generation.

## MVP Non-Goals Alignment

Status: aligned.

MVP does not include:

- Server proxy.
- User account system.
- App Store release preparation.
- Custom ASR.
- Apple Calendar / Reminders sync.
- Full role-card system.
- External framework marketplace.
- Mirror Cards.
- Ability graph.
- Schema-driven dynamic UI.
- Complex animation.

Note: XML-like streaming card generation is not considered schema-driven dynamic UI. It renders only the fixed first-party ThinkingCard component and does not change durable data storage.

Future adapter boundaries are still documented:

- `PromptProvider`: local to remote.
- `LLMClient`: direct GLM to proxy.
- `ReminderService`: local notification to Apple Reminders / Calendar.
- `LensCard`: future role/person/framework variants.
- `PrincipleAsset`: future principle comparison and training.

## Daily Loop Alignment

Status: aligned after correction.

Source state machine:

```text
VerifyYesterday
Capture
Organizing
ReviewCards
SelectMode
SelectLens
AnswerQuestions
ReviewQuests
ExtractPrinciple
SessionComplete
```

Data architecture now treats this loop state as the fact source. History display statuses are derived and can be rebuilt.

## Projects Alignment

Status: aligned for MVP implementation.

Project is defined as an abstract long-running topic or workflow, not a raw company project name or decorative folder.

The documents now agree that:

- AI may suggest project candidates.
- AI may suggest project links.
- AI may generate project insights only from confirmed links.
- AI may suggest merge candidates.
- User confirmation is required for project creation, links, and merges.
- Project progress must be based on linked evidence.
- Project thinking change must show before/after examples linked to history.
- `ProjectLink`, `ProjectInsight`, and `ProjectMergeCandidate` are required data concepts.

Current implementation includes:

- Project and ProjectLink domain models, repositories, and migrations.
- ProjectCandidate, ProjectMergeCandidate, and ProjectInsight domain models, repositories, migrations, and strict parsers.
- Manual Project creation from current main quest.
- Manual Project creation from historical Quest and PrincipleAsset evidence.
- AI project candidate suggestion and review.
- AI project link suggestion and review.
- AI project merge candidate suggestion and review with strict confirmed-source validation.
- Duplicate source-id prevention for ProjectLink creation.
- Project list grouped by confirmed evidence.
- Project Detail with Overview and Evidence Timeline.
- History deep-link routing from Project evidence.
- ProjectInsight generation and review from confirmed ProjectLink evidence.
- Explicit insufficient-evidence state when before/after thinking change evidence does not exist.

Still future scope:

- Project rename/archive UI.
- Richer project field editing and merge audit display polish.

## Growth Alignment

Status: aligned for MVP report trigger implementation.

The documents now agree that:

- Growth metrics are trend indicators, not user labels.
- Every metric must explain current value, previous value, delta, and reason.
- Positive and negative contributions must link to source evidence.
- `MetricContribution` is required to explain score changes.
- Growth UI cannot show unsupported numbers.
- With fewer than 3 complete loops or no contribution events, Growth must show evidence collection state instead of scores.

Implementation now has repository, migrations, local attribution, metric contribution detail UI, inaccurate/dismissed feedback, evidence deep links, weekly/monthly AI-assisted report generation triggers from history evidence, and a recent report review panel backed by accepted contributions. Remaining future work is deeper evidence drilldown and longitudinal comparison polish.

## Prompt / GLM Alignment

Status: aligned for MVP architecture.

- Prompt text is behind `PromptProvider`.
- GLM calls are behind `LLMClient`.
- Prompt output shapes exist for daily cards, lenses, questions, quests, verification, principles, project links, project merges, weekly calibration, and monthly growth.
- Project and Growth prompt outputs require source ids when they affect long-term evidence.

Implementation has robust parsing/eval coverage for Today prompts, Growth contributions, Project candidate/link outputs, ProjectInsight outputs, and ProjectMergeCandidate output shape. Project merge candidate generation/review is implemented behind ProjectAIService and AppStore review actions; candidates are saved only when both projects are active and overlapping refs resolve to confirmed project links.

## UI / Interaction Alignment

Status: aligned for design direction, pending implementation.

- Today owns the active state machine.
- History is the evidence archive.
- Projects is a dense evidence-backed working surface.
- Growth is a score explanation and evidence surface.
- Settings owns privacy, model, notification, and data controls.
- Page backgrounds must be full bleed; accidental white gutters are not acceptable.
- Projects and Growth may be minimal, but not placeholder-only.

## Development Gate

Implementation can continue only if new code satisfies these checks:

- No SwiftUI page directly calls GLM or database tables.
- Repository protocols own persistence boundaries.
- Project and Growth summaries cannot be created without evidence ids.
- Prompt outputs are parsed defensively.
- UI changes do not change stored semantic data.
- Tests or manual verification cover the full Today loop and evidence recovery.
