import bpy,numpy as np
body=bpy.data.objects['Dealer_Body'];p=np.empty(len(body.data.vertices)*3,dtype=np.float32);body.data.vertices.foreach_get('co',p);p=p.reshape(-1,3)+np.array([.17,.02,0]);x,y,z=p.T
image=next(n.image for m in body.data.materials if m and m.node_tree for n in m.node_tree.nodes if n.type=='TEX_IMAGE');w,h=image.size;pix=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pix);pix=pix.reshape(h,w,4)
uv=np.empty(len(body.data.loops)*2,dtype=np.float32);body.data.uv_layers.active.data.foreach_get('uv',uv);uv=uv.reshape(-1,2);idx=np.empty(len(body.data.loops),dtype=np.int32);body.data.loops.foreach_get('vertex_index',idx)
rgb=pix[np.clip((uv[:,1]*(h-1)).astype(int),0,h-1),np.clip((uv[:,0]*(w-1)).astype(int),0,w-1),:3]
color=np.zeros((len(p),3),dtype=np.float32);count=np.zeros(len(p),dtype=np.int32);np.add.at(color,idx,rgb);np.add.at(count,idx,1);color/=count[:,None];lum=color.mean(axis=1)
for name,mask in [('coat_outer',(z>.3)&(z<.8)&((abs(y)>.24)|(x<-.14))),('pants',(z>.3)&(z<.6)&(abs(y)>.06)&(abs(y)<.13)&(abs(x)<.055)),('front_panel',(z>.3)&(z<.8)&(x>.07)&(abs(y)>.13)),('r_glove',(z>1.1)&(z<1.3)&(x>.18)&(y<.1)&(y>-.18))]:print(name,int(mask.sum()),np.quantile(lum[mask],[0,.1,.25,.5,.75,.9,1]).round(3).tolist())
np.save(r'D:\无限世界地下酒馆和赌局\game\verification\dealer_rig\vertex_albedo.npy',color)
