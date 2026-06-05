# Claude Code Current Status

Last updated: 2026-06-05

## Current Worker

Status: Subtask 050 is prepared for Claude Code delegation.

Active prepared slice:

- Subtask: `050-project-detail-visual-qa-launch-fixture`
- Owner: Claude Code implementation candidate, Codex final acceptance.
- PRD file: `docs/subtasks/050-project-detail-visual-qa-launch-fixture-prd.md`
- Progress file: `docs/subtasks/050-project-detail-visual-qa-launch-fixture-progress.md`
- Claude prompt file: `docs/subtasks/050-project-detail-visual-qa-launch-fixture-claude-prompt.md`
- Event log: `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-events.jsonl`
- Expected raw log: `docs/subtasks/logs/050-project-detail-visual-qa-launch-fixture-claude-run.jsonl`
- Purpose: add a Debug/UITest-only launch fixture so Codex can reliably open Projects/Project Detail for real iPhone 17 screenshots without changing production persistence or product semantics.
- Allowed files: `Sources/App/MingSiApp.swift`, `Sources/App/AppStore.swift`, `Tests/App/AppStoreStateMachineTests.swift`, and the 050 progress file.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Delegation rationale: bounded local source/test implementation with explicit acceptance tests; Codex remains final screenshot and taste owner.

Latest accepted delegated slice:

- Subtask: `048-project-detail-visual-smoke-readiness`
- Owner: Claude Code read-only audit, Codex final acceptance.
- PRD file: `docs/subtasks/048-project-detail-visual-smoke-readiness-prd.md`
- Progress file: `docs/subtasks/048-project-detail-visual-smoke-readiness-progress.md`
- Claude prompt file: `docs/subtasks/048-project-detail-visual-smoke-readiness-claude-prompt.md`
- Expected findings: `docs/subtasks/048-project-detail-visual-smoke-readiness-findings.md`
- Expected event log: `docs/subtasks/logs/048-project-detail-visual-smoke-readiness-events.jsonl`
- Expected raw log: `docs/subtasks/logs/048-project-detail-visual-smoke-readiness-claude-run.jsonl`
- Purpose: produce source-inferred Project Detail visual-smoke readiness findings so Codex can run targeted iPhone 17 screenshots and choose a narrow follow-up implementation slice.
- Allowed write files: 048 progress and findings only.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Delegation rationale: this is a bounded read-only audit with document-only output and no product-source edits, suitable for Claude Code while Codex stays in final product judgment role.
- Launch state: completed after recovery. Three earlier `prepare` attempts failed with local process creation errors (`fork: Resource temporarily unavailable` / `os error 35`) before the user restarted Codex; the fresh launch then reached `START`, `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, and `HANDOFF`.
- Worker result: `HANDOFF/DONE`. Findings identify 10 Project Detail screenshot states, 6 source-inferred visual risks, and 3 narrow follow-up candidates. No Swift source or test files were modified.
- Codex acceptance: accepted as read-only planning evidence only. Real iPhone 17 screenshots are still required before confirming any visual risk or implementing follow-ups.

Current framework fix in progress:

- Subtask: delegation resource hygiene / zombie guard.
- Owner: Codex direct framework fix.
- Files: `scripts/claude_delegate.sh`, `delegation-framework/claude-code-managed-delegation/SKILL.md`, and local installed `claude-code-managed-delegation` skill.
- Purpose: prevent repeated Codex-side shell/polling and foreground print-mode launches from accumulating unreaped child processes.
- State: wrapper now keeps non-interactive tmux mode by default, makes `claude agents --json` preflight opt-in, and blocks prepare/launch/wait when zombie thresholds are exceeded.

Previous accepted framework slice:

- Subtask: `046-delegation-strict-handoff-detection`
- Owner: Codex direct implementation after Claude Code launch blockers.
- PRD file: `docs/subtasks/046-delegation-strict-handoff-detection-prd.md`
- Progress file: `docs/subtasks/046-delegation-strict-handoff-detection-progress.md`
- Claude prompt file: `docs/subtasks/046-delegation-strict-handoff-detection-claude-prompt.md`
- Expected event log: `docs/subtasks/logs/046-delegation-strict-handoff-detection-events.jsonl`
- Expected raw log: `docs/subtasks/logs/046-delegation-strict-handoff-detection-claude-run.jsonl`
- Purpose: tighten `scripts/claude_delegate.sh` so bare/template `## HANDOFF` sections are not treated as completed handoffs unless a real final status token exists.
- Allowed files: `scripts/claude_delegate.sh` and the 046 progress file.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Delegation rationale: this is a narrow shell-wrapper behavior fix with explicit regression commands and no MingSi product semantics, suitable for Claude Code implementation under Codex verification.
- Launch attempt 1: `prepare` succeeded, but `launch` failed before worker start with `error: cannot fork() for branch: Resource temporarily unavailable`; no worker worktree, raw log, source diff, or `HANDOFF` exists yet.
- Launch attempt 2: failed before worker start with `scripts/claude_delegate.sh: fork: Resource temporarily unavailable`; no worker progress, raw log, source diff, or `HANDOFF` exists yet.
- Launch attempt 3: failed before worker start with `error: cannot fork() for branch: Resource temporarily unavailable`; Codex classified the blocker as local system process creation failure with no worker output to inspect or salvage.
- Codex direct implementation state: `scripts/claude_delegate.sh` now routes `handoff_reached` through strict final-token detection, preserving `CODEX_ACCEPTED` while removing bare `## HANDOFF` from the success path.
- Manager fix: repo-external absolute progress fixtures now bypass worker worktree path mapping, avoiding `path is outside repo` noise during negative tests.
- Verification state: accepted after fresh manager verification. Syntax check passed; 044 real handoff still surfaces `Status: DONE_WITH_CONCERNS`; placeholder `## HANDOFF` does not show active handoff and `wait` exits `75`; 029 pending progress still exits `75`; `git diff --check` passed.

