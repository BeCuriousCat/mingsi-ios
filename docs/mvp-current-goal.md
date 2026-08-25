# MingSi Current Goal

Date: 2026-08-20

## Current Product Stage

MingSi is implementing and validating the vNext multi-matter coaching loop:

```text
记录一天中的多件事项
-> AI 建议拆分，用户确认
-> 任意时刻只训练一件
-> 形成可验证行动
-> 按真实证据更新判断
-> 项目结束时完成最小复盘
-> 长期沉淀可回链的成长证据和原则
```

The user-facing term is `事项`; the internal aggregate is `TrainingCase`. The existing three-stage training hierarchy remains visible, while the internal `DailyLoopState` and `TrainingCaseSession` remain implementation details.

## Single Simulator Execution Standard

- Daily use and manual debugging use only the existing iPhone 17 Simulator with UDID `9F93EE80-68DF-4922-8A73-B0590F5143D4`.
- Do not switch simulator models or start any other device. iPad and other device records may remain installed, but they must not be booted or used for verification.
- Use the fixed simulator destination by UDID when launching or testing; do not substitute a name-only destination.
- Preflight on 2026-08-20 confirmed the app is installed and launchable on the fixed iPhone 17 simulator; no new crash was observed in the current launch. This is a launch check only, not real-use evidence.
- Full `MingSiUITests` regression ran serially on the fixed iPhone 17 simulator on 2026-08-20: 55 passed, 0 failed. The run used about 1 GB of temporary build/test capacity; retain several GB of headroom before repeating it.

## Current Milestone

The active milestone is **MingSi vNext: Closed-Loop Reliability and Usability Acceptance**.

Target delivery gates (implementation status is tracked below; this list is not a claim that they have passed):

- v33-v39 migrations, SQLite online-backup versioned pre-migration backup, legacy fallback, export, and legacy backfill are verified.
- Today can confirm multiple matters, keep one active matter, persist before switching, and prevent evidence/context crossover.
- Due verification is non-blocking and can be completed or deferred without creating false evidence.
- Verification and `GrowthSettlement` commit together; settlement shows evidence, never a per-session score change.
- History, Projects, and Growth resolve evidence back to the correct matter and source.
- Project closure requires reason and actual outcome; archive and review commit atomically, restoration preserves the closure review and prior status, and AI principle candidates require explicit evidence-backed confirmation.
- Meaningful recommendations and evidence classifications go through the shared `CentralLLMDecisionCenter`; local code only supplies bounded candidates and enforces consent, safety, cooldown, mastery, and durable state.
- The model also diagnoses each confirmed matter's phase, training dimension, and recommended lens before the question loop; vNext production waits for that decision and never presents a local interpretation. Missing-key/offline mode remains retryable; only injected test/preview paths may show an explicitly labeled fallback.
- Guidance copy comes from the versioned catalog, while the model decides whether to show one eligible hint and whether verification evidence supports or contradicts it.
- A user-triggered weekly review remains evidence-gated at three recent verifications across two calendar days; the model may select existing guidance IDs and evidence refs, but cannot write scores or new UI copy.
- Simulator build, focused vNext tests, full unit/UI regression, migration rehearsal, and real-device launch pass.

## Acceptance Status (2026-08-20)

