# MingSi Architecture Decisions

This file records active architecture decisions that should guide implementation and delegation.

## ADR-001: Local-First MVP With Direct GLM BYOK

Decision:

- MVP is an iPhone SwiftUI app that directly calls GLM with the user's own API Key.
- API Key is stored in Keychain.
- No server proxy is part of MVP.

Rationale:

- The alpha user can run without backend deployment.
- BYOK avoids embedding a shared secret in the app.
- Protocol boundaries keep the future proxy path open.

Required boundaries:

- `LLMClient` and `StreamingLLMClient` abstract transport.
- `PromptProvider` abstracts prompt source.
- `PromptRun` records audit evidence.

## ADR-002: Persist Meaning And Evidence, Not Presentation

Decision:

- Durable storage preserves raw input, confirmed cards, answers, quests, verification, principles, projects, links, metric contributions, prompt runs, and source refs.
- UI card layout, animation state, temporary streaming drafts, and display grouping are not authoritative records.

Rationale:

- The product expects future UI and card-shape iteration without losing user assets.
- Projects and Growth must remain reconstructable from evidence.

## ADR-003: History Is The Evidence Archive

Decision:

- History is the cross-feature evidence archive for Daily, Projects, and Growth.
- Project and Growth drilldowns must link back to History source evidence.

Rationale:

- This avoids unsupported dashboard claims.
- The user can audit why a project or growth conclusion exists.

## ADR-004: AI Failure Cannot Be Hidden By Fallback

Decision:

- Local fallback may keep the user moving, but must be visibly marked as fallback and repairable.
- Failed PromptRun records remain visible and retryable.
- Retry success should replace only the failed prompt's draft output and remove the repair item.

Rationale:

- Hidden fallback turns historical inputs into unreliable assets.
- The user must be able to understand whether a result came from GLM or local fallback.

## ADR-005: Growth Is An Attribution Ledger

Decision:

- Growth scores and narratives are hidden when evidence is insufficient.
- Metric changes must be explained with positive and negative `MetricContribution` entries and source links.

Rationale:

- The product trains thinking; it should not invent personality or ability assessments from weak evidence.

## ADR-006: Projects Are User-Confirmed Long-Running Topics

Decision:

- AI can propose project candidates, project links, insights, and merge candidates.
- Durable semantic changes require user confirmation.
- Project progress uses evidence signals such as Done, Learned, Unblocked, Newly Blocked, and Next Bet instead of percentages.

Rationale:

- Project meaning is a user-owned abstraction.
- AI clustering without confirmation would create misleading long-term memory.

## ADR-007: Claude Code Is A Bounded Worker, Not The Owner

Decision:

- Claude Code may receive narrow, testable implementation or read-only audit slices.
- Codex remains product owner, architect, reviewer, and final verifier.
- Delegated slices require a PRD, progress file, Claude prompt file, and manager log entry.
- Do not inspect or polish partial code before `TARGETED_VERIFIED` / `HANDOFF`.

Rationale:

- Past broad delegations produced partial diffs requiring manager rescue.
- The pipeline is still useful for bounded parser/service/UI slices when acceptance tests are clear.

## ADR-008: Visual Taste Is A Product Constraint

Decision:

- The UI should feel like a calm native thinking coach: warm paper, ink, graphite, restrained green.
- Avoid AI purple, neon blue, generic dashboard cards, and unsupported decorative summaries.
- Visual changes must preserve safe areas, tab bar spacing, dynamic colors, and dark-mode readability.

Rationale:

- The product's credibility depends on clarity, restraint, and evidence, not AI-wrapper aesthetics.