Latest accepted slice:

- Subtask: `045-extensible-lens-library-boundary`
- Owner: Codex direct implementation after Claude Code launch blocker.
- PRD file: `docs/subtasks/045-extensible-lens-library-boundary-prd.md`
- Progress file: `docs/subtasks/045-extensible-lens-library-boundary-progress.md`
- Claude prompt file: `docs/subtasks/045-extensible-lens-library-boundary-claude-prompt.md`
- Expected event log: `docs/subtasks/logs/045-extensible-lens-library-boundary-events.jsonl`
- Expected raw log: `docs/subtasks/logs/045-extensible-lens-library-boundary-claude-run.jsonl`
- Purpose: turn the existing built-in first-principles lens catalog into a small extensible lens library/provider boundary without adding custom lenses, remote loading, persistence, prompt text, parser, AppStore, or UI changes.
- Allowed source/test files: `Sources/Domain/Models.swift`, `Tests/App/AppStoreStateMachineTests.swift`, plus the 045 progress file.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Delegation attempt: `scripts/claude_delegate.sh prepare` and `launch` both failed before execution with `spawn /bin/sh EAGAIN`; no worker progress or handoff exists.
- Current implementation state: Codex added `LensCatalogProviding`, `LensLibrary`, `BuiltinLensCatalog.library`, compatibility lookups, and focused catalog tests in the manager checkout.
- Verification state: accepted after fresh manager verification: `AppStoreStateMachineTests` passed with 110 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.

Previous accepted delegated slice:

- Subtask: `044-project-status-filter`
- Owner: Claude Code implementation candidate, Codex acceptance.
- PRD file: `docs/subtasks/044-project-status-filter-prd.md`
- Progress file: `docs/subtasks/044-project-status-filter-progress.md`
- Claude prompt file: `docs/subtasks/044-project-status-filter-claude-prompt.md`
- Event log: `docs/subtasks/logs/044-project-status-filter-events.jsonl`
- Raw log: `docs/subtasks/logs/044-project-status-filter-claude-run.jsonl`
- Worker path: `.claude/worktrees/subtask-044-project-status-filter`
- Launch state: completed with `HANDOFF/DONE_WITH_CONCERNS`; Codex accepted after fresh manager verification.
- Purpose: add display-only Projects top-level status filtering over existing `ProjectStatus` values without changing Project semantics, AppStore orchestration, persistence, migrations, prompts, parsers, or LLM behavior.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Verification: focused `HistoryFeatureTests` passed with 65 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.
- Pipeline note: `status` displayed the template `## HANDOFF` placeholder before real handoff; Codex ignored it for acceptance and recorded it as a separate wrapper strictness follow-up.

Latest framework slice:

