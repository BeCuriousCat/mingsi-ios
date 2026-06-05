# Claude Code Prompt: Subtask 042 Lens Prompt Context Wiring

You are Claude Code working as a bounded implementation worker for Codex on MingSi / 明思.

Use the Claude skill `codex-delegated-worker` if available.

Codex owns product judgment, architecture, final review, and final verification. You own only this scoped implementation slice.

## Read First

Read:

- `docs/subtasks/042-lens-prompt-context-wiring-prd.md`
- `docs/subtasks/042-lens-prompt-context-wiring-progress.md`
- `docs/subtasks/039-first-principles-lens-catalog-prd.md`
- `docs/mvp-current-goal.md`
- `docs/architecture-decisions.md`

Then update `docs/subtasks/042-lens-prompt-context-wiring-progress.md` with `START` before broad source inspection.

## Source Inspection Rules

Do not read large files all at once. Use targeted ranges:

- `Sources/Domain/Models.swift` lines 95-180 for read-only lens catalog context.
- `Sources/Services/CoreProtocols.swift` lines 35-260 for `PromptContextPayload`.
- `Sources/Services/TodayAIService.swift` lines 85-130 and 300-450 for request/context assembly.
- `Tests/Services/TodayAIServiceContextTests.swift` lines 180-325 and 400-455 for existing request payload tests.

Use `rg` for any additional targeted lookup.

## Progress Contract

Update `docs/subtasks/042-lens-prompt-context-wiring-progress.md` at exactly:

- `START`: after reading required docs and before broad source inspection.
- `RED`: after adding failing tests.
- `IMPLEMENTED`: after source changes.
- `TARGETED_VERIFIED`: after required verification.
- `HANDOFF`: final report with one status token.

At `HANDOFF`, include exactly one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Allowed Writes

Allowed:

- `Sources/Services/CoreProtocols.swift`
- `Sources/Services/TodayAIService.swift`
- `Tests/Services/TodayAIServiceContextTests.swift`
- `docs/subtasks/042-lens-prompt-context-wiring-progress.md`

Do not edit any other file. If another file appears necessary, write `NEEDS_CONTEXT`.

Do not commit.

## Required Behavior

Implement only the Subtask 042 PRD:

1. `LLMRequest.jsonPayload["selectedLens"]` for `generateQuestions` and `generateQuests` uses `ThinkingLens.catalogItem.promptId`.
2. `DefaultContextAssembler.inputSummary` uses the prompt-facing lens id.
3. Structured context exposes catalog metadata for the selected lens:
   - local id;
   - prompt-facing id;
   - version;
   - title;
   - method line.
4. Existing `PromptContextPayload.selectedLens` compatibility keeps resolving back to local `ThinkingLens`.
5. No SwiftUI-only fields, no persistence changes, no PromptProvider text changes.

## Tests

Use TDD. Add or update tests before implementation in `Tests/Services/TodayAIServiceContextTests.swift`.

Required tests:

- `generateQuestions` with `.firstPrinciples` sends `selectedLens == "first_principles"` in `jsonPayload`.
- Structured context still allows `payload.selectedLens == .firstPrinciples`.
- Structured context exposes lens metadata containing local id `firstPrinciples`, prompt id `first_principles`, version `builtin.v1`, and title `第一性原理`.
- `generateQuests` with `.leverageAnalysis` sends `selectedLens == "leverage_analysis"` in `jsonPayload`.

Prefer small value types. Keep changes source-compatible where practical.

## Verification

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
git diff --check
```

If `xcodebuild` is blocked by worker worktree infrastructure, record the exact error in `HANDOFF` and still run `git diff --check`.

## Handoff Format

At the end, update the progress file with `HANDOFF` and include:

- final status token;
- files changed;
- implementation summary;
- verification commands and results;
- any concerns or non-goals left for Codex.
