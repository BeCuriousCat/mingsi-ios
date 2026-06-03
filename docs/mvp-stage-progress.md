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

## Known Remaining Work

1. Visual QA across Today, History, Projects, Growth, Settings on iPhone 17 simulator, including dark mode.
2. Project overview hierarchy and merge audit display need additional taste and evidence review.
3. Growth report explanations need continued drilldown polish.
4. Historical AI retry UI now exists for History day detail, but still needs real simulator visual QA and live GLM failure-path confirmation.
5. Prompt inspector needs a user-visible way to inspect actual prompt composition without exposing secrets.
6. AI repair and retry UI still needs clearer per-run completion/failure feedback in History and Settings beyond the global Today/banner message.
7. Claude Code implementation worktrees currently need explicit setup for untracked vendored GRDB test resources before xcodebuild verification can run reliably.
8. Process files should stay updated after each implementation or delegation slice.

## Current Recommended Next Slice

After Settings AI audit grouping, historical retry persistence/AppStore guard, and Subtask 027 History repair UI, the next bounded slice should be:

- Real simulator visual QA across Today, History, Projects, Growth, Settings, with special attention to History repair rows, dark mode readability, and long historical candidate lists.

Secondary candidates:

- Real simulator visual confirmation for all tabs.
- Prompt inspector read-only view.
- Project overview hierarchy and merge audit display polish.

Choose the slice based on the user's newest bug report or the highest user-facing instability.
