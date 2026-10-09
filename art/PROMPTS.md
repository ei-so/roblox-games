# Steal a Ride: ChatGPT image prompts

19 images: 15 in-game icons, 1 game icon, 3 thumbnails. Make them in the ChatGPT app, save them, and tell Claude "art is ready".

## How to save

- Save every image into **`art/raw/`** (create the folder) using the **exact file name** given for it, as PNG.
- Don't resize or crop anything; Claude does that.
- If an image comes out with words or letters on it (except the game icon), ask ChatGPT: *"Same image, but no text."*
- If you don't like one, just regenerate it. Only the saved file counts.

---

## Part A: in-game icons (15 images, one chat)

Do all 15 in **one chat**, so they share a style.

**1. Start the chat with this message.** It sets the style; no image yet.

```
For this whole chat, every image I ask for is a single game icon for a cute Roblox game, all in one matching style:
- cute chunky toy-like 3D cartoon look, soft shading, thick clean rounded shapes, bright saturated colors
- one object only, centered, filling about 85% of a square 1024x1024 canvas
- TRANSPARENT background (PNG with alpha), no shadow on the background, no border, no frame
- absolutely no text, letters, or numbers
Reply "ready" and wait for my first icon.
```

**2. Then send these one at a time.** Save each result with the file name shown.

| # | Save as | Prompt to send |
|---|---|---|
| 1 | `ability_dash.png` | `Icon: a blue speed boot with white motion streaks and a small yellow lightning bolt.` |
| 2 | `ability_jump.png` | `Icon: a bouncy red coil spring with a big white upward arrow above it.` |
| 3 | `ability_glide.png` | `Icon: a single big white feathered wing with soft sky-blue tips.` |
| 4 | `ability_swim.png` | `Icon: a curling blue water wave with a splash droplet.` |
| 5 | `ability_fireproof.png` | `Icon: an orange flame inside a sturdy blue shield.` |
| 6 | `ability_phase.png` | `Icon: a glowing purple ghostly star passing through a swirling portal ring.` |
| 7 | `gear_net.png` | `Icon: a chunky orange toy net-launcher gun with a rolled-up net on top.` |
| 8 | `gear_trap.png` | `Icon: a slippery yellow banana peel lying on a small blue puddle.` |
| 9 | `gear_soda.png` | `Icon: a red soda can with a lightning bolt label and fizzy bubbles popping out.` |
| 10 | `rarity_common.png` | `Icon: a round medallion badge with a faceted grey stone gem in the middle.` |
| 11 | `rarity_uncommon.png` | `Icon: the same round medallion badge style, with a faceted emerald green gem.` |
| 12 | `rarity_rare.png` | `Icon: the same round medallion badge style, with a faceted sapphire blue gem.` |
| 13 | `rarity_epic.png` | `Icon: the same round medallion badge style, with a faceted amethyst purple gem.` |
| 14 | `rarity_legendary.png` | `Icon: the same round medallion badge style but golden, with a sparkling golden gem and a tiny crown on top.` |
| 15 | `rarity_mythic.png` | `Icon: the same round medallion badge style, with a glowing rainbow-pink gem and little stars around it.` |

---

## Part B: game icon + thumbnails (4 images, a new chat)

Start a **new chat** for these. Each prompt says which screenshots to **attach** from the `screenshots/` folder. Attach them in the same message as the prompt, so ChatGPT copies our real creature designs.

### 16. Game icon: save as `page_icon.png`

Attach: `screenshots/09-creatures.jpg`, `screenshots/10-guardians.jpg`

```
Make the square 1024x1024 game icon for a Roblox game called "STEAL A RIDE".
Scene: a cheeky kid riding the cute orange fox from my first reference image, holding a glowing spotted egg above their head, with the grumpy giant white rooster from my second reference image chasing right behind them.
Big bold yellow title text "STEAL A RIDE" with a thick dark outline across the top.
Style: cute chunky toy-like 3D cartoon, soft shading, bright saturated colors, bright blue sky background. Use the creature designs from my reference images.
```

### 17. Thumbnail: the heist. Save as `thumb_heist.png`

Attach: `screenshots/10-guardians.jpg`, `screenshots/03-lake.jpg`

```
Make a wide 16:9 landscape thumbnail for my Roblox game.
Scene: a player sprinting away from the grumpy giant white swan (from my first reference image) along a pebbly lakeside path, carrying a glowing spotted egg over their head, cartoon motion lines, a nest full of eggs behind them. Use the lake area from my second reference image as the setting.
Style: cute chunky toy-like 3D cartoon, soft shading, bright saturated colors, dynamic action angle. No text.
```

### 18. Thumbnail: riding. Save as `thumb_riding.png`

Attach: `screenshots/11-riding.jpg`, `screenshots/09-creatures.jpg`

```
Make a wide 16:9 landscape thumbnail for my Roblox game.
Scene: a happy player riding the cute teal baby dragon (from my first reference image) at full speed down a snowy path through a pine forest, a colorful speed trail behind them, two other players racing alongside riding a fox and a penguin from my second reference image.
Style: cute chunky toy-like 3D cartoon, soft shading, bright saturated colors, sense of speed. No text.
```

### 19. Thumbnail: Mama Dragon. Save as `thumb_mama.png`

Attach: `screenshots/12-mama-dragon.jpg`, `screenshots/01-home-row.jpg`

```
Make a wide 16:9 landscape thumbnail for my Roblox game.
Scene: a huge purple mama dragon with golden horns (from my first reference image) stomping down a grassy lane lined with colorful player bases (from my second reference image; there is no paved road), glowing red weak-spot orbs on her head and chest, a group of small players below pointing and cheering, a big red boss health bar across the top of the image. Dramatic dusk sky.
Style: cute chunky toy-like 3D cartoon, soft shading, bright saturated colors, epic boss-fight feeling. No text except the empty health bar.
```

---

## When you're done

Check `art/raw/` has 19 files, then tell Claude **"art is ready"**. Claude will:

1. Check each image. Icons without a transparent background get cut out automatically.
2. Resize them: icons to 256×256, the game icon to 512×512, thumbnails to 1920×1080.
3. Upload the 15 icons to your Roblox account and add them to the Stable cards, Index, gear hotbar, Shop and Dash button.
4. Put the game icon and thumbnails in `art/page/`, ready for you to upload in **Creator Hub → your game → Places → Thumbnails / Icon**.

Fewer than 19 is fine; Claude uses what's there, and the rest keep today's look.

---

## Rename: new game icon for "STEAL A MOUNT" (2026-10-07)

The game is renamed from Steal a Ride (name taken) to **Steal a Mount**. Thumbnails have no text, so keep them. Only redo the icon.

New chat. Attach: `screenshots/09-creatures.jpg`, `screenshots/12-mama-dragon.jpg`. Save as `raw/page_icon.png` (overwrite), then tell Claude "icon is ready".

```
Make the square 1024x1024 game icon for a Roblox game called "STEAL A MOUNT".
Scene: a cheeky kid riding the cute orange fox from my first reference image at full speed, clutching a glowing spotted egg under one arm, looking back with a grin. Right behind them, the huge Mama Dragon from my second reference image roars, wings spread.
Big bold yellow title text "STEAL A MOUNT" with a thick dark outline across the top, readable even when the icon is tiny.
Style: cute chunky toy-like 3D cartoon, soft shading, bright saturated colors, high contrast, bright blue sky background. Use the creature designs from my reference images.
```
