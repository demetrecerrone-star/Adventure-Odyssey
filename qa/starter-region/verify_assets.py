"""Validate frozen terrain hashes, exact copied gutters, route/lot planning clearance."""
import hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).parent
j=json.loads((root/'layout.json').read_text()); nav=json.loads((root/'navigation.json').read_text())
full=np.zeros((3072,4608,4),dtype=np.uint8); coverage=np.zeros((3072,4608),dtype=np.uint8)
for c in j['chunks']:
 p=root/c['file']; assert hashlib.sha256(p.read_bytes()).hexdigest()==c['sha256']
 a=np.array(Image.open(p).convert('RGBA'));x,y,w,h=c['world_rect'];assert a.shape==(h+4,w+4,4)
 full[y:y+h,x:x+w]=a[2:2+h,2:2+w];coverage[y:y+h,x:x+w]+=1
assert (coverage==1).all() and (full[:,:,3]==255).all()
for c in j['chunks']:
 x,y,w,h=c['world_rect'];a=np.array(Image.open(root/c['file']).convert('RGBA'))
 xx=np.clip(np.arange(x-2,x+w+2),0,4607);yy=np.clip(np.arange(y-2,y+h+2),0,3071)
 assert np.array_equal(a,full[yy[:,None],xx[None,:]]),c['file']
lot=Image.new('1',(4608,3072));d=ImageDraw.Draw(lot)
for p in nav['reserved_lots']:d.polygon([tuple(q)for q in p['polygon']],fill=1)
lot=np.array(lot);water=np.array(Image.open(root/'water-bank-mask.png'))>0
for r in j['routes']:
 mask=Image.new('1',(4608,3072));d=ImageDraw.Draw(mask);p=[tuple(q)for q in r['points']];d.line(p,fill=1,width=72,joint='curve')
 for x,y in p:d.ellipse((x-36,y-36,x+36,y+36),fill=1)
 a=np.array(mask);assert not (a&lot).any(),r['id']+' lot overlap';assert not (a&water).any(),r['id']+' visual water overlap'
print('PASS: 54 hashes, full opaque single coverage, all copied gutters, five route/lot/water planning clearances')
