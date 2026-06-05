# MingSi Project Continuation Context

Last updated: 2026-06-05

## Current Role Contract

Codex is the MingSi / 明思 product owner, architect, engineering owner, delegation manager, and final verifier.

Claude Code may be used only for bounded implementation or read-only audit slices. Codex must shape the task, keep process docs current, review any worker result after `HANDOFF`, and run fresh verification before acceptance.

## Current Pursuit Goal

Codex is pursuing a usable personal alpha and an engineering loop that can be audited after a context restart.

There are now two explicitly separate project threads:

1. MingSi product hardening is the business main thread.
2. Codex-to-Claude Code managed delegation is a reusable framework thread that should remain extractable and open-sourceable.

The delegation framework may be dogfooded on MingSi subtasks, but its public contract must not depend on MingSi product semantics, SwiftUI, iOS, or a fixed `docs/subtasks` path.

The current goal is:

- Make MingSi a quiet, reliable, evidence-backed thinking coach rather than an AI wrapper.
- Make Claude Code delegation useful through observable checkpoints, task-local hook events, raw logs, and final handoff evidence.
- Treat GLM/Claude token counters as weak telemetry only; progress is proven by progress files, changed files, tests, builds, screenshots, and logs.
- Use Claude Code generously when the slice is well bounded: the user expects GLM coding-plan capacity to be spent to buy back GPT manager tokens, with ordinary worker tasks budgeted high enough to finish rather than starve.
- Prefer direct Codex implementation when a slice is too small, too taste-heavy, or too process-critical for delegation.
- Reduce manager-token overhead by moving routine delegation boilerplate into a generic task contract, templates, wrapper commands, and conclusion-first monitoring.

## Current MVP Stop Condition

Use `docs/mvp-current-goal.md` as the active stop condition.

MVP can stop only when the app is a coherent personal alpha that supports:

- Today input, Quick / Standard / Deep mode, streaming organization, card review, lens questions, quests, principle candidates, supplementary input, and retryable AI failure recovery.
- History as an evidence archive with raw input, cards, lens, questions, quests, verification, principles, project evidence, growth contributions, search, date navigation, and local filters.
- Projects as evidence-backed long-running topics.
- Growth as an attribution ledger, not unsupported scoring.
- Settings with BYOK GLM configuration, Keychain storage, connection validation, and AI audit visibility.
- AI failures visible, retryable, and auditable.
- iPhone simulator build and targeted MVP regression tests passing.

## Current Worktree State

At the last recorded check, Subtask 038 source/docs and the delegation relaunch guard were committed in the latest local commit.

The repo may become dirty again during new subtasks. Treat the live worktree as authoritative and do not clean or revert unrelated user, Codex, Claude Code, GLM, or other-agent changes.

Subtask 030 pipeline hardening is Codex-authored. No Claude Code worker was delegated for 030.

Subtasks 032 and 033 proved the repaired Claude Code wrapper path:

- 032 proved print fallback can run from the isolated worker worktree and reach worker-progress `HANDOFF`.
- 033 proved the conclusion-first log model: worker progress is the manager-facing conclusion source, event/raw logs are retained as flow logs, and default `launch/status/wait` no longer require the manager to consume raw JSONL.
- The wrapper now syncs `scripts/claude_delegate.sh` and `scripts/claude_event_bridge.sh` into worker worktrees so workers can inspect the delegation pipeline from isolation.

Subtask 034 proved the wrapper on a real MingSi business slice:

- Manual Principle creation is available from Growth.
- Worker reached `HANDOFF/DONE`.
- Codex accepted with a manager fix so long-lived principles read from `activePrinciples`, not Today's resettable principle candidates.

Subtask 035 proved the wrapper on a Settings auditability slice:

- Settings has a collapsed read-only `Prompt 模板` inspector.
- Worker reached `HANDOFF/DONE`.
- Codex accepted with a manager fix so `SettingsView` reads templates through `AppStore.promptTemplate(for:mode:)` and the `PromptProvider` boundary.
- Commit: `23eef3e Add prompt inspector read-only view`.

Subtask 036 proved the wrapper on a History/Settings AI repair feedback slice:

- History repair rows and Settings PromptRun audit rows now show clearer per-run/per-candidate status.
- Worker reached `HANDOFF/DONE` after one API-disconnect non-delivery attempt.
- Codex accepted with a manager copy fix so candidate status text does not overstate current persistence behavior.
- Commit: `2c023b2 Polish AI repair status feedback`.

Subtask 037 proved the wrapper on a Projects display-audit slice:

- Pending Project merge rows now show clearer evidence refs and merge consequences.
- Project Detail shows accepted merge history as a conditional `合并审计` section.
- Worker reached `HANDOFF/DONE`.
- Codex accepted the scoped display-only diff after focused tests, `git diff --check`, and iPhone 17 simulator build.

Subtask 038 proved the wrapper on a Growth display-audit slice and exposed a framework relaunch-safety fix:

