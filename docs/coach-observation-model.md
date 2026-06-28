# Coach Observation Model

Date: 2026-06-26

## Purpose

MingSi should not only ask better questions. It should make the user feel:

> MingSi is observing how I describe and think, then training the part I skipped.

This document defines the observation layer between raw user input and coach advice. It is not a new feature surface. It is the product contract for how MingSi reads a user's description, infers the user's thinking process, diagnoses missing parts, and turns that diagnosis into training feedback.

## Why This Layer Exists

The current coach system can recommend lenses, track coach turns, and gate weak prompt outputs. That is necessary but not sufficient.

If MingSi jumps from user input to questions or tasks, the user still experiences it as an AI answer engine. To feel like training, MingSi must first show its observation:

```text
I saw what you included.
I saw what you treated as fact, judgment, or action.
I saw what you skipped.
Therefore we train this ability next.
```

This layer is the local, inspectable frame that keeps the LLM from producing generic advice.

## Observation Stack

### 1. Material Observation

Question: what did the user provide?

MingSi should identify whether the input contains:

- background: when, where, under what context;
- actor/object: who or what the event is about;
- trigger: what started the event;
- action: what the user or others did;
- result: what changed afterward;
- feeling: emotional or bodily signal;
- fact: directly observed detail;
- interpretation: explanation of why something happened;
- judgment: conclusion, evaluation, or priority;
- assumption: premise being treated as true;
- constraint: time, resource, authority, information, relationship, or system limit;
- goal: what the user wanted to achieve;
- standard: what would count as good or done;
- open question: what the user is unsure about.

This is not summary. It is an inventory of thinking material.

### 2. Process Observation

Question: how does the user appear to be thinking?

MingSi should infer patterns such as:

- starts from emotion before evidence;
- describes action but not goal;
- names a conclusion but not the observation behind it;
- treats one person's reaction as the whole system;
- jumps from problem to task before defining success;
- focuses on visible symptoms and misses constraints;
- uses prior experience without checking whether conditions still match;
- delays action because the judgment cannot be calibrated;
- has enough evidence but avoids committing to a small test.

This is the core LLM observation task: distill the user's thinking process, not the event content alone.

### 3. Gap Diagnosis

Question: what did the user not think through yet?

Use these reusable gap types:

- narrative gap: the event cannot be replayed by another person;
- observation gap: facts and interpretations are mixed;
- object gap: the affected person, user, customer, teammate, system, or object is unclear;
- goal gap: desired outcome or success standard is missing;
- constraint gap: boundary conditions are not named;
- causal gap: why A led to B is assumed, not traced;
- counterexample gap: no disconfirming signal is considered;
- judgment gap: the current conclusion is not grounded enough to trust;
- execution gap: next action, owner, standard, or resistance is missing;
- calibration gap: no future signal can verify whether the judgment was right;
- experience gap: prior experience is recalled but not classified as reproduce, adapt, or reject.

The coach should select one primary gap per turn. Other gaps may stay visible as baseline checks, but the user should not receive a broad questionnaire.

### 4. Training Translation

Question: what ability is trained by closing this gap?

Map the primary gap to a user-facing training ability:

| Gap | Ability | User-facing meaning |
| --- | --- | --- |
| narrative gap | 描述力 | 把一件事讲清楚，让别人能复盘 |
| observation gap | 观察力 | 分清事实、感受、解释和证据 |
| object gap | 描述力 / 判断力 | 说清这件事服务于谁、影响谁 |
| goal gap | 判断力 | 明确什么重要、什么算达成 |
| constraint gap | 分析力 | 看清边界、资源、关系和系统限制 |
| causal gap | 分析力 | 追踪因果链、反馈和延迟影响 |
| counterexample gap | 分析力 | 主动寻找会推翻当前解释的信号 |
| judgment gap | 判断力 | 在不确定中做可解释取舍 |
| execution gap | 执行力 | 把判断安排成可完成、可验证的行动 |
| calibration gap | 校准力 | 用未来结果修正今天判断 |
| experience gap | 校准力 / 判断力 | 判断过往经验该复现、调整还是否定 |

