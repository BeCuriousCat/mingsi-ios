# Superpowers TODO

This workspace captures product/architecture upgrades that make 明思 feel reliable and alive during AI work, without changing the durable data model.

## Current Focus: Streaming Card Generation

Goal:

- Make `organizeCards` usable even when GLM responses are slow.
- Show real progress from the model stream, not a fake progress bar.
- Keep storage, History, Projects, Growth, and later prompt context unchanged by treating stream output as temporary UI state.

## TODO

- [x] Promote streaming card generation from future scope to MVP scope.
- [x] Specify XML-like `MINGSI_STREAM_V1` protocol for `organizeCards`.
- [x] Define `StreamingLLMClient` and `XMLStreamingCardAssembler` architecture.
- [x] Define temporary `StreamingCardDraft` UI state and conversion to `ThinkingCard`.
- [x] Define failure and retry behavior for partial streams.
- [x] Update UX expectations and subtle animation rules.
- [x] Update prompt spec with few-shot XML-like output rules.
- [x] Update MVP task breakdown so implementation is tracked before MVP completion.
- [x] Implement streaming client, assembler, Today UI integration, and tests.
- [x] Harden persistence boundary so streamed candidates stay in memory until confirmed or excluded.
- [x] Harden XML parser validation so malformed schema is rejected and literal angle-bracket text is preserved.
- [x] Verify full iOS test suite after streaming and parser fixes.

## Design Principles

- Streaming is a transport and presentation layer, not a new fact source.
- Only closed and validated cards can become `ThinkingCard`.
- Only user-confirmed or explicitly excluded `ThinkingCard` records are persisted.
- Only user-confirmed, non-excluded `ThinkingCard` records can feed questions, quests, projects, growth, and history evidence.
- PromptRun may store the concatenated raw stream for audit, but token-level storage is not required in MVP.
- Animation should make waiting readable, not theatrical.
