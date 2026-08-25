# Product Risks and Design Language

## Real-Use Risks

The product has a strong concept, but real users may still fail to use it consistently. The MVP should anticipate these issues early.

### 1. The Daily Loop May Feel Too Heavy

Risk:

- The user is already busy.
- A 10-15 minute reflection can still feel expensive after a long workday.
- Too many required steps can make the user abandon the loop.

Product response:

- Support three modes:
  - Quick: capture -> organize -> one main quest.
  - Standard: capture -> cards -> lens -> quest.
  - Deep: full reflection with questions and calibration.
- Let the user save an incomplete loop without shame.
- Always make Resume Today obvious.

### 2. AI May Sound Generic

Risk:

- If questions feel like generic self-help, the user will stop trusting the product.

Product response:

- Questions must reference confirmed cards.
- Prompts must require evidence, assumptions, and alternatives.
- User should be able to mark "not useful" on AI questions or quests.
- Weekly review should identify which lenses were useful.

Current product priority:

- Optimize Prompt and thinking lenses before expanding distribution, sync, or marketplace surfaces.
- The coach should maintain a stateful Today turn, not only make a one-shot lens decision. If the turn is `not_ready`, MingSi should ask for clarification or evidence before converging on action.
- A good question should expose one of four things: an evidence gap, a hidden assumption, a disconfirming signal, or a next calibration signal.
- Evidence gaps should be classified when possible: missing observation, missing baseline, missing causal link, missing counterexample, missing constraint, or missing calibration signal.
- A good question should also make its answer useful: updating a judgment, choosing an action, testing an assumption, collecting evidence, or watching a calibration signal.
- A good question should declare the reasoning move it trains: separating fact from interpretation, testing an alternative explanation, making a leverage tradeoff, decomposing constraints, mapping feedback loops, checking delayed effects, tracing second-order consequences, or calibrating a prediction.
- A good question should cite the confirmed card titles that triggered it, so the user can see which evidence the coach is working from.
- The lens system should train specific reasoning moves: evidence check, opposing view, leverage analysis, first principles, system thinking, and judgment calibration.
- A selected built-in lens must train at least one matching reasoning move: evidence check -> fact/interpretation split; opposing view -> alternative explanation; leverage analysis -> leverage tradeoff; first principles -> constraint decomposition; system thinking -> feedback loop, delayed effect, or second-order consequence; judgment calibration -> prediction calibration.
- System thinking is used when records show feedback loops, delayed effects, repeated rework, constraints, dependency propagation, or second-order consequences.
- When system thinking is selected, questions must train at least one system move: `feedback_loop`, `delayed_effect`, or `second_order_consequence`; generic alternative-explanation questions are not enough.
- A good quest should work as a calibration instrument: it should test one judgment, close one evidence gap, or produce one observable signal rather than become generic busywork.
- A good quest should cite the confirmed card titles that justify it, so tomorrow's action remains traceable to today's evidence instead of becoming a free-floating todo.
- A good quest should also carry the selected lens's reasoning move into action. A leverage-analysis session should not silently become an opposing-view task, and a system-thinking session should not silently become generic execution work.
- A good quest should respect coach readiness. If the coach turn is not ready and the user has not explicitly overridden to proceed, generating a task is premature convergence rather than coaching.
- A good verification should compare the original prediction with actual evidence, name the evidence gained, identify the observable signal, compare completion or acceptance criteria against evidence, and update the next judgment or calibration action. Its recommendation should name the next calibration action, test, or signal to watch rather than offer generic encouragement.
- A good principle should be a reusable behavior rule grounded in confirmed source cards, actionable and verifiable rather than a slogan or free-floating advice. If the rule cannot cite today's evidence, name at least two concrete next-time actions, and state observable success criteria, it should not be created.
- Principle practice evidence should stay explainable: automatic practiced/internalized records need a structured local match signal and attribution policy version so later review can see which action or rule field caused the attribution.
- Principle practice evidence also needs `practice_role` so Growth can distinguish `targetedPractice`, `secondaryPractice`, and `possibleSignal`; only targeted or locally verified secondary practice should reinforce training state, while possible signals remain review material.
- Principle training summaries should surface the latest practice evidence summary instead of reducing practice to a count, otherwise users cannot audit whether the training attribution is reasonable.
- Users must be able to mark a principle practice attribution as inaccurate from the same Growth surface where the latest evidence is shown. Disputed practice evidence should remain visible as an audit line and exportable for review, but it must be excluded from active training summaries and must not reinforce long-term principle state.
- A structured local match signal that was already disputed for a principle should suppress repeated automatic practice attribution for that same principle/signal until a stronger structured policy can prove the new attribution is materially different. Legacy summary parsing is only a compatibility fallback.
- ReviewQuests can show the expected training target for a quest when it locally matches an active principle, and users can manually calibrate that target to another active principle or reset it to automatic. This must not create practice evidence before the next-day verification. The selection is an attribution input, not long-term reinforcement.
- Manual quest training targets should only accept active principles. Needs-review principles remain review material, not direct training targets.
- VerifyQuest prompts may receive the expected training principle and the central LLM decides whether the supplied evidence appears to practice it. Local code only validates the returned evidence references, user-confirmed source ownership, and the transaction that records the result; it must not invent a practice judgment when the model failed.
- Needs-review principles should show the latest not-applicable or misrecalled feedback reason in Growth, not only a negative-feedback count.
- Referenced principles in Today should show the local recall reason before asking for helpful/not-applicable/misrecalled feedback; otherwise feedback becomes a guess about a black-box retrieval.
- Recalled principles should be framed as experience replay, not passive references. The UI should ask whether the user should复现 the prior experience in this case, whether the scene is different, or whether the recall was wrong.
- Negative referenced-principle feedback should link back to the same PromptRun that produced the recall and count as user denial in Prompt asset quality, otherwise the audit panel can look healthy while real users are rejecting bad recalls.
- Principle recall feedback should store a structured `retrievalSignal` alongside the human-readable reason, and current retrieval policy should demote the bad signal rather than blindly penalizing the whole principle. Only legacy feedback without a signal should fall back to principle-level penalty.
- The same `retrievalSignal` must be shown back to users as a localized "命中信号" in Today and Growth review surfaces, so users can dispute a concrete recall signal instead of interpreting raw policy/debug text.
- Verified lens outcomes should feed the next prompt as `lensFeedback`: reinforce useful lens moves, adjust uncertain moves, and avoid low-value or uncalibratable patterns.
- Feedback should target specific `lensMoves`, not discard a whole lens after one weak outcome.
- `lensFeedback` should be a capped structured summary from verified history, not full raw records. This protects privacy, keeps prompt cost low, and prevents old daily text from overwhelming today's context.
- Prompt changes must be protected by fixed eval fixtures so coaching quality does not drift back to generic advice.
- Add a deterministic coaching quality gate for obvious regressions: generic questions, missing evidence-gap / answer-use / lens-move fields, missing source grounding for questions, quests, or principles, weak principle actionability, vague calibration targets, missing selected-lens moves, missing primary-training focus on the first question, `missingCoachTurnAlignment`, repeated avoided lens moves, unadjusted lens moves, missing reinforced lens moves, missing system-thinking moves, busywork quests, weak verification notes that omit the original prediction, actual evidence, evidence gained, judgment update, observable signal, and completion or acceptance criteria evidence, weak verification recommendations that do not name the next calibration action or signal, and verification outputs that omit the expected-principle practice assessment when a training principle was provided.
- This gate does not replace human or LLM review. It is a cheap local guardrail for "obviously not good enough" outputs, so the central LLM remains responsible for the substantive judgment while local code handles schema, evidence ownership, and safety.
- Runtime `qualityGateFailed` results should use the same existing fallback and retry path as malformed or empty AI responses: preserve user progress, show an editable local result only for an explicitly offline or missing-key run, and keep the failed prompt auditable.

