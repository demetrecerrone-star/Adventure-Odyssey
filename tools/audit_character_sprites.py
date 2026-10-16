#!/usr/bin/env python3
"""Audit and back up original AO player sprite PNGs without changing them.

Run after the source payload is reconstructed and before adding any
separated underwear/clothing/equipment textures. The source ZIP remains
unchanged. Standard-library only; works in the Godot CI container.
"""
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(".")
BODY = ROOT / "assets" / "characters"
HAIR = ROOT / "assets" / "hair"
OUT = ROOT / "screenshots"
DIRECTIONS = ("down", "left", "up", "right")
EXPECTED = [f"base_variant_{i:02d}" for i in range(1, 9)]

def image_info(path: Path) -> dict:
    binary = path.read_bytes()
    if binary[:8] != b"\x89PNG\r\n\x1a\n" or binary[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG: {path}")
    width, height = struct.unpack(">II", binary[16:24])
    if width < 8 or height < 8:
        raise ValueError(f"Unexpected sprite dimensions: {path} ({width} x {height})")
    return {
        "path": path.as_posix(),
        "width": width,
        "height": height,
        "sha256": hashlib.sha256(binary).hexdigest(),
        "bytes": len(binary),
    }

def inspect_group(directory: Path) -> dict:
    frames = sorted(directory.glob("*.png"))
    if not frames:
        raise ValueError(f"Missing sprites: {directory}")
    result = {}
    for facing in DIRECTIONS:
        group = [p for p in frames if re.fullmatch(rf"{facing}_\d{{2}}\.png", p.name)]
        if not group or not any(p.name == f"{facing}_00.png" for p in group):
            raise ValueError(f"Missing {facing} first frame in {directory}")
        numbers = sorted(int(p.stem.split("_")[-1]) for p in group)
        if numbers != list(range(len(numbers))):
            raise ValueError(f"Non-contiguous frames: {directory}/{facing}: {numbers}")
        metadata = [image_info(p) for p in group]
        widths = set((p["width"], p["height"]) for p in metadata)
        if len(widths) != 1:
            raise ValueError(f"Inconsistent frame sizes within {directory}/{facing}: {widths}")
        result[facing] = metadata
    return result

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not BODY.is_dir() or not HAIR.is_dir():
        raise ValueError("Reconstructed character / hair source directories are missing")
    original_names = sorted(p.name for p in BODY.iterdir() if p.is_dir() and p.name.startswith("base_variant_"))
    if original_names != EXPECTED:
        raise ValueError(f"Expected original 8 body variants, found: {original_names}")
    bodies = {variant: inspect_group(BODY / variant) for variant in EXPECTED}
    hair_dirs = sorted(p for p in HAIR.iterdir() if p.is_dir())
    hairs = {p.name: inspect_group(p) for p in hair_dirs}
    if not hairs:
        raise ValueError("Missing separate hair artwork")
    all_paths = [p for root in (bodies, hairs) for directions in root.values() for frames in directions.values() for p in frames]
    paths = sorted({Path(m["path"]) for m in all_paths})
    manifest = {
        "type": "adventure_odyssey_original_player_sprite_audit_v1",
        "source": "reconstructed original game source; png bytes unchanged",
        "directions": list(DIRECTIONS),
        "body_variants": bodies,
        "hair_styles": hairs,
        "sprite_files": len(paths),
        "original_artwork_read_only": True,
    }
    path = OUT / "ao_character_sprite_baseline_manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    backup = OUT / "ao_original_character_sprites.zip"
    with zipfile.ZipFile(backup, "w", compression=zipfile.ZIP_STORED) as z:
        for source in paths:
            z.write(source, arcname=source.as_posix())
        z.write(path, arcname=path.as_posix())
    print("AO ORIGINAL SPRITE AUDIT: PASS")
    print(f"Body appearances: {len(bodies)}; hair styles: {len(hairs)}; PNG files backed up: {len(paths)}")
    for variant, faces in bodies.items():
        summary = ", ".join(f"{d}={len(faces[d])} x {faces[d][0]['width']}x{faces[d][0]['height']}" for d in DIRECTIONS)
        print(f"  {variant}: {summary}")
    print(f"Backup: {backup} ({backup.stat().st_size} bytes), manifest: {path}")

if __name__ == "__main__":
    main()