- Subtask: `043-delegation-status-handoff-summary`
- Owner: Codex direct implementation.
- PRD file: `docs/subtasks/043-delegation-status-handoff-summary-prd.md`
- Progress file: `docs/subtasks/043-delegation-status-handoff-summary-progress.md`
- Claude prompt file: none; no Claude Code worker was delegated because the bug was inside `scripts/claude_delegate.sh`.
- Worker path: none.
- Launch state: not launched.
- Purpose: fix wrapper `status` so routine manager status shows active `HANDOFF` summary/final status token and prefers manager-side `CODEX_ACCEPTED` progress after acceptance.
- Manager consumption rule: read conclusion progress/HANDOFF first; raw/event logs remain diagnostic only.
- Verification: wrapper syntax check passed; 042 status regression checks passed; 029 pending-handoff guard still exited `75`; `git diff --check` passed.

Latest accepted slice:

- Subtask: `042-lens-prompt-context-wiring`
- Owner: Claude Code implementation candidate, Codex acceptance.
- PRD file: `docs/subtasks/042-lens-prompt-context-wiring-prd.md`
- Progress file: `docs/subtasks/042-lens-prompt-context-wiring-progress.md`
- Claude prompt file: `docs/subtasks/042-lens-prompt-context-wiring-claude-prompt.md`
- Event log: `docs/subtasks/logs/042-lens-prompt-context-wiring-events.jsonl`
- Raw log: `docs/subtasks/logs/042-lens-prompt-context-wiring-claude-run.jsonl`
- Worker path: `.claude/worktrees/subtask-042-lens-prompt-context-wiring`
- Launch state: completed with `HANDOFF/DONE_WITH_CONCERNS`; Codex accepted after fresh manager verification.
- Purpose: wire existing built-in lens catalog metadata into Today AI request/context payloads so model-facing `selectedLens` uses prompt ids like `first_principles` while local persistence and filters keep `ThinkingLens.rawValue`.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Verification: focused `TodayAIServiceContextTests` passed with 16 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.
- Pipeline note: `status` briefly showed stale progress after the worker reached `HANDOFF`; raw/event logs were opened only after conclusion-progress inconsistency.

Previous accepted slice:

- Subtask: `041-project-detail-hierarchy-cleanup`
- Owner: Claude Code implementation candidate, Codex acceptance.
- PRD file: `docs/subtasks/041-project-detail-hierarchy-cleanup-prd.md`
- Progress file: `docs/subtasks/041-project-detail-hierarchy-cleanup-progress.md`
- Claude prompt file: `docs/subtasks/041-project-detail-hierarchy-cleanup-claude-prompt.md`
- Event log: `docs/subtasks/logs/041-project-detail-hierarchy-cleanup-events.jsonl`
- Raw log: `docs/subtasks/logs/041-project-detail-hierarchy-cleanup-claude-run.jsonl`
- Worker path: `.claude/worktrees/subtask-041-project-detail-hierarchy-cleanup`
- Launch state: completed with `HANDOFF/DONE_WITH_CONCERNS`; Codex accepted with a manager display-helper fix.
- Purpose: implement the display-only Project Detail hierarchy cleanup accepted from Subtask 040 findings without changing Project semantics, AppStore, persistence, prompt, parser, or LLM behavior.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Verification: focused `HistoryFeatureTests` passed with 61 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.

Previous accepted slice:

- Subtask: `040-project-overview-hierarchy-audit`
- Owner: Claude Code read-only audit candidate, Codex acceptance.
- PRD file: `docs/subtasks/040-project-overview-hierarchy-audit-prd.md`
- Progress file: `docs/subtasks/040-project-overview-hierarchy-audit-progress.md`
- Claude prompt file: `docs/subtasks/040-project-overview-hierarchy-audit-claude-prompt.md`
- Findings file: `docs/subtasks/040-project-overview-hierarchy-audit-findings.md`
- Event log: `docs/subtasks/logs/040-project-overview-hierarchy-audit-events.jsonl`
- Raw log: `docs/subtasks/logs/040-project-overview-hierarchy-audit-claude-run.jsonl`
- Worker path: `.claude/worktrees/subtask-040-project-overview-hierarchy-audit`
- Launch state: completed with `HANDOFF/DONE`; Codex accepted the read-only findings.
- Purpose: audit current Projects overview and Project Detail hierarchy to choose a narrow evidence-backed implementation slice without changing Project semantics.
- Manager consumption rule: read worker progress/HANDOFF and findings first; raw/event logs are diagnostic only.
- Verification: `git diff --check -- docs/subtasks/040-project-overview-hierarchy-audit-progress.md docs/subtasks/040-project-overview-hierarchy-audit-findings.md` passed in the worker; Codex reran `git diff --check` in the manager checkout.
- Accepted recommendation: prepare a separate display-only implementation slice for Project Detail hierarchy: fix thinking-change headline accuracy, reduce placeholder overview noise, visually group sections, and hide empty progress signals.

