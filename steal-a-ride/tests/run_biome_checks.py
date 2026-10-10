"""Per-biome checklist: every biome in Config.Biomes must ship every per-biome hook.

Adding a biome? It must have all of these (the test names the biome and the missing hook):
  - 3 species, each in Config.Species, ability nil or in Config.Abilities with an icon in Config.Icons.Abilities
  - Config.Guardians[id].recipe
  - Config.GuardianFX.guardians[id] with layers + step burst, and a complete Config.guardianRage(id)
  - Config.GuardianSounds[id] idle / alert / chase / step
  - Config.EggFX.themes[id], Config.EscapeMusic.tracks[id], Config.Sounds["Ambience" .. id]
  - BiomeVFX.luau: AIR[id] and LIGHT[id]
  - with a lane: Config.Patch.messages[id] and an icon for the lane ability;
    PATCH[id] in BiomeVFX too unless the biome uses shortcuts (b.shortcuts) instead of escape patches
  - Config.Events.secretOddsByBiome[id] (Forest / Lake predate Secret Eggs)
  - a Config.Tips entry titled with the spaced id ("CrystalCaverns" -> "Crystal Caverns"; the first 7 biomes predate this)
  - CreatureRig cut heights are optional: unlisted mesh creatures cut at the .28 default
"""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile
from run_feedback_checks import module
from run_stick_checks import PRELUDE

ROOT = Path(__file__).resolve().parents[1] / 'src'


def vfx_keys():
    source = (ROOT / 'StarterPlayer/StarterPlayerScripts/BiomeVFX.luau').read_text(encoding='utf-8-sig')
    keys = {}
    for table in ('AIR', 'LIGHT', 'PATCH'):
        start = source.index(f'local {table} = {{')
        body, depth = [], 0
        for line in source[start:].splitlines()[1:]:
            if depth == 0 and line.startswith('}'):
                break
            match = re.match(r'\t(\w+) = ', line)
            if depth == 0 and match:
                body.append(match.group(1))
            depth += line.count('{') - line.count('}')
        keys[table] = body
    return keys


def lua_set(names):
    return '{' + ', '.join(f'{n} = true' for n in names) + '}'


def checklist(config_src, keys):
    return PRELUDE + 'local Config=' + config_src + f'''
local AIR, LIGHT, PATCH = {lua_set(keys['AIR'])}, {lua_set(keys['LIGHT'])}, {lua_set(keys['PATCH'])}
''' + r'''
local LEGACY_NO_SECRET = { Forest = true, Lake = true } -- Secret Eggs start in the Desert
local LEGACY_NO_GUIDE = { Forest = true, Lake = true, Desert = true, Jungle = true, Tundra = true, Volcano = true, Cosmic = true }

local function checklist()
	local tipTitles = {}
	for _, t in Config.Tips do tipTitles[t.title] = true end
	for _, b in Config.Biomes do
		local function need(ok, hook) assert(ok, b.id .. " is missing " .. hook) end
		need(b.species and #b.species == 3, "3 species")
		for _, s in b.species do
			local sp = Config.Species[s]
			need(sp, "Config.Species." .. s)
			need(sp.ability == nil or (Config.Abilities[sp.ability] and Config.Icons.Abilities[sp.ability]),
				s .. " ability " .. tostring(sp.ability) .. " in Config.Abilities + Config.Icons.Abilities")
		end
		need(Config.Guardians[b.id] and Config.Guardians[b.id].recipe, "Config.Guardians recipe")
		local fx = Config.GuardianFX.guardians[b.id]
		need(fx and #fx.layers > 0 and fx.step, "Config.GuardianFX.guardians layers + step")
		local r = Config.guardianRage(b.id)
		need(#r.layers >= #Config.GuardianFX.rage.layers and r.light.color and r.sound and r.chase, "Config.guardianRage package")
		local snd = Config.GuardianSounds[b.id]
		need(snd and snd.idle and snd.alert and snd.chase and snd.step, "Config.GuardianSounds idle/alert/chase/step")
		need(Config.EggFX.themes[b.id], "Config.EggFX.themes")
		need(Config.EscapeMusic.tracks[b.id], "Config.EscapeMusic.tracks")
		need(Config.Sounds["Ambience" .. b.id], "Config.Sounds.Ambience" .. b.id)
		need(AIR[b.id], "BiomeVFX AIR")
		need(LIGHT[b.id], "BiomeVFX LIGHT")
		if b.lane then
			need(Config.Patch.messages[b.id], "Config.Patch.messages")
			need(Config.Abilities[b.lane] and Config.Icons.Abilities[b.lane], "lane ability " .. b.lane .. " + icon")
			if not b.shortcuts then need(PATCH[b.id], "BiomeVFX PATCH") end
		end
		need(LEGACY_NO_SECRET[b.id] or Config.Events.secretOddsByBiome[b.id], "Config.Events.secretOddsByBiome")
		local spaced = b.id:gsub("(%l)(%u)", "%1 %2")
		need(LEGACY_NO_GUIDE[b.id] or tipTitles[spaced], "a Config.Tips entry titled '" .. spaced .. "'")
	end
	return #Config.Biomes
end
'''


def complete(config_src, keys):
    return checklist(config_src, keys) + r'''
print("PASS: " .. checklist() .. " biomes complete")
'''


def bare_biome_fails(config_src, keys):
    return checklist(config_src, keys) + r'''
table.insert(Config.Biomes, { id = "Fakeland", lane = "Swim", species = {} })
local ok, err = pcall(checklist)
assert(not ok and string.find(tostring(err), "Fakeland", 1, true), "a bare new biome must fail the checklist, got: " .. tostring(err))
print("PASS: a bare new biome fails the checklist (" .. tostring(err):match("Fakeland.*") .. ")")
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', type=Path, required=True)
    args = parser.parse_args()
    config_src = module('ReplicatedStorage/Shared/Config.luau', {})
    keys = vfx_keys()
    with tempfile.TemporaryDirectory(prefix='sam-biome-') as temp:
        for name, build in (('complete', complete), ('bare', bare_biome_fails)):
            script = Path(temp) / f'{name}.luau'
            script.write_text(build(config_src, keys), encoding='utf-8')
            subprocess.run([str(args.runtime / 'luau.exe'), str(script)], check=True)


if __name__ == '__main__':
    main()