### 3. The User May Avoid Hard Questions

Risk:

- The product may become a comfortable summary tool instead of a thinking trainer.

Product response:

- Add one optional "hard question" after each session.
- Use gentle but direct copy.
- Track repeated avoidance patterns through verification reasons.

### 4. Privacy Anxiety May Reduce Use

Risk:

- Work content may be sensitive.
- User may hesitate to write enough detail.

Product response:

- Encourage abstract naming.
- Collapse raw input in history.
- Show what will be sent to the model.
- Support sensitive-card exclusion.
- Keep local-first storage where practical.

### 5. Metrics May Feel Fake

Risk:

- Ability scores can feel arbitrary.
- Users may reject them if they look like objective intelligence scores.

Product response:

- Present metrics as personal trends.
- Always link scores to evidence.
- Prefer before/after examples over large dashboard charts.

### 6. History Can Become Clutter

Risk:

- Daily entries may accumulate without becoming useful.

Product response:

- History should default to verified outcomes and confirmed cards.
- Raw input stays collapsed.
- Growth and Projects deep-link to relevant historical evidence.
- Search and filters must support project, lens, card type, and quest status.

### 7. Novelty May Fade

Risk:

- The first week may feel exciting, then the loop becomes repetitive.

Product response:

- Rotate the recommended thinking lens.
- Weekly calibration should change the next training focus.
- Surface visible before/after examples monthly.
- Keep the daily loop lightweight.

