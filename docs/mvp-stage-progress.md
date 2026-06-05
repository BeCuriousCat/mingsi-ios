# MingSi MVP Stage Progress

Date: 2026-06-05

## Summary

The project has moved from concept and skeleton into MVP hardening. The main product loop and evidence foundations exist, but the repo is still in a dirty, active integration state. Continue with small verified slices and keep docs current after every slice.

## Completed Or Mostly Completed

- Product documents exist for PRD, UX, prompt spec, technical architecture, data architecture, and task breakdown.
- SwiftUI iOS app shell exists with Today, History, Projects, Growth, and Settings tabs.
- Local-first persistence is in place with SQLite/GRDB, repositories, and migrations.
- GLM BYOK path exists with Keychain API key storage, Base URL/model configuration, connection validation, user-facing failure messages, and compatibility handling for `response_format`.
- Prompt boundaries exist through provider/client/tracing concepts.
- PromptRun audit and unresolved failure recovery exist.
- Today supports supplementary input after generated cards by returning to Capture and clearing downstream derived artifacts.
- Design tokens support system dark mode.
- History supports date navigation, search, evidence filters, advanced local filters, source evidence sections, and deep links.
- Project evidence foundations exist, including Project, ProjectLink, ProjectInsight, ProjectMergeCandidate, and user review concepts.
- Growth evidence foundations exist, including MetricSnapshot, MetricContribution, evidence gates, and report review concepts.

## Recently Fixed