- Growth report review rows now show metric title, accepted positive/negative contribution counts, strongest contribution, and stored metric reason or conservative fallback copy.
- Metric detail keeps evidence navigation and shows fallback reason text when accepted contributions exist but no stored reason is present.
- Worker reached `HANDOFF/DONE_WITH_CONCERNS`; the concern was worker Bash failure, so Codex reran verification in the manager worktree.
- Codex accepted after focused `HistoryFeatureTests` passed with 53 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- The delegation wrapper now preserves worker progress on relaunch unless `CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=1` and recognizes `## HANDOFF`.

Subtask 039 proved the wrapper on a bounded product/catalog slice:

- Today now includes `第一性原理` as an MVP built-in lens.
- Lens metadata is represented through `BuiltinLensCatalog`, including durable local id, prompt-facing id, version, display copy, method line, short label, and SF Symbol name.
- Existing persisted `ThinkingLens.rawValue` values remain unchanged.
- Worker reached `HANDOFF/DONE_WITH_CONCERNS`; the concern was the known GRDB worker-worktree `xcodebuild` issue, so Codex reran verification in the manager worktree.
- Codex accepted after focused `AppStoreStateMachineTests` passed with 105 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.

Subtask 040 proved the wrapper on a read-only Projects hierarchy audit:

- Worker reached `HANDOFF/DONE`.
- Findings map the current Projects top-level and Project Detail hierarchy with concrete symbols in `Sources/Features/FeatureTabs.swift`.
- Codex accepted the recommendation to make the next implementation slice display-only: fix Project Detail thinking-change headline accuracy, reduce placeholder overview noise, group sections, and hide empty progress signals.
- Status segment filtering was explicitly deferred to a separate slice because it requires new view state.

Subtask 041 implemented the accepted Project Detail hierarchy cleanup:

- Worker reached `HANDOFF/DONE_WITH_CONCERNS`; the concern was the known GRDB worker-worktree `xcodebuild` issue.
- Codex accepted the display-only direction and added a manager fix for overview trimming/whitespace filtering and empty Overview surface suppression.
- Project Detail now groups sections into primary, secondary, and tertiary tiers.
- Thinking-change copy no longer labels projects with before/after evidence as `证据不足`; it waits for user-confirmed ProjectInsight.
- Codex accepted after focused `HistoryFeatureTests` passed with 61 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.

Subtask 042 wired the lens catalog into Today AI prompt/context payloads:

- Worker reached `HANDOFF/DONE_WITH_CONCERNS`; the concern was the known GRDB worker-worktree `xcodebuild` issue.
- Model-facing `selectedLens` now uses catalog prompt ids such as `first_principles`, `leverage_analysis`, and `evidence_check`.
- Local persisted lens identity remains `ThinkingLens.rawValue` through structured context, so persistence/history filters keep stable local ids.
- Structured prompt context now includes selected lens catalog metadata: local id, prompt id, version, title, and method line.
- Codex accepted after focused `TodayAIServiceContextTests` passed with 16 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- Pipeline observation: `scripts/claude_delegate.sh status` briefly showed stale progress even after the worker wrote `HANDOFF`; raw/event logs were opened only after the conclusion path became inconsistent. Treat this as a wrapper follow-up, not a product blocker.

Subtask 043 fixed that delegation framework status follow-up:

- No Claude Code worker was launched because the bug was inside the manager wrapper.
- `scripts/claude_delegate.sh status` now surfaces active `HANDOFF` summaries and final status tokens instead of only printing the top of long progress files.
- After Codex acceptance, routine status prefers manager-side `Status: CODEX_ACCEPTED` progress over an older worker copy.
- Flow logs remain diagnostic-only; conclusion progress remains the default manager consumption path.
- Verification covered wrapper syntax, 042 handoff summary visibility, 042 manager-accepted progress precedence, 029 pending-handoff rejection, and `git diff --check`.

Subtask 044 added Projects top-level status filtering:

- Worker reached `HANDOFF/DONE_WITH_CONCERNS`; the concern was the known GRDB worker-worktree `xcodebuild` issue.
- Projects top-level board now has local `全部 / 活跃 / 关注中 / 暂停 / 已归档` chips over existing `ProjectStatus` values.
- Filtering is display-only local `ProjectsView` state and does not change Project semantics, AppStore orchestration, persistence, migrations, prompt, parser, LLM, Keychain, Growth, Settings, or Today behavior.
- Missing Project metadata remains visible under `全部` and is excluded from concrete status filters.
- `议题治理` / merge review remains based on unfiltered evidence-backed project count.
- Codex accepted after focused `HistoryFeatureTests` passed with 65 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- Pipeline observation: `scripts/claude_delegate.sh status` displayed the template `## HANDOFF` placeholder before real handoff. Codex ignored it for acceptance; treat this as a delegation-wrapper strictness follow-up.

## Latest Completed Product Evidence

Subtask 029 safe-area / floating-tab visual acceptance is complete:

- Commit: `c555dd0 Accept safe area visual verification`.
- Real iPhone 17 simulator screenshots cover Today, History, Projects, Growth, and Settings in light/dark modes.
- History top content no longer enters the status bar / Dynamic Island area.
- Growth and Settings content can scroll above the floating Tab bar.
- Projects kept full-width background treatment without reintroducing side gutters.
- Settings AI audit expand/collapse flicker was accepted from the user's direct confirmation and was not re-recorded.

