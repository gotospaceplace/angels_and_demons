from pathlib import Path
import struct,json,sys
from PIL import Image
import trimesh
root=Path(__file__).resolve().parent
wadpaths=[Path(p) for p in sys.argv[1:]]
if not wadpaths: raise SystemExit('Usage: python restore_textures.py /path/to/cs_dust.wad [/path/to/cstrike.wad ...]')
entries={}
for path in wadpaths:
 d=path.read_bytes();assert d[:4]==b'WAD3',f'{path} not WAD3'
 count,diroff=struct.unpack_from('<ii',d,4)
 for i in range(count):
  p=diroff+i*32
  off,sz,usize,typ,comp,_=struct.unpack_from('<iiiBBH',d,p)
  name=d[p+16:p+32].split(b'\0')[0].decode('latin1')
  entries[name.lower()]=(d,off,sz,comp,path.name,name)
def get(name):
 if name.lower() not in entries:return None
 d,off,sz,comp,wad,actual=entries[name.lower()]
 if comp:return None
 w,h=struct.unpack_from('<II',d,off+16)
 mips=struct.unpack_from('<4I',d,off+24)
 if not (0<w<=4096 and 0<h<=4096 and mips[0]):return None
 pix=d[off+mips[0]:off+mips[0]+w*h]
 po=off+mips[3]+w*h//64
 n=struct.unpack_from('<H',d,po)[0]
 pal=d[po+2:po+2+n*3]
 if len(pix)!=w*h or len(pal)!=n*3:return None
 im=Image.frombytes('P',(w,h),pix);im.putpalette(pal+bytes(max(0,768-len(pal))))
 return im.convert('RGB'),wad
v=json.loads((root/'validation.json').read_text())
(root/'textures').mkdir(exist_ok=True)
found={};unmatched=[]
for item in v['texture_names']:
 name=item['name'];res=get(name)
 if res:
  im,wad=res;im.save(root/'textures'/f'{name}.png');found[name]=wad
 else:unmatched.append(name)
scene=trimesh.load(root/'aim_map.glb',force='scene')
updated=0
for geom_name,geom in scene.geometry.items():
 mat=geom.visual.material
 name=mat.name
 if name in found:
  img=Image.open(root/'textures'/f'{name}.png').convert('RGBA')
  geom.visual.material=trimesh.visual.material.PBRMaterial(name=name,baseColorTexture=img,baseColorFactor=[255,255,255,255],metallicFactor=0,roughnessFactor=1,doubleSided=False)
  updated+=1
scene.export(root/'aim_map_textured.glb')
check=trimesh.load(root/'aim_map_textured.glb',force='scene')
textured=sum(1 for g in check.geometry.values() if getattr(g.visual.material,'baseColorTexture',None) is not None)
v['phase2c_texture_sources']=found
v['phase2c_unmatched_texture_names']=unmatched
v['phase2c_textured_mesh_nodes']=textured
v['phase2c_note']='Textures are original Counter-Strike WAD assets for local prototyping; distribution rights not established. Animated frames are static.'
(root/'validation_phase2c.json').write_text(json.dumps(v,indent=2))
print(json.dumps({'found':found,'unmatched':unmatched,'mesh_nodes_textured':textured,'mesh_nodes_total':len(check.geometry),'glb_size':(root/'aim_map_textured.glb').stat().st_size},indent=2))
