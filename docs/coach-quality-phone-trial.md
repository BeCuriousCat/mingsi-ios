# Coach Quality Phone Trial

Status: PENDING

This file is the evidence record for the final coach-quality baseline stop condition: one real phone-day trial.

## Trial Scope

Run one real day on the physical iPhone:

Before starting, connect and unlock the iPhone, then run:

```bash
scripts/prepare_coach_quality_phone_trial.sh
```

The script first tries to wake CoreDevice's tunnel for paired devices. If it
still reports `tunnel=disconnected`, the phone is paired but not ready for an
install. Unlock it, keep it awake, connect by USB if Wi-Fi pairing is stale,
and rerun the script before starting the trial.

After install, the script launch-checks the app. If iOS refuses to launch
because the developer profile is not trusted, trust the profile on the iPhone:
Settings -> General -> VPN & Device Management -> Developer App -> Trust. Then
rerun the script before starting the trial.

1. Morning or work-session input: write one messy real event.
2. Today flow: confirm MingSi identifies one primary gap and one foundational ability.
3. Repair step: add the missing sentence or evidence MingSi asks for.
4. Tomorrow validation: save one action with observable completion criteria.
5. Next day: record the result and judgment update.

## Pass Criteria

- The main path feels like coaching, not form filling.
- MingSi names one main gap instead of asking many questions.
- The wording is plain and does not expose high-cost terms.
- The saved action can be checked the next day.
- Next-day calibration updates the original judgment.
- The phone run completes without losing draft date, answers, quest, or verification evidence.

## Evidence

Every field below must be filled before `Status: PASSED`. If there were no issues, write `None` for `Issues found`.

- Trial date: 2026-07-08
- Device: 陈泽威的 iPhone (00008140-0019242901E8801C)
- Starting app commit: bf70d51
- Ending app commit: bf70d51
- Primary gap MingSi identified:
- Foundational ability MingSi trained:
- Minimal training action:
- Tomorrow validation action:
- Next-day result:
- Judgment update:
- Issues found:
- Decision:

## Preparation Notes

- 2026-07-08: Installed `bf70d51` on the physical iPhone. First launch check
  failed because iOS has not explicitly trusted the developer profile yet.

When the trial passes, change the status line to:

`Status: PASSED`
