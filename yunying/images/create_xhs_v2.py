#!/usr/bin/env python3
"""明思 XHS cards v2 — Esther Design System applied."""

from PIL import Image, ImageDraw, ImageFont
import random

# ── Esther palette ─────────────────────────────────────────────────
INK       = (26, 26, 26)        # #1A1A1A
INK_LIGHT = (74, 74, 90)        # #4A4A5A
INK_FAINT = (138, 138, 154)     # #8A8A9A
CREAM     = (254, 252, 246)     # #FEFCF6
CREAM_DK  = (250, 246, 235)     # #FAFAEB
PAPER_EDGE= (243, 234, 219)     # #F3EADB
YELLOW    = (244, 215, 88)      # #F4D758
BLUE      = (43, 127, 216)      # #2B7FD8
RED       = (232, 74, 95)       # #E84A5F
WHITE     = (255, 255, 255)

# ── Fonts ──────────────────────────────────────────────────────────
SYS = "/System/Library/Fonts"
CANON = "/Users/chenzewei/.claude/skills/canvas-design/canvas-fonts"

def ff(name, size):
    zh = {"zh": f"{SYS}/Hiragino Sans GB.ttc",
          "song": f"{SYS}/Supplemental/Songti.ttc"}
    path = zh.get(name, f"{CANON}/{name}")
    return ImageFont.truetype(path, size)

OUT = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/xhs"
W, H = 1080, 1440

def base_card():
    img = Image.new("RGBA", (W, H), CREAM + (255,))
    draw = ImageDraw.Draw(img)
    random.seed(7)
    # Light grid texture (esther spec)
    for y in range(0, H, 40):
        draw.line([(0, y), (W, y)], fill=(0, 0, 0, 8))
    for x in range(0, W, 40):
        draw.line([(x, 0), (x, H)], fill=(0, 0, 0, 8))
    # Subtle noise
    for _ in range(6000):
        x, y = random.randint(0, W - 2), random.randint(0, H - 2)
        n = random.randint(-3, 3)
        c = tuple(max(0, min(255, CREAM[i] + n)) for i in range(3))
        draw.rectangle([x, y, x + 2, y + 2], fill=c + (20,))
    return img, draw

def center_y(draw, y, text, font, fill, w=W):
    bb = draw.textbbox((0, 0), text, font=font)
    x = (w - bb[2] + bb[0]) // 2
    draw.text((x, y), text, fill=fill, font=font)

def right_x(draw, text, font, right_edge):
    bb = draw.textbbox((0, 0), text, font=font)
    return right_edge - (bb[2] - bb[0])

def wrap_text(text, font, max_w, draw):
    lines, cur = [], ""
    for ch in text:
        test = cur + ch
        bb = draw.textbbox((0, 0), test, font=font)
        if bb[2] - bb[0] > max_w:
            if cur: lines.append(cur)
            cur = ch
        else:
            cur = test
    if cur: lines.append(cur)
    return lines

def page_num(draw, n, y=H - 70):
    """Oversized faded page number — esther tip-header style."""
    f = ff("Fraunces-Regular.ttf", 120) if False else ff("GeistMono-Regular.ttf", 28)
    # Use a smaller styled number
    num = f"0{n}"
    center_y(draw, y, num, ff("GeistMono-Regular.ttf", 20), INK_FAINT + (60,))

def yellow_rule(draw, x, y, width=60):
    draw.rectangle([x, y, x + width, y + 4], fill=YELLOW)

