"""Build a guarded Studio installer from changed sources and the captured live baseline."""
from pathlib import Path
import json
import zlib

ROOT = Path(__file__).resolve().parents[1]


def normalized(s):
    return s.replace("\r\n", "\n").rstrip("\n")


def signature(s):
    raw = normalized(s).encode("utf-8")
    return {"length": len(raw), "adler": zlib.adler32(raw)}


def build():
    records = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        rel = path.relative_to(ROOT / "src")
        before = ROOT / "live-before-feedback-20261007" / rel
        original = ROOT / "before-feedback-20261007" / rel
        source = path.read_text(encoding="utf-8-sig")
        if before.exists():
            baseline = before.read_text(encoding="utf-8-sig")
            if normalized(source) == normalized(baseline):
                continue
        elif original.exists():
            assert normalized(source) == normalized(original.read_text(encoding="utf-8-sig")), f"missing live baseline: {rel}"
            continue
        else:
            assert path.stem in ("MamaInput", "NestStatus"), f"uncaptured new source: {rel}"
            baseline = None
        name = ".".join(rel.with_suffix("").parts)
        records.append({"path": name, "class": "ModuleScript" if name.startswith(("ReplicatedStorage.", "ServerScriptService.Services.")) else "LocalScript",
                        "before": signature(baseline) if baseline is not None else None, "after": signature(source), "source": source})
    output = ROOT / "feedback-update-20261007"
    output.mkdir(exist_ok=True)
    (output / "manifest.json").write_text(json.dumps(records, ensure_ascii=False), encoding="utf-8")
    print(f"Prepared {len(records)} sources in {output / 'manifest.json'}")
    return records


if __name__ == "__main__":
    build()