- History advanced filter chips no longer resize based on selected text, reducing horizontal filter row bounce.
- History advanced filter selection disables implicit animation to avoid top clipping during menu selection.
- Added a regression test for stable History filter chip metrics.
- Completed read-only Claude Code visual smoke audit. Accepted Settings AI audit list scalability as the next high-priority bounded implementation slice.
- Settings AI audit now groups recent calls into failed and successful sections, with failures expanded and successes collapsed by default.
- Completed read-only Claude Code audit for historical AI retry. Codex accepted the current-state map but rejected immediate implementation because the proposed new table would require an explicit migration and the retry semantics remain product-sensitive.
- Added historical AI retry candidate-review PRD and data architecture alignment. Historical retry is now specified as a reviewable candidate flow, starting with `organizeCards` only and requiring explicit migration before durable candidate storage.
- Added `HistoricalRetryCandidate` domain model, v8 SQLite migration, repository contract, SQLite repository implementation, and persistence tests. This establishes durable candidate storage but does not yet add History UI or AppStore retry orchestration.
- Added historical AI retry AppStore guard/use-case actions for `organizeCards`. Historical retry now reconstructs the old DailyEntry input, calls the existing Today AI service, stores regenerated cards as a reviewable candidate payload, leaves current-day cards unchanged, rejects unsupported prompts, and blocks candidate acceptance when confirmed cards already exist.
- Hardened live GLM behavior for user-reported AI instability: local prompts now default to Simplified Chinese while following the user's input language, `DirectGLMClient` retries recoverable 429/529/5xx responses for both normal and SSE calls, and AppStore exposes an AI busy state that disables duplicate Today/background retry actions.
- Added local History repair helper coverage for candidate payload preview decoding, candidate status labels, and `organizeCards`-only historical retry support. This unblocks test compilation for Subtask 027 but does not complete the full History repair UI.
- Completed Subtask 027 History repair UI via Claude Code delegation plus Codex acceptance fix. History day detail now exposes `历史 AI 修复`, loads unresolved prompt failures and historical retry candidates, lets supported `organizeCards` failures generate candidate cards, shows candidate previews/statuses, and supports accept/dismiss review actions. Codex added a downstream-evidence repair guard so warnings cover confirmed cards, tasks, verification, principles, project links, growth contributions, and lens/session summaries.
- Completed Subtask 028 real simulator visual QA documentation. Screenshots identified P1 safe-area / floating Tab bar overlap issues and chose Subtask 029 as the next implementation slice.
- Prepared Subtask 029 safe-area / floating Tab bar delegation package. Claude Code attempts did not produce a handoff, so no 029 implementation has been accepted.
- Added Subtask 030 Claude Code delegation pipeline hardening. Future implementation attempts have repo-owned `prepare`, `launch`, `status`, and `wait` commands, task-local hook settings, file-bridge event logs, explicit prompt separation after `--allowedTools`, strict handoff detection, and macOS-compatible timestamps.
- Fixed Settings AI audit group expand/collapse flicker at the SwiftUI view level by removing group-wide animation and row transition while keeping chevron-only feedback.
- Completed Subtask 029 safe-area/floating-tab visual acceptance after Claude Code non-delivery and Codex direct source work. iPhone 17 simulator screenshots now cover Today, History, Projects, Growth, and Settings in light/dark modes, with extra Growth/Settings bottom-scroll evidence.
- Completed Subtasks 032 and 033 Claude Code utilization smokes. The wrapper now runs non-interactive print fallback inside the isolated worker worktree, uses worker progress as the manager-facing conclusion source, retains event/raw logs as flow logs, keeps flow-log tails hidden by default, and syncs delegation scripts into worker worktrees for local read-only inspection.
- Separated the reusable Codex-to-Claude Code delegation framework thread from MingSi product hardening. Added a generic skill prototype and parameterized the wrapper task/log roots so future projects are not tied to MingSi `docs/subtasks`.
- Completed Subtask 034 manual Principle creation via Claude Code dogfood plus Codex acceptance fix. Growth now has a direct `添加原则` entry, manual principles persist through the existing repository as active `PrincipleAsset` records linked to today's DailyEntry, and long-lived `activePrinciples` are not cleared by Today reset.
- Added dynamic delegation wait backoff guidance and wrapper support: default `wait` can use 3/6/9 minute checks before manager intervention, and now reports whether conclusion progress actually moved before allowing stall classification.
- Completed Subtask 035 Prompt inspector read-only view via Claude Code delegation plus Codex boundary fix. Settings now has a collapsed `Prompt 模板` inspector for current first-party prompt templates, prompt/mode metadata, and selectable System/User text without exposing secrets or sending model requests.
- Completed Subtask 036 AI repair status feedback polish via Claude Code delegation plus Codex copy fix. History repair rows and Settings PromptRun audit rows now explain whether a run is success evidence, repairable failure, audit-only failure, reviewable candidate, terminal result, blocked, or failed without changing retry semantics.
- Completed Subtask 037 Project merge audit display via Claude Code delegation. Pending merge rows now explain evidence refs and merge consequences, and Project Detail shows retained `mergeHistory` as a conditional `合并审计` section without changing merge behavior.
- Completed Subtask 038 Growth report drilldown polish via Claude Code delegation plus Codex acceptance fix. Growth report review rows now show metric title, positive/negative accepted contribution counts, the leading contribution, and stored metric reason or conservative fallback copy; metric detail keeps evidence navigation while showing fallback reason text when accepted contributions exist.
- Verified the Subtask 038 delegation relaunch-safety follow-up. The wrapper now preserves worker progress on relaunch unless `CLAUDE_DELEGATE_OVERWRITE_WORKER_PROGRESS=1`, recognizes `## HANDOFF`, and keeps `status` / `wait` conclusion-first with raw/event logs retained only for diagnostics.
- Completed Subtask 039 First Principles Lens Catalog via Claude Code delegation. Today now includes `第一性原理` as an MVP built-in lens through a lightweight built-in catalog boundary, while existing lens raw values remain stable and catalog prompt ids are separate metadata.
- Completed Subtask 040 Project overview hierarchy audit via Claude Code delegation. Findings recommend a narrow display-only Project Detail hierarchy slice: fix thinking-change headline accuracy, reduce placeholder overview noise, visually group sections, and hide empty progress signals.
- Completed Subtask 041 Project Detail hierarchy cleanup via Claude Code delegation plus Codex manager fix. Project Detail now avoids placeholder-heavy overview rows, distinguishes insufficient thinking-change evidence from unconfirmed insight candidates, hides empty progress signals, and groups sections into clearer visual tiers without changing Project semantics.
- Completed Subtask 042 Lens Prompt Context Wiring via Claude Code delegation. Today AI request payloads now use built-in lens catalog prompt ids such as `first_principles` / `leverage_analysis`, while structured context preserves local `ThinkingLens.rawValue` and exposes lens catalog metadata for audit/debugging. Focused `TodayAIServiceContextTests` passed with 16 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- Completed Subtask 043 Delegation Status Handoff Summary as a direct framework fix. The wrapper `status` command now surfaces active `HANDOFF` summaries and final status tokens, and prefers manager-side `CODEX_ACCEPTED` progress after Codex acceptance, preserving conclusion-first monitoring without routine raw/event log inspection.
- Completed Subtask 044 Project Status Filter via Claude Code delegation. Projects top-level board now has local `全部 / 活跃 / 关注中 / 暂停 / 已归档` filtering over existing `ProjectStatus` values, with no AppStore, persistence, migration, prompt, parser, LLM, or Project semantic changes. Focused `HistoryFeatureTests` passed with 65 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- Completed Subtask 045 Extensible Lens Library Boundary from the user's request that `第一性原理` live under a可扩展透镜库 rather than a UI/prompt smoke stack. Claude Code wrapper prepare/launch were blocked before execution by OS `spawn /bin/sh EAGAIN`, so Codex directly implemented the narrow Domain/test slice: `LensCatalogProviding`, `LensLibrary`, `BuiltinLensCatalog.library`, local-id/prompt-id/ThinkingLens lookup tests, with no UI, AppStore, persistence, prompt, parser, LLM, Keychain, History, Projects, Growth, or Settings changes. Focused `AppStoreStateMachineTests` passed with 110 tests and 0 failures, `git diff --check` passed, and iPhone 17 simulator build passed.
- Completed Subtask 047 First Principles Lens Prompt Guidance as a direct architecture slice. Built-in lens catalog items now carry `promptGuidance`, and Today AI request assembly exposes `lensTitle`, `lensMethodLine`, and `lensPromptGuidance` through the existing `PromptContextPayload` / legacy payload boundary. This keeps `第一性原理` as normal extensible lens-library data rather than a UI or Prompt call-site branch. Focused tests passed with 18 tests and 0 failures.
- Completed Subtask 046 Delegation Strict Handoff Detection as a framework/control-plane fix after Claude Code launch was blocked before worker start three times. The wrapper now requires a real final status token before `status` prints an active handoff summary or `wait` exits success; bare/template `## HANDOFF`, `Pending worker update.`, and `- HANDOFF: reached` no longer count as completion. Manager-side `CODEX_ACCEPTED` remains accepted, flow logs remain diagnostic-only, external temporary progress fixtures no longer pollute status with outside-repo path noise, and `git diff --check` passed.
- Completed Subtask 048 Project Detail visual-smoke readiness audit via Claude Code after the user restarted Codex and cleared the Codex-owned zombie process buildup. Worker reached `HANDOFF/DONE`; Codex accepted the read-only findings as planning evidence only. The audit identifies 10 Project Detail screenshot states, 6 source-inferred visual risks, and 3 narrow follow-up candidates. No Swift source or test files were modified; real iPhone 17 screenshots are still required before confirming visual risks or implementing follow-ups.
- Started delegation resource-hygiene hardening after Subtask 048 reproduced residual process-leak risk. `scripts/claude_delegate.sh` now keeps tmux/session mode by default in non-interactive shells, makes Claude agent/MCP preflight opt-in, and blocks prepare/launch/wait when Codex or total zombie counts exceed configured thresholds. The generic skill prototype now treats resource hygiene as part of delegation correctness.
- Completed Subtask 051 delegation lifecycle cleanup after Subtask 050 exposed a launch-before-START failure. The wrapper now observes tmux/session launch exit status instead of backgrounding the launcher by default, reports task-scoped worker liveness in `status`/`wait`, exits `wait` early when no worker process and no checkpoint exist, and provides task-scoped `cleanup` before relaunch. This is a generic framework fix; no MingSi product source changed.

