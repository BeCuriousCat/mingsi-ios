# Coach Training Feedback v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make answer feedback carry a typed experience-replay decision line so the Today coach frame consistently teaches reproduce/adapt/reject instead of treating past experience as passive recall.

**Architecture:** Keep the source of truth in the domain model. Extend `CoachAnswerTrainingFeedback` with one explicit field, fill it in `CoachAnswerFeedbackPolicy`, render it in `TodayView`, and include it in the AppStore loop message used when unresolved gaps block progression.

**Tech Stack:** Swift, SwiftUI, XCTest, existing MingSi domain/app test suite.

---

### Task 1: Add Typed Experience Replay Decision Line

**Files:**
- Modify: `Tests/App/AppStoreStateMachineTests.swift`
- Modify: `Sources/Domain/Models.swift`
- Modify: `Sources/Features/Today/TodayView.swift`
- Modify: `Sources/App/AppStore.swift`

- [x] **Step 1: Write the failing domain test**

Add assertions to `testCoachAnswerFeedbackPolicySeparatesRepairedAndMissingTrainingMaterials`:

```swift
XCTAssertEqual(feedback.experienceReplayDecisionLine, ExperienceReplayTraining.line)
XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.reproduceLine))
XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.adaptLine))
XCTAssertTrue(feedback.experienceReplayDecisionLine.contains(ExperienceReplayTraining.rejectLine))
```

- [x] **Step 2: Verify RED**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachAnswerFeedbackPolicySeparatesRepairedAndMissingTrainingMaterials
```

Expected: compile failure because `CoachAnswerTrainingFeedback` has no `experienceReplayDecisionLine`.

- [x] **Step 3: Implement minimal domain field**

Add `experienceReplayDecisionLine: String` to `CoachAnswerTrainingFeedback` and set it to `ExperienceReplayTraining.line` in `CoachAnswerFeedbackPolicy.makeFeedback`.

- [x] **Step 4: Bind UI and loop message to the field**

Render the `过往经验复现` row body as:

```swift
"\(feedback.experienceReplayDecisionLine)\n\(feedback.experienceReplayPrompt)"
```

Update `coachAnswerTrainingFeedbackMessage(for:)` so blocked progression messages include the same decision line.

- [x] **Step 5: Verify GREEN**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachAnswerFeedbackPolicySeparatesRepairedAndMissingTrainingMaterials
```

Expected: test passes.

- [x] **Step 6: Run focused class verification**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests
```

Expected: all `AppStoreStateMachineTests` pass.

- [x] **Step 7: Commit**

```bash
git add Tests/App/AppStoreStateMachineTests.swift Sources/Domain/Models.swift Sources/Features/Today/TodayView.swift Sources/App/AppStore.swift docs/superpowers/plans/2026-06-29-coach-training-feedback-v2-plan.md
git commit -m "feat: expose experience replay decision in coach feedback"
```
