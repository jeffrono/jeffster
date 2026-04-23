#!/usr/bin/env python3
"""
Generate jeffster-demo.gif — a simulated Windows XP cmd.exe session
running Jeffster.pl (the interactive FreeDB picker).

Transcript: three randomly-drawn artists from masterArtistList.csv
(Love, Mantronix, Ween), picking 4 real albums that would have been
returnable from FreeDB in early 2002, then 'D' to download.

Output: jeffster-demo.gif (720x450, palette-optimized GIF)
"""

from PIL import Image, ImageDraw, ImageFont
import os

# ------------------------------------------------------------------ config
# Render at 1.67x the web display size — sharp enough to look crisp after
# browser downscaling, but small enough to keep the GIF under ~3 MB.
W, H = 1200, 750
TITLE_H = 40
BODY_TOP = TITLE_H + 2
PAD_X, PAD_Y = 16, 10
FONT_PATH = "/System/Library/Fonts/Supplemental/Courier New.ttf"
FONT_PATH_BOLD = "/System/Library/Fonts/Supplemental/Courier New Bold.ttf"
FONT_PATH_UI = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_PATH_UI_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_SIZE = 20
LINE_H = 24
MAX_COLS = 80

INK = (200, 200, 200)          # classic cmd foreground
BG = (0, 0, 0)
TITLE_BG_1 = (10, 36, 106)     # XP title gradient left
TITLE_BG_2 = (31, 81, 141)     # XP title gradient right
TITLE_INK = (255, 255, 255)
CURSOR = (200, 200, 200)
STAR_RED = (255, 70, 70)
HI = (255, 255, 255)

font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
font_bold = ImageFont.truetype(FONT_PATH_BOLD, FONT_SIZE)
font_ui = ImageFont.truetype(FONT_PATH_UI_BOLD, 16)

# Measure char width
bbox = font.getbbox("M")
CHAR_W = bbox[2] - bbox[0]

# ------------------------------------------------------------------ terminal
class Terminal:
    def __init__(self):
        # buffer is a list of (text, style) lines; style ∈ {'', 'hi', 'star', 'cyan'}
        self.buffer = []
        self.partial = ""            # current typed input on partial line (appended after last line)
        self.partial_row = None      # the row index (in buffer) being typed onto (None → new row)
        self.show_cursor = True
        self.max_visible = (H - BODY_TOP - PAD_Y * 2) // LINE_H

    def println(self, text="", style=""):
        """Append a full line (output from the program)."""
        # first commit any partial input onto the current last line
        self._commit_partial_to_line()
        # handle embedded newlines by splitting
        for line in text.split("\n"):
            self.buffer.append((line, style))

    def append_to_last(self, text, style=""):
        """Append text to end of the last buffered line (e.g., after a prompt)."""
        if not self.buffer:
            self.buffer.append(("", style))
        last_text, last_style = self.buffer[-1]
        self.buffer[-1] = (last_text + text, last_style)

    def type_char(self, ch):
        """User typed a character — append to the partial (which becomes part of current last line)."""
        self.partial += ch

    def commit_enter(self):
        """User pressed Enter — commit the partial input and move to next line."""
        self._commit_partial_to_line()

    def _commit_partial_to_line(self):
        if self.partial:
            self.append_to_last(self.partial)
            self.partial = ""

    def set_last_style(self, style):
        t, _ = self.buffer[-1]
        self.buffer[-1] = (t, style)

    def prepend_marker_to_row(self, row_index, marker):
        """Prepend a marker string to an earlier row — used for '**** JUST ADDED *****'."""
        t, s = self.buffer[row_index]
        self.buffer[row_index] = (marker + t, "star")

    def render(self):
        img = Image.new("RGB", (W, H), BG)
        d = ImageDraw.Draw(img)

        # Title bar with gradient
        for x in range(W):
            ratio = x / W
            r = int(TITLE_BG_1[0] + (TITLE_BG_2[0] - TITLE_BG_1[0]) * ratio)
            g = int(TITLE_BG_1[1] + (TITLE_BG_2[1] - TITLE_BG_1[1]) * ratio)
            b = int(TITLE_BG_1[2] + (TITLE_BG_2[2] - TITLE_BG_1[2]) * ratio)
            d.line([(x, 0), (x, TITLE_H)], fill=(r, g, b))

        # Title text
        title = "C:\\WINDOWS\\system32\\cmd.exe - perl Jeffster.pl"
        d.text((12, 10), title, fill=TITLE_INK, font=font_ui)

        # Pseudo min/max/close buttons (far right)
        btn_w, btn_h, btn_gap = 30, 26, 4
        bx = W - 3 * (btn_w + btn_gap) - 4
        for i, col in enumerate([(200, 200, 210), (200, 200, 210), (230, 100, 100)]):
            d.rectangle([bx + i*(btn_w+btn_gap), 7, bx + i*(btn_w+btn_gap) + btn_w, 7 + btn_h],
                        fill=col, outline=(80, 80, 90))

        # Thin client-area border
        d.line([(0, TITLE_H), (W, TITLE_H)], fill=(150, 150, 150))
        d.line([(0, TITLE_H+1), (W, TITLE_H+1)], fill=(150, 150, 150))

        # Body: draw the last max_visible lines (scroll up)
        # If a partial is in progress, treat it as appended after the buffer's last line
        display_lines = list(self.buffer)
        if self.partial and display_lines:
            last_text, last_style = display_lines[-1]
            display_lines[-1] = (last_text + self.partial, last_style)

        visible = display_lines[-self.max_visible:]
        y = BODY_TOP + PAD_Y

        for text, style in visible:
            if style == "star":
                # The "**** JUST ADDED *****" lines: render the marker segment in red, rest normal
                # The marker looks like '**** JUST ADDED *****  ' at the start
                if text.startswith("**** JUST ADDED *****"):
                    head = "**** JUST ADDED *****  "
                    tail = text[len(head):] if text.startswith(head) else text
                    d.text((PAD_X, y), head, fill=STAR_RED, font=font_bold)
                    w = d.textlength(head, font=font_bold)
                    d.text((PAD_X + w, y), tail, fill=INK, font=font)
                else:
                    d.text((PAD_X, y), text, fill=INK, font=font)
            elif style == "hi":
                d.text((PAD_X, y), text, fill=HI, font=font_bold)
            elif style == "prompt":
                d.text((PAD_X, y), text, fill=INK, font=font)
            else:
                d.text((PAD_X, y), text, fill=INK, font=font)
            y += LINE_H

        # Cursor on the last visible line
        if self.show_cursor and visible:
            last_text, _ = visible[-1]
            cx = PAD_X + int(d.textlength(last_text, font=font))
            cy = BODY_TOP + PAD_Y + (len(visible) - 1) * LINE_H
            d.rectangle([cx, cy + 1, cx + CHAR_W - 1, cy + LINE_H - 2], fill=CURSOR)

        return img