## Known Remaining Work

1. Project Detail hierarchy cleanup is implemented and build/test verified; Subtask 048 now provides the screenshot matrix, but real iPhone 17 light/dark screenshots still need to be captured before visual follow-up implementation.
2. Growth report drilldown has Subtask 038 coverage; deeper longitudinal comparison can be added later only with enough evidence.
3. Historical AI retry UI now exists for History day detail, but still needs live GLM failure-path confirmation.
4. Lens catalog prompt ids and prompt guidance are wired into Today AI prompt payloads for question and quest generation. Later prompt/context work should remain focused and preserve `PromptProvider` / `LLMClient` boundaries.
5. Claude Code implementation worktrees currently need explicit setup for untracked vendored GRDB test resources before xcodebuild verification can run reliably.
6. Delegation wrapper strict handoff detection is fixed in Subtask 046, and Subtask 048 added resource guards for Codex zombie buildup. Future framework work should still validate tmux-mode launches under real delegation load.
7. Subtask 051 adds launch lifecycle and cleanup handling, but it still cannot reap zombies already owned by Codex if the Codex parent process itself fails to reap children.
8. Process files should stay updated after each implementation or delegation slice.
9. Claude Code flow logs are retained for diagnosis, but manager review should consume worker progress/HANDOFF first and open raw/event logs only when acceptance fails or progress reveals a hard issue.
10. Subtask 047 keeps First Principles lens behavior under the Domain library/provider boundary. Future lens work should extend catalog metadata instead of adding UI/prompt-specific lens branches.

## Current Recommended Next Slice

After Subtasks 046 and 047, the next bounded slice should be chosen from:

- Project Detail real iPhone 17 visual-smoke screenshots using the Subtask 048 matrix, followed by a narrow display-only fix only if screenshots confirm the risk.
- Live GLM failure-path confirmation for History repair, if a real BYOK configuration is available for safe testing.
- Delegation worker-launch reliability hardening, especially tmux/session-mode validation and post-handoff process cleanup checks.

Choose the slice based on the user's newest bug report or the highest user-facing instability. Prefer Claude Code for read-only audits and narrow UI/service implementation slices that have a clear progress contract and acceptance evidence.