- [x] Source-level fixes for the project-closure reason label, History repair filtering, and same-source Growth contribution de-duplication.
- [x] v37 CoachPromptTurn schema, AppStore lifecycle, exact presented-output attribution, quality-gate outcomes, and local feedback categories are complete.
- [x] v38 persists one immutable weekly Guidance review per natural week. Repeated actions and App restarts reuse it without another model request.
- [x] v39-v40 persist side-quest preferences, one open invitation at a time, LLM offer/hold decisions with PromptRun audit, and one immutable positive life-experience event with continuity after an accepted quest is completed. Invitations are visible by default but remain optional; notifications require explicit permission. It remains separate from the five coaching metrics.
- [x] Simulator build and unit-test evidence after canonical Verification attribution: `MingSiTests` 905 passed, 1 skipped, 0 failed. Full UI regression is not included in this evidence.
- [x] The fixed `MingSi Dev` iPhone 17 simulator (`9F93EE80-68DF-4922-8A73-B0590F5143D4`) is available for manual testing, isolated from UI-test fixture data; no other device is part of daily execution.
- [x] Manual-case dead-end is closed: the central model receives each new manual Case before presenting a training prescription; vNext missing-key/offline mode stays retryable without promoting a local judgment, legacy missing prescriptions self-repair on open, injected preview questions stay Case-scoped, and restart restores the active Case state without evidence crossover.
- [x] Settings separates ordinary model/data controls from advanced Prompt diagnostics and local asset packs; production UI hides remote registry, subscription, remote-manifest, and Marketplace surfaces while QA fixtures retain coverage.
- [x] Post-fix unit/VNext regression passes: `VNextTests` 79 passed; full `MingSiTests` executed 967 with 1 skipped and 0 failures. `MingSiUITests.swift` is no longer incorrectly compiled into the unit-test target.
- [x] Today judgment-stage density gate passes: Guidance details and state actions are progressive disclosure, coach feedback follows the training content, and the first answer field no longer overlaps the fixed primary action on the dedicated iPhone 17 simulator.
- [x] `MingSi Dev` normal persisted-data launch remains alive with no crash report or process fault; the observed install/launch failure was traced to full local storage and recovered by removing only regenerable MingSi DerivedData. Daily debugging remains simulator-only.
- [x] Growth shows the controlled weekly-review evidence gate before exposing its generate action: the local 7-day verification and day-coverage progress matches `WeeklyGuidanceReviewPolicy`, and an AI generation command appears only after the existing 3-verification, 2-day threshold is met.
- [x] Black-box migration rehearsal passes against the preserved real v32 database copy: the consistent backup remains at v32, the working database reaches v38, all legacy record counts remain intact, and current Growth evidence has zero missing Case links or duplicate evidence keys.
- [x] Synthetic v1 and complex v32 fixtures continue to prove schema backfill, export coverage, and failure rollback.
- [x] Full `MingSiUITests` regression: 55 passed, 0 failed on the fixed iPhone 17 simulator UDID. The stale side-quest fixture assertion was aligned with the stable catalog title and independently rerun before the passing suite.
- [ ] Real-device launch remains pending and is intentionally not used for daily debugging.
- [ ] 3-7 day real-use trial: remains READY; no user-generated observations exist, so the Day 1-7 record remains blank. It begins only with intentional normal use on the fixed iPhone 17 simulator.

The current next objective is the **3-7 day real-use trial**. Daily execution remains on the fixed simulator only; no other device launch is scheduled. Prompt copy changes remain frozen until presented-turn feedback provides repeated evidence such as `wrong_target`, `repetitive`, or `too_abstract`.

Use [vnext-real-use-trial.md](vnext-real-use-trial.md) for the daily privacy-minimized record and the vNext.1 decision summary.

The implementation source of truth is [vnext-final-execution-plan.md](vnext-final-execution-plan.md).

## Experience Gate

After implementation acceptance, run a 3-7 day real-use trial. Record:

- daily matter count and AI grouping edit rate;
- completion, suspension, and abandonment stage per matter;
- any evidence crossover or wrong context use;
- coach feedback: useful, wrong target, repetitive, too abstract, or gave away the answer;
- action completion-criteria quality;
- verification completion and deferral reasons;
- whether growth settlement feels credible without inviting score gaming;
- whether project closure creates reusable principles;
- guidance frequency, repetition, and mastery accuracy.

The trial informs vNext.1. It is not a prerequisite for this implementation.

## Explicitly Deferred

`Provider Profile Foundation v1` is superseded by this milestone and is not the current goal. Do not start multi-provider expansion, account/user center, cloud sync, team collaboration, a remote guidance marketplace, rankings, streak incentives, or a new score for the five evidence-based coaching metrics until vNext has passed implementation acceptance and the real-use trial. The side-quest life-experience ledger is intentionally separate from those metrics.

## Constraints

- Do not expose engineering state names in product UI.
- Do not allow simultaneous active coaching requests for multiple matters.
- Do not auto-confirm, merge, split, close, restore, or save principles.
- Do not bypass the central decision center for a meaningful recommendation or classification. Do not add gratuitous calls when no decision is required. A configured model failure must remain retryable; it must not be replaced by a local-looking judgment.
- Do not turn Projects into task management.
- Do not add per-session scores, ranking, or personality judgments. Positive side-quest life experience, optional notifications, and its non-punitive continuity record are allowed and remain separate from the five coaching metrics. Mainline streak incentives remain out of scope.
- Do not delete old data or rewrite historical verification facts.
- Keep API keys in Keychain and out of database export, logs, and PromptRun content.
