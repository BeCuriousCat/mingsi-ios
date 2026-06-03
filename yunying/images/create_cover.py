#!/usr/bin/env python3
"""MingSi README Cover — Ink Discipline (refined master pass)."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import random

W, H = 1920, 1080
FONT_DIR = "/Users/chenzewei/.claude/skills/canvas-design/canvas-fonts"

def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(f"{FONT_DIR}/{name}", size)

# Palette
PAPER     = (245, 240, 232)
GRAPHITE  = (44, 44, 44)
CINNABAR  = (197, 75, 60)
DEEP_GRN  = (45, 106, 79)
INDIGO    = (67, 56, 202)
AMBER     = (200, 160, 60)
LIGHT_GRAY = (180, 175, 168)
MID_GRAY  = (120, 118, 112)
BORDER    = (215, 210, 202)

# ── Base layer with efficient paper texture ────────────────────────
img = Image.new("RGBA", (W, H), PAPER + (255,))
draw = ImageDraw.Draw(img)

random.seed(42)
# Efficient noise: draw small rectangles instead of pixel-by-pixel
for _ in range(12000):
    x = random.randint(0, W - 1)
    y = random.randint(0, H - 1)
    s = random.randint(1, 3)
    n = random.randint(-5, 5)
    r = max(0, min(255, PAPER[0] + n))
    g = max(0, min(255, PAPER[1] + n))
    b = max(0, min(255, PAPER[2] + n))
    draw.rectangle([x, y, x + s, y + s], fill=(r, g, b, 30))

# ── Faint ruled lines ─────────────────────────────────────────────
for y in range(0, H, 34):
    draw.line([(0, y), (W, y)], fill=(232, 228, 220, 50), width=1)

# ── Corner marks (register marks) ─────────────────────────────────
def corner_mark(x, y, dx, dy):
    draw.line([(x, y), (x, y + dy * 24)], fill=CINNABAR + (160,), width=2)
    draw.line([(x, y), (x + dx * 24, y)], fill=CINNABAR + (160,), width=2)

corner_mark(48, 48, 1, 1)
corner_mark(W - 48, 48, -1, 1)
corner_mark(48, H - 48, 1, -1)
corner_mark(W - 48, H - 48, -1, -1)

# ── Desk objects: pencils ─────────────────────────────────────────
def draw_pencil(draw, ox, oy, angle_deg, length, body_color, eraser_color):
    a = math.radians(angle_deg)
    cos_a, sin_a = math.cos(a), math.sin(a)
    # Body
    for i in range(length):
        px = ox + i * cos_a
        py = oy + i * sin_a
        shade = body_color[0] + int(i * 0.08) if body_color[0] < 200 else body_color[0]
        w = 4 if i < length - 12 else 4 - (length - 12 - i) * 0.15
        draw.ellipse([px - 3, py - w, px + 3, py + w],
                     fill=(shade, shade - 8, shade - 16, 200))
    # Tip taper
    for i in range(18):
        t = i / 18
        px = ox - i * cos_a
        py = oy - i * sin_a
        w = 3.5 * (1 - t)
        draw.ellipse([px - w, py - w, px + w, py + w],
                     fill=(int(80 + t * 80), int(70 + t * 70), int(55 + t * 55), 230))
    # Tip point
    draw.ellipse([ox - 18 * cos_a - 1, oy - 18 * sin_a - 1,
                  ox - 18 * cos_a + 1, oy - 18 * sin_a + 1],
                 fill=GRAPHITE + (240,))
    # Metal ferrule
    for i in range(10):
        mx = ox + (length - 12 + i) * cos_a
        my = oy + (length - 12 + i) * sin_a
        draw.ellipse([mx - 3.2, my - 4.2, mx + 3.2, my + 4.2],
                     fill=(195, 190, 175, 180))
    # Eraser
    ex = ox + (length + 2) * cos_a
    ey = oy + (length + 2) * sin_a
    draw.ellipse([ex - 3.5, ey - 4.5, ex + 3.5, ey + 4.5],
                 fill=eraser_color + (200,))

draw_pencil(draw, 135, 860, 12, 200, (150, 140, 130), (197, 155, 150))
draw_pencil(draw, 105, 810, 6, 160, (130, 125, 115), (180, 150, 140))
draw_pencil(draw, 250, 920, 20, 170, (170, 160, 145), (200, 165, 155))

# ── Notebook ──────────────────────────────────────────────────────
nb_x, nb_y, nb_w, nb_h = 68, 920, 280, 130
# Shadow
draw.rectangle([nb_x + 4, nb_y + 4, nb_x + nb_w + 4, nb_y + nb_h + 4],
               fill=(0, 0, 0, 15))
# Pages
draw.rectangle([nb_x, nb_y, nb_x + nb_w, nb_y + nb_h],
               fill=(252, 248, 240, 180), outline=BORDER + (100,))
draw.line([(nb_x + nb_w // 2, nb_y), (nb_x + nb_w // 2, nb_y + nb_h)],
          fill=BORDER + (80,))
# Ruled lines
for i in range(7):
    ly = nb_y + 18 + i * 14
    if ly < nb_y + nb_h - 8:
        draw.line([(nb_x + 14, ly), (nb_x + nb_w // 2 - 8, ly)],
                  fill=(175, 170, 160, 45))
        draw.line([(nb_x + nb_w // 2 + 8, ly), (nb_x + nb_w - 14, ly)],
                  fill=(175, 170, 160, 45))
# Simulated handwriting
for i in range(5):
    ly = nb_y + 20 + i * 14
    if ly < nb_y + nb_h - 10:
        l_len = random.randint(55, 95)
        r_len = random.randint(50, 85)
        draw.line([(nb_x + 18, ly), (nb_x + 18 + l_len, ly)],
                  fill=(95, 92, 85, 70), width=1)
        draw.line([(nb_x + nb_w // 2 + 14, ly), (nb_x + nb_w // 2 + 14 + r_len, ly)],
                  fill=(95, 92, 85, 70), width=1)

# ═══════════════════════════════════════════════════════════════════
# iPhone mockup
# ═══════════════════════════════════════════════════════════════════
pw, ph = 320, 660
pcx, pcy = 500, 500
pl, pt = pcx - pw // 2, pcy - ph // 2
pr, pb = pcx + pw // 2, pcy + ph // 2
cr = 46

# Multi-layer shadow for realism
for offset, blur_r, alpha in [(12, 24, 20), (8, 12, 30), (4, 6, 40)]:
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [pl + offset, pt + offset, pr + offset, pb + offset],
        radius=cr, fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur_r))
    img = Image.alpha_composite(img, sh)
draw = ImageDraw.Draw(img)

# Body
draw.rounded_rectangle([pl, pt, pr, pb], radius=cr,
                        fill=(26, 26, 28), outline=(55, 55, 58, 180), width=2)
# Side button
draw.rectangle([pr + 1, pt + 140, pr + 4, pt + 210], fill=(55, 55, 58, 160), width=0)

# Screen
sm = 6
sl, st2, sr2, sb2 = pl + sm, pt + sm, pr - sm, pb - sm
sr_ = cr - 3
draw.rounded_rectangle([sl, st2, sr2, sb2], radius=sr_, fill=(250, 246, 238))

# Dynamic Island
diw, dih = 105, 30
draw.rounded_rectangle([pcx - diw // 2, st2 + 10, pcx + diw // 2, st2 + 10 + dih],
                        radius=15, fill=(26, 26, 28))

# Status bar time
f_status = font("IBMPlexMono-Regular.ttf", 11)
draw.text((sl + 24, st2 + 16), "9:41", fill=GRAPHITE, font=f_status)

# ── Screen content ─────────────────────────────────────────────────
cpad = 22
cl = sl + cpad
cr3 = sr2 - cpad
ct = st2 + 10 + dih + 20

f_date = font("IBMPlexMono-Regular.ttf", 12)
f_scr_title = font("WorkSans-Bold.ttf", 20)
f_scr_body = font("WorkSans-Regular.ttf", 14)
f_scr_label = font("WorkSans-Regular.ttf", 11)
f_scr_btn = font("WorkSans-Bold.ttf", 15)

draw.text((cl, ct), "2026.05.31  周日", fill=MID_GRAY, font=f_date)
draw.text((cl, ct + 18), "今日复盘", fill=GRAPHITE, font=f_scr_title)

# Input area
itop = ct + 50
ih = 120
draw.rectangle([cl, itop, cr3, itop + ih],
               fill=(240, 236, 226, 160), outline=(212, 207, 197, 120))
ilines = [
    "今天和客户开了需求评审会，发现",
    "他们对核心功能的预期和我理解的",
    "有偏差。会后整理了三个必须确认",
    "的问题。技术方案 deadline 可能",
    "要延期一周..."
]
for i, line in enumerate(ilines):
    draw.text((cl + 10, itop + 10 + i * 20), line, fill=GRAPHITE, font=f_scr_body)

# Cursor blink line
draw.rectangle([cl + 10 + 170, itop + 10 + 4 * 20, cl + 10 + 171, itop + 10 + 4 * 20 + 14],
               fill=CINNABAR + (180,))

# Card previews
cdtop = itop + ih + 14
cards = [
    ("事实", LIGHT_GRAY, "客户预期与理解有偏差"),
    ("风险", CINNABAR, "deadline 可能延期"),
    ("任务", DEEP_GRN, "确认三个核心问题"),
]
for i, (label, color, text) in enumerate(cards):
    cy = cdtop + i * 52
    draw.rectangle([cl, cy, cr3, cy + 44], fill=(248, 244, 236, 200), outline=(222, 218, 210))
    draw.rectangle([cl, cy, cl + 3, cy + 44], fill=color)
    draw.ellipse([cl + 12, cy + 6, cl + 20, cy + 14], fill=color)
    draw.text((cl + 24, cy + 3), label, fill=color, font=f_scr_label)
    draw.text((cl + 12, cy + 22), text, fill=GRAPHITE, font=f_scr_body)

# Button
btop = cdtop + 3 * 52 + 10
draw.rounded_rectangle([cl, btop, cr3, btop + 36], radius=8, fill=CINNABAR)
draw.text((cl + (cr3 - cl) // 2 - 34, btop + 7), "整理成卡片", fill=(255, 252, 245), font=f_scr_btn)

# Home indicator
draw.rounded_rectangle([pcx - 52, sb2 - 16, pcx + 52, sb2 - 8], radius=3, fill=(110, 108, 102))

# ═══════════════════════════════════════════════════════════════════
# Right side typography
# ═══════════════════════════════════════════════════════════════════
rx = 840  # right content start

# Cinnabar seal stamp
scx, scy = W - 180, 160
ss = 52
draw.rectangle([scx - ss, scy - ss, scx + ss, scy + ss], outline=CINNABAR + (180,), width=3)
draw.rectangle([scx - ss + 5, scy - ss + 5, scx + ss - 5, scy + ss - 5],
               outline=CINNABAR + (100,), width=1)
f_seal = font("YoungSerif-Regular.ttf", 36)
draw.text((scx - 34, scy - 20), "明思", fill=CINNABAR + (200,), font=f_seal)
f_seal_sub = font("IBMPlexMono-Regular.ttf", 9)
draw.text((scx - 38, scy + ss + 8), "M I N G S I", fill=MID_GRAY + (150,), font=f_seal_sub)

# Main title
f_main = font("YoungSerif-Regular.ttf", 76)
draw.text((rx, 200), "明思", fill=GRAPHITE)

f_sub = font("InstrumentSans-Regular.ttf", 32)
draw.text((rx, 290), "MingSi", fill=MID_GRAY, font=f_sub)

# Divider
draw.line([(rx, 348), (rx + 60, 348)], fill=CINNABAR, width=3)

# Tagline
f_tag = font("WorkSans-Regular.ttf", 28)
draw.text((rx, 370), "把事情想清楚。", fill=GRAPHITE, font=f_tag)

# ── Cycle ──────────────────────────────────────────────────────────
cy_top = 440
f_cy_en = font("GeistMono-Regular.ttf", 15)
f_cy_zh = font("WorkSans-Regular.ttf", 12)

cycle = [("Clarify", "澄清"), ("Challenge", "质疑"), ("Choose", "选择"), ("Act", "行动"), ("Calibrate", "校准")]
cx = rx
sp = 150

for i, (en, zh) in enumerate(cycle):
    x = cx + i * sp
    draw.text((x, cy_top), en, fill=GRAPHITE, font=f_cy_en)
    draw.text((x, cy_top + 20), zh, fill=MID_GRAY, font=f_cy_zh)
    if i < 4:
        ax = x + len(en) * 9 + 10
        draw.text((ax, cy_top - 2), "→", fill=CINNABAR, font=f_cy_en)

# ── Description ───────────────────────────────────────────────────
dt = 520
f_desc = font("WorkSans-Regular.ttf", 15)
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
    draw.text((rx, dt + i * 24), line, fill=GRAPHITE, font=f_desc)

# ── Feature list ──────────────────────────────────────────────────
ft = dt + len(lines) * 24 + 32
f_feat = font("IBMPlexMono-Regular.ttf", 12)
feats = [
    ("●", DEEP_GRN, "今日复盘"), ("●", CINNABAR, "思考卡片"), ("●", INDIGO, "思考透镜"),
    ("●", AMBER, "深度追问"), ("●", DEEP_GRN, "次日验证"), ("●", MID_GRAY, "历史证据"),
]
for i, (dot, color, label) in enumerate(feats):
    col, row = i % 3, i // 3
    fx = rx + col * 175
    fy = ft + row * 24
    draw.text((fx, fy), dot, fill=color, font=f_feat)
    draw.text((fx + 14, fy), label, fill=GRAPHITE, font=f_feat)

# ── Bottom tech line ──────────────────────────────────────────────
f_bot = font("IBMPlexMono-Regular.ttf", 13)
draw.text((rx, H - 76), "iOS  /  SwiftUI  /  本地存储  /  开源", fill=LIGHT_GRAY, font=f_bot)

# ── Right edge vertical rule ──────────────────────────────────────
draw.line([(W - 48, 72), (W - 48, H - 72)], fill=BORDER + (60,), width=1)

# ═══════════════════════════════════════════════════════════════════
# Save
# ═══════════════════════════════════════════════════════════════════
out = "/Users/chenzewei/Documents/codex/2026-05-30/image-2/yunying/images/00-cover-readme.png"
img.convert("RGB").save(out, "PNG", dpi=(300, 300))
print(f"Saved: {out}  ({W}x{H})")
