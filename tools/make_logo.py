"""Erzeugt das Pixel-Art-Logo "Anton Brainless Productions" (assets/logos/)."""
from PIL import Image

FONT = {  # 5x7 Pixel-Font, eigene Glyphen
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    " ": ["000"] * 7,
}

BRAIN = [  # 16x14, 1 = Hirn, 2 = Furche, 3 = Leiterbahn
    "0000111101111000",
    "0011122111221100",
    "0112111121111210",
    "0121112111211110",
    "1111121112111221",
    "1211111211121111",
    "1112111121111211",
    "1111211112112111",
    "0111111211111110",
    "0011211111211100",
    "0000111111110000",
    "0000003333000000",
    "0000030000300000",
    "0000300000030000",
]

PINK, FURROW, NEON, CYAN = (230, 70, 140), (120, 20, 70), (255, 40, 120), (0, 230, 255)


def text_width(text):
    return sum(len(FONT[c][0]) + 1 for c in text) - 1


def draw_text(img, text, x, y, color, shadow=None):
    for c in text:
        glyph = FONT[c]
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    if shadow:
                        img.putpixel((x + gx + 1, y + gy + 1), shadow)
                    img.putpixel((x + gx, y + gy), color)
        x += len(glyph[0]) + 1


def main():
    lines = [("ANTON", NEON), ("BRAINLESS", NEON), ("PRODUCTIONS", CYAN)]
    width = max(text_width(t) for t, _ in lines) + 4
    height = 14 + 3 + len(lines) * 9 + 2
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    bx = (width - 16) // 2
    for y, row in enumerate(BRAIN):
        for x, v in enumerate(row):
            color = {"1": PINK, "2": FURROW, "3": CYAN}.get(v)
            if color:
                img.putpixel((bx + x, y), color + (255,))
    y = 17
    for text, color in lines:
        draw_text(img, text, (width - text_width(text)) // 2, y, color + (255,), (40, 0, 30, 255))
        y += 9
    img = img.resize((width * 8, height * 8), Image.NEAREST)
    img.save("assets/logos/anton_brainless_productions.png")
    print("logo", img.size)


if __name__ == "__main__":
    main()