# ------------------------------------------------------------------ animation
frames = []

def snap(term, ms):
    frames.append((term.render(), ms))

def emit_line(term, text="", style="", dwell=90):
    term.println(text, style)
    snap(term, dwell)

def type_user(term, text, per_char=70, final_hold=250):
    for ch in text:
        term.type_char(ch)
        snap(term, per_char)
    snap(term, final_hold)
    term.commit_enter()

def hold(term, ms):
    snap(term, ms)

# ------------------------------------------------------------------ session

term = Terminal()

# cmd shell banner
emit_line(term, "Microsoft Windows XP [Version 5.1.2600]", dwell=60)
emit_line(term, "(C) Copyright 1985-2001 Microsoft Corp.", dwell=60)
emit_line(term, "", dwell=40)
emit_line(term, "C:\\Jeffster>", dwell=200)
term.append_to_last("perl Jeffster.pl")
snap(term, 300)
term.commit_enter()
emit_line(term, "", dwell=350)

# --- ARTIST 1: love ---
emit_line(term, "Please enter artist name,", dwell=80)
emit_line(term, "...OR press D to begin downloading albums: ", dwell=300)
type_user(term, "love", per_char=80, final_hold=500)

emit_line(term, "", dwell=70)
emit_line(term, "Listing results 1 to 16 (of 47):", dwell=250)
emit_line(term, "", dwell=80)

love_results = [
    "1) 11 Tracks - Love - Forever Changes",
    "2) 7 Tracks - Love - Da Capo",
    "3) 14 Tracks - Love - Love",
    "4) 11 Tracks - Love - Four Sail",
    "5) 16 Tracks - Love - Out Here",
    "6) 12 Tracks - Love - False Start",
    "7) 10 Tracks - Love & Rockets - Express",
    "8) 11 Tracks - Love & Rockets - Earth, Sun, Moon",
    "9) 13 Tracks - Love Spit Love - Trysome Eatone",
    "10) 14 Tracks - Love Battery - Far Gone",
    "11) 12 Tracks - Loveless - Gift to the World",
    "12) 10 Tracks - Loverboy - Get Lucky",
    "13) 13 Tracks - Lovin' Spoonful - Anthology",
    "14) 11 Tracks - Lovage - Music to Make Love...",
    "15) 14 Tracks - Love Tractor - Themes From...",
    "16) 10 Tracks - Love Tambourines - Alive",
]
for row in love_results:
    emit_line(term, row, dwell=55)
