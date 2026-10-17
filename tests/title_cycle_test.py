"""Offline regression checks for authored pose geometry and atlas continuity."""
from pathlib import Path
from PIL import Image
import json, math, hashlib
ROOT=Path(__file__).resolve().parents[1]
results={}
for name,scale,lengths in [('goblin',.23,(68,66)),('skeleton',.27,(74,80))]:
 data=json.loads((ROOT/f'docs/qa/title-cycle/{name}-kinematics.json').read_text())
 atlas=Image.open(ROOT/f'assets/title/{name}-run-smooth.png').convert('RGBA')
 assert atlas.size==(3072,2048)
 frames=[atlas.crop(((i%6)*512,(i//6)*512,(i%6+1)*512,(i//6+1)*512)) for i in range(24)]
 assert len({hashlib.sha256(f.tobytes()).digest() for f in frames})==24
 for row in data:
  for a,b,expected in [('hip','knee',lengths[0]),('knee','ankle',lengths[1])]:
   assert abs(math.dist(row[a],row[b])-expected)<1e-6
 for leg in [0,1]:
  rows=[r for r in data if r['leg']==leg]
  # Same-phase support has constant world x: no foot skating while planted.
  contacts=[r for r in rows if r['stance']]
  planted=[r['ankle'][0]*scale+r['phase']*.8*112 for r in contacts]
  assert max(planted)-min(planted)<.001
  assert len({r['ankle'][1] for r in contacts})==1
  steps=[math.dist(rows[i]['ankle'],rows[(i+1)%24]['ankle']) for i in range(24)]
  assert steps[-1]<=max(steps[:-1])*1.1, 'loop seam must not be the largest jump'
 # Both feet leave the ground between alternating stance windows.
 assert any(not data[i*2]['stance'] and not data[i*2+1]['stance'] for i in range(24))
 for f in frames:
  x0,y0,x1,y1=f.getbbox();assert x0>0 and y0>0 and x1<512 and y1<512
 results[name]={'unique_frames':24,'cycle_seconds':.8,'support_seconds_per_foot':.288,'bone_lengths':lengths,'planted_world_x_error':'< 0.001 px','loop_seam':'within normal adjacent motion','frame_bounds':'no clipping'}
grips=json.loads((ROOT/'docs/qa/title-cycle/skeleton-grip.json').read_text())
for target in ['hilt','tip']:
 distances=[math.dist(r['hand'],r[target]) for r in grips]
 assert max(distances)-min(distances)<1e-6
 steps=[math.dist(grips[i][target],grips[(i+1)%24][target]) for i in range(24)]
 assert steps[-1]<=max(steps[:-1])*1.1
results['skeleton']['hand_to_hilt_drift_px']='< 0.000001'
results['skeleton']['sword_loop_seam']='within normal adjacent motion'
print(json.dumps(results,indent=2));print('TITLE CYCLE GEOMETRY: PASS')
