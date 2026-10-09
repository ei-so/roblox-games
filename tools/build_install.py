from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src'
def literal(text):
    return '[====[' + text + ']====]'

def build():
    lines = ["local function folder(parent,name) local f=parent:FindFirstChild(name); if not f then f=Instance.new('Folder'); f.Name=name; f.Parent=parent end return f end",
             "local RS=game:GetService('ReplicatedStorage'); local SSS=game:GetService('ServerScriptService'); local SG=game:GetService('StarterGui')",
             "local modules=folder(RS,'Modules'); local remotes=folder(RS,'Remotes'); local services=folder(SSS,'Services')",
             "for _,name in ipairs({'BuyGenerator','BuyUpgrade','Reboot'}) do if not remotes:FindFirstChild(name) then local r=Instance.new('RemoteEvent'); r.Name=name; r.Parent=remotes end end",
             "local gui=SG:FindFirstChild('MainUI'); if not gui then gui=Instance.new('ScreenGui'); gui.Name='MainUI'; gui.Parent=SG end gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui:SetAttribute('PowerCoreOwned',true)",
             "local function source(parent,name,class,code) local s=parent:FindFirstChild(name); if s then assert(s:GetAttribute('PowerCoreOwned'),'Refusing to replace unowned '..s:GetFullName()); s:Destroy() end s=Instance.new(class); s.Name=name; s.Source=code; s:SetAttribute('PowerCoreOwned',true); s.Parent=parent end"]
    for f in sorted((SRC/'Modules').glob('*.luau')):
        lines.append(f"source(modules,'{f.stem}','ModuleScript',{literal(f.read_text(encoding='utf8'))})")
    for f in sorted((SRC/'Services').glob('*.luau')):
        lines.append(f"source(services,'{f.stem}','ModuleScript',{literal(f.read_text(encoding='utf8'))})")
    for name, target, cls in [('UIController.client','gui','LocalScript'),('ReactorVisuals.client',"game:GetService('StarterPlayer').StarterPlayerScripts",'LocalScript')]:
        f=SRC/(name+'.luau')
        if f.exists(): lines.append(f"source({target},'{name.split('.')[0]}','{cls}',{literal(f.read_text(encoding='utf8'))})")
    test=ROOT/'tests/EconomyChecks.luau'
    lines.append(f"source(SSS,'PowerCoreChecks','ModuleScript',{literal(test.read_text(encoding='utf8'))})")
    lines.append(f"source(SSS,'Main','Script',{literal((SRC/'Main.server.luau').read_text(encoding='utf8'))})")
    lines.append("return 'Power Core scripts installed.'")
    dest=ROOT/'build'; dest.mkdir(exist_ok=True)
    (dest/'InstallScripts.luau').write_text('\n'.join(lines),encoding='utf8')
    print('Generated build/InstallScripts.luau')
if __name__=='__main__': build()
