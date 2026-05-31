# Google Stitch UI Generation Prompt

Use this prompt in Google Stitch to generate high-fidelity iOS app UI mockups.

## Prompt

```text
Create high-fidelity iOS app UI mockups for a product called "明思".

PART 1: PRODUCT OVERVIEW AND USER FLOW

This is not a generic journal app, not a chatbot, and not a todo list. It is a personal thinking coach designed to help busy knowledge workers train their ability to think clearly, make better judgments, and turn reflection into focused action.

Core slogan:
"不替你思考，而是训练你把事情想清楚。"

Core product loop:
Clarify -> Challenge -> Choose -> Act -> Calibrate

The app helps the user:
1. Capture messy daily thoughts through text or voice input.
2. Let AI organize the input into structured thinking cards.
3. Review and correct the cards.
4. Choose a thinking lens such as First Principles, Opportunity Cost, Opposing View, Evidence Check, or Leverage Analysis.
5. Answer focused coaching questions.
6. Generate tomorrow's main quest and optional side quests.
7. Verify the next day whether the quest was completed and whether it was actually valuable.
8. Track growth over time through clarity, value judgment, execution reliability, calibration, and reflection depth.

Target user:
A busy individual knowledge worker who often executes quickly but wants to improve thinking quality, judgment, and prioritization. The user may work in a confidential company environment, so the UI should encourage abstract, desensitized reflection rather than copying raw company documents.

Generate iPhone app screens for the following flow:

Screen 1: Today / Verification
- Top header with today's date.
- A card showing yesterday's main quest.
- Completion controls: 完成, 部分完成, 未完成.
- Actual value controls: 高, 中, 低, 不确定.
- A calm primary button: 保存验证.

Screen 2: Today / Capture
- Header: 今日复盘.
- A large but elegant text input area with prompt starters.
- Prompt examples:
  - 今天真正推进了什么？
  - 哪件事让我感觉不清楚？
  - 我是否回避了一个关键判断？
  - 明天最不能忽略什么？
- Privacy reminder: 不要输入公司敏感资料、代码、客户信息或内部数据。
- Primary button: 整理成卡片.

Screen 3: Organized Thinking Cards
- Title: AI 已整理出 7 张思考卡片.
- Cards grouped by type: 问题, 决策, 风险, 任务.
- Example cards:
  - 问题：项目边界不清
  - 决策：短期先兼容旧逻辑
  - 风险：继续累积技术债
  - 任务：明天确认接口归属
- Each card should look editable and structured, not like a chat bubble.
- Include small type labels, subtle icons or color accents, and compact actions.
- Primary button: 确认卡片.

Screen 4: Thinking Lens
- Title: 选择思考透镜.
- Show recommended lens card:
  机会成本
  "你今天做了很多执行动作，但需要判断哪些真正值得继续。"
- Show alternative lenses:
  第一性原理, 反方质疑, 证据检查, 杠杆分析.
- The lens selector should feel intelligent and premium, not playful or mystical.
- Primary button: 使用这个透镜.

Screen 5: Deep Questions and Tomorrow Quest
- Show one or two focused question cards.
- Example question:
  "如果明天只能完成一件事，哪件事最能改变项目状态？"
- Below, show a generated main quest card:
  主线任务：确认项目当前真实瓶颈
  为什么重要：继续执行可能只是扩大消耗，必须先确认阻塞类型。
  完成条件：明确瓶颈属于需求、协作还是技术，并写下下一步动作。
  训练能力：识别核心约束
- Primary button: 接受主线任务.

Screen 6: Growth / Monthly Review
- Title: 本月成长.
- Show five trend indicators:
  清晰度, 价值判断, 执行可靠性, 校准能力, 反思深度.
- Include a Before / After comparison card:
  Before: "明天继续推进项目。"
  After: "明天先确认阻塞是否来自需求边界，完成条件是输出 3 个待确认问题。"
- Include insight:
  "你开始更清楚地定义完成条件，但仍然容易低估沟通成本。"

PART 2: AESTHETIC AND VISUAL REQUIREMENTS

Design style:
- Apple-like native iOS design.
- Minimal, elegant, calm, and premium.
- Simple but not empty; clean but rich in hierarchy.
- Similar emotional quality to Things, Day One, Linear, and Apple Health, but not a copy of any of them.
- This should feel like a thoughtful personal operating system, not a productivity gimmick.

Visual direction:
- Light mode first.
- Use a refined neutral background, not pure white everywhere.
- Use small semantic accent colors for card types, but avoid a one-color theme.
- Avoid dominant purple gradients, heavy blue/slate dark themes, beige/sand/brown palettes, decorative blobs, or marketing-style hero layouts.
- Use restrained cards with around 8px corner radius.
- Use SF Pro-like typography, clear hierarchy, generous spacing, and readable Chinese text.
- Cards should feel tactile and editable.
- Buttons should be native, quiet, and confident.

Interaction and motion readiness:
- Design components that could later support subtle animation.
- Cards should be able to expand into details.
- Raw text should feel like it can transform into structured cards.
- Lens selection can feel like a focused carousel or stacked transition.
- Quest acceptance can have a subtle confirmation state.
- Do not use excessive celebration effects, game coins, fantasy RPG visuals, badges, leaderboards, or cartoonish rewards.

Important constraints:
- Do not make the UI primarily chat-based.
- Do not create a landing page.
- Do not show generic dashboard charts without evidence.
- Do not make the app look like a corporate admin panel.
- Do not use fantasy game UI. The quest system should be lightweight and elegant.
- Keep all visible UI text in Simplified Chinese.
- Make the interface feel useful on the first screen.

Output:
Generate polished high-fidelity iPhone mockups showing the six screens above. The screens should look like a coherent product with consistent spacing, typography, color roles, and component behavior.
```

## Short Variant

Use this when Stitch performs better with shorter prompts:

```text
Design high-fidelity iOS mockups for "明思", a Chinese personal thinking coach app. It is not a journal, chatbot, or todo list. Its purpose is to train users to think clearly through the loop: Clarify -> Challenge -> Choose -> Act -> Calibrate.

Create 6 iPhone screens: Today verification, daily capture input, organized thinking cards, thinking lens selection, deep questions + tomorrow main quest, and monthly growth review.

The app helps busy knowledge workers enter messy daily thoughts, AI organizes them into editable cards, the user chooses a thinking lens, answers focused questions, confirms tomorrow's main quest, and later verifies whether the action was valuable.

Use Simplified Chinese UI text. Style should be Apple-like, native iOS, minimal but not empty, calm, premium, structured, and tasteful. Use subtle semantic card accents, SF Pro-like typography, 8px cards, clear hierarchy, and refined spacing. Avoid chat bubbles as the main UI, fantasy RPG visuals, coins, leaderboards, heavy gradients, decorative blobs, dark blue/slate themes, beige/brown palettes, and marketing hero pages. The quest system should feel elegant and lightweight, not game-like.
```
