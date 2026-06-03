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

## Known Remaining Work

1. Visual QA across Today, History, Projects, Growth, Settings on iPhone 17 simulator, including dark mode.
2. Project overview hierarchy and merge audit display need additional taste and evidence review.
3. Growth report explanations need continued drilldown polish.
4. Historical AI retry needs clear user entry points and candidate review behavior for failed old records.
5. Prompt inspector needs a user-visible way to inspect actual prompt composition without exposing secrets.
6. Process files should stay updated after each implementation or delegation slice.

## Current Recommended Next Slice

After Settings AI audit grouping, the next bounded implementation slice should be:

- Historical AI retry entry point and candidate review UX.

Secondary candidates:

- Real simulator visual confirmation for all tabs.
- Prompt inspector read-only view.
- Project overview hierarchy and merge audit display polish.

Choose the slice based on the user's newest bug report or the highest user-facing instability.
