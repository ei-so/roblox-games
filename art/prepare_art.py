from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

ART = Path(__file__).resolve().parent
RAW = ART / 'raw'
ICONS = ART / 'icons'
PAGE = ART / 'page'
ICONS.mkdir(exist_ok=True)
PAGE.mkdir(exist_ok=True)
expected = [f'ability_{x}.png' for x in ('dash','jump','glide','swim','fireproof','phase')]
expected += ['gear_net.png','gear_banana.png','gear_soda.png']
expected += [f'rarity_{x}.png' for x in ('common','uncommon','rare','epic','legendary','mythic')]
expected += ['page_icon.png','thumb_heist.png','thumb_riding.png','thumb_mama.png']
missing = [name for name in expected if not (RAW / name).is_file()]
assert not missing, f'Missing art: {missing}'
for name in expected:
    with Image.open(RAW / name) as source:
        source.load()
        if name.startswith(('ability_', 'gear_', 'rarity_')):
            assert 'A' in source.getbands() and source.getchannel('A').getextrema()[0] == 0, f'No transparency: {name}'
            target = ICONS / ('gear_trap.png' if name == 'gear_banana.png' else name)
            size = (256,256)
            prepared = ImageOps.pad(source.convert('RGBA'), size, method=Image.Resampling.LANCZOS, color=(0,0,0,0))
        else:
            target = PAGE / name
            size = (512,512) if name == 'page_icon.png' else (1920,1080)
            prepared = ImageOps.fit(source.convert('RGB'), size, method=Image.Resampling.LANCZOS)
        prepared.save(target)
        with Image.open(target) as check:
            assert check.size == size
            if target.parent == ICONS:
                assert check.mode == 'RGBA' and check.getchannel('A').getextrema() == (0,255)
        print(f'{target.name}: {size[0]}x{size[1]}')
assert len(list(ICONS.glob('*.png'))) == 15
assert len(list(PAGE.glob('*.png'))) == 4
sheet = Image.new('RGB',(1000,750),(35,38,56))
draw = ImageDraw.Draw(sheet)
for i, path in enumerate(sorted(ICONS.glob('*.png'))):
    x,y=(i%5)*200,(i//5)*250
    with Image.open(path) as icon:
        preview = icon.resize((176,176),Image.Resampling.LANCZOS)
        sheet.paste(preview,(x+12,y+12),preview)
    draw.text((x+10,y+204),path.stem,fill='white')
sheet.save(ART/'icons-preview.jpg',quality=95)
page_sheet=Image.new('RGB',(960,920),(35,38,56))
page_sheet.paste(Image.open(PAGE/'page_icon.png').resize((320,320)),(0,0))
for i,name in enumerate(('thumb_heist.png','thumb_riding.png','thumb_mama.png')):
    preview=Image.open(PAGE/name).resize((480,270),Image.Resampling.LANCZOS)
    page_sheet.paste(preview,((i%2)*480,330+(i//2)*290))
page_sheet.save(ART/'page-preview.jpg',quality=95)