## Product Shape Optimizations

The product should not be a rigid funnel. It should be a guided workspace.

Recommended shape:

```text
Today = active loop
History = evidence layer
Projects = context layer
Growth = calibration layer
Settings = control layer
```

Today should adapt to the user's state:

- If yesterday has an unverified quest, start with verification.
- If today has no input, start with capture.
- If cards exist but are unconfirmed, resume card review.
- If questions are answered but quest is missing, resume quest generation.
- If the loop is complete, show tomorrow's main quest.

This makes the product feel responsive without requiring the user to follow tabs in order.

## Design Language

Recommended design language:

```text
Calm Native Intelligence
```

Attributes:

- Calm: low visual noise, no productivity anxiety.
- Native: feels like a first-class iOS app.
- Intelligent: uses structure, evidence, and precise prompts rather than flashy AI effects.
- Personal: serious enough for work reflection, warm enough for daily private use.

The design should communicate:

- Clarity.
- Thoughtfulness.
- Focus.
- Trust.
- Progress through evidence.

It should avoid:

- Chatbot-first UI.
- Generic SaaS dashboards.
- Heavy gamification.
- Wellness-journal softness.
- Corporate admin-panel density.
- Template card grids.

## Native iOS and SwiftUI Rationale

Programming language does not automatically create good taste. Good taste comes from product judgment, component design, typography, spacing, motion, and restraint.

However, native Swift/SwiftUI improves the odds of achieving the desired interaction quality because it gives direct access to iOS-native patterns:

- SwiftUI transitions and `matchedGeometryEffect` for smooth card expansion and state changes.
- Native gestures, sheets, navigation, menus, and context actions.
- Native keyboard and dictation behavior.
- Haptics for important confirmations.
- Dynamic Type and accessibility support.
- SQLite/GRDB local persistence for on-device records.
- AppIntents, Shortcuts, Widgets, and notifications as future extensions.

Recommended implementation:

- Use SwiftUI as the primary UI layer.
- Use small UIKit bridges only where SwiftUI is not sufficient, such as advanced text editing if needed.
- Avoid WebView as the primary app shell for the MVP.
- Keep PromptCore, LLMCore, storage, and future server adapters separate so the product can later support web or Android without rewriting the thinking system.

## Interaction Opportunities for Native iOS

MVP can stay simple, but the architecture should support:

- Raw input transforming into cards.
- Card expansion into detail.
- Lens focus transition.
- Quest acceptance confirmation.
- Subtle haptic on accepting the main quest.
- Reduce Motion support.
- Widget showing tomorrow's main quest.
- Notification asking for next-day verification.
- Shortcut for quick capture.

These are natural on iOS and would feel less polished if implemented as a generic web-style shell.

## Design and Engineering Boundary

To keep the app extensible:

- The UI should be native and high-taste.
- The data model should stay semantic and platform-neutral.
- Prompt and model capabilities should be exposed through stable provider protocols.
- Prompt and eval logic should not depend on iOS-specific UI.

This gives the MVP a premium iOS experience while preserving long-term product portability.