Subtask 028 captured the original real iPhone 17 simulator findings that drove 029:

- P1: History content can appear under the status / Dynamic Island area.
- P1: Growth and Settings content can rest under the floating Tab bar.
- P2: Settings dark-mode placeholder/disabled text contrast is low.
- P2: Today dark-mode return state needs confirmation after the safe-area fix.

Source:

- `docs/subtasks/028-real-simulator-visual-qa-findings.md`

## Active / Paused Subtask

No active Claude Code worker is running.

Latest completed subtask:

- Subtask: `044-project-status-filter`
- PRD: `docs/subtasks/044-project-status-filter-prd.md`
- Progress: `docs/subtasks/044-project-status-filter-progress.md`
- Claude prompt: `docs/subtasks/044-project-status-filter-claude-prompt.md`
- Worker path: `.claude/worktrees/subtask-044-project-status-filter`
- Result: `HANDOFF/DONE_WITH_CONCERNS`, Codex accepted after fresh focused tests, diff check, and iPhone 17 simulator build.

Latest framework subtask:

- Subtask: `043-delegation-status-handoff-summary`
- PRD: `docs/subtasks/043-delegation-status-handoff-summary-prd.md`
- Progress: `docs/subtasks/043-delegation-status-handoff-summary-progress.md`
- Result: direct Codex wrapper fix, no Claude Code worker launched, Codex accepted after targeted wrapper regression checks.

## Subtask 029 Claude Attempts

Attempt 1:

- Session id: `61459`
- Log: `docs/subtasks/logs/029-claude-run-failed-args.jsonl`
- Result: failed before `START` because CLI argument parsing swallowed the prompt after variadic `--allowedTools`.
- Accepted output: none.

Attempt 2:

- Session id: `32727`
- Log: `docs/subtasks/logs/029-claude-run-no-start.jsonl`
- Result: ran for two low-frequency checks with log output but never updated `START`.
- Process killed: PID `13981`.
- Accepted output: none.

Attempt 3:

- Session id: `20801`
- Log: `docs/subtasks/logs/029-claude-run-focused.jsonl`
- Result: reached `START`, then failed to reach `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, or `HANDOFF` after repeated low-frequency checks.
- Process killed: PID `18237`.
- Accepted output: none.

These attempts are historical evidence only. Do not reuse the broad 029 prompt pattern for new implementation work.

## Recommended Next Action

Preferred next move:

1. Choose the next bounded MVP hardening slice from `docs/mvp-stage-progress.md`:
   - Project Detail visual smoke verification and any narrow follow-up from screenshots.
   - Live GLM failure-path confirmation for History repair.
   - Delegation wrapper strict handoff detection follow-up for template `## HANDOFF` placeholders.
2. Prefer a slice that improves alpha usability and can be verified by focused tests plus an iPhone 17 build.
3. Use Claude Code generously when the slice has a clear write set and acceptance tests, but keep Codex responsible for product judgment and final acceptance.
4. Keep the delegation framework generic:
   - Boundary doc: `docs/delegation-framework-boundary.md`
   - Skill prototype: `delegation-framework/claude-code-managed-delegation/SKILL.md`
   - Wrapper: `scripts/claude_delegate.sh`
5. Use the new delegation wrapper for future Claude Code implementation workers:
   - `scripts/claude_delegate.sh prepare <id-topic> docs/subtasks/<id-topic>-progress.md`
   - `scripts/claude_delegate.sh launch <id-topic> docs/subtasks/<id-topic>-claude-prompt.md docs/subtasks/<id-topic>-progress.md`
   - `scripts/claude_delegate.sh status <id-topic> docs/subtasks/<id-topic>-progress.md`
   - `scripts/claude_delegate.sh wait <id-topic> docs/subtasks/<id-topic>-progress.md`
   - On launch, the wrapper syncs matching `docs/subtasks/<id-topic>*` files into the worker worktree.
   - For monitoring, worker progress is authoritative when present; manager progress is only the fallback.
   - Manager review should consume worker progress/HANDOFF first. Event/raw logs are flow logs and should be opened only after a problem, failed acceptance, or non-trivial discrepancy.
   - Default wait uses `CLAUDE_DELEGATE_WAIT_SCHEDULE=180,360,540`; after those checks, if there is no `HANDOFF` and no conclusion-progress movement, Codex may intervene after classifying the stall.

Do not launch another broad `claude -p` implementation run for this slice without a stricter wrapper. The focused prompt improved behavior enough to reach `START`, but not enough to produce `HANDOFF`.

## Required Next Verification

For the next accepted implementation slice, Codex must rerun at minimum:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Add focused unit tests or simulator screenshots according to the slice's risk and acceptance criteria.

## Review Entry Points

Start future review here:

1. `docs/project-continuation-context.md`
2. `docs/mvp-current-goal.md`
3. `docs/mvp-stage-progress.md`
4. `docs/subtasks/claude-code-current-status.md`
5. `docs/subtasks/029-safe-area-floating-tab-progress.md`
6. `docs/agent-delegation-log.md`
7. `docs/verification-log.md`