# ═══════════════════════════════════════════════════════════════════
# Card 1 — Cover (big impact, lots of whitespace)
# ═══════════════════════════════════════════════════════════════════
def c01_cover():
    img, draw = base_card()
    # Yellow border (esther spec: 40px)
    draw.rectangle([0, 0, W, 36], fill=YELLOW)
    draw.rectangle([0, H - 36, W, H], fill=YELLOW)
    draw.rectangle([0, 0, 36, H], fill=YELLOW)
    draw.rectangle([W - 36, 0, W, H], fill=YELLOW)

    m = 72  # inner margin
    # Top tag
    draw.text((m, 80), "M I N G S I", fill=INK_FAINT, font=ff("GeistMono-Regular.ttf", 16))

    # Big question — serif, oversized
    draw.text((m, 240), "做了很多事", fill=INK, font=ff("song", 80))
    # Highlight word with yellow bg
    draw.text((m, 340), "但没想清楚", fill=INK, font=ff("song", 80))
    # Yellow highlight bar under "没想清楚"
    bb = draw.textbbox((m, 340), "但没想清楚", font=ff("song", 80))
    draw.rectangle([bb[0], bb[3] + 4, bb[2], bb[3] + 12], fill=YELLOW)

    # Short divider
    yellow_rule(draw, m, 480, 80)

    # Tagline — lighter, smaller
    draw.text((m, 520), "明思帮你把事情想清楚。", fill=INK_LIGHT, font=ff("zh", 32))

    # Brand block bottom area
    draw.text((m, 920), "个人思维训练与复盘", fill=INK, font=ff("song", 36))
    draw.text((m, 972), "不是日记 / 不是 Todo / 不是 AI 聊天", fill=INK_FAINT, font=ff("zh", 22))

    # Cycle strip at bottom
    draw.rectangle([m, 1080, W - m, 1132], fill=CREAM_DK)
    cycle = "Clarify  >  Challenge  >  Choose  >  Act  >  Calibrate"
    center_y(draw, 1092, cycle, ff("GeistMono-Regular.ttf", 18), BLUE)

    draw.text((m, 1200), "iOS / SwiftUI / 本地存储 / 开源", fill=INK_FAINT, font=ff("GeistMono-Regular.ttf", 16))

    img.convert("RGB").save(f"{OUT}/01-cover.png", "PNG", dpi=(300, 300))
    print("01 cover")


# ═══════════════════════════════════════════════════════════════════
# Card 2 — Problem (magazine layout, varied density)
# ═══════════════════════════════════════════════════════════════════
def c02_problem():
    img, draw = base_card()
    m = 80

    # Section number — oversized faded (esther tip-header)
    draw.text((m, 60), "01", fill=BLUE + (30,), font=ff("GeistMono-Bold.ttf", 100))
    draw.text((m + 110, 100), "三个你一定有过的感受", fill=INK, font=ff("song", 44))
    yellow_rule(draw, m, 170, 80)

    problems = [
        ("日记写了几周就断了",
         "记的是感受，不是判断。写完就完了，\n没有追问，没有验证，没有校准。"),
        ("Todo 越来越长但没人在意质量",
         "完成了打勾，没完成延期。但没人问\n「这件事重要吗？完成它证明了什么？」"),
        ("AI 聊天聊完就忘了",
         "AI 给了建议，你点了头，关掉窗口，\n什么都没留下。没有证据，没有闭环。"),
    ]

    y = 220
    for i, (title, desc) in enumerate(problems):
        # Oversized number (esther number-card style)
        draw.text((m, y), f"0{i + 1}", fill=BLUE + (20,), font=ff("GeistMono-Bold.ttf", 72))

        # Title on the right of the number
        draw.text((m + 120, y + 14), title, fill=INK, font=ff("zh", 30))

        # Description below
        for j, line in enumerate(desc.split("\n")):
            draw.text((m + 120, y + 60 + j * 38), line, fill=INK_LIGHT, font=ff("zh", 24))

        # Yellow separator
        if i < 2:
            y += 150
            draw.rectangle([m + 120, y - 14, m + 120 + 80, y - 10], fill=YELLOW)
        y += 30

    # Bottom emphasis — quote-highlight style
    draw.rectangle([m, 1040, W - m, 1110], fill=YELLOW + (40,))
    draw.text((m + 16, 1058), "问题不是缺工具，是缺一个闭环。", fill=INK, font=ff("zh", 28))

    page_num(draw, 2)
    img.convert("RGB").save(f"{OUT}/02-problem.png", "PNG", dpi=(300, 300))
    print("02 problem")


