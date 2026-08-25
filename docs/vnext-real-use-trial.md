# MingSi vNext Real-Use Trial

Status: READY  
Window: 3-7 consecutive days  
Scope: normal use on the fixed iPhone 17 Simulator, UDID `9F93EE80-68DF-4922-8A73-B0590F5143D4`.

Preflight (2026-08-24): the app is installed and launchable on the fixed iPhone 17 simulator; the UI gate passed with `scripts/run_ui_automation.sh --only-testing MingSiUITests` (56 tests, 0 failures). `DebuggerVersionStore` warnings were non-fatal. This is an acceptance check only and does not start the trial.

Data status: no user-generated observations exist; the Day 1-7 record remains blank.

## Single Simulator Execution Standard

- Daily use and manual debugging use only UDID `9F93EE80-68DF-4922-8A73-B0590F5143D4`.
- Do not switch simulator models or start another device. iPad and other device records may remain installed, but they are retained only as non-running records.
- Full `MingSiUITests` regression passed on 2026-08-24: 56 passed, 0 failed, run serially on the fixed iPhone 17 simulator. Leave several GB of temporary build/test headroom before repeating it.
- The real-use record below is intentionally unfilled. Do not fabricate Day 1-7 observations, outcomes, or feedback.

## Guardrails

- Do not seed or fabricate outcomes to improve the metrics.
- Do not copy raw captures, place labels, calendar text, health samples, API keys, or PromptRun bodies into this record.
- Record an issue once with its opaque item, Quest, Verification, or PromptRun identifier when available; never infer an issue from a score alone.
- Prompt wording remains frozen during the window. Urgent correctness, privacy, data-loss, or crash fixes may be made only with a linked incident entry below.
- The trial does not authorize Pi, Provider Profile, account, sync, marketplace, ranking, or a new main-growth scoring model.

## Daily Record

| Day | Matters captured | Grouping edited? | Completed / suspended / abandoned | Context crossover? | Coach feedback | Verification / deferral reason | Settlement credible? | Guidance noise | Side-quest reading | Notes / incident IDs |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 |  |  |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |  |  |  |
| 7 |  |  |  |  |  |  |  |  |  |  |

Use only these compact labels where they apply:

- Coach feedback: `useful`, `wrong_target`, `repetitive`, `too_abstract`, `gave_answer`.
- Guidance noise: `appropriate`, `too_often`, `repeated`, `already_mastered`.
- Settlement credibility: `credible`, `unclear_evidence`, `feels_like_scoring`, `not_shown`.
- Context crossover: `none`, `cards`, `questions`, `quest`, `verification`, `prompt_context`.
- Side-quest reading: copy the aggregate counts only from Settings > 生活奇遇试用记录; note grounding or pressure feedback separately without location detail.

## End-of-Window Review

Record aggregate evidence before deciding vNext.1:

| Decision area | Evidence | Decision: retain / adjust / remove | Follow-up |
| --- | --- | --- | --- |
| Multi-matter grouping and active-case isolation |  |  |  |
| Coach question quality and Prompt version |  |  |  |
| Verification and growth settlement |  |  |  |
| Project closure and principles |  |  |  |
| Guidance selection |  |  |  |
| Life side quests and rewards |  |  |  |
| Pi multi-turn need |  |  |  |

Pi may be evaluated only when the completed window has at least 20 opted-in side-quest planning decisions and the evidence matches every gate in `agent-runtime-decision.md`.