Previous accepted slice:

- Subtask: `039-first-principles-lens-catalog`
- Owner: Claude Code implementation candidate, Codex acceptance.
- PRD file: `docs/subtasks/039-first-principles-lens-catalog-prd.md`
- Progress file: `docs/subtasks/039-first-principles-lens-catalog-progress.md`
- Claude prompt file: `docs/subtasks/039-first-principles-lens-catalog-claude-prompt.md`
- Event log: `docs/subtasks/logs/039-first-principles-lens-catalog-events.jsonl`
- Raw log: `docs/subtasks/logs/039-first-principles-lens-catalog-claude-run.jsonl`
- Worker path: `.claude/worktrees/subtask-039-first-principles-lens-catalog`
- Launch state: completed with `HANDOFF/DONE_WITH_CONCERNS`; Codex accepted after fresh manager verification.
- Purpose: add MVP built-in `第一性原理` as a first-party lens through a lightweight built-in catalog boundary without adding persistence, migrations, custom lens UI, PromptProvider changes, parser changes, LLM changes, Keychain changes, or AppStore orchestration changes.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Verification: focused `AppStoreStateMachineTests` passed with 105 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.

Previous accepted slice:

- Subtask: `038-growth-report-drilldown-polish`
- Owner: Claude Code implementation candidate, Codex acceptance.
- PRD file: `docs/subtasks/038-growth-report-drilldown-polish-prd.md`
- Progress file: `docs/subtasks/038-growth-report-drilldown-polish-progress.md`
- Claude prompt file: `docs/subtasks/038-growth-report-drilldown-polish-claude-prompt.md`
- Expected event log: `docs/subtasks/logs/038-growth-report-drilldown-polish-events.jsonl`
- Expected raw log: `docs/subtasks/logs/038-growth-report-drilldown-polish-claude-run.jsonl`
- Launch state: completed with `HANDOFF/DONE_WITH_CONCERNS`; Codex applied a manager acceptance fix and accepted after fresh verification.
- Purpose: improve display-only Growth report review and metric drilldown clarity without changing AppStore Growth behavior, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, or Project semantics.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.
- Verification: focused `HistoryFeatureTests` passed with 53 tests and 0 failures; `git diff --check` passed; iPhone 17 simulator build passed.
- Pipeline follow-up verified: `scripts/claude_delegate.sh` now preserves worker progress on relaunch by default, recognizes `## HANDOFF`, and `wait` found the worker handoff while keeping raw/event logs diagnostic-only.

Current framework thread:

- The Codex-to-Claude Code delegation framework is now treated as a separate tooling project from MingSi product hardening.
- Boundary doc: `docs/delegation-framework-boundary.md`
- Generic skill prototype: `delegation-framework/claude-code-managed-delegation/SKILL.md`
- Wrapper now supports configurable task and log roots:
  - `CLAUDE_DELEGATE_TASK_ROOT`
  - `CLAUDE_DELEGATE_LOG_DIR`
- MingSi continues to use `docs/subtasks` by default, but future projects can use a different task root without changing the wrapper.

Latest delegated product slice:

- Subtask: `038-growth-report-drilldown-polish`
- Owner: Claude Code implementation, Codex acceptance.
- PRD file: `docs/subtasks/038-growth-report-drilldown-polish-prd.md`
- Progress file: `docs/subtasks/038-growth-report-drilldown-polish-progress.md`
- Claude prompt file: `docs/subtasks/038-growth-report-drilldown-polish-claude-prompt.md`
- Event log: `docs/subtasks/logs/038-growth-report-drilldown-polish-events.jsonl`
- Raw log: `docs/subtasks/logs/038-growth-report-drilldown-polish-claude-run.jsonl`
- Launch state: completed and Codex-accepted with manager fix.
- Purpose: improve display-only Growth report review and metric drilldown clarity without changing AppStore Growth behavior, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, or Project semantics.
- Result: worker reached `HANDOFF/DONE_WITH_CONCERNS`; Codex accepted the helper/test direction, fixed report rows to include stored metric reason or conservative fallback copy, and reran focused tests, `git diff --check`, wrapper smoke checks, and iPhone 17 simulator build.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.

