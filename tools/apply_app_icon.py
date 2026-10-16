#!/usr/bin/env python3
"""Use the user's unmodified Golden AO Fantasy Compass Emblem as the app icon.

All icon assets are prepared directly from the user's original square image.
They are not an AI recreation, recolor, crop, or generated alternative.
Runs after unpacking the Godot source, before import or Android export.
"""
from pathlib import Path
import re
import hashlib

branding=Path("assets/branding")
source=branding/"Golden_AO_Fantasy_Compass_Emblem_original.png"
icon512=branding/"adventure_odyssey_icon_512.png"
icon192=branding/"adventure_odyssey_icon_192.png"
icon432=branding/"adventure_odyssey_icon_432.png"
for required in [source,icon512,icon192,icon432]:
    if not required.is_file() or required.stat().st_size<100000:
        raise SystemExit("AO APP ICON ERROR: missing or empty icon: "+str(required))

# Each approved PNG is fingerprinted so no substitute, crop, recolor, or
# accidental overwrite can silently enter an Android build.
# These are Git blob hashes of the actual committed original and resize copies.
approved_blob_sha1={
    source:"51e30ab2c0275f2342231b4bd38e14b4b7bd063d",
    icon192:"d4b788e1cecef9b28d8a0c028efce7e9bffaf84d",
    icon432:"f74c1ec0fb4477c429dfb3094bf053816853c0a9",
    icon512:"38b0badbbfb22599fac2ad54123cf749038cb7b3",
}
for icon_path,expected in approved_blob_sha1.items():
    data=icon_path.read_bytes()
    digest=hashlib.sha1(b"blob "+str(len(data)).encode("ascii")+b"\x00"+data).hexdigest()
    if digest!=expected:
        raise SystemExit("AO APP ICON ERROR: approved artwork modified: "+str(icon_path))
if hashlib.sha256(source.read_bytes()).hexdigest()!="ebb0a9c1874c2c9bac31b7e9e818f9a3bdf6421728ab00c6bf6ccbb0e9a2ba1e":
    raise SystemExit("AO APP ICON ERROR: original upload SHA-256 mismatch")
# Source image dimensions are 1254x1254; generated Android sizes only resize.
project=Path("project.godot")
text=project.read_text(encoding="utf-8")
iconline='config/icon="res://assets/branding/adventure_odyssey_icon_512.png"'
if re.search(r'(?m)^config/icon=.*$',text):
    text=re.sub(r'(?m)^config/icon=.*$',lambda _:iconline,text,count=1)
else:
    if 'config/name="Adventure Odyssey"' not in text:
        raise SystemExit("AO APP ICON ERROR: unable to find Adventure Odyssey application block")
    text=text.replace('config/name="Adventure Odyssey"','config/name="Adventure Odyssey"\n'+iconline,1)
project.write_text(text,encoding="utf-8")

preset=Path("export_presets.cfg")
cfg=preset.read_text(encoding="utf-8")
header="[preset.0.options]"
if cfg.count(header)!=1:
    raise SystemExit("AO APP ICON ERROR: expected one primary Android export preset")
prefix,settings=cfg.split(header,1)
next_idx=settings.find("\n[preset.")
if next_idx>=0:
    body,tail=settings[:next_idx],settings[next_idx:]
else:
    body,tail=settings,""
# Use the exact image with only platform-required size reductions.
keys={
 "launcher_icons/main_192x192":'res://assets/branding/adventure_odyssey_icon_192.png',
 "launcher_icons/adaptive_foreground_432x432":'res://assets/branding/adventure_odyssey_icon_432.png',
}
for key,value in keys.items():
    line=f'{key}="{value}"'
    pattern=r"(?m)^"+re.escape(key)+r"=.*$"
    if re.search(pattern,body):
        body=re.sub(pattern,lambda _:line,body,count=1)
    else:
        body=body.rstrip()+"\n"+line+"\n"
cfg=prefix+header+body+tail
preset.write_text(cfg,encoding="utf-8")
print("ADVENTURE ODYSSEY ICON PATCH OK: original user's gold-blue AO artwork, not a substitute.")
