# Subtask 015: Project Evidence Digest

## Goal

把 Project Detail 从“证据列表 + 证据不足提示”推进到一个最小可用的项目解释层：

```text
confirmed ProjectLink evidence
-> local evidence digest
-> progress signals / next bet / open evidence gaps
-> Project Detail UI
```

这个切片不生成 AI 洞察，不新增存储结构；它只把已存在的 ProjectLink 和 HistoryRecord 转成可审查的本地解释，避免项目页看起来像普通列表或假 dashboard。

## Product Rules

- Project 仍然是用户确认的长期议题，不是关键词聚类。
- 任何项目解释都必须能回到 ProjectLink source id。
- 进展不是百分比；只显示 Done / Learned / Unblocked / Newly Blocked / Next Bet 这类证据信号。
- 思考变化必须有 before / after 证据；证据不足时继续显示“不生成变化叙事”。
- UI 应该是安静的工作台：温纸背景、石墨文字、少量语义色，不使用紫色、霓虹、AI 风格大卡。

## In Scope

1. Local evidence digest model
   - Add a small pure Swift digest type derived from `ProjectEvidenceBoardItem`.
   - It should expose:
     - `progressSignals`
     - `latestSignal`
     - `nextBet`
     - `evidenceGapMessage`
     - `hasBeforeAfterEvidence`
   - No repository or migration changes.

2. Project Detail UI
   - Add a “进展信号” section above Evidence Timeline.
   - Show compact rows for evidence-backed signals.
   - Show “下一步押注” from latest evidence when available.
   - Keep thinking change section evidence-gated.

3. Tests
   - Add tests that prove:
     - task links map to Done-like progress signal.
     - blocker/risk links map to blocker/risk signal.
     - mixed evidence produces a next bet.
     - before/after requires at least two evidence entries.

4. Documentation / delegation record
   - Add progress file for this subtask.
   - Update `docs/agent-delegation-log.md` after implementation and verification.

## Out of Scope

- AI-generated ProjectInsight.
- Project merge UI.
- Rename/archive editing.
- New database schema.
- Search/filter.
- Large visual redesign.
- Dynamic schema-driven UI.

## Acceptance Criteria

- Project Detail shows evidence-backed progress signals before the timeline.
- Each progress signal is derived from a concrete ProjectLink and keeps the existing timeline deep link path.
- Single-evidence projects still show insufficient before/after evidence for thinking change.
- No Project or Growth page displays unsupported numeric progress.
- Targeted tests pass.
- Full iOS test suite passes before claiming completion.