Previous delegated product slice:

- Subtask: `037-project-merge-audit-display`
- Owner: Claude Code implementation, Codex acceptance.
- PRD file: `docs/subtasks/037-project-merge-audit-display-prd.md`
- Progress file: `docs/subtasks/037-project-merge-audit-display-progress.md`
- Claude prompt file: `docs/subtasks/037-project-merge-audit-display-claude-prompt.md`
- Expected event log: `docs/subtasks/logs/037-project-merge-audit-display-events.jsonl`
- Expected raw log: `docs/subtasks/logs/037-project-merge-audit-display-claude-run.jsonl`
- Launch state: completed and Codex-accepted.
- Purpose: improve display-only Project merge review and accepted merge-history audit visibility without changing AppStore merge behavior, persistence, migrations, PromptProvider, LLM clients, parser, Keychain, or Growth semantics.
- Result: worker reached `HANDOFF/DONE`; Codex accepted the scoped UI/helper/test diff after rerunning focused tests, `git diff --check`, and an iPhone 17 simulator build.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.

Previous delegated product slice:

- Subtask: `036-ai-repair-status-feedback`
- Owner: Claude Code implementation, Codex acceptance.
- PRD file: `docs/subtasks/036-ai-repair-status-feedback-prd.md`
- Progress file: `docs/subtasks/036-ai-repair-status-feedback-progress.md`
- Claude prompt file: `docs/subtasks/036-ai-repair-status-feedback-claude-prompt.md`
- Event log: `docs/subtasks/logs/036-ai-repair-status-feedback-events.jsonl`
- Raw log: `docs/subtasks/logs/036-ai-repair-status-feedback-claude-run.jsonl`
- Launch state: completed and Codex-accepted with manager fix.
- Purpose: improve per-run/per-candidate AI repair status feedback in History and Settings without changing retry behavior, persistence, PromptProvider, LLM clients, parser, Keychain, or migrations.
- Result: first launch exited before `START` due an API socket close; relaunch reached `HANDOFF/DONE`. Codex accepted the UI/test direction but fixed candidate status copy so it does not claim accepted candidates are written into the day record.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.

Previous delegated product slice:

- Subtask: `035-prompt-inspector-readonly`
- Owner: Claude Code implementation, Codex acceptance.
- PRD file: `docs/subtasks/035-prompt-inspector-readonly-prd.md`
- Progress file: `docs/subtasks/035-prompt-inspector-readonly-progress.md`
- Claude prompt file: `docs/subtasks/035-prompt-inspector-readonly-claude-prompt.md`
- Event log: `docs/subtasks/logs/035-prompt-inspector-readonly-events.jsonl`
- Raw log: `docs/subtasks/logs/035-prompt-inspector-readonly-claude-run.jsonl`
- Launch state: completed and Codex-accepted with manager fix.
- Purpose: add a read-only Settings Prompt inspector that exposes current first-party prompt templates and schema metadata without changing prompt strategy, LLM calls, Keychain, persistence, or retry semantics.
- Result: worker reached `HANDOFF/DONE`; Codex accepted the UI/test direction but moved template access behind `AppStore.promptTemplate(for:mode:)` so Settings does not construct `LocalPromptProvider` directly.
- Manager consumption rule: read worker progress/HANDOFF first; raw/event logs are diagnostic only.

Previous prepared slice:

- Subtask: `034-manual-principle-creation`
- Owner: Claude Code implementation dogfood candidate.
- PRD file: `docs/subtasks/034-manual-principle-creation-prd.md`
- Progress file: `docs/subtasks/034-manual-principle-creation-progress.md`
- Claude prompt file: `docs/subtasks/034-manual-principle-creation-claude-prompt.md`
- Expected event log: `docs/subtasks/logs/034-manual-principle-creation-events.jsonl`
- Expected raw log: `docs/subtasks/logs/034-manual-principle-creation-claude-run.jsonl`
- Launch state: completed and Codex-accepted with manager fix.
- Purpose: dogfood the reusable delegation framework on a real MingSi business slice without baking MingSi semantics into the framework.
- Result: worker reached `HANDOFF/DONE`; Codex accepted the direction but fixed the long-lived principle source so Growth reads `activePrinciples` rather than Today's resettable `principles`.

