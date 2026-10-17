"""Build isolated skin/iris masks from approved body atlases; never modify art.
Red = warm skin pigment, green = iris pigment. Armor is never an input.
Eye coordinates refer to registered 256px cells and follow the existing gait bob.
"""
from pathlib import Path
import json, math
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/character-appearance'
EYES = {
 'male': [[(120,79,3,1.8),(137,79,3,1.8)],[(111,76,2,1.5)],[(145,76,2,1.5)],[]],
 'female': [[(118,80,3,1.8),(137,80,3,1.8)],[(114,78,2,1.5)],[(143,78,2,1.5)],[]],
}
def masks(a, base, direction, phase=None):
 rgb=a[:,:,:3].astype(float)/255; r,g,b=rgb.transpose(2,0,1)
 y,x=np.mgrid[:256,:256]
 bob=0 if phase is None else math.sin(phase*math.pi/2)*.9
 skin=(np.clip((r-g-.025)/.07,0,1)*np.clip((g-b-.015)/.055,0,1)*np.clip((r-.12)/.15,0,1))
 iris=np.zeros((256,256))
 for cx,cy,rx,ry in EYES[base][direction]:
  dist=((x-cx)/rx)**2+((y-cy-bob)/ry)**2
  coverage=np.clip((1.2-dist)*2,0,1)
  # Preserve highlights, black pupil and desaturated sclera.
  pigment=np.clip((r-g-.01)/.08,0,1)*np.clip((r-.08)/.12,0,1)
  iris=np.maximum(iris,coverage*pigment)
  skin*=1-np.clip((2.0-dist)*2,0,1)
 active=a[:,:,3]>0
 out=np.zeros_like(a);out[:,:,0]=(skin*active*255).astype('uint8');out[:,:,1]=(iris*active*255).astype('uint8');out[:,:,3]=255
 return out
if __name__=='__main__':
 records=[]
 for base in EYES:
  for source in sorted((ROOT/'assets/character-outfits'/base).glob('*/*-body.png')):
   a=np.array(Image.open(source).convert('RGBA')); frames=a.shape[1]//256
   name=source.name; direction=None if name.startswith('idle') else ['down','left','right','up'].index(name.split('-')[1])
   mask=np.concatenate([masks(a[:,i*256:(i+1)*256],base,i if direction is None else direction,None if direction is None else i) for i in range(frames)],axis=1)
   dest=OUT/base/source.parent.name/name.replace('-body','-mask');dest.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(mask).save(dest)
   records.append({'body':str(source.relative_to(ROOT)),'mask':str(dest.relative_to(ROOT)),'skin_pixels':int(np.count_nonzero(mask[:,:,0])),'iris_pixels':int(np.count_nonzero(mask[:,:,1]))})
 (OUT/'mask-inventory.json').write_text(json.dumps({'schema_version':1,'status':'palette_mask_candidate','original_art_modified':False,'records':records},indent=2)+'\n')
 print(f'Built {len(records)} isolated masks; original body and armor files untouched.')