The product may show high-level labels like 沟通力、思考力、执行力, but prompt and coach logic should operate on the specific gap and ability.

## Coach Communication Form

Every coach intervention should follow this shape:

```text
我观察到：你已经说清了 A，但 B 还不够清楚。
这说明：当前主要缺口是 C。
本轮训练：先练 D，不急着让 AI 给结论。
请你补充：E。
```

### Respect Without Appeasement

MingSi is a coach, not a satisfaction engine. It should respect the user while
refusing to validate weak thinking just to make the user feel good.

Empathy is not agreement. The coach may acknowledge that the situation is hard,
ambiguous, or pressuring, but only as a bridge into the real repair move. It
must not use the user's pressure, difficulty, or need to feel understood as a
reason to endorse an unsupported judgment or let the user skip evidence.

The coach should name the thinking move that needs repair when the user's input
contains:

- a weak claim with no support;
- missing evidence or missing facts;
- a premature conclusion;
- a vague goal or success standard;
- an avoided responsibility or skipped owner/action;
- a harmful or repeatedly low-value pattern;
- an old experience reused without a fit check.

The critique must target the thinking move, not the person. MingSi must not
diagnose the user's personality, intelligence, motivation, or hidden intent.

Good correction shape:

```text
我观察到：你已经给了结论，但还没有给出能支撑这个结论的事实。
风险是：如果直接进入行动，我们无法知道是在解决问题，还是在执行一个过早判断。
本轮训练：练观察力和证据纪律。
下一步修补：先写出一个直接看到或听到的事实，再判断它是否支持你的结论。
```

Bad correction shape:

```text
你已经想得很充分了，继续按这个方向推进会让你更有信心。
我理解你压力很大，所以现在这样也合理。
```

The second version is warm but unhelpful: it validates confidence without
naming a gap, risk, ability, or repair move.

Examples:

```text
我观察到：你写了自己的动作和感受，但没有写出当时看到的事实。
这说明：当前主要缺口是观察 gap，事实和解释混在一起。
本轮训练：先练观察力，不急着给结论。
请你补充：一个你亲眼看到或直接听到的事实，再写一句你的解释。
```

```text
我观察到：你已经有了下一步动作，但还没有说清这个动作服务于谁、解决什么问题。
这说明：当前主要缺口是目标 gap。
本轮训练：先练判断力，把重要性和成功标准说清。
请你补充：如果这件事做对了，谁的什么问题会变少？
```

```text
我观察到：你提到了以前类似的做法，但还没有判断这次条件是否一样。
这说明：当前主要缺口是 experience gap。
本轮训练：先练校准力，不机械套用经验。
请你补充：这条经验在本次是复现、调整，还是否定？为什么？
```

## Product Placement

The Today loop should keep four user-visible boundaries distinct:

- `结果校准`: verify yesterday's validation action before starting new material.
- `今天内容`: collect today's facts, actions, thoughts, and raw context. This is not the review conclusion.
- `今日复盘`: MingSi observes how the user described and judged the material, then names the missing thinking material and training ability.
- `明日验证`: turn today's reviewed judgment into a verifiable action for tomorrow. This is not a generic todo list.

This boundary is part of the coach contract. If the UI or prompt makes Capture
feel like the whole review, or makes Review Quests feel like ordinary task
generation, the product drifts back toward "AI answer" instead of training.

For product design, treat Today as two connected loops:

- Today understanding loop: `今天内容 -> 今日复盘`. This loop trains the user to
  describe the event, separate evidence from judgment, expose skipped thinking
  material, and replay relevant past experience.
- Tomorrow validation loop: `明日验证 -> 结果校准`. This loop trains the user to
  turn one reviewed judgment into a small observable validation action, then use the
  next day's result to calibrate whether the judgment was useful.