emit_line(term, "", dwell=60)
emit_line(term, "Type the number of the album you want,", dwell=70)
emit_line(term, "...OR press ENTER for next page of results,", dwell=70)
emit_line(term, "...OR press A if done with this artist", dwell=70)
emit_line(term, "...OR press D to begin download: ", dwell=350)
type_user(term, "1", per_char=90, final_hold=500)

# redraw with **** JUST ADDED ***** on row 1
emit_line(term, "", dwell=70)
emit_line(term, "Listing results 1 to 16 (of 47):", dwell=180)
emit_line(term, "", dwell=50)
# just show the first 3 rows with the marker, rest elided for pacing
row1_idx_before = len(term.buffer)
emit_line(term, "1) 11 Tracks - Love - Forever Changes", dwell=40)
# after the line is added, prepend the marker
term.prepend_marker_to_row(row1_idx_before, "**** JUST ADDED *****  ")
snap(term, 320)
emit_line(term, "2) 7 Tracks - Love - Da Capo", dwell=40)
emit_line(term, "3) 14 Tracks - Love - Love", dwell=40)
emit_line(term, "... [13 more] ...", style="", dwell=50)
emit_line(term, "", dwell=50)
emit_line(term, "Type the number of the album you want,", dwell=60)
emit_line(term, "...OR press ENTER for next page of results,", dwell=60)
emit_line(term, "...OR press A if done with this artist", dwell=60)
emit_line(term, "...OR press D to begin download: ", dwell=300)
type_user(term, "A", per_char=120, final_hold=500)

# --- ARTIST 2: mantronix ---
emit_line(term, "", dwell=60)
emit_line(term, "Please enter artist name,", dwell=70)
emit_line(term, "...OR press D to begin downloading albums: ", dwell=250)
type_user(term, "mantronix", per_char=75, final_hold=500)
emit_line(term, "", dwell=60)
emit_line(term, "Listing results 1 to 16 (of 14):", dwell=220)
emit_line(term, "", dwell=60)
mantronix_results = [
    "1) 8 Tracks - Mantronix - The Album",
    "2) 8 Tracks - Mantronix - Music Madness",
    "3) 10 Tracks - Mantronix - In Full Effect",
    "4) 10 Tracks - Mantronix - This Should Move Ya",
    "5) 12 Tracks - Mantronix - The Incredible Sound...",
    "6) 14 Tracks - Mantronix - That's My Beat",
    "7) 10 Tracks - Mantronix - Tribute",
    "8) 9 Tracks - Mantronix - King of the Beats",
]
for row in mantronix_results:
    emit_line(term, row, dwell=55)
emit_line(term, "", dwell=50)
emit_line(term, "Type the number of the album you want,", dwell=60)
emit_line(term, "...OR press ENTER for next page of results,", dwell=60)
emit_line(term, "...OR press A if done with this artist", dwell=60)
emit_line(term, "...OR press D to begin download: ", dwell=300)
type_user(term, "1", per_char=90, final_hold=500)

# abbreviated redraw
emit_line(term, "", dwell=60)
emit_line(term, "Listing results 1 to 16 (of 14):", dwell=160)
emit_line(term, "", dwell=40)
row1_idx = len(term.buffer)
emit_line(term, "1) 8 Tracks - Mantronix - The Album", dwell=30)
term.prepend_marker_to_row(row1_idx, "**** JUST ADDED *****  ")
snap(term, 300)
emit_line(term, "2) 8 Tracks - Mantronix - Music Madness", dwell=30)
emit_line(term, "... [more] ...", dwell=40)
emit_line(term, "", dwell=40)
emit_line(term, "...OR press D to begin download: ", dwell=250)
type_user(term, "A", per_char=120, final_hold=400)