# ═══════════════════════════════════════════════════════════════════
# Card 3 — Loop (number-card vertical flow)
# ═══════════════════════════════════════════════════════════════════
def c03_loop():
    img, draw = base_card()
    m = 80

    draw.text((m, 60), "02", fill=YELLOW + (80,), font=ff("GeistMono-Bold.ttf", 100))
    draw.text((m + 110, 100), "明思的五个步骤", fill=INK, font=ff("song", 44))
    yellow_rule(draw, m, 170, 80)

    steps = [
        ("Clarify", "澄清", "输入今天的事、想法、困惑。\n不需要写成文章，想到什么说什么。"),
        ("Challenge", "质疑", "AI 整理成卡片，你确认或修正。\n透镜提供不同审视角度。"),
        ("Choose", "选择", "AI 提出追问，你做出判断。\n发现假设、漏洞和取舍。"),
        ("Act", "行动", "从判断中生成明天的任务，\n包含完成标准和验证问题。"),
        ("Calibrate", "校准", "第二天回看昨天的判断是否成立，\n校准你的思考偏差。"),
    ]

    y = 210
    for i, (en, zh, desc) in enumerate(steps):
        # Big faded number
        num_str = str(i + 1)
        draw.text((m, y), num_str, fill=INK_FAINT + (25,), font=ff("GeistMono-Bold.ttf", 56))

        # English keyword — blue, mono
        draw.text((m + 64, y + 4), en, fill=BLUE, font=ff("GeistMono-Regular.ttf", 26))
        # Chinese — red accent
        draw.text((m + 64, y + 38), zh, fill=RED, font=ff("zh", 24))

        # Description
        for j, line in enumerate(desc.split("\n")):
            draw.text((m + 64, y + 76 + j * 34), line, fill=INK_LIGHT, font=ff("zh", 22))

        # Arrow connector (except last)
        if i < 4:
            arrow_y = y + 130
            draw.text((m + 10, arrow_y), ">", fill=YELLOW, font=ff("GeistMono-Bold.ttf", 24))

        y += 148

    # Bottom strip
    draw.rectangle([m, 1060, W - m, 1110], fill=CREAM_DK)
    center_y(draw, 1070, "输入混乱的思考，输出可验证的判断。", ff("zh", 24), INK)

    page_num(draw, 3)
    img.convert("RGB").save(f"{OUT}/03-loop.png", "PNG", dpi=(300, 300))
    print("03 loop")


# ═══════════════════════════════════════════════════════════════════
# Card 4 — Features (tag-card grid, 2x3 + 1 centered)
# ═══════════════════════════════════════════════════════════════════
def c04_features():
    img, draw = base_card()
    m = 72

    draw.text((m, 60), "03", fill=RED + (40,), font=ff("GeistMono-Bold.ttf", 100))
    draw.text((m + 110, 100), "七个核心功能", fill=INK, font=ff("song", 44))
    yellow_rule(draw, m, 170, 80)

    features = [
        ("今日复盘", BLUE, "语音或文字输入\n低成本收集思考材料"),
        ("思考卡片", YELLOW, "AI 整理成七类卡片\n你确认或修正"),
        ("思考透镜", BLUE, "证据校验、反方视角\n杠杆分析"),
        ("深度追问", RED, "引导你思考\n不替你下结论"),
        ("明日任务", YELLOW, "生成带完成标准的\n可验证任务"),
        ("次日验证", BLUE, "校准判断\n不只是记录完成"),
        ("历史证据", INK_FAINT, "复盘、卡片、任务的证据链"),
    ]

    col_w = (W - m * 2 - 20) // 2
    y = 200
    for i, (name, color, desc) in enumerate(features):
        if i < 6:
            col = i % 2
            row = i // 2
            cx = m + col * (col_w + 20)
            cy = y + row * 190
        else:
            # 7th item centered
            cx = m + (W - m * 2 - col_w) // 2 - m // 2
            cy = y + 3 * 190

        # White card
        draw.rectangle([cx, cy, cx + col_w, cy + 168], fill=WHITE + (240,), outline=(0, 0, 0, 10))
        # Pill tag (esther tag-card style)
        pill_w = draw.textbbox((0, 0), name, font=ff("zh", 20))[2]
        draw.rounded_rectangle([cx + 20, cy + 20, cx + 28 + pill_w, cy + 50],
                               radius=20, fill=color + (30,))
        draw.text((cx + 24, cy + 23), name, fill=color, font=ff("zh", 20))
        # Description
        for j, line in enumerate(desc.split("\n")):
            draw.text((cx + 20, cy + 68 + j * 34), line, fill=INK_LIGHT, font=ff("zh", 22))

    page_num(draw, 4)
    img.convert("RGB").save(f"{OUT}/04-features.png", "PNG", dpi=(300, 300))
    print("04 features")


