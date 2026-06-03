#!/usr/bin/env python3
"""MingSi — High-res image generation with safe Chinese fonts (2x retina)."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import random

# ── Font setup ─────────────────────────────────────────────────────
CANON  = "/Users/chenzewei/.claude/skills/canvas-design/canvas-fonts"
SYS    = "/System/Library/Fonts"

# Primary Chinese font: Hiragino Sans GB (cleanest CJK coverage on macOS)
ZH = f"{SYS}/Hiragino Sans GB.ttc"
# Fallback: Arial Unicode MS for rare characters
ZH2 = f"{SYS}/Supplemental/Arial Unicode.ttf"

def ff(name: str, size: int) -> ImageFont.FreeTypeFont:
    """Font factory. zh_* names -> system CJK fonts, rest -> canvas fonts."""
    zh_map = {
        "zh":  ZH,
        "zh2": ZH2,
    }
    path = zh_map.get(name, f"{CANON}/{name}")
    return ImageFont.truetype(path, size)

# ── Palette ────────────────────────────────────────────────────────
PAPER      = (245, 240, 232)
GRAPHITE   = (44, 44, 44)
CINNABAR   = (197, 75, 60)
DEEP_GRN   = (45, 106, 79)
INDIGO     = (67, 56, 202)
AMBER      = (200, 160, 60)
LIGHT_GRAY = (180, 175, 168)
MID_GRAY   = (120, 118, 112)
BORDER     = (215, 210, 202)
CARD_BG    = (248, 244, 236)
INPUT_BG   = (242, 238, 228)

OUT = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images"

def paper_tex(draw: ImageDraw.ImageDraw, W: int, H: int) -> None:
    random.seed(42)
    for _ in range(18000):
        x, y = random.randint(0, W - 2), random.randint(0, H - 2)
        s = random.randint(1, 4)
        n = random.randint(-5, 5)
        c = tuple(max(0, min(255, PAPER[i] + n)) for i in range(3))
        draw.rectangle([x, y, x + s, y + s], fill=c + (28,))

def ruled(draw: ImageDraw.ImageDraw, W: int, H: int, gap: int = 68) -> None:
    for y in range(0, H, gap):
        draw.line([(0, y), (W, y)], fill=(232, 228, 220, 40), width=1)

def corners(draw: ImageDraw.ImageDraw, W: int, H: int) -> None:
    for x, y in [(60, 60), (W - 60, 60), (60, H - 60), (W - 60, H - 60)]:
        dx, dy = (1 if x < W // 2 else -1), (1 if y < H // 2 else -1)
        draw.line([(x, y), (x, y + dy * 40)], fill=CINNABAR + (140,), width=3)
        draw.line([(x, y), (x + dx * 40, y)], fill=CINNABAR + (140,), width=3)

def pencil(draw: ImageDraw.ImageDraw, ox: int, oy: int, deg: float,
           length: int, body: tuple, eraser: tuple) -> None:
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    for i in range(length):
        px, py = ox + i * ca, oy + i * sa
        s = body[0] + int(i * 0.08) if body[0] < 200 else body[0]
        w = 7 if i < length - 16 else max(1, 7 - (length - 16 - i) * 0.25)
        draw.ellipse([px - 5, py - w, px + 5, py + w], fill=(s, s - 8, s - 16, 200))
    for i in range(24):
        t = i / 24
        px, py = ox - i * ca, oy - i * sa
        w = 5.5 * (1 - t)
        draw.ellipse([px - w, py - w, px + w, py + w],
                     fill=(int(80 + t * 80), int(70 + t * 70), int(55 + t * 55), 230))
    draw.ellipse([ox - 24 * ca - 1, oy - 24 * sa - 1,
                  ox - 24 * ca + 1, oy - 24 * sa + 1], fill=GRAPHITE + (240,))
    for i in range(14):
        mx, my = ox + (length - 16 + i) * ca, oy + (length - 16 + i) * sa
        draw.ellipse([mx - 5, my - 6, mx + 5, my + 6], fill=(195, 190, 175, 180))
    ex, ey = ox + (length + 4) * ca, oy + (length + 4) * sa
    draw.ellipse([ex - 5, ey - 7, ex + 5, ey + 7], fill=eraser + (200,))


# ═══════════════════════════════════════════════════════════════════
# COVER (2x = 3840x2160)
# ═══════════════════════════════════════════════════════════════════
def create_cover() -> None:
    W, H = 3840, 2160
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_tex(draw, W, H)
    ruled(draw, W, H, 68)
    corners(draw, W, H)

    # Desk pencils
    pencil(draw, 250, 1700, 12, 400, (150, 140, 130), (197, 155, 150))
    pencil(draw, 200, 1600, 6, 320, (130, 125, 115), (180, 150, 140))
    pencil(draw, 480, 1820, 20, 340, (170, 160, 145), (200, 165, 155))

    # Notebook
    nx, ny, nw, nh = 130, 1820, 560, 260
    draw.rectangle([nx + 8, ny + 8, nx + nw + 8, ny + nh + 8], fill=(0, 0, 0, 18))
    draw.rectangle([nx, ny, nx + nw, ny + nh], fill=(252, 248, 240, 180), outline=BORDER + (100,))
    draw.line([(nx + nw // 2, ny), (nx + nw // 2, ny + nh)], fill=BORDER + (80,), width=2)
    for i in range(10):
        ly = ny + 30 + i * 22
        if ly < ny + nh - 16:
            draw.line([(nx + 24, ly), (nx + nw // 2 - 16, ly)], fill=(175, 170, 160, 50), width=1)
            draw.line([(nx + nw // 2 + 16, ly), (nx + nw - 24, ly)], fill=(175, 170, 160, 50), width=1)
    for i in range(6):
        ly = ny + 34 + i * 22
        if ly < ny + nh - 20:
            l1 = random.randint(80, 180)
            l2 = random.randint(70, 160)
            draw.line([(nx + 30, ly), (nx + 30 + l1, ly)], fill=(95, 92, 85, 70), width=2)
            draw.line([(nx + nw // 2 + 22, ly), (nx + nw // 2 + 22 + l2, ly)], fill=(95, 92, 85, 70), width=2)

    # Phone mockup
    pw, ph = 640, 1320
    pcx, pcy = 1000, 1000
    pl, pt = pcx - pw // 2, pcy - ph // 2
    pr, pb = pcx + pw // 2, pcy + ph // 2
    cr = 80

    # Multi-layer shadow
    for off, bl, al in [(20, 40, 18), (14, 20, 28), (6, 10, 38)]:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([pl + off, pt + off, pr + off, pb + off],
                                              radius=cr, fill=(0, 0, 0, al))
        sh = sh.filter(ImageFilter.GaussianBlur(bl))
        img.paste(sh, mask=sh)
    draw = ImageDraw.Draw(img)

    draw.rounded_rectangle([pl, pt, pr, pb], radius=cr,
                            fill=(26, 26, 28), outline=(55, 55, 58, 180), width=3)
    draw.rectangle([pr + 2, pt + 280, pr + 8, pt + 420], fill=(55, 55, 58, 160))
    sm = 10
    sl, st2, sr2, sb2 = pl + sm, pt + sm, pr - sm, pb - sm
    draw.rounded_rectangle([sl, st2, sr2, sb2], radius=cr - 4, fill=(250, 246, 238))
    diw, dih = 210, 56
    draw.rounded_rectangle([pcx - diw // 2, st2 + 18, pcx + diw // 2, st2 + 18 + dih],
                            radius=28, fill=(26, 26, 28))
    draw.text((sl + 40, st2 + 28), "9:41", fill=GRAPHITE, font=ff("GeistMono-Regular.ttf", 20))

    # Screen content
    pad = 40
    cl, cr3 = sl + pad, sr2 - pad
    ct = st2 + 18 + dih + 36

    draw.text((cl, ct), "2026.05.31", fill=MID_GRAY, font=ff("GeistMono-Regular.ttf", 22))
    draw.text((cl, ct + 34), "今日复盘", fill=GRAPHITE, font=ff("zh", 38))

    itop = ct + 92
    ih = 240
    draw.rectangle([cl, itop, cr3, itop + ih], fill=INPUT_BG + (160,), outline=(212, 207, 197, 120))
    ilines = [
        "今天和客户开了需求评审会，发现",
        "他们对核心功能的预期和我理解的",
        "有偏差。会后整理了三个必须确认",
        "的问题。技术方案 deadline 可能",
        "要延期一周..."
    ]
    for i, line in enumerate(ilines):
        draw.text((cl + 18, itop + 18 + i * 38), line, fill=GRAPHITE, font=ff("zh", 26))

    # Cursor
    draw.rectangle([cl + 18 + 280, itop + 18 + 4 * 38, cl + 20 + 280, itop + 18 + 4 * 38 + 26],
                   fill=CINNABAR + (180,))

    cdtop = itop + ih + 26
    cards = [
        ("事实", LIGHT_GRAY, "客户预期与理解有偏差"),
        ("风险", CINNABAR, "deadline 可能延期"),
        ("任务", DEEP_GRN, "确认三个核心问题"),
    ]
    for i, (label, color, text) in enumerate(cards):
        cy = cdtop + i * 100
        draw.rectangle([cl, cy, cr3, cy + 86], fill=CARD_BG + (200,), outline=(222, 218, 210))
        draw.rectangle([cl, cy, cl + 6, cy + 86], fill=color)
        draw.ellipse([cl + 20, cy + 10, cl + 34, cy + 24], fill=color)
        draw.text((cl + 42, cy + 6), label, fill=color, font=ff("zh", 22))
        draw.text((cl + 20, cy + 40), text, fill=GRAPHITE, font=ff("zh", 26))

    btop = cdtop + 3 * 100 + 20
    draw.rounded_rectangle([cl, btop, cr3, btop + 66], radius=14, fill=CINNABAR)
    draw.text((cl + (cr3 - cl) // 2 - 64, btop + 14), "整理成卡片", fill=(255, 252, 245),
              font=ff("zh", 28))
    draw.rounded_rectangle([pcx - 96, sb2 - 28, pcx + 96, sb2 - 14], radius=5, fill=(110, 108, 102))

    # ── Right typography ───────────────────────────────────────────
    rx = 1680

    # Seal
    scx, scy, ss = W - 360, 320, 100
    draw.rectangle([scx - ss, scy - ss, scx + ss, scy + ss], outline=CINNABAR + (180,), width=5)
    draw.rectangle([scx - ss + 10, scy - ss + 10, scx + ss - 10, scy + ss - 10],
                   outline=CINNABAR + (100,), width=2)
    draw.text((scx - 68, scy - 42), "明思", fill=CINNABAR + (200,), font=ff("zh", 72))
    draw.text((scx - 74, scy + ss + 16), "M I N G S I", fill=MID_GRAY + (150,),
              font=ff("GeistMono-Regular.ttf", 16))

    # Title
    draw.text((rx, 380), "明思", fill=GRAPHITE, font=ff("zh", 144))
    draw.text((rx, 555), "MingSi", fill=MID_GRAY, font=ff("InstrumentSans-Regular.ttf", 60))
    draw.line([(rx, 660), (rx + 110, 660)], fill=CINNABAR, width=5)
    draw.text((rx, 700), "把事情想清楚。", fill=GRAPHITE, font=ff("zh", 52))

    # Cycle
    cy_top = 830
    cycle = [("Clarify", "澄清"), ("Challenge", "质疑"), ("Choose", "选择"), ("Act", "行动"), ("Calibrate", "校准")]
    sp = 290
    for i, (en, zh) in enumerate(cycle):
        x = rx + i * sp
        draw.text((x, cy_top), en, fill=GRAPHITE, font=ff("GeistMono-Regular.ttf", 28))
        draw.text((x, cy_top + 38), zh, fill=MID_GRAY, font=ff("zh", 22))
        if i < 4:
            ax = x + len(en) * 17 + 18
            draw.text((ax, cy_top - 4), "->", fill=CINNABAR, font=ff("GeistMono-Bold.ttf", 28))

    # Description
    dt = 960
    lines = [
        "明思是一个帮用户把每天的事情想清楚的个人复盘系统。",
        "",
        "不是日记，不是 Todo，不是 AI 聊天。",
        "是一个训练判断力的闭环。",
        "",
        "用户输入每天发生的事、想法、困惑。",
        "AI 整理成卡片、追问、提供视角。",
        "用户确认、判断、行动、第二天验证。",
    ]
    for i, line in enumerate(lines):
        draw.text((rx, dt + i * 46), line, fill=GRAPHITE, font=ff("zh", 28))

    # Feature list
    ft = dt + len(lines) * 46 + 56
    feats = [
        ("--", DEEP_GRN, "今日复盘"), ("--", CINNABAR, "思考卡片"), ("--", INDIGO, "思考透镜"),
        ("--", AMBER, "深度追问"), ("--", DEEP_GRN, "次日验证"), ("--", MID_GRAY, "历史证据"),
    ]
    for i, (dot, color, label) in enumerate(feats):
        col, row = i % 3, i // 3
        fx = rx + col * 340
        fy = ft + row * 44
        draw.text((fx, fy), dot, fill=color, font=ff("GeistMono-Regular.ttf", 22))
        draw.text((fx + 30, fy), label, fill=GRAPHITE, font=ff("zh", 22))

    # Bottom
    draw.text((rx, H - 140), "iOS  /  SwiftUI  /  本地存储  /  开源", fill=LIGHT_GRAY,
              font=ff("GeistMono-Regular.ttf", 24))
    draw.line([(W - 80, 100), (W - 80, H - 100)], fill=BORDER + (50,), width=1)

    img.convert("RGB").save(f"{OUT}/00-cover-readme.png", "PNG", dpi=(300, 300))
    print(f"Cover: {W}x{H}")


# ═══════════════════════════════════════════════════════════════════
# App Screens (2x = 1080x1920)
# ═══════════════════════════════════════════════════════════════════
def _screen(W: int = 1080, H: int = 1920):
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    draw = ImageDraw.Draw(img)
    paper_tex(draw, W, H)
    pad = 56
    sl, st, sr, sb = pad + 50, pad + 90, W - pad - 50, H - pad - 50
    return img, draw, sl, st, sr, sb


def create_today_review() -> None:
    W, H = 1080, 1920
    img, draw, sl, st, sr, sb = _screen(W, H)

    draw.text((sl, st), "2026.05.31", fill=MID_GRAY, font=ff("GeistMono-Regular.ttf", 22))
    draw.text((sl, st + 38), "今日复盘", fill=GRAPHITE, font=ff("zh", 44))
    draw.line([(sl, st + 102), (sl + 80, st + 102)], fill=CINNABAR, width=3)

    itop = st + 130
    ih = 380
    draw.rectangle([sl, itop, sr, itop + ih], fill=INPUT_BG + (180,), outline=(210, 205, 195, 150))
    ilines = [
        "今天和客户开了需求评审会，发现",
        "他们对核心功能的预期和我理解的",
        "有偏差。会后整理了三个必须确认",
        "的问题。",
        "",
        "另外，技术方案的 deadline 可能",
        "要延期一周，原因是第三方接口文",
        "档不完整...",
    ]
    for i, line in enumerate(ilines):
        draw.text((sl + 24, itop + 24 + i * 40), line, fill=GRAPHITE, font=ff("zh", 26))

    ctop = itop + ih + 40
    draw.text((sl, ctop), "已识别", fill=MID_GRAY, font=ff("zh", 22))
    cards = [
        ("事实", LIGHT_GRAY, "客户预期与理解存在三处偏差"),
        ("风险", CINNABAR, "第三方接口文档不完整，deadline 或延期"),
        ("任务", DEEP_GRN, "确认三个核心功能问题并同步客户"),
    ]
    for i, (label, color, text) in enumerate(cards):
        cy = ctop + 40 + i * 110
        draw.rectangle([sl, cy, sr, cy + 94], fill=CARD_BG + (200,), outline=(225, 220, 212))
        draw.rectangle([sl, cy, sl + 6, cy + 94], fill=color)
        draw.ellipse([sl + 22, cy + 14, sl + 36, cy + 28], fill=color)
        draw.text((sl + 46, cy + 8), label, fill=color, font=ff("zh", 22))
        draw.text((sl + 22, cy + 44), text, fill=GRAPHITE, font=ff("zh", 26))

    btn_y = ctop + 40 + 3 * 110 + 28
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 76], radius=14, fill=CINNABAR)
    draw.text(((sl + sr) // 2 - 72, btn_y + 16), "整理成卡片", fill=(255, 252, 245),
              font=ff("zh", 28))

    draw.text((sl, sb - 28), "clarify -> challenge -> choose -> act -> calibrate",
              fill=LIGHT_GRAY, font=ff("GeistMono-Regular.ttf", 16))

    img.convert("RGB").save(f"{OUT}/01-today-review.png", "PNG", dpi=(300, 300))
    print(f"Today review: {W}x{H}")


def create_thinking_cards() -> None:
    W, H = 1080, 1920
    img, draw, sl, st, sr, sb = _screen(W, H)

    draw.text((sl, st), "思考卡片", fill=GRAPHITE, font=ff("zh", 42))
    draw.text((sl, st + 56), "5 张卡片  /  已确认 2 张", fill=MID_GRAY, font=ff("zh", 22))
    draw.line([(sl, st + 92), (sl + 80, st + 92)], fill=CINNABAR, width=3)

    cards = [
        ("事实", LIGHT_GRAY, "客户预期与产品规划存在三处关键偏差", "V"),
        ("风险", CINNABAR, "第三方接口文档缺失，项目 deadline 可能延期一周", ""),
        ("任务", DEEP_GRN, "本周内向客户发送三份确认问题清单", "V"),
        ("问题", INDIGO, "如果 deadline 延期，哪些功能可以并行推进？", ""),
        ("想法", AMBER, "或许应该在下一次迭代前做一次内部对齐", ""),
    ]
    ctop = st + 120
    for i, (label, color, text, confirmed) in enumerate(cards):
        cy = ctop + i * 148
        draw.rectangle([sl, cy, sr, cy + 132], fill=CARD_BG + (200,), outline=(225, 220, 212))
        draw.rectangle([sl, cy, sl + 6, cy + 132], fill=color)
        draw.text((sl + 28, cy + 14), label, fill=color, font=ff("zh", 22))
        draw.text((sl + 28, cy + 50), text, fill=GRAPHITE, font=ff("zh", 26))
        if confirmed:
            draw.text((sr - 60, cy + 14), "[v]", fill=DEEP_GRN, font=ff("GeistMono-Regular.ttf", 22))
        else:
            draw.text((sr - 60, cy + 14), "[ ]", fill=LIGHT_GRAY, font=ff("GeistMono-Regular.ttf", 22))

    btn_y = ctop + 5 * 148 + 28
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 76], radius=14, fill=GRAPHITE)
    draw.text(((sl + sr) // 2 - 56, btn_y + 16), "继续追问", fill=(255, 252, 245),
              font=ff("zh", 28))

    img.convert("RGB").save(f"{OUT}/02-thinking-cards.png", "PNG", dpi=(300, 300))
    print(f"Thinking cards: {W}x{H}")


def create_lens_selection() -> None:
    W, H = 1080, 1920
    img, draw, sl, st, sr, sb = _screen(W, H)

    draw.text((sl, st), "选择透镜", fill=GRAPHITE, font=ff("zh", 42))
    draw.text((sl, st + 56), "用不同角度审视今天的判断", fill=MID_GRAY, font=ff("zh", 24))
    draw.line([(sl, st + 96), (sl + 80, st + 96)], fill=CINNABAR, width=3)

    lenses = [
        ("[1]", "证据校验", "检验每个判断是否有充分的事实支撑", True),
        ("[2]", "反方视角", "站在对立面审视你的推理链条", False),
        ("[3]", "杠杆分析", "找到投入产出比最高的行动方向", False),
    ]
    ltop = st + 136
    for i, (icon, name, desc, sel) in enumerate(lenses):
        cy = ltop + i * 200
        bc = CINNABAR if sel else (225, 220, 212)
        bg = (252, 244, 240, 200) if sel else CARD_BG + (200,)
        draw.rectangle([sl, cy, sr, cy + 172], fill=bg, outline=bc, width=3 if sel else 1)
        if sel:
            draw.rectangle([sl, cy, sl + 6, cy + 172], fill=CINNABAR)
        # Icon circle
        draw.ellipse([sl + 36, cy + 36, sl + 108, cy + 108], outline=MID_GRAY, width=2)
        draw.text((sl + 48, cy + 52), icon, fill=GRAPHITE, font=ff("GeistMono-Bold.ttf", 28))
        draw.text((sl + 136, cy + 40), name, fill=GRAPHITE, font=ff("zh", 30))
        draw.text((sl + 136, cy + 86), desc, fill=MID_GRAY, font=ff("zh", 22))
        if sel:
            draw.text((sr - 60, cy + 66), "<--", fill=CINNABAR, font=ff("GeistMono-Regular.ttf", 22))

    btn_y = ltop + 3 * 200 + 40
    draw.rounded_rectangle([sl, btn_y, sr, btn_y + 76], radius=14, fill=CINNABAR)
    draw.text(((sl + sr) // 2 - 56, btn_y + 16), "开始审视", fill=(255, 252, 245),
              font=ff("zh", 28))
    draw.text((sl, btn_y + 100), "未来支持自定义透镜 / Lens Pack", fill=LIGHT_GRAY,
              font=ff("zh", 20))

    img.convert("RGB").save(f"{OUT}/03-lens-selection.png", "PNG", dpi=(300, 300))
    print(f"Lens selection: {W}x{H}")


def create_history_evidence() -> None:
    W, H = 1080, 1920
    img, draw, sl, st, sr, sb = _screen(W, H)

    draw.text((sl, st), "历史证据", fill=GRAPHITE, font=ff("zh", 42))
    draw.text((sl, st + 56), "<< 2026 年 5 月 >>", fill=MID_GRAY, font=ff("zh", 24))
    draw.line([(sl, st + 96), (sl + 80, st + 96)], fill=CINNABAR, width=3)

    entries = [
        ("5月30日 周六", "3 卡片 / 1 任务", "已完成", DEEP_GRN, True, [
            ("事实", LIGHT_GRAY, "客户反馈了四个关键需求变更"),
            ("任务", DEEP_GRN, "整理变更影响评估报告"),
        ]),
        ("5月29日 周五", "5 卡片 / 2 任务", "部分完成", AMBER, False, []),
        ("5月28日 周四", "4 卡片 / 1 任务", "已完成", DEEP_GRN, False, []),
        ("5月27日 周三", "2 卡片 / 1 任务", "未验证", LIGHT_GRAY, False, []),
        ("5月26日 周二", "6 卡片 / 2 任务", "已完成", DEEP_GRN, True, [
            ("风险", CINNABAR, "上游依赖方可能无法按时交付"),
            ("想法", AMBER, "考虑引入备选供应商作为 Plan B"),
        ]),
    ]

    y = st + 130
    for date, meta, status, sc, expanded, cards in entries:
        draw.text((sl, y), date, fill=GRAPHITE, font=ff("zh", 24))
        draw.text((sl + 230, y + 2), meta, fill=MID_GRAY, font=ff("GeistMono-Regular.ttf", 18))
        draw.ellipse([sr - 130, y + 6, sr - 116, y + 20], fill=sc)
        draw.text((sr - 110, y), status, fill=sc, font=ff("zh", 20))
        y += 40
        if expanded:
            for ctype, ccolor, ctext in cards:
                draw.rectangle([sl + 20, y, sr, y + 68], fill=CARD_BG + (180,), outline=(225, 220, 212))
                draw.rectangle([sl + 20, y, sl + 28, y + 68], fill=ccolor)
                draw.text((sl + 42, y + 8), ctype, fill=ccolor, font=ff("GeistMono-Regular.ttf", 18))
                draw.text((sl + 42, y + 36), ctext, fill=GRAPHITE, font=ff("zh", 22))
                y += 78
        draw.line([(sl, y + 6), (sr, y + 6)], fill=(225, 220, 212))
        y += 24

    img.convert("RGB").save(f"{OUT}/04-history-evidence.png", "PNG", dpi=(300, 300))
    print(f"History evidence: {W}x{H}")


if __name__ == "__main__":
    print("Generating 2x retina images with Hiragino Sans GB...")
    create_cover()
    create_today_review()
    create_thinking_cards()
    create_lens_selection()
    create_history_evidence()
    print("\nDone. All images regenerated at 2x resolution.")
