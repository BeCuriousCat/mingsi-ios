# MingSi MVP Stage Progress

Date: 2026-06-03

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
- Codex began direct Subtask 029 safe-area/floating-tab source work and passed build verification, but full light/dark simulator screenshot acceptance is still incomplete.
- Completed Subtasks 032 and 033 Claude Code utilization smokes. The wrapper now runs non-interactive print fallback inside the isolated worker worktree, uses worker progress as the manager-facing conclusion source, retains event/raw logs as flow logs, keeps flow-log tails hidden by default, and syncs delegation scripts into worker worktrees for local read-only inspection.

## Known Remaining Work

1. Subtask 029 safe-area and floating Tab bar layout fix remains partially verified after Claude Code non-delivery and Codex direct source changes.
2. Visual QA must be completed after Subtask 029 across Today, History, Projects, Growth, Settings on iPhone 17 simulator, including dark mode.
3. Project overview hierarchy and merge audit display need additional taste and evidence review.
4. Growth report explanations need continued drilldown polish.
5. Historical AI retry UI now exists for History day detail, but still needs live GLM failure-path confirmation.
6. Prompt inspector needs a user-visible way to inspect actual prompt composition without exposing secrets.
7. AI repair and retry UI still needs clearer per-run completion/failure feedback in History and Settings beyond the global Today/banner message.
8. Claude Code implementation worktrees currently need explicit setup for untracked vendored GRDB test resources before xcodebuild verification can run reliably.
9. Process files should stay updated after each implementation or delegation slice.
10. Claude Code flow logs are retained for diagnosis, but manager review should consume worker progress/HANDOFF first and open raw/event logs only when acceptance fails or progress reveals a hard issue.

## Current Recommended Next Slice

After Subtask 030 pipeline hardening and the partial Subtask 029 source work, the next bounded slice should be:

- Complete Subtask 029 simulator screenshot verification, especially Settings/Growth bottom content around the floating Tab bar and History top content around the Dynamic Island.

Secondary candidates:

- Run the new Claude Code delegation wrapper on the next genuinely bounded worker slice and measure whether it saves manager effort.
- Prompt inspector read-only view.
- Project overview hierarchy and merge audit display polish.

Choose the slice based on the user's newest bug report or the highest user-facing instability.