# ═══════════════════════════════════════════════════════════════════
# Card 5 — "Not..." (dark panel contrast page)
# ═══════════════════════════════════════════════════════════════════
def c05_not():
    img, draw = base_card()
    m = 80

    # Dark panel (esther terminal/quote style)
    draw.rectangle([0, 0, W, H], fill=(26, 26, 42))  # dark bg
    # Re-draw grid on dark
    for y in range(0, H, 40):
        draw.line([(0, y), (W, y)], fill=(255, 255, 255, 5))
    for x in range(0, W, 40):
        draw.line([(x, 0), (x, H)], fill=(255, 255, 255, 5))

    draw.text((m, 60), "04", fill=YELLOW + (40,), font=ff("GeistMono-Bold.ttf", 100))
    draw.text((m + 110, 100), "明思不是什么", fill=WHITE, font=ff("song", 44))

    # Yellow short rule
    draw.rectangle([m + 110, 160, m + 190, 164], fill=YELLOW)

    items = [
        ("不是日记", "不是记录人生，而是训练判断。\n输入是为了校准，不是为了回顾。"),
        ("不是 Todo", "明日任务不是普通 Todo，\n而是让明天的任务变成可验证的判断。"),
        ("不是 AI 聊天", "不是 AI 聊天，而是证据驱动的\n个人复盘系统。AI 整理追问，你判断。"),
        ("不是打卡", "不统计连续天数，不做性格标签，\n不做「你比 80% 用户更自律」。"),
    ]

    y = 220
    for i, (title, desc) in enumerate(items):
        # Title with red color (刀口 — surgery red)
        draw.text((m, y), title, fill=RED, font=ff("zh", 30))
        for j, line in enumerate(desc.split("\n")):
            draw.text((m, y + 44 + j * 38), line, fill=(200, 200, 210), font=ff("zh", 24))
        if i < 3:
            draw.rectangle([m, y + 130, m + 80, y + 134], fill=YELLOW + (80,))
        y += 160

    # Bottom emphasis — yellow highlight (esther highlighter style)
    draw.rectangle([m, 980, W - m, 1050], fill=YELLOW + (60,))
    draw.text((m + 16, 998), "它是基于事实、行动、反馈和校准的训练闭环。",
              fill=INK, font=ff("zh", 26))

    page_num_dark = lambda n: center_y(draw, H - 70, f"0{n}", ff("GeistMono-Regular.ttf", 20), (200, 200, 210, 60))
    page_num_dark(5)

    img.convert("RGB").save(f"{OUT}/05-not.png", "PNG", dpi=(300, 300))
    print("05 not")


# ═══════════════════════════════════════════════════════════════════
# Card 6 — Quote + CTA (editorial quote style)
# ═══════════════════════════════════════════════════════════════════
def c06_cta():
    img, draw = base_card()
    m = 80

    draw.text((m, 60), "05", fill=BLUE + (30,), font=ff("GeistMono-Bold.ttf", 100))

    # Oversized opening quote (esther editorial quote)
    draw.text((m - 10, 140), "\"", fill=YELLOW + (180,), font=ff("song", 140))

    # Main quote
    draw.text((m + 10, 280), "明思不替你思考。", fill=INK, font=ff("song", 48))
    draw.text((m + 10, 350), "它只是每天把你说过的话、", fill=INK_LIGHT, font=ff("zh", 30))
    draw.text((m + 10, 394), "做过的事、没想清楚的判断，", fill=INK_LIGHT, font=ff("zh", 30))
    draw.text((m + 10, 438), "重新摆到你面前。", fill=INK_LIGHT, font=ff("zh", 30))

    # Closing quote
    cx = right_x(draw, "\"", ff("song", 140), W - m)
    draw.text((cx, 460), "\"", fill=YELLOW + (180,), font=ff("song", 140))

    # Yellow rule
    yellow_rule(draw, m, 640, 80)

    # Key point
    draw.text((m, 690), "如果你每天花几分钟", fill=INK, font=ff("zh", 28))
    draw.text((m, 730), "认真面对自己的判断", fill=INK, font=ff("zh", 28))
    # Highlighted conclusion
    draw.text((m, 770), "你的判断会慢慢变准。", fill=BLUE, font=ff("zh", 28))

    # Subtle note
    draw.text((m, 840), "这不是鸡汤，这是校准。", fill=INK_FAINT, font=ff("zh", 22))

    # Brand block
    yellow_rule(draw, m, 960, W - 2 * m)

    # Seal stamp — simplified
    sx = W // 2
    draw.rectangle([sx - 50, 1020, sx + 50, 1120], outline=INK + (40,), width=2)
    draw.rectangle([sx - 44, 1026, sx + 44, 1114], outline=INK + (20,), width=1)
    center_y(draw, 1048, "明思", ff("song", 40), INK)

    center_y(draw, 1170, "MingSi", ff("InstrumentSans-Regular.ttf", 26), INK_FAINT)
    center_y(draw, 1210, "iOS / SwiftUI / 本地存储 / 开源", ff("GeistMono-Regular.ttf", 16), INK_FAINT)
    center_y(draw, 1300, "把事情想清楚。", ff("zh", 24), INK)

    img.convert("RGB").save(f"{OUT}/06-cta.png", "PNG", dpi=(300, 300))
    print("06 cta")


if __name__ == "__main__":
    print("Generating XHS cards v2 (Esther Design System)...")
    c01_cover()
    c02_problem()
    c03_loop()
    c04_features()
    c05_not()
    c06_cta()
    print("Done. 6 cards with Esther DS.")
