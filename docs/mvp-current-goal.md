# MingSi MVP Current Goal

Date: 2026-06-03

## Current Stop Condition

MVP can stop only when the app can run as a coherent personal alpha version that turns one daily reflection into durable thinking assets:

- Today supports input, Quick / Standard / Deep mode, streaming card organization, card review, lens questions, quests, principle candidates, supplementary input, and retryable AI failure recovery.
- History works as an evidence archive, not a flat card list. It must expose raw input, cards, lens, questions, quests, verification, principles, project evidence, growth contributions, search, date navigation, and local filters.
- Projects are evidence-backed long-running topics. No project progress or thinking-change claim can appear without source evidence.
- Growth is an attribution ledger. No score or growth narrative can appear without enough completed loops and source-linked contributions.
- Settings supports BYOK GLM configuration, Base URL, model, connection validation, Keychain storage, and AI call audit visibility.
- AI failures are visible, retryable, and auditable. Local fallback can keep the user moving, but cannot pretend to be a successful model result.
- Prompt and model boundaries stay behind `PromptProvider`, `LLMClient`, `StreamingLLMClient`, `PromptRun`, and repository abstractions.
- The app builds on iPhone simulator and targeted MVP regression tests pass.

## Current Stage Priority

The repo is past raw skeleton work. Current priority is MVP hardening:

1. Keep process docs aligned before additional coding.
2. Stabilize visual and interaction bugs in Today / History / Projects / Growth.
3. Keep AI repair, retry, and PromptRun audit paths visible and testable.
4. Harden evidence-backed Project and Growth views.
5. Avoid adding non-MVP expansions until the alpha loop is stable.

## Current Implementation Bias

- Prefer small, testable slices.
- Delegate only narrow implementation or read-only audit tasks to Claude Code.
- Do not delegate product semantics, state-machine ownership, prompt/context strategy, persistence migrations, or final visual taste.
- Do not merge or polish partial Claude output before its progress file reaches `HANDOFF`.

## Active Constraints

- Dirty worktree is expected. Do not revert unrelated Codex, Claude Code, GLM, or user changes.
- SwiftUI views must not directly import GRDB or call `LLMClient`.
- No fake data may stand in for missing Project or Growth evidence.
- Prompt outputs that affect Projects or Growth must carry source ids.
- History remains the source evidence archive for Project and Growth drilldown.

## Repo Document Authority

Use these documents as the current source of truth:

- `docs/prd.md`
- `docs/implementation-gap-audit.md`
- `docs/mvp-task-breakdown.md`
- `docs/technical-architecture.md`
- `docs/data-architecture.md`
- `docs/ux-flow.md`
- `docs/prompt-spec.md`
- `docs/prompt-context-engineering-prd.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- `docs/architecture-decisions.md`
- `docs/agent-delegation-log.md`
