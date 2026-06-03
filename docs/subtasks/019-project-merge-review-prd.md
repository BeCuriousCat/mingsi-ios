# Subtask 019 PRD: Project Merge Review

## Goal

让 Projects 能发现两个长期议题可能其实是同一个问题，并让用户确认后完成一个可审计的最小合并闭环。

## Product Principle

项目合并不是名字相似就合并，也不是 AI 自动修改用户资产。它必须遵守：

- AI 只能提出 `ProjectMergeCandidate`。
- 候选必须包含 `sourceProjectId`、`targetProjectId`、`reason` 和 `overlappingEvidenceRefs`。
- `overlappingEvidenceRefs` 必须能对应到已确认的项目证据。
- 用户接受后才修改 Project 状态。
- 合并必须保留源项目 id、名称、目标、阻塞和合并理由，写入 target project 的 `mergeHistory`。
- 源项目不删除，只改为 `.archived`。

## Scope

MVP slice includes:

- Add PromptID and prompt template for `suggestProjectMerges`.
- Add `ProjectAIService.suggestProjectMerges(context:)`.
- Build merge context from active projects and confirmed project links.
- Persist generated merge candidates with `.pending` status.
- Add AppStore state for pending merge candidates, loading, and message.
- Add AppStore actions:
  - generate merge candidates
  - accept merge candidate
  - reject merge candidate
  - dismiss merge candidate
- Show pending merge candidates in Projects UI with accept/reject/dismiss controls.

## Non-Goals

- No automatic merge.
- No hard delete.
- No moving or rewriting ProjectLink rows in this slice.
- No complex split UI.
- No project rename editor.
- No schema-driven dynamic UI.

## UX

Projects page adds a compact “议题治理” section:

- If at least 2 active projects exist, show “检查可合并议题”.
- While generating, show progress text.
- If no candidate, show muted explanation.
- Pending merge candidates show:
  - source project name -> target project name
  - reason
  - overlapping evidence count
  - Accept / Reject / Dismiss controls

Accepted behavior:

- target project remains active.
- source project becomes archived.
- target project `mergeHistory` appends a readable audit line with source/target ids, names, reason, and evidence refs.
- candidate status becomes `.accepted`.
- UI refreshes project lists and pending candidates.

Rejected/dismissed behavior:

- candidate status becomes `.rejected` or `.dismissed`.
- no Project state changes.
- candidate disappears from pending UI.

## Data / Architecture

- Use existing `ProjectMergeCandidateRepository`.
- Add `projectMergeCandidateRepository` to `AppStore`.
- Project UI calls AppStore only.
- `ProjectAIService` owns GLM request construction and parser call.
- `TodayAIResponseParser.parseProjectMergeCandidates(from:)` already exists and must stay strict.
- No migration required.

## Acceptance Tests

- ProjectAIService merge request includes active projects, project evidence refs, source record ids, and project ids as context refs.
- Generated merge candidates are saved only when both projects exist, both are active, and every overlapping evidence ref belongs to either project.
- Invalid candidates with unknown project ids or unresolved evidence refs are dropped.
- Accepting a merge archives source project, updates target `mergeHistory`, and marks candidate accepted.
- Rejecting/dismissing a merge candidate does not alter project status.
- UI has a visible pending merge review section driven by AppStore state.