# --- ARTIST 3: ween ---
emit_line(term, "", dwell=60)
emit_line(term, "Please enter artist name,", dwell=70)
emit_line(term, "...OR press D to begin downloading albums: ", dwell=250)
type_user(term, "ween", per_char=80, final_hold=500)
emit_line(term, "", dwell=60)
emit_line(term, "Listing results 1 to 16 (of 38):", dwell=220)
emit_line(term, "", dwell=60)
ween_results = [
    "1) 26 Tracks - Ween - GodWeenSatan: The Oneness",
    "2) 23 Tracks - Ween - The Pod",
    "3) 16 Tracks - Ween - Chocolate and Cheese",
    "4) 19 Tracks - Ween - Pure Guava",
    "5) 10 Tracks - Ween - 12 Golden Country Greats",
    "6) 14 Tracks - Ween - The Mollusk",
    "7) 12 Tracks - Ween - White Pepper",
    "8) 21 Tracks - Ween - Paintin' the Town Brown",
]
for row in ween_results:
    emit_line(term, row, dwell=55)
emit_line(term, "", dwell=50)
emit_line(term, "...OR press D to begin download: ", dwell=300)
type_user(term, "3", per_char=90, final_hold=500)

# abbreviated redraw with marker on row 3
emit_line(term, "", dwell=60)
emit_line(term, "Listing results 1 to 16 (of 38):", dwell=160)
emit_line(term, "", dwell=40)
emit_line(term, "1) 26 Tracks - Ween - GodWeenSatan: The Oneness", dwell=30)
emit_line(term, "2) 23 Tracks - Ween - The Pod", dwell=30)
row3_idx = len(term.buffer)
emit_line(term, "3) 16 Tracks - Ween - Chocolate and Cheese", dwell=30)
term.prepend_marker_to_row(row3_idx, "**** JUST ADDED *****  ")
snap(term, 280)
emit_line(term, "... [more] ...", dwell=40)
emit_line(term, "", dwell=40)
emit_line(term, "...OR press D to begin download: ", dwell=250)
type_user(term, "6", per_char=90, final_hold=500)

# another redraw with marker on 6
emit_line(term, "", dwell=60)
emit_line(term, "Listing results 1 to 16 (of 38):", dwell=150)
emit_line(term, "", dwell=40)
emit_line(term, "... [rows 1-5] ...", dwell=30)
row6_idx = len(term.buffer)
emit_line(term, "6) 14 Tracks - Ween - The Mollusk", dwell=30)
term.prepend_marker_to_row(row6_idx, "**** JUST ADDED *****  ")
snap(term, 280)
emit_line(term, "... [more] ...", dwell=40)
emit_line(term, "", dwell=40)
emit_line(term, "...OR press D to begin download: ", dwell=250)
type_user(term, "A", per_char=120, final_hold=400)

# --- D for download ---
emit_line(term, "", dwell=60)
emit_line(term, "Please enter artist name,", dwell=70)
emit_line(term, "...OR press D to begin downloading albums: ", dwell=250)
type_user(term, "D", per_char=120, final_hold=600)

# configVals output
emit_line(term, "C:\\Jeffster\\", dwell=60)
emit_line(term, "G:\\MP3s\\", dwell=60)
emit_line(term, "G:\\shared\\", dwell=60)
emit_line(term, "307908cbb6fff10bf0083932a95aeb4a", dwell=200)
emit_line(term, "", dwell=50)

# --- DOWNLOAD: Love - Forever Changes ---
emit_line(term, "Downloading Love - Forever Changes...", dwell=200)
emit_line(term, "", dwell=60)
fc_tracks = [
    ("Alone Again Or", 4),
    ("A House Is Not a Motel", 4),
    ("Andmoreagain", 3),
    ("The Daily Planet", 4),
    ("Old Man", 4),
    ("The Red Telephone", 3),
    ("Maybe the People Would Be the Times", 4),
    ("Live and Let Live", 4),
]
for name, rank in fc_tracks:
    emit_line(term, f"Love - {name}.mp3: {rank}", dwell=160)
emit_line(term, "(8 of 11)", dwell=200)
emit_line(term, "Transferring: 4 -- Processing: 2 -- Busy: 0 -- Offline: 2", dwell=300)
emit_line(term, "G:\\MP3s\\!Love - Forever Changes (8 of 11)\\", dwell=350)
emit_line(term, "", dwell=60)

