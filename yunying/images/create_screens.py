#!/usr/bin/env python3
"""MingSi App Screen Mockups — Ink Discipline philosophy."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random

FONT_DIR = "/Users/chenzewei/.claude/skills/canvas-design/canvas-fonts"

def font(name, size):
    return ImageFont.truetype(f"{FONT_DIR}/{name}", size)

# Colors
PAPER    = (245, 240, 232)
GRAPHITE = (44, 44, 44)
CINNABAR = (197, 75, 60)
DEEP_GRN = (45, 106, 79)
INDIGO   = (67, 56, 202)
AMBER    = (200, 160, 60)
LIGHT_GRAY = (180, 175, 168)
MID_GRAY  = (120, 118, 112)
CARD_BG   = (248, 244, 236)
INPUT_BG  = (242, 238, 228)

def paper_texture(img, draw, W, H):
    random.seed(42)
    for y in range(0, H, 2):
        for x in range(0, W, 2):
            n = random.randint(-3, 3)
            r = max(0, min(255, PAPER[0] + n))
            g = max(0, min(255, PAPER[1] + n))
            b = max(0, min(255, PAPER[2] + n))
            draw.point((x, y), fill=(r, g, b, 255))
            if x + 1 < W:
                draw.point((x + 1, y), fill=(r, g, b, 255))

def phone_frame(draw, cx, cy, w=380, h=820):
    """Draw phone frame, returns screen bounds."""
    left = cx - w // 2
    top = cy - h // 2
    right = cx + w // 2
    bot = cy + h // 2
    r = 50
    # Body
    draw.rounded_rectangle([left, top, right, bot], radius=r, fill=(28, 28, 30), outline=(60, 60, 62), width=2)
    # Screen
    m = 6
    sr = r - 3
    draw.rounded_rectangle([left + m, top + m, right - m, bot - m], radius=sr, fill=PAPER)
    # Dynamic Island
    di_w, di_h = 110, 30
    draw.rounded_rectangle([cx - di_w // 2, top + m + 12, cx + di_w // 2, top + m + 12 + di_h],
                           radius=15, fill=(28, 28, 30))
    # Home indicator
    draw.rounded_rectangle([cx - 60, bot - m - 14, cx + 60, bot - m - 6], radius=4, fill=(100, 98, 92))
    return left + m, top + m + 52, right - m, bot - m - 22


def create_today_review():
    """Screen 1: 今日复盘输入页面"""
    W, H = 540, 960  # 9:16 padded
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_texture(img, draw, W, H)

    pad = 32
    sl, st, sr, sb = pad + 30, pad + 50, W - pad - 30, H - pad - 30

    # Title area
    f_date = font("IBMPlexMono-Regular.ttf", 13)
    f_title = font("WorkSans-Bold.ttf", 26)
    f_body = font("WorkSans-Regular.ttf", 15)
    f_small = font("WorkSans-Regular.ttf", 13)
    f_btn = font("WorkSans-Bold.ttf", 16)

    draw.text((sl, st), "2026.05.31  周日", fill=MID_GRAY, font=f_date)
    draw.text((sl, st + 24), "今日复盘", fill=GRAPHITE, font=f_title)

    # Divider
    draw.line([(sl, st + 62), (sl + 50, st + 62)], fill=CINNABAR, width=2)

    # Input area
    input_top = st + 80
    input_h = 200
    draw.rectangle([sl, input_top, sr, input_top + input_h], fill=INPUT_BG + (180,), outline=(210, 205, 195, 150))
    input_lines = [
        "今天和客户开了需求评审会，发现",
        "他们对核心功能的预期和我理解的",
        "有偏差。会后整理了三个必须确认",
        "的问题。",
        "",
        "另外，技术方案的 deadline 可能",
        "要延期一周，原因是第三方接口文",
        "档不完整...",
    ]
    for i, line in enumerate(input_lines):
        draw.text((sl + 14, input_top + 14 + i * 22), line, fill=GRAPHITE, font=f_body)

    # Card preview section
    card_top = input_top + input_h + 24
    draw.text((sl, card_top), "已识别", fill=MID_GRAY, font=f_small)

    cards = [
        ("事实", LIGHT_GRAY, "客户预期与理解存在三处偏差"),
        ("风险", CINNABAR, "第三方接口文档不完整，deadline 或延期"),
        ("任务", DEEP_GRN, "确认三个核心功能问题并同步客户"),
    ]

    for i, (label, color, text) in enumerate(cards):
        cy = card_top + 24 + i * 62
        draw.rectangle([sl, cy, sr, cy + 52], fill=CARD_BG + (200,), outline=(225, 220, 212))
        # Left color bar
        draw.rectangle([sl, cy, sl + 4, cy + 52], fill=color)
        # Dot + label
        draw.ellipse([sl + 14, cy + 8, sl + 22, cy + 16], fill=color)
        draw.text((sl + 28, cy + 4), label, fill=color, font=f_small)
        # Text
        draw.text((sl + 14, cy + 24), text, fill=GRAPHITE, font=f_body)

    # Button
    btn_y = card_top + 24 + 3 * 62 + 16
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 44], radius=10, fill=CINNABAR)
    draw.text(((sl + sr) // 2 - 44, btn_y + 10), "整理成卡片", fill=(255, 252, 245), font=f_btn)

    # Micro label at bottom
    f_micro = font("IBMPlexMono-Regular.ttf", 10)
    draw.text((sl, sb - 16), "clarify → challenge → choose → act → calibrate", fill=LIGHT_GRAY, font=f_micro)

    output = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/01-today-review.png"
    img.convert("RGB").save(output, "PNG", dpi=(300, 300))
    print(f"Saved: {output}")


def create_thinking_cards():
    """Screen 2: 思考卡片页面"""
    W, H = 540, 960
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_texture(img, draw, W, H)

    pad = 32
    sl, st, sr, sb = pad + 30, pad + 50, W - pad - 30, H - pad - 30

    f_title = font("WorkSans-Bold.ttf", 24)
    f_label = font("WorkSans-Regular.ttf", 13)
    f_body = font("WorkSans-Regular.ttf", 14)
    f_btn = font("WorkSans-Bold.ttf", 15)
    f_count = font("IBMPlexMono-Regular.ttf", 12)

    draw.text((sl, st), "思考卡片", fill=GRAPHITE, font=f_title)
    draw.text((sl, st + 32), "5 张卡片 · 已确认 2 张", fill=MID_GRAY, font=f_count)
    draw.line([(sl, st + 52), (sl + 50, st + 52)], fill=CINNABAR, width=2)

    cards = [
        ("事实", LIGHT_GRAY, "客户预期与产品规划存在三处关键偏差", True),
        ("风险", CINNABAR, "第三方接口文档缺失，项目 deadline 可能延期一周", False),
        ("任务", DEEP_GRN, "本周内向客户发送三份确认问题清单", True),
        ("问题", INDIGO, "如果 deadline 延期，哪些功能可以并行推进？", False),
        ("想法", AMBER, "或许应该在下一次迭代前做一次内部对齐", False),
    ]

    card_top = st + 68
    for i, (label, color, text, confirmed) in enumerate(cards):
        cy = card_top + i * 82
        draw.rectangle([sl, cy, sr, cy + 72], fill=CARD_BG + (200,), outline=(225, 220, 212))
        draw.rectangle([sl, cy, sl + 4, cy + 72], fill=color)

        # Label
        draw.text((sl + 16, cy + 8), label, fill=color, font=f_label)

        # Text
        draw.text((sl + 16, cy + 28), text, fill=GRAPHITE, font=f_body)

        # Status
        if confirmed:
            draw.text((sr - 40, cy + 8), "✓", fill=DEEP_GRN, font=f_label)
        else:
            draw.text((sr - 40, cy + 8), "○", fill=LIGHT_GRAY, font=f_label)

    # Button
    btn_y = card_top + 5 * 82 + 16
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 42], radius=10, fill=GRAPHITE)
    draw.text(((sl + sr) // 2 - 36, btn_y + 9), "继续追问", fill=(255, 252, 245), font=f_btn)

    output = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/02-thinking-cards.png"
    img.convert("RGB").save(output, "PNG", dpi=(300, 300))
    print(f"Saved: {output}")


def create_lens_selection():
    """Screen 3: 透镜选择页面"""
    W, H = 540, 960
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_texture(img, draw, W, H)

    pad = 32
    sl, st, sr, sb = pad + 30, pad + 50, W - pad - 30, H - pad - 30

    f_title = font("WorkSans-Bold.ttf", 24)
    f_sub = font("WorkSans-Regular.ttf", 14)
    f_name = font("WorkSans-Bold.ttf", 17)
    f_desc = font("WorkSans-Regular.ttf", 13)
    f_btn = font("WorkSans-Bold.ttf", 15)
    f_icon = font("GeistMono-Regular.ttf", 22)

    draw.text((sl, st), "选择透镜", fill=GRAPHITE, font=f_title)
    draw.text((sl, st + 32), "用不同角度审视今天的判断", fill=MID_GRAY, font=f_sub)
    draw.line([(sl, st + 56), (sl + 50, st + 56)], fill=CINNABAR, width=2)

    lenses = [
        ("⌕", "证据校验", "检验每个判断是否有充分的事实支撑", True),
        ("⇄", "反方视角", "站在对立面审视你的推理链条", False),
        ("⊿", "杠杆分析", "找到投入产出比最高的行动方向", False),
    ]

    lens_top = st + 80
    for i, (icon, name, desc, selected) in enumerate(lenses):
        cy = lens_top + i * 110
        border_color = CINNABAR if selected else (225, 220, 212)
        bg_tint = (252, 244, 240, 200) if selected else CARD_BG + (200,)
        draw.rectangle([sl, cy, sr, cy + 92], fill=bg_tint, outline=border_color, width=2 if selected else 1)
        if selected:
            draw.rectangle([sl, cy, sl + 4, cy + 92], fill=CINNABAR)

        # Icon circle
        draw.ellipse([sl + 20, cy + 20, sl + 60, cy + 60], outline=MID_GRAY, width=1)
        draw.text((sl + 30, cy + 26), icon, fill=GRAPHITE, font=f_icon)

        # Text
        draw.text((sl + 76, cy + 22), name, fill=GRAPHITE, font=f_name)
        draw.text((sl + 76, cy + 48), desc, fill=MID_GRAY, font=f_desc)

        # Selected indicator
        if selected:
            draw.text((sr - 30, cy + 36), "●", fill=CINNABAR, font=f_desc)

    # Button
    btn_y = lens_top + 3 * 110 + 24
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 44], radius=10, fill=CINNABAR)
    draw.text(((sl + sr) // 2 - 36, btn_y + 10), "开始审视", fill=(255, 252, 245), font=f_btn)

    # Hint
    f_hint = font("IBMPlexMono-Regular.ttf", 11)
    draw.text((sl, btn_y + 60), "未来支持自定义透镜 · Lens Pack", fill=LIGHT_GRAY, font=f_hint)

    output = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/03-lens-selection.png"
    img.convert("RGB").save(output, "PNG", dpi=(300, 300))
    print(f"Saved: {output}")


def create_history_evidence():
    """Screen 4: 历史证据页面"""
    W, H = 540, 960
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_texture(img, draw, W, H)

    pad = 32
    sl, st, sr, sb = pad + 30, pad + 50, W - pad - 30, H - pad - 30

    f_title = font("WorkSans-Bold.ttf", 24)
    f_date = font("WorkSans-Bold.ttf", 14)
    f_body = font("WorkSans-Regular.ttf", 13)
    f_meta = font("IBMPlexMono-Regular.ttf", 11)
    f_small = font("WorkSans-Regular.ttf", 12)

    draw.text((sl, st), "历史证据", fill=GRAPHITE, font=f_title)

    # Month selector
    draw.text((sl, st + 36), "◀  2026 年 5 月  ▶", fill=MID_GRAY, font=f_body)
    draw.line([(sl, st + 60), (sl + 50, st + 60)], fill=CINNABAR, width=2)

    entries = [
        ("5月30日 周六", "3 卡片 · 1 任务", "已完成", DEEP_GRN, True, [
            ("事实", LIGHT_GRAY, "客户反馈了四个关键需求变更"),
            ("任务", DEEP_GRN, "整理变更影响评估报告"),
        ]),
        ("5月29日 周五", "5 卡片 · 2 任务", "部分完成", AMBER, False, []),
        ("5月28日 周四", "4 卡片 · 1 任务", "已完成", DEEP_GRN, False, []),
        ("5月27日 周三", "2 卡片 · 1 任务", "未验证", LIGHT_GRAY, False, []),
        ("5月26日 周二", "6 卡片 · 2 任务", "已完成", DEEP_GRN, True, [
            ("风险", CINNABAR, "上游依赖方可能无法按时交付"),
            ("想法", AMBER, "考虑引入备选供应商作为 Plan B"),
        ]),
    ]

    entry_top = st + 76
    y = entry_top
    for date, meta, status, status_color, expanded, cards in entries:
        # Date row
        draw.text((sl, y), date, fill=GRAPHITE, font=f_date)
        draw.text((sl + 120, y + 1), meta, fill=MID_GRAY, font=f_meta)
        # Status dot + text
        draw.ellipse([sr - 72, y + 3, sr - 64, y + 11], fill=status_color)
        draw.text((sr - 60, y), status, fill=status_color, font=f_meta)

        y += 24

        # Expanded cards
        if expanded:
            for ctype, ccolor, ctext in cards:
                draw.rectangle([sl + 12, y, sr, y + 38], fill=CARD_BG + (180,), outline=(225, 220, 212))
                draw.rectangle([sl + 12, y, sl + 16, y + 38], fill=ccolor)
                draw.text((sl + 24, y + 4), ctype, fill=ccolor, font=f_meta)
                draw.text((sl + 24, y + 20), ctext, fill=GRAPHITE, font=f_small)
                y += 44

        # Separator
        draw.line([(sl, y + 4), (sr, y + 4)], fill=(225, 220, 212), width=1)
        y += 16

    output = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/04-history-evidence.png"
    img.convert("RGB").save(output, "PNG", dpi=(300, 300))
    print(f"Saved: {output}")


if __name__ == "__main__":
    create_today_review()
    create_thinking_cards()
    create_lens_selection()
    create_history_evidence()
    print("All screens generated.")
