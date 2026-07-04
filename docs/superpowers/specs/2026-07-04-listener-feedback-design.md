# Listener Feedback Design

## Goal

Make coach feedback read like a real listener saying what they did not understand, instead of an abstract training system naming gaps.

## Scope

This small iteration changes the answer-question stage only.

It should:
- Prefer plain listener language: "我听懂了什么", "我没听懂什么", "请补一句".
- Avoid primary feedback copy such as "训练缺口", "校准点", and "复盘训练契约".
- Keep the current optional flow: the user can repair the answer or explicitly continue.
- Judge the answer with today's confirmed cards as context, so the coach does not ask for background that was already established earlier in the same flow.

It should not:
- Add long-term memory.
- Add a new agent framework.
- Change quest generation logic.
- Remove the explicit "带着缺口继续" action.

## Product Rule

When a user omits context that has not been established, MingSi should say exactly what a listener cannot resolve, such as:

> 我没听懂："它/这个/他们" 指谁，或者这件事发生前的背景是什么。

When that context already exists in confirmed cards, MingSi should not ask for it again. It may still ask for the next missing piece, such as goal, success standard, observable fact, or calibration signal.

## Acceptance

- Unresolved answer feedback no longer uses "训练缺口" or "校准点" in the main lines.
- The visible repair prompt starts with "请补一句".
- Answer observation can include confirmed cards as context.
- Existing optional continuation behavior remains unchanged.