# --- DOWNLOAD: Mantronix - The Album ---
emit_line(term, "Downloading Mantronix - The Album...", dwell=200)
emit_line(term, "", dwell=60)
mx_tracks = [
    ("Fresh Is the Word", 4),
    ("Ladies", 3),
    ("Bassline", 4),
    ("Hardcore Hip-Hop", 4),
    ("Mega-Mix", 4),
    ("Needle to the Groove", 3),
]
for name, rank in mx_tracks:
    emit_line(term, f"Mantronix - {name}.mp3: {rank}", dwell=140)
emit_line(term, "(6 of 8)", dwell=200)
emit_line(term, "Transferring: 3 -- Processing: 1 -- Busy: 1 -- Offline: 2", dwell=250)
emit_line(term, "G:\\MP3s\\!Mantronix - The Album (6 of 8)\\", dwell=300)
emit_line(term, "", dwell=60)

# --- DOWNLOAD: Ween - Chocolate and Cheese ---
emit_line(term, "Downloading Ween - Chocolate and Cheese...", dwell=200)
emit_line(term, "", dwell=50)
cc_tracks = [
    ("Take Me Away", 4),
    ("Spinal Meningitis", 3),
    ("Freedom of '76", 4),
    ("I Can't Put My Finger on It", 4),
]
for name, rank in cc_tracks:
    emit_line(term, f"Ween - {name}.mp3: {rank}", dwell=130)
emit_line(term, "...", dwell=180)
emit_line(term, "(13 of 16)", dwell=200)
emit_line(term, "Transferring: 5 -- Processing: 2 -- Busy: 1 -- Offline: 3", dwell=250)
emit_line(term, "G:\\MP3s\\!Ween - Chocolate and Cheese (13 of 16)\\", dwell=300)
emit_line(term, "", dwell=60)

# --- DOWNLOAD: Ween - The Mollusk ---
emit_line(term, "Downloading Ween - The Mollusk...", dwell=180)
emit_line(term, "", dwell=50)
mol_tracks = [
    ("I'm Dancing in the Show Tonight", 4),
    ("The Mollusk", 4),
    ("Mutilated Lips", 4),
    ("Ocean Man", 4),
]
for name, rank in mol_tracks:
    emit_line(term, f"Ween - {name}.mp3: {rank}", dwell=130)
emit_line(term, "...", dwell=180)
emit_line(term, "(12 of 14)", dwell=200)
emit_line(term, "Transferring: 4 -- Processing: 1 -- Busy: 0 -- Offline: 2", dwell=250)
emit_line(term, "G:\\MP3s\\!Ween - The Mollusk (12 of 14)\\", dwell=400)

# final cursor dwell
hold(term, 1500)

# ------------------------------------------------------------------ save GIF
print(f"Generated {len(frames)} frames")

images = [f[0] for f in frames]
durations = [f[1] for f in frames]

# Build a shared palette by sampling a handful of frames that cover every
# color the session produces (title bar gradient, antialiased grays on text,
# the red star marker). Using multiple representative frames gives Pillow's
# ADAPTIVE quantizer the full color range to build a 64-color palette from.
# 64 colors gives antialiased glyph edges enough gray shades to stay crisp.
sample_indices = [
    0,                        # cmd banner
    len(images) // 10,        # mid typing
    len(images) // 3,         # first listing with text
    len(images) // 2,         # mid redraw with red marker
    (len(images) * 2) // 3,   # ween section
    len(images) - 20,         # download phase
]
# Stack sample frames vertically into a single palette-source image
sample_imgs = [images[i] for i in sample_indices if i < len(images)]
if sample_imgs:
    palette_src = Image.new("RGB", (W, H * len(sample_imgs)))
    for i, im in enumerate(sample_imgs):
        palette_src.paste(im, (0, i * H))
    master = palette_src.convert("P", palette=Image.ADAPTIVE, colors=64)
else:
    master = images[0].convert("P", palette=Image.ADAPTIVE, colors=64)
images_p = [im.quantize(palette=master, dither=Image.Dither.NONE) for im in images]

out = "jeffster-demo.gif"
# disposal=1 ("do not dispose") lets the GIF encoder store only the
# dirty rectangle for each frame relative to the previous frame —
# massive savings during typing animations since only a few pixels change
# per frame. optimize=True tells Pillow to compute that dirty rectangle.
images_p[0].save(
    out,
    save_all=True,
    append_images=images_p[1:],
    duration=durations,
    loop=0,
    optimize=True,
    disposal=1,
)
size_kb = os.path.getsize(out) / 1024
print(f"Wrote {out}: {size_kb:.1f} KB, {len(frames)} frames, ~{sum(durations)/1000:.1f}s total")
