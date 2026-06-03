#!/usr/bin/env python3
"""明思 Xiaohongshu carousel cards — warm paper aesthetic, 3:4 vertical."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random

FONT_DIR = "/Users/chenzewei/.claude/skills/canvas-design/canvas-fonts"
SYS = "/System/Library/Fonts"
ZH = f"{SYS}/Hiragino Sans GB.ttc"
SONG = f"{SYS}/Supplemental/Songti.ttc"

def ff(name: str, size: int):
    zh_map = {"zh": ZH, "song": SONG}
    path = zh_map.get(name, f"{FONT_DIR}/{name}")
    return ImageFont.truetype(path, size)

# Colors
PAPER    = (245, 240, 232)
GRAPHITE = (44, 44, 44)
CINNABAR = (197, 75, 60)
DEEP_GRN = (45, 106, 79)
INDIGO   = (67, 56, 202)
AMBER    = (200, 160, 60)
LIGHT_GRAY = (180, 175, 168)
MID_GRAY = (120, 118, 112)
BORDER   = (215, 210, 202)
CARD_BG  = (248, 244, 236)

OUT = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/xhs"

def paper(draw, W, H):
    random.seed(99)
    for _ in range(8000):
        x, y = random.randint(0, W - 2), random.randint(0, H - 2)
        s = random.randint(1, 4)
        n = random.randint(-4, 4)
        c = tuple(max(0, min(255, PAPER[i] + n)) for i in range(3))
        draw.rectangle([x, y, x + s, y + s], fill=c + (24,))

def card(W=1080, H=1440):
    """Base 3:4 card."""
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper(draw, W, H)
    return img, draw

def center_text(draw, y, text, font, fill, W=1080):
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    x = (W - tw) // 2
    draw.text((x, y), text, fill=fill, font=font)

def left_block(draw, x, y, text, font, fill, max_w):
    """Left-aligned text block with line wrapping."""
    lines = []
    current = ""
    for char in text:
        test = current + char
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] > max_w:
            lines.append(current)
            current = char
        else:
            current = test
    if current:
        lines.append(current)
    for i, line in enumerate(lines):
        draw.text((x, y + i * (font.size + 14)), line, fill=fill, font=font)
    return y + len(lines) * (font.size + 14)


# ═══════════════════════════════════════════════════════════════════
# Card 1: Hook cover
# ═══════════════════════════════════════════════════════════════════
def card01_cover():
    img, draw = card()
    W, H = img.size

    # Top corner marks
    draw.line([(48, 48), (48, 90)], fill=CINNABAR + (140,), width=3)
    draw.line([(48, 48), (90, 48)], fill=CINNABAR + (140,), width=3)
    draw.line([(W - 48, H - 48), (W - 48, H - 90)], fill=CINNABAR + (140,), width=3)
    draw.line([(W - 48, H - 48), (W - 90, H - 48)], fill=CINNABAR + (140,), width=3)

    # Top label
    draw.text((72, 80), "M I N G S I", fill=LIGHT_GRAY, font=ff("GeistMono-Regular.ttf", 18))

    # Main question
    center_text(draw, 280, "做了很多事", ff("zh", 64), GRAPHITE, W)
    center_text(draw, 370, "但没想清楚？", ff("zh", 64), GRAPHITE, W)

    # Divider
    draw.line([(W // 2 - 60, 470), (W // 2 + 60, 470)], fill=CINNABAR, width=4)

    # Answer
    center_text(draw, 510, "明思帮你把事情想清楚。", ff("zh", 36), MID_GRAY, W)

    # Bottom seal
    sx, sy = W // 2, 720
    draw.rectangle([sx - 50, sy - 50, sx + 50, sy + 50], outline=CINNABAR + (160,), width=3)
    draw.rectangle([sx - 44, sy - 44, sx + 44, sy + 44], outline=CINNABAR + (80,), width=1)
    center_text(draw, sy - 22, "明思", ff("song", 40), CINNABAR, W)

    # Bottom
    center_text(draw, 850, "个人思维训练与复盘 App", ff("zh", 24), LIGHT_GRAY, W)
    center_text(draw, 1320, "左滑了解 >", ff("zh", 20), LIGHT_GRAY, W)

    img.convert("RGB").save(f"{OUT}/01-cover.png", "PNG", dpi=(300, 300))
    print("01 cover")


# ═══════════════════════════════════════════════════════════════════
# Card 2: Problem
# ═══════════════════════════════════════════════════════════════════
def card02_problem():
    img, draw = card()
    W, H = img.size
    margin = 80

    draw.text((margin, 80), "01", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 20))
    draw.text((margin, 120), "三个你一定有过的感受", fill=GRAPHITE, font=ff("zh", 36))

    problems = [
        ("日记写了几周就断了", "记的是感受，不是判断。写完就完了，\n没有追问，没有验证，没有校准。"),
        ("Todo 越来越长但没人在意质量", "完成了打勾，没完成延期。但没人问\n\"这件事重要吗？完成它证明了什么？\""),
        ("AI 聊天聊完就忘了", "AI 给了建议，你点了头，关掉窗口，\n什么都没留下。没有证据，没有闭环。"),
    ]

    y = 220
    for i, (title, desc) in enumerate(problems):
        # Number
        num = f"0{i + 1}"
        draw.text((margin, y), num, fill=CINNABAR, font=ff("GeistMono-Regular.ttf", 16))
        # Title
        draw.text((margin + 48, y - 4), title, fill=GRAPHITE, font=ff("zh", 28))
        # Description
        for j, line in enumerate(desc.split("\n")):
            draw.text((margin + 48, y + 40 + j * 34), line, fill=MID_GRAY, font=ff("zh", 22))
        # Divider
        if i < 2:
            draw.line([(margin, y + 120), (W - margin, y + 120)], fill=BORDER + (80,))
        y += 148

    # Bottom line
    draw.line([(margin, 1200), (W - margin, 1200)], fill=CINNABAR, width=3)
    draw.text((margin, 1240), "问题不是缺工具，是缺一个闭环。", fill=GRAPHITE, font=ff("zh", 26))

    img.convert("RGB").save(f"{OUT}/02-problem.png", "PNG", dpi=(300, 300))
    print("02 problem")


# ═══════════════════════════════════════════════════════════════════
# Card 3: Core loop
# ═══════════════════════════════════════════════════════════════════
def card03_loop():
    img, draw = card()
    W, H = img.size
    margin = 80

    draw.text((margin, 80), "02", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 20))
    draw.text((margin, 120), "明思的五个步骤", fill=GRAPHITE, font=ff("zh", 36))

    steps = [
        ("Clarify", "澄清", "输入今天的事、想法、困惑。不需要写成文章，想到什么说什么。"),
        ("Challenge", "质疑", "AI 整理成卡片，你确认或修正。透镜提供不同审视角度。"),
        ("Choose", "选择", "AI 提出追问，你做出判断。发现假设、漏洞、取舍。"),
        ("Act", "行动", "从判断中生成明天的任务，包含完成标准和验证问题。"),
        ("Calibrate", "校准", "第二天回看昨天的判断是否成立，校准思考偏差。"),
    ]

    y = 220
    for i, (en, zh, desc) in enumerate(steps):
        # Step number circle
        cx = margin + 28
        cy = y + 28
        draw.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], outline=CINNABAR, width=2)
        draw.text((cx - 8, cy - 12), str(i + 1), fill=CINNABAR, font=ff("zh", 22))

        # English + Chinese
        draw.text((margin + 72, y), en, fill=GRAPHITE, font=ff("GeistMono-Regular.ttf", 24))
        draw.text((margin + 72, y + 32), zh, fill=CINNABAR, font=ff("zh", 24))

        # Description
        y2 = left_block(draw, margin + 72, y + 68, desc, ff("zh", 20), MID_GRAY, W - margin - 72 - 20)

        # Connector line
        if i < 4:
            line_y = y + 56
            draw.line([(margin + 28, line_y), (margin + 28, y2 + 10)], fill=BORDER + (100,), width=1)
        y = max(y2 + 28, y + 140)

    # Bottom
    draw.line([(margin, 1260), (W - margin, 1260)], fill=CINNABAR, width=3)
    center_text(draw, 1300, "输入混乱的思考，输出可验证的判断。", ff("zh", 24), GRAPHITE, W)

    img.convert("RGB").save(f"{OUT}/03-loop.png", "PNG", dpi=(300, 300))
    print("03 loop")


# ═══════════════════════════════════════════════════════════════════
# Card 4: Features grid
# ═══════════════════════════════════════════════════════════════════
def card04_features():
    img, draw = card()
    W, H = img.size
    margin = 72

    draw.text((margin, 80), "03", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 20))
    draw.text((margin, 120), "七个核心功能", fill=GRAPHITE, font=ff("zh", 36))

    features = [
        ("今日复盘", DEEP_GRN, "语音或文字输入，低成本收集思考材料"),
        ("思考卡片", CINNABAR, "AI 整理成七类卡片，你确认或修正"),
        ("思考透镜", INDIGO, "证据校验、反方视角、杠杆分析"),
        ("深度追问", AMBER, "引导你思考，不替你下结论"),
        ("明日任务", DEEP_GRN, "生成带完成标准的可验证任务"),
        ("次日验证", DEEP_GRN, "校准判断，不只是记录完成"),
        ("历史证据", MID_GRAY, "复盘、卡片、任务的证据链"),
    ]

    y = 210
    col_w = (W - margin * 2 - 20) // 2
    for i, (name, color, desc) in enumerate(features):
        col = i % 2
        row = i // 2
        cx = margin + col * (col_w + 20)
        cy = y + row * 158

        # Card background
        draw.rectangle([cx, cy, cx + col_w, cy + 140], fill=CARD_BG + (200,), outline=BORDER + (120,))
        # Left color bar
        draw.rectangle([cx, cy, cx + 5, cy + 140], fill=color)
        # Feature name
        draw.text((cx + 22, cy + 16), name, fill=color, font=ff("zh", 24))
        # Description
        left_block(draw, cx + 22, cy + 56, desc, ff("zh", 18), MID_GRAY, col_w - 44)

    # Bottom note

    # Bottom note
    draw.line([(margin, 1300), (W - margin, 1300)], fill=CINNABAR, width=3)
    draw.text((margin, 1340), "所有数据存储在设备本地，不经服务器。", fill=MID_GRAY, font=ff("zh", 22))

    img.convert("RGB").save(f"{OUT}/04-features.png", "PNG", dpi=(300, 300))
    print("04 features")


# ═══════════════════════════════════════════════════════════════════
# Card 5: "It's not..."
# ═══════════════════════════════════════════════════════════════════
def card05_not():
    img, draw = card()
    W, H = img.size
    margin = 80

    draw.text((margin, 80), "04", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 20))
    draw.text((margin, 120), "明思不是什么", fill=GRAPHITE, font=ff("zh", 36))
    draw.line([(margin, 178), (margin + 80, 178)], fill=CINNABAR, width=3)

    items = [
        ("不是日记", "明思不是记录人生，而是训练判断。\n输入是为了校准，不是为了回顾。"),
        ("不是 Todo", "明思的明日任务不是普通 Todo，\n而是让明天的任务变成可验证的判断。"),
        ("不是 AI 聊天", "明思不是 AI 聊天，而是证据驱动的\n个人复盘系统。AI 整理追问，你判断。"),
        ("不是打卡", "不统计连续天数，不做性格标签，\n不做\"你比 80% 用户更自律\"。"),
    ]

    y = 230
    for i, (title, desc) in enumerate(items):
        # Title with strikethrough feel
        draw.text((margin, y), title, fill=CINNABAR, font=ff("zh", 28))
        # Description
        for j, line in enumerate(desc.split("\n")):
            draw.text((margin, y + 44 + j * 36), line, fill=GRAPHITE, font=ff("zh", 24))
        y += 160

    # Bottom emphasis
    draw.rectangle([margin, 1080, W - margin, 1120], fill=CINNABAR + (20,))
    draw.rectangle([margin, 1080, margin + 5, 1120], fill=CINNABAR)
    draw.text((margin + 22, 1086), "它是基于事实、行动、反馈和校准的训练闭环。", fill=GRAPHITE, font=ff("zh", 24))

    img.convert("RGB").save(f"{OUT}/05-not.png", "PNG", dpi=(300, 300))
    print("05 not")


# ═══════════════════════════════════════════════════════════════════
# Card 6: Quote + CTA
# ═══════════════════════════════════════════════════════════════════
def card06_cta():
    img, draw = card()
    W, H = img.size
    margin = 80

    # Top
    draw.text((margin, 80), "05", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 20))

    # Big quote
    draw.text((margin, 160), "\"", fill=CINNABAR, font=ff("song", 100))

    draw.text((margin + 20, 250), "明思不替你思考。", fill=GRAPHITE, font=ff("zh", 36))
    draw.text((margin + 20, 310), "它只是每天把你说过的话、", fill=MID_GRAY, font=ff("zh", 30))
    draw.text((margin + 20, 358), "做过的事、没想清楚的判断，", fill=MID_GRAY, font=ff("zh", 30))
    draw.text((margin + 20, 406), "重新摆到你面前。", fill=MID_GRAY, font=ff("zh", 30))

    draw.text((W - margin - 40, 460), "\"", fill=CINNABAR, font=ff("song", 100))

    # Divider
    draw.line([(margin, 590), (W - margin, 590)], fill=BORDER + (100,), width=1)

    # Key point
    draw.text((margin, 640), "如果你每天花几分钟", fill=GRAPHITE, font=ff("zh", 28))
    draw.text((margin, 686), "认真面对自己的判断", fill=GRAPHITE, font=ff("zh", 28))
    draw.text((margin, 740), "你的判断会慢慢变准。", fill=CINNABAR, font=ff("zh", 28))

    # Subtitle
    draw.text((margin, 820), "这不是鸡汤，这是校准。", fill=MID_GRAY, font=ff("zh", 22))

    # Bottom CTA area
    draw.line([(margin, 980), (W - margin, 980)], fill=CINNABAR, width=3)

    # Seal
    sx, sy = W // 2, 1100
    draw.rectangle([sx - 60, sy - 60, sx + 60, sy + 60], outline=CINNABAR + (160,), width=3)
    draw.rectangle([sx - 54, sy - 54, sx + 54, sy + 54], outline=CINNABAR + (80,), width=1)
    center_text(draw, sy - 24, "明思", ff("song", 44), CINNABAR, W)

    center_text(draw, 1200, "MingSi", ff("InstrumentSans-Regular.ttf", 28), MID_GRAY, W)
    center_text(draw, 1260, "iOS / SwiftUI / 本地存储 / 开源", ff("GeistMono-Regular.ttf", 18), LIGHT_GRAY, W)

    # Bottom swipe hint
    center_text(draw, 1360, "把事情想清楚。", ff("zh", 24), GRAPHITE, W)

    img.convert("RGB").save(f"{OUT}/06-cta.png", "PNG", dpi=(300, 300))
    print("06 cta")

if __name__ == "__main__":
    print("Generating Xiaohongshu carousel cards...")
    card01_cover()
    card02_problem()
    card03_loop()
    card04_features()
    card05_not()
    card06_cta()
    print("Done. 6 cards generated.")
