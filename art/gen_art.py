"""Generate Steal a Ride's 2D art with Gemini (key: GEMINI_API_KEY in ../.env).

python art/gen_art.py          # makes whatever is missing; re-run after a quota stop
Icons are drawn on a solid key color, then that color is cut out to a transparent 256x256 PNG.
"""
import base64, json, pathlib, sys, time, urllib.error, urllib.request
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent
MODEL = "gemini-3.1-flash-image"
STYLE = ("cute chunky toy-like style, bright saturated colors, soft 3D cartoon shading, thick clean shapes, "
         "Roblox game UI art")
ICON = ("A single game icon: {what}. Centered, filling most of the square, " + STYLE +
        ". On a perfectly flat solid {bg} background, no shadow on the background, no border, no text, no letters.")

GREEN, MAGENTA = ("pure green #00FF00", (0, 255, 0)), ("pure magenta #FF00FF", (255, 0, 255))
ICONS = {
    # abilities
    "ability_dash": ("a blue speed boot with white motion streaks and a small lightning bolt", MAGENTA),
    "ability_jump": ("a bouncy red coil spring with a big upward arrow", MAGENTA),
    "ability_glide": ("a single big white feathered wing with soft blue tips", MAGENTA),
    "ability_swim": ("a blue water wave with a splash droplet", MAGENTA),
    "ability_fireproof": ("an orange flame inside a sturdy blue shield", MAGENTA),
    "ability_phase": ("a glowing purple ghostly star swirling through a portal ring", GREEN),
    # gear
    "gear_net": ("a chunky orange toy net launcher gun with a rolled net", MAGENTA),
    "gear_trap": ("a slippery yellow banana peel trap on a small blue puddle", MAGENTA),
    "gear_soda": ("a red soda can with a lightning bolt label and fizz bubbles", GREEN),
    # rarity badges: a round gem medallion in the rarity color
    "rarity_common": ("a round medallion badge with a faceted grey stone gem in the middle", MAGENTA),
    "rarity_uncommon": ("a round medallion badge with a faceted emerald green gem in the middle", MAGENTA),
    "rarity_rare": ("a round medallion badge with a faceted sapphire blue gem in the middle", MAGENTA),
    "rarity_epic": ("a round medallion badge with a faceted amethyst purple gem in the middle", GREEN),
    "rarity_legendary": ("a round golden medallion badge with a sparkling golden topaz gem and a tiny crown", MAGENTA),
    "rarity_mythic": ("a round medallion badge with a glowing rainbow pink gem and little stars around it", GREEN),
}
SHOTS = ROOT.parent / "screenshots"
PAGE = {
    "page_icon": ("1:1", "The game icon for a Roblox game called STEAL A RIDE: a cheeky kid riding a cute fox, holding a "
                  "glowing egg above their head, a grumpy giant white rooster chasing behind. Big bold yellow title text "
                  "'STEAL A RIDE' with a dark outline. " + STYLE + ". Bright sky background.", ["09-creatures.jpg"]),
    "thumb_heist": ("16:9", "Roblox game thumbnail: a player sprinting away from a grumpy giant white swan by a lake, "
                    "carrying a glowing spotted egg over their head, cartoon motion lines, nest of eggs behind. " + STYLE +
                    ". Match the creature designs in the reference images.", ["10-guardians.jpg", "03-lake.jpg"]),
    "thumb_riding": ("16:9", "Roblox game thumbnail: a happy player riding a cute teal baby dragon at full speed down a "
                     "road through a snowy forest, colorful trail behind, other players riding a fox and a penguin. " + STYLE +
                     ". Match the creature designs in the reference images.", ["11-riding.jpg", "09-creatures.jpg"]),
    "thumb_mama": ("16:9", "Roblox game thumbnail: a huge purple mama dragon with golden horns stomping down a street of "
                   "colorful player bases, glowing red weak spots on her head and chest, a group of players clicking "
                   "and cheering below, a big red health bar at the top. " + STYLE +
                   ". Match the dragon design in the reference image.", ["12-mama-dragon.jpg"]),
}


def api_key():
    for line in (ROOT.parent / ".env").read_text().splitlines():
        if line.startswith("GEMINI_API_KEY="):
            return line.split("=", 1)[1].strip()
    sys.exit("GEMINI_API_KEY missing from .env")


def generate(prompt, aspect, refs=()):
    parts = [{"text": prompt}]
    for ref in refs:
        parts.append({"inlineData": {"mimeType": "image/jpeg", "data": base64.b64encode((SHOTS / ref).read_bytes()).decode()}})
    body = {"contents": [{"parts": parts}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect}}}
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(), headers={"x-goog-api-key": api_key(), "Content-Type": "application/json"})
    for attempt in range(3):
        try:
            data = json.load(urllib.request.urlopen(req, timeout=180))
            for part in data["candidates"][0]["content"]["parts"]:
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
            raise RuntimeError("no image in response: " + json.dumps(data)[:300])
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:300]
            if e.code == 429:
                sys.exit("Quota reached (429). Re-run later to finish: " + msg)
            if attempt == 2 or e.code < 500:
                raise RuntimeError(f"HTTP {e.code}: {msg}")
            time.sleep(5 * (attempt + 1))


def cut_out(png_bytes, key_rgb, out):
    """Key color -> transparent, crop to the icon, pad to a square, 256x256."""
    tmp = out.with_suffix(".raw.png")
    tmp.write_bytes(png_bytes)
    img = Image.open(tmp).convert("RGBA")
    px = img.load()
    kr, kg, kb = key_rgb
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, _ = px[x, y]
            d = abs(r - kr) + abs(g - kg) + abs(b - kb)
            if d < 120:
                px[x, y] = (r, g, b, 0)
            elif d < 220:  # soft fringe
                px[x, y] = (r, g, b, int(255 * (d - 120) / 100))
    img = img.crop(img.getbbox())
    side = int(max(img.size) * 1.08)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(img, ((side - img.width) // 2, (side - img.height) // 2), img)
    square.resize((256, 256), Image.LANCZOS).save(out)
    tmp.unlink()


def main():
    (ROOT / "icons").mkdir(exist_ok=True)
    (ROOT / "page").mkdir(exist_ok=True)
    for name, (what, (bg_text, bg_rgb)) in ICONS.items():
        out = ROOT / "icons" / f"{name}.png"
        if not out.exists():
            print("icon", name, flush=True)
            cut_out(generate(ICON.format(what=what, bg=bg_text), "1:1"), bg_rgb, out)
    for name, (aspect, prompt, refs) in PAGE.items():
        out = ROOT / "page" / f"{name}.png"
        if not out.exists():
            print("page", name, flush=True)
            raw = ROOT / "page" / f"{name}.raw.png"
            raw.write_bytes(generate(prompt, aspect, refs))
            size = (512, 512) if aspect == "1:1" else (1920, 1080)
            Image.open(raw).convert("RGB").resize(size, Image.LANCZOS).save(out)
            raw.unlink()
    print("done")


if __name__ == "__main__":
    main()
