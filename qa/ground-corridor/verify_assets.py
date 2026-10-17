from pathlib import Path
from PIL import Image
import numpy as np,json
p=Path(__file__).parent;m=json.loads((p/'layout.json').read_text());out=np.zeros((1023,2880,3),np.uint8)
for c in m['chunks']:
 x,y,w,h=c['local_rect'];a=np.array(Image.open(p/c['file']).convert('RGB'));assert a.shape==(h+4,w+4,3);out[y:y+h,x:x+w]=a[2:2+h,2:2+w]
pad=np.pad(out,((2,2),(2,2),(0,0)),mode='edge')
for c in m['chunks']:
 x,y,w,h=c['local_rect'];a=np.array(Image.open(p/c['file']).convert('RGB'));assert np.array_equal(a,pad[y:y+h+4,x:x+w+4]),c['file']
result={'all_12_cores_and_2px_gutters_exact':True,'total_rgba_mib':sum((c['local_rect'][2]+4)*(c['local_rect'][3]+4)*4 for c in m['chunks'])/1048576,'source_art_modified':False}
(p/'results/assets.json').write_text(json.dumps(result,indent=2));print(result)
# Reservations remain non-colliding; flag future building placement conflicts.
from PIL import ImageDraw,ImageChops
conflicts=[]
for route in m['routes']:
 mask=Image.new('1',tuple(m['local_size']));d=ImageDraw.Draw(mask);d.line([tuple(v) for v in route['points']],fill=1,width=72)
 for x,y in route['points']:d.ellipse((x-36,y-36,x+36,y+36),fill=1)
 for lot in m['reserved_lots']:
  other=Image.new('1',mask.size);ImageDraw.Draw(other).polygon([tuple(v) for v in lot['polygon']],fill=1);overlap=ImageChops.logical_and(mask,other)
  if overlap.getbbox():conflicts.append({'route':route['id'],'lot':lot['id'],'overlap_pixels':int(np.count_nonzero(np.array(overlap))),'bbox':overlap.getbbox()})
(p/'results/lot-clearance.json').write_text(json.dumps({'method':'72px raster route versus reserved non-colliding lots','overlaps':conflicts},indent=2))
print('Placement warnings:',conflicts)