Previous prepared slice:

- Subtask: `033-claude-code-conclusion-log-smoke`
- Owner: Claude Code read-only smoke candidate.
- PRD file: `docs/subtasks/033-claude-code-conclusion-log-smoke-prd.md`
- Progress file: `docs/subtasks/033-claude-code-conclusion-log-smoke-progress.md`
- Claude prompt file: `docs/subtasks/033-claude-code-conclusion-log-smoke-claude-prompt.md`
- Event log: `docs/subtasks/logs/033-claude-code-conclusion-log-smoke-events.jsonl`
- Raw log: `docs/subtasks/logs/033-claude-code-conclusion-log-smoke-claude-run.jsonl`
- Launch state: completed and Codex-accepted; no active worker is running.

Latest utilization smoke:

- Subtask: `033-claude-code-conclusion-log-smoke`
- Result: `DONE`, Codex-accepted.
- Evidence: default print fallback no longer streams raw JSONL to the manager terminal; raw/event flow logs are retained on disk, while `status` and `wait` consume worker progress as the conclusion source.
- Worker evidence: `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` were present inside the isolated worker worktree and inspected there; worker progress reached `HANDOFF`; no product source files were modified.
- Remaining note: normal `git worktree add` setup output can still appear before Claude starts. It is not model raw flow output.

Prior utilization smoke:

- Subtask: `032-claude-code-worker-fallback-smoke`
- Result: worker reached `HANDOFF` with final token `DONE`; Codex accepted with follow-up.
- Evidence: wrapper launched print fallback from the isolated worker worktree, worker progress became the active conclusion source, and default `status` / `wait` consumed progress rather than flow-log tails.
- Limitation found: the first 032 launch still streamed raw JSONL to the manager terminal through `tee`, and untracked `scripts/` files were not present in the worker worktree. The wrapper has been patched and Subtask 033 is prepared to verify the repaired behavior.

Earlier utilization smoke:

- Subtask: `031-claude-code-utilization-smoke`
- Result: `DONE_WITH_CONCERNS`, Codex-reconciled.
- Evidence: wrapper command path launched and fell back to print mode; hook events and raw stream usage were recorded.
- Limitation: old print fallback ran from the manager worktree, so worker-side progress writing was not proven.
- Follow-up: Subtask 032 will verify the patched print fallback runs from the isolated worker worktree.

Current delegation infrastructure:

- Subtask: `030-claude-code-pipeline-hardening`
- Owner: Codex direct implementation; Claude Code was not delegated.
- PRD file: `docs/subtasks/030-claude-code-pipeline-hardening-prd.md`
- Progress file: `docs/subtasks/030-claude-code-pipeline-hardening-progress.md`
- Wrapper: `scripts/claude_delegate.sh`
- Event bridge: `scripts/claude_event_bridge.sh`
- Task-local settings example: `.claude/delegation/030-claude-code-pipeline-hardening-settings.json`
- Event log: `docs/subtasks/logs/030-claude-code-pipeline-hardening-events.jsonl`
- Current state: wrapper verified for help, prepare, status, strict wait handoff detection, worker-progress handoff detection, manual event bridge append, and a 031 print-fallback launch with real model usage.
- Launch behavior: wrapper creates/reuses `.claude/worktrees/subtask-<id-topic>`, syncs matching `docs/subtasks/<id-topic>*` files into the worker worktree, and then launches Claude with `--worktree --tmux --agent` when interactive. In non-interactive shells, it falls back to `claude -p` from the isolated worker worktree.
- Monitoring behavior: `status` and `wait` prefer a worker progress file with real `HANDOFF`, can fall back to a manager progress file with real `HANDOFF` for legacy print-fallback runs, and otherwise prefer the worker copy.

Latest MVP visual acceptance:

