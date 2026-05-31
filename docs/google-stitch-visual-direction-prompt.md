# Google Stitch Visual Direction Prompt

Use this when the previous Stitch result looks too generic or template-like.

## Opinionated Visual Prompt

```text
Design a high-fidelity iPhone app UI for a Chinese app called "明思".

The app should feel like a private thinking desk on an iPhone: calm, precise, native, and quietly intelligent. It should not look like a SaaS dashboard, a generic AI chat app, a habit tracker, or a template productivity app.

Core idea:
The user pours messy thoughts into the app. The app gently turns them into structured thinking cards, helps the user inspect them through a thinking lens, and then creates one focused quest for tomorrow.

Visual metaphor:
Use the feeling of "a clean desk with organized thinking slips", not "dashboard panels". Cards should feel like carefully arranged thinking objects. The interface should have depth through hierarchy, spacing, and subtle motion-ready layers, not through decorative gradients.

Generate 4 polished iPhone screens in one coherent style:

1. Today Capture
2. Organized Thinking Cards
3. Thinking Lens + Deep Question
4. Tomorrow Main Quest

Important design direction:
- Native Apple-like iOS interface.
- Minimal, but not empty.
- Quiet, premium, reflective, and precise.
- The app should feel serious enough for work reflection, but personal enough for daily use.
- Use Simplified Chinese UI text.
- Avoid generic productivity dashboard layout.
- Avoid chat bubbles as the main interface.
- Avoid large hero sections.
- Avoid gamified fantasy visuals.
- Avoid colorful template cards that all look the same.
- Avoid purple gradient AI app style.
- Avoid beige/brown wellness journal style.
- Avoid dark navy enterprise dashboard style.

Visual system:
- Background: very light porcelain gray, subtle depth, not pure white and not beige.
- Primary text: graphite/near-black.
- Secondary text: soft gray.
- Accent colors should be semantic and restrained:
  - Problem: muted amber.
  - Decision: calm blue.
  - Risk: restrained coral.
  - Task/Quest: deep teal.
  - Insight: muted green.
- Use color as a small spine, dot, or label, not as a full card background.
- Card radius around 8px to 12px.
- Cards should have fine borders or subtle shadows, not heavy floating panels.
- Typography should feel like SF Pro: sharp, readable, modern.
- Use strong hierarchy: date and state are quiet; current action is clear.

Screen 1: Today Capture
Layout:
- Top-left date: 今天 · 5月31日
- Small status label: 澄清阶段
- A thin progress rail showing 澄清 -> 挑战 -> 取舍 -> 行动 -> 校准, with 澄清 active.
- Main area is a large "thinking sheet" input surface, not a plain textarea.
- Inside the surface, show faint prompt starters:
  - 今天真正推进了什么？
  - 哪件事让我感觉不清楚？
  - 我是否回避了一个关键判断？
- Below the input, show a small privacy reminder:
  不要输入公司敏感资料、代码、客户信息或内部数据。
- Bottom primary button: 整理成卡片

The capture screen should feel inviting, not blank. It should suggest "start thinking here".

Screen 2: Organized Thinking Cards
Layout:
- Header: AI 已整理出 7 张思考卡片
- Subtext: 请确认哪些是真正重要的内容
- Show a vertical stack of varied-height cards.
- Each card has a thin semantic color spine on the left, a small type label, a clear title, and a concise body.
- Example cards:
  问题 · 项目边界不清
  今天多次提到接口职责不明确，可能是当前主要阻塞。

  决策 · 短期先兼容旧逻辑
  你倾向于先保证交付，但这可能继续累积技术债。

  任务 · 明天确认接口归属
  完成条件：明确谁负责边界定义。

- Include small actions as icons or compact text: 编辑, 合并, 敏感.
- Bottom primary button: 确认卡片

The cards should feel editable and thoughtful, not like generic colored cards.

Screen 3: Thinking Lens + Deep Question
Layout:
- Header: 选择思考透镜
- The recommended lens should appear as a focused, elegant lens card.
- Lens card:
  机会成本
  你今天做了很多执行动作，但需要判断哪些真正值得继续。
- Under it, show alternative lens chips:
  第一性原理, 反方质疑, 证据检查, 杠杆分析
- Then show one deep question card:
  如果明天只能完成一件事，哪件事最能改变项目状态？
- Include a small answer input field with calm styling.
- Bottom primary button: 生成明日任务

This screen should feel like an intelligent coach asking one sharp question, not like a chatbot conversation.

Screen 4: Tomorrow Main Quest
Layout:
- Header: 明日主线任务
- Main quest card should feel slightly more important than other cards, but not like a game badge.
- Use a deep teal accent and a subtle structured layout.
- Content:
  主线任务
  确认项目当前真实瓶颈

  为什么重要
  继续执行可能只是扩大消耗，必须先确认阻塞类型。

  完成条件
  明确瓶颈属于需求、协作还是技术，并写下下一步动作。

  训练能力
  识别核心约束
- Include small secondary actions: 修改, 明天提醒
- Bottom primary button: 接受主线任务

This quest card should feel like a concise mission brief from a thoughtful coach.

Interaction feel:
- Cards should look like they could gently expand.
- The organized cards should visually feel like they emerged from the raw input.
- The lens card should feel focused, like the app is narrowing attention.
- The quest card should feel final and actionable.
- Use subtle motion-ready spacing and stable component structure, but do not show flashy animation.

Overall mood:
Quiet intelligence.
Structured reflection.
Personal operating system.
Apple-like taste.
Minimal but meaningful.
No template dashboard.
No generic AI assistant.
No fantasy gamification.
```

## Even Shorter Art Direction

```text
Create a high-fidelity iPhone UI for a Chinese personal thinking coach app. Make it feel like a private thinking desk: calm, native Apple-like, precise, premium, and structured. Not a chatbot, not a dashboard, not a habit tracker, not fantasy gamification.

Use a very light porcelain-gray background, graphite text, restrained semantic accents, 8-12px cards, SF Pro-like typography, generous spacing, and subtle depth. Cards should feel like editable thinking slips with thin colored spines, not generic colorful blocks.

Generate 4 screens: Today Capture, Organized Thinking Cards, Thinking Lens + Deep Question, Tomorrow Main Quest. Use Simplified Chinese UI text. The visual style should be minimal but not empty, serious but personal, and elegant enough to feel Apple-like.
```