The user-visible loop names should make the boundary explicit:

- `闭环一：今天内容与今日复盘`.
- `闭环二：明日验证与结果校准`.
- `闭环二：结果校准`.

The top progress indicator should also be grouped, not shown as one undifferentiated
`1/10` journal pipeline:

- `今日理解闭环`: `今天内容 -> 今日复盘`.
- `行动验证闭环`: `明日验证 -> 结果校准`.

The boundary rule is:

```text
复盘解决理解问题；验证解决校准问题。
```

The two loops should not collapse into a single journal flow:

```text
今天内容只收集材料。
今日复盘只修补理解、证据、判断和经验复现缺口。
明日验证只设计一个能验证今日判断的验证行动。
结果校准只回看昨天验证行动的完成、价值和判断更新。
```

`明日验证` must not become an extra place to continue writing today's review.
`结果校准` must not become a new review of today's material. It only checks
completion, actual value, and whether yesterday's judgment should be updated.
The visible calibration questions are: did it get done, did it create real
value, and should yesterday's judgment be confirmed, adjusted, or rejected?
The third question is a structured user choice, not only explanatory copy. It
must be stored as the user's current calibration stance and passed into Verify
Quest context as `judgmentUpdate` so the coach can compare stance with evidence.

Each visible stage should state what this page is allowed to do:

- Capture: `本页只写今天内容`.
- Answer Questions: `本页只复盘今天`.
- Review Quests: `本页只设计明天的验证行动`.
- Verify Yesterday: `本页只校准昨天结果`.

This is not instructional decoration. It prevents the user from mixing raw
material, review, validation action design, and result calibration into one long
journal entry.

### Capture

Capture should help the user describe without turning the screen into a form. It should show the scaffold for "讲清楚一件事", but the coach's real observation happens after the user provides material.

Capture should avoid saying "you are bad at X" before observation exists. It can say:

```text
先把材料说出来。明思会观察你说清了什么、跳过了什么，再决定本轮训练点。
```

When the user names an action but the event cannot be replayed by another
person, MingSi should train description before goal design. For example, "I
pushed the proposal a bit and still feel stuck" should not immediately become a
goal question. It is missing background, object, trigger, and result, so the
coach should first ask the user to make the event replayable.

If the user explicitly says the issue is "not knowing who this serves" or "the
goal is unclear", the primary gap remains goal design. That signal means the
user has already exposed the target of training.

### Organize Cards

`organizeCards` should remain low-risk structure extraction. It should not inject historical principles or coach memory.

However, it may classify material into observation inventory fields in the future:

- provided material;
- implied judgment;
- possible gap signals.

For MVP, it can keep producing thinking cards. The observation model should be applied after cards are confirmed.

### Review Cards

ReviewCards is where the user confirms the material inventory. The coach should not diagnose from unconfirmed material.

### Select Lens / Training Prescription

The lens should be downstream of observation. The product should read as:

```text
明思观察了你的材料 -> 诊断主要缺口 -> 推荐训练方式
```

not:

```text
用户选择一个滤镜 -> AI 按滤镜提问
```

### Answer Questions

Answer Questions is the visible `今日复盘` stage. It should make the user feel
that MingSi is observing their thinking process, not simply asking for more
text.

Question cards should show the observation frame:

- ability diagnosis: which basic capability is being trained this turn;
- material separation training: make `fact`, `feeling`, `interpretation`,
  `judgment`, and `action` visible as distinct materials;
- material inventory: what the user has already made clear and what must be
  supplied next;
- observed: what MingSi saw in the user's input or answer;
- gap: what is missing;
- training: what ability this question trains;
- ask: what the user should now supply;
- proceed: what makes the answer sufficient.

The answer box should not imply the user needs a polished essay. It should ask for the missing thinking material.

After the user answers, the feedback frame should train a judgment sentence,
not merely say whether the answer is good enough. The minimum shape is:

```text
我现在相信 X；
明天用 Y 观察它是否成立；
如果出现 Z，我就更新判断。
```

This keeps the handoff to Review Quests grounded in a testable judgment rather
than a generic tomorrow task.

The answer feedback frame must also separate the coach's assessment into
explicit parts:

```text
你刚补上：A。
当前仍缺：B。
能否进入明日验证：可以 / 不能；原因是 C。
下一句修补：D。
过往经验复现：E。
```

This prevents the coach from collapsing into a single approval or rejection
sentence. The user should be able to see which thinking material improved,
which gap remains open, and what exact repair move would make the answer ready
for tomorrow validation.

### Review Quests

Review Quests is the visible `明日验证` stage. It should not read as "AI made
some tasks." A quest exists to test a judgment from today's review.

Before showing the quest card list, Review Quests should show a page-level
anchor:

```text
今天待验证判断：X
下面的验证行动只验证这个判断。
```

`X` should come from the main quest's `calibrationTarget` when available. This
turns the quest from a generic task into a calibration instrument. If no
calibration target exists, the page should warn that the review has not yet
produced a verifiable judgment and the primary action should be blocked instead
of pretending the task is ready.

Quests should only appear after the coach has either:

- enough material to form a verifiable action; or
- an explicit user override that preserves the missing gap as tomorrow's calibration target.

Quest copy should preserve the training link:

```text
这个任务不是普通待办。它验证你今天对 X 的判断。
```

## Experience Replay Rule

MingSi should use prior experience as training material, not authority.

When an old principle or pattern is recalled, the coach must ask:

- reproduce: which part can be reused as-is?
- adapt: which conditions are different this time?
- reject: why is the old experience misleading here?

The user should see this as "经验复现判断", not as a passive reference list.

## LLM Observation Contract

When LLM is used for coach observation, the expected output should be structured:

```json
{
  "observed_material": {
    "provided": ["action", "feeling", "judgment"],
    "missing": ["goal", "observable_fact", "calibration_signal"]
  },
  "thinking_process_observation": "The user jumps from action pressure to conclusion before naming observable facts.",
  "primary_gap": "observation_gap",
  "secondary_gaps": ["goal_gap", "calibration_gap"],
  "training_ability": "观察力",
  "coach_feedback": {
    "observed": "你写了行动和压力，但没有写出一个可观察事实。",
    "diagnosis": "当前不是缺行动，而是事实和解释还混在一起。",
    "training": "本轮先练观察力。",
    "ask": "请补一个你亲眼看到或直接听到的事实，再写一句你的解释。",
    "proceed_when": "当答案能分开事实和解释时，可以进入下一步判断。"
  },
  "experience_replay_prompt": "有没有一次你因为事实和解释混在一起而误判？这次要复现、调整，还是否定那条经验？"
}
```

Rules:

- Do not diagnose personality, intelligence, or motivation.
- Do not claim hidden intent.
- Do not overfit to the user's industry or role.
- Do not generate a task before the primary gap is closed, unless the user explicitly overrides.
- Use the user's confirmed material as evidence for the observation.
- Keep one primary gap per turn.

## Implementation Implications

This model should be implemented before broad prompt expansion:

1. Done: add a pure domain model for observation materials, gaps, core abilities, and coach observation feedback.
2. Done: add deterministic local heuristics for obvious gaps after confirmed cards:
   - action without goal -> goal gap -> judgment training;
   - judgment without fact -> observation gap -> observation training;
   - experience reuse without fit check -> experience gap -> calibration training plus counterexample check.
3. Done: enforce one primary gap per turn so coach feedback remains training, not a broad questionnaire.
4. Next: add prompt context fields only after the observation model is stable.
5. Next: update `generateQuestions` prompt to use coach observation before writing questions.
6. Next: render the observation frame in Today before the question input.
7. Next: add quality gates that reject questions missing an observation/gap/training/ask link.

Do not implement this as a generic chat agent. Keep it Today-local, auditable, and testable.