- Subtask: `029-safe-area-floating-tab`
- Owner: Codex direct implementation after Claude Code non-delivery; Codex manager completed final simulator verification.
- Reason: this is a bounded SwiftUI layout implementation slice with fixed acceptance criteria and no prompt/persistence/product-semantics changes.
- PRD file: `docs/subtasks/029-safe-area-floating-tab-prd.md`
- Progress file: `docs/subtasks/029-safe-area-floating-tab-progress.md`
- Claude prompt file: `docs/subtasks/029-safe-area-floating-tab-claude-prompt.md`
- Latest raw log: `docs/subtasks/logs/029-claude-run-focused.jsonl`
- Failed first launch log: `docs/subtasks/logs/029-claude-run-failed-args.jsonl`
- Stopped no-checkpoint launch log: `docs/subtasks/logs/029-claude-run-no-start.jsonl`
- Worker path: `.claude/worktrees/subtask-029-safe-area-floating-tab`
- Current launch state: closed after worker non-delivery and Codex direct acceptance
- Failed launch session id: `61459`
- Stopped no-checkpoint session id: `32727`
- Stopped focused session id: `20801`
- Current acceptance state: no Subtask 029 worker code accepted. Codex source changes are build-verified and visually accepted with iPhone 17 simulator screenshots covering Today, History, Projects, Growth, and Settings in light/dark modes plus Growth/Settings bottom-scroll evidence.

Current wrapper commands:

```bash
scripts/claude_delegate.sh prepare <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh launch <id-topic> docs/subtasks/<id-topic>-claude-prompt.md docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh status <id-topic> docs/subtasks/<id-topic>-progress.md
scripts/claude_delegate.sh wait <id-topic> docs/subtasks/<id-topic>-progress.md
```

Default print-mode budget guard:

- `CLAUDE_DELEGATE_MAX_BUDGET_USD=30.00` for ordinary bounded Claude Code coding tasks.
- For large delegated tasks, explicitly raise to `60.00` or higher.
- Default wait schedule is `CLAUDE_DELEGATE_WAIT_SCHEDULE=180,360,540`; after those checks, if there is no `HANDOFF` and no conclusion-progress movement, Codex may intervene after classifying the stall.
- Relaunch safety: `CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=0` by default; set `1` only when intentionally discarding an existing worker attempt and resetting worker progress.

Do not run another broad `claude -p` implementation attempt for Subtask 029.

Previous MVP slice:

- Subtask: `028-real-simulator-visual-qa`
- Owner: Codex manager
- Result: findings recorded; next slice chosen as safe-area and floating-tab layout fix.
- Progress file: `docs/subtasks/028-real-simulator-visual-qa-progress.md`
- Findings file: `docs/subtasks/028-real-simulator-visual-qa-findings.md`
- Screenshot directory: `docs/subtasks/screenshots/028-real-simulator-visual-qa/`

## Latest Claude Code Worker

Subtask: `027-history-repair-ui`

- Final status: `DONE`, accepted by Codex after one manager-side TDD correction.
- Worker path: `.claude/worktrees/subtask-027-history-repair-ui`
- Main progress file: `docs/subtasks/027-history-repair-ui-progress.md`
- Worker progress file: `.claude/worktrees/subtask-027-history-repair-ui/docs/subtasks/027-history-repair-ui-progress.md`
- First failed launch log: `docs/subtasks/logs/027-claude-run.jsonl`
- Successful escalated launch log: `docs/subtasks/logs/027-claude-run-escalated.jsonl`
- Manager acceptance record: `docs/agent-delegation-log.md`

## Where To Review

Use these files in order:

1. `docs/subtasks/claude-code-current-status.md`
   - One-screen answer for whether a Claude task is currently running and where the files are.
2. `docs/agent-delegation-log.md`
   - Manager-level decision record: why delegated, what was accepted or rejected, and verification result.
3. `docs/subtasks/<id>-<topic>-progress.md`
   - Checkpoint record for the delegated task.
4. `docs/subtasks/logs/<id>-*.jsonl`
   - Raw Claude Code stream output when a Claude process was actually launched.

## Required Contract For Future Delegations

Before launching Claude Code, Codex must create and update these artifacts:

- PRD: `docs/subtasks/<id>-<topic>-prd.md`
- Progress: `docs/subtasks/<id>-<topic>-progress.md`
- Claude prompt: `docs/subtasks/<id>-<topic>-claude-prompt.md`
- Raw log: `docs/subtasks/logs/<id>-claude-run*.jsonl`
- Current status pointer: `docs/subtasks/claude-code-current-status.md`
- Manager record: `docs/agent-delegation-log.md`

If a slice is not delegated, the current status file must say `no active Claude Code worker is running` and explain why no Claude log is expected.
