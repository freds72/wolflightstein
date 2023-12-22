function autoarray(t)
	return setmetatable(t or {},
	{
		-- auto create array
		__index=function(t,k)
			local v={}
			t[k]=v
			return v
		end
	})
end

local _grid=autoarray()
local _lights={}

function make_cam(x,y,a)
	return {
		pos={x,y},
		angle=a,
	 project2d=function(self,x,y)
	 	return 64+x*8,64-y*8
	 end
	}
end

local function v_add(a,b,s)
	s=s or 1
	return {
		a[1]+s*b[1],
		a[2]+s*b[2]
	}
end

local function v_scale(a,s)
	return {
		s*a[1],
		s*a[2]
	}
end

local function lerp(a,b,t)
	return a+(b-a)*t
end
local function v_lerp(a,b,t)
	local ax,ay=a[1],a[2]
	local au,av=a.u,a.v
	return {
    	ax+(b[1]-ax)*t,
    	ay+(b[2]-ay)*t,
    	u=au+(b.u-au)*t,
    	v=av+(b.v-av)*t
	}
end

local function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]
end
 
local function v_normz(v)
	local x,y=v[1],v[2]
	local a=atan2(x,y)
	local d=x*cos(a)+y*sin(a)
	if(d>0) return {v[1]/d,v[2]/d},d
	return v,0
end

local _actors={}
local cam

local _walls={}
local dists={}
local angles={}
for i=0,127 do
  local x=i-63.5
	angles[i]=atan2(x,64)
	dists[i]=sqrt(x*x+64*64)
end

-- get flags for wall boundaries
local _wall_by_id={}
for i=32,39 do
	_wall_by_id[fget(i)]=i
end

function draw_walls(walls,xshift,yshift)
	for w in all(walls) do
		local a,b=unpack(w)
		line(a[1]-xshift,a[2]-yshift,b[1]-xshift,b[2]-yshift,11)
	end
end

function v_tostr(a)
	return "["..a[1].." "..a[2].."]"
end

function scan(walls,start,min_ij,max_ij,id,mask,n,side)
	-- clear flag bits at tile i j
	local function fclear(i,j)
		local id=fget(mget(i,j))&~mask
		-- replace with corresponding tile
		mset(i,j,_wall_by_id[id|0x80])
	end
	local function in_range(a)
		local i,j=unpack(a)
		return 
			min_ij[1]<=i and i<=max_ij[1] and
			min_ij[2]<=j and j<=max_ij[2]
	end

	local extents={
		[-1]=start,
		[1]=start}
	fclear(start[1],start[2])
	-- to pixel/world units
	local origin={
		min_ij[1]*8,
		min_ij[2]*8,
	}
	local cx,cy=0,0

	for s=-1,1,2 do
		local cursor=v_add(start,side,s)
		while in_range(cursor) do
			local other_id=fget(mget(unpack(cursor)))
			-- past segment?
			if(other_id&0x80==0 or other_id&mask!=id&mask) break
			fclear(unpack(cursor))
			extents[s]=cursor
			cursor=v_add(cursor,side,s)
		end		
	end
	local n_offset={0,0}
	if(sgn(n[1])==-1 or sgn(n[2])==-1) n_offset=v_scale(n,-1)
	local a,b=v_add(origin,extents[-1],8),v_add(origin,extents[1],8)
	a=v_add(a,n_offset,8)
	b=v_add(b,n_offset,8)
	local a_offset,b_offset={0,0},side
	if(sgn(side[1])==-1 or sgn(side[2])==-1) a_offset,b_offset=side,{0,0}
	add(walls,{
		v_add(a,a_offset,-8),v_add(b,b_offset,8),
		n=n,
		cp=v_dot(a,n)
	})
end

function _init()
	tline(17)	
	poke(0x5f36,1)
	poke(0x5f54,0x60,0x00)
	memcpy(0x0,0x6000,0x2000)
	_map_display(0)
	
	local normals={
		[1]={-1,0},
		[2]={0,-1},
		[4]={1,0},
		[8]={0,1}
	}

	local mem=0x8000
	local mini,minj=0,0
	local maxi,maxj=31,31

	for j=minj,maxj do
		for i=mini,maxi do
			local s=mget(i,j)
			local id=fget(s)
			-- store flag in himem
			poke(mem,id)
			mem+=1
			if id==4 then
				local i,j=i,j
				local actor={
					pos={i+1,j+1},
					sx=56,sy=0,radius=24,
					update=function(self)
						local t=time()/4
						self.pos={i+1+0.5*cos(t),j+1+0.5*sin(t)}
						return true
					end
				}
				add(_lights,actor)			
				add(_actors,actor)
			elseif id==1 then
				-- player starting pos
				cam=make_cam(i+0.5,j+0.5,0)
			elseif id&0x80>0 then
				-- wall tile?
				for shift=0,3 do
					local mask=1<<shift
					if id&mask>0 then
						local n=normals[id&mask]
						scan(_walls,{i,j},{mini,minj},{maxi,maxj},id,mask,n,{-n[2],n[1]})
					end
				end
			end
		end
	end
	
	for i=0,15 do
		for j=0,15 do
			mset(32+i,j,i+j*16)
		end
	end
end

function solid(x,y)
 return fget(mget(x,y),1)
end

function solid_area(x,y,w,h)

 return 
  solid(x-w,y-h) or
  solid(x+w,y-h) or
  solid(x-w,y+h) or
  solid(x+w,y+h)
end


function _update()
	local dx,dy=0,0
	if(btn(2)) dx=1
	if(btn(3)) dx=-1
	if(btn(0)) dy=-1
	if(btn(1)) dy=1
	
	cam.angle+=dy/128
	local u,v=cos(cam.angle),-sin(cam.angle)
 local x,y=unpack(cam.pos)
	local du=dx*u/8
	local dv=dx*v/8	
	if solid_area(x+du,y,0.1,0.1) then
	 du=0
	end
	if solid_area(x,y+dv,0.1,0.1) then
	 dv=0
	end

	cam.pos={x+du,y+dv}
	
	if btnp(🅾️) then
		add(_actors,{
			pos={cam.pos[1],cam.pos[2]},
			ttl=45+rnd(15),
			sx=56,
			update=function(self)
				self.ttl-=1
				if(self.ttl<0) return
				local x,y=self.pos[1],self.pos[2]
				x+=0.3*u
				y+=0.3*v
				if(solid(x,y)) return
				self.pos[1],self.pos[2]=x,y
				-- still active
				return true
			end
		})
	end
	
	for _,a in pairs(_actors) do
		if a.update and not a:update() then
			del(_actors,a)
		end
	end
end

function solid(i,j)
	return fget(mget(i,j))==2
end

function wallhit(posx,posy,u,v,out)
 local mapx,mapy=posx\1,posy\1
 -- initial tile
 out[mapx|mapy<<5]=0
 local sidex,sidey
 local ddx,ddy=1/u,1/v
 local mapdx,mapdy
 local distx,disty
 local hit=false
 local side=0
 if u<0 then
 	mapdx=-1
	ddx=-ddx
	distx=(posx-mapx)*ddx
 else
 	mapdx=1
  distx=(mapx+1-posx)*ddx
 end

 if v<0 then
 	mapdy=-1
  ddy=-ddy
  disty=(posy-mapy)*ddy
 else
 	mapdy=1
  disty=(mapy+1-posy)*ddy
 end

	local dist=0
 	while hit==false and dist<16 do
		if distx<disty then
			distx+=ddx
			mapx+=mapdx
			side=u<0 and 1 or 0
		else
			disty+=ddy
			mapy+=mapdy
			side=v<0 and 2 or 4
		end		
		local k=mapx|mapy<<5
		if @(0x8000|k)==2 then
			local len=0
			if side<2 then
				len=(mapx-posx+(1-mapdx)/2)/u
			else
				len=(mapy-posy+(1-mapdy)/2)/v			
			end
			return true,mapx,mapy,side,len,(mapx\16)+2*(mapy\16)
		end
		-- non solid visible tiles
		if (mapx|mapy)&0xffe0==0 then
			out[k]=dist
		end
		dist+=1
	end
end

function rot_inv(p,a)
 local c,s=cos(a),-sin(a)
 return {p[1]*c+p[2]*s,-p[1]*s+p[2]*c}
end

function _draw()
 cls(5)
 palt(0,false)

 --
	local tiles={}
	local zbuf={}
	local do_later=autoarray()
	local cx,cy=unpack(cam.pos)
 for i=0,127 do
 	local angle=angles[i]
 	local u,v=sin(angle+cam.angle),cos(angle+cam.angle)
 	
 	--[[
		local hit,x1,y1,leftright=lineofsight(cam.pos[1],cam.pos[2],cam.pos[1]+10*u,cam.pos[2]+10*v,10) 
		]]
		local hit,x1,y1,side,dist,tileid,tx=wallhit(cx,cy,u,v,tiles)
  -- 
 	if hit==true then
			local h=dists[i]/dist
  	zbuf[i]=dist
  	local sx,mx=16,0
  	if side<2 then
   	tx=2*(v*dist+cy)
   	sx+=8  
   	--mx+=2  
   else
   	tx=2*(u*dist+cx)
   end
   
   -- wall coords
	  local dy=63.5-h/2   
	  -- scale texture dv by 16
   local dv=(2<<4)/h
   local err=flr(dy)-dy
   -- scale u by 16
	 local walls=do_later[tileid]	 
   add(walls,function(xshift,yshift) 
		--tline(i,dy,i,63.5+h/2,(mx+(tx%2))<<4,err*dv,0,dv) 
		--rect(x1*8,y1*8,x1*8+7,y1*8+7,2)
		local pct,tx,ty=8*((tx/2)&0x0.ffff)
		if(side==0) tx,ty=x1*8,y1*8+pct
		if(side==1) tx,ty=x1*8+8,y1*8+pct
		if(side==2) tx,ty=x1*8+pct,y1*8+8
		if(side==4) tx,ty=x1*8+pct,y1*8
		tx+=xshift
		ty+=yshift
		rectfill(i,dy,i,63.5+h/2,sget(tx,ty))
		end)
  end
 end 	
 local done={}	
 for k,dist in pairs(tiles) do
 	local i,j=k&31,k\32
	i\=16
 	j\=16
 	local grid_id=i+2*j
 	if not done[grid_id] then
 	 	done[grid_id]=true
	 	local x0,y0=i*512-cx*32,j*512-cy*32
	 	local verts={
	 	 {x0,y0,u=i,v=j},
	 	 {x0+512,y0,u=i+16-0x0.0001,v=j},
	 	 {x0+512,y0+512,u=i+16-0x0.0001,v=j+16},
	 	 {x0,y0+512,u=i,v=j+16}}
	 	local clip
		 local znear=4
	
	 	for i=1,4 do
	 	 	local v=verts[i]
	 		local p=rot_inv(v,cam.angle)
	 		verts[i]=p
			if(p[1]<znear) clip=true
				local w=64/p[1] 
				p.w=w
				p.x=63.5+w*p[2]
				p.y=63.5+w*16
				-- shift to match tline additional precision
				p.u=v.u<<4
				p.v=v.v<<4
			end
			if clip then
				-- near clipping required?
				local res,v0={},verts[#verts]
				local d0=v0[1]-znear
				for i,v1 in inext,verts do
					local side=d0>0
					if(side) add(res,v0)
					local d1=v1[1]-znear
					if (d1>0)!=side then
						-- clip!
						local t=d0/(d0-d1)
						local v=v_lerp(v0,v1,t)
						-- project
						-- z is clipped to near plane
						
						v.x=63.5+(v[2]<<4)
						v.y=63.5+(16<<4)
						v.w=16
						add(res,v)
					end
					v0,d0=v1,d1
				end
				verts=res
			end		
			
			_map_display(1)
			poke(0x5f54,0x00,0x60)
			cls()
			local mask=0b00010001
			for a in all(_lights) do
				local grids,r,x,y=autoarray(),a.radius/8,unpack(a.pos)
				for i=max((x-r)\16),min((x+r)\16,31) do
					for j=max((y-r)\16),min((y+r)\16,31) do
						add(grids[i+2*j],a)
					end
				end
				for a in all(grids[grid_id]) do
					poke(0x5f5e,mask)
					collect_light(_walls,a.pos[1]*8,a.pos[2]*8,a.radius,-i*128,-j*128-1)
					
					mask<<=1
				end
			end
			poke(0x5f5e,0xff)
			-- todo: map to "kill" wall colors
			--fillp(0x33cc.8)
			--rectfill(0,0,127,127,0xf0)
			--fillp()
			poke(0x5f54,0x60,0x00)
			
			poke4(0x5f38,0x0020.1010)
			for i=1,15 do
				pal(i,1)
			end
			palt(0,false)
			-- draw including sprite 0
			poke(0x5f36, 0x9)
			mode7(verts,#verts,i+j)
			poke(0x5f36, 0x1)
			if(btn(5)) for i=1,10 do flip() end
			--sspr(0,0,128,128,64*i,64*j,64,64)
			pal()

			--_map_display(0)
			--poke4(0x5f38,0x001c.0202)
			for i=1,15 do
				pal(i,2)
			end
			for fn in all(do_later[grid_id]) do
			 fn(-i*128,-j*128-1)
			 if(btn(5)) flip()
			end
			pal()
			_map_display(0)
		 		 
   		--polyfill(verts,cam.pos,cam.angle,-16,0,1)			
			--[[
			local p0=verts[#verts]
			for i=1,#verts do
			local p1=verts[i]
				line(
					p0.x,p0.y,
					p1.x,p1.y,
						8)
					p0=p1
			end
			]]
		end
 	--pset(mx+i,j,6)	 
 end

 -- actors
 palt(14,true)
 local drawables={}
 for _,a in pairs(_actors) do
  -- visible?
  if tiles[flr(a.pos[1])+32*flr(a.pos[2])] then
	  local p=rot_inv({a.pos[1]-cam.pos[1],a.pos[2]-cam.pos[2]},cam.angle)
	  if p[1]>0.1 then
		  local w=64/p[1]
	  	add(drawables,{
				info=a.pos[1].." "..a.pos[2].."\nid:"..((a.pos[1]\16)+2*(a.pos[2]\16)),
	  		x=64+w*p[2],
	  		depth=p[1],
	  		sx=a.sx,
	  		key=-64/p[1]})
	  end
	 end
 end
 
 sort(drawables)
 
 for _,a in pairs(drawables) do
  local w=-a.key
  -- assumes all actors to be 8x8
  local sx,dsx=a.sx,8/w
  local x0=a.x-w/2
  -- clip sprite start to 0
  if(x0<0) x0,sx=0,sx-dsx*x0
  for dx=flr(x0),min(127,flr(a.x+w/2)-1) do
		-- get wall distance
		local z=zbuf[dx] or 32000
		-- is slice visible
		if z>a.depth then
			sspr(sx,0,1,8,dx,64-w/2,1,w)
		end
		sx+=dsx
	end
	--print(a.info,x0,64-w,8)
 end

 palt()
 print("grid:"..(cam.pos[1]\16).." "..(cam.pos[2]\16))
end

function collect_light(walls,x0,y0,r0,xshift,yshift)
	x0+=xshift
	y0+=yshift
	clip(x0-r0+1,y0-r0+1,2*r0,2*r0)
	rectfill(0,0,127,127,15)
	local ymin,ymax=max((y0-r0)\1),min((y0+r0)\1,127)
	
	local shift={xshift,yshift}
	for _,w in next,walls do
	 -- backfacing?
	 local w0,w1=v_add(w[1],shift),v_add(w[2],shift)
	 local n0={
			 w0[1]-x0,
			 w0[2]-y0}
	 if v_dot(n0,w.n)<r0 and v_dot({x0,y0},w.n)<w.cp then
		 local n0=v_normz(n0)	
		 local n1=v_normz({
			 w1[1]-x0,
			 w1[2]-y0}) 	
		 local w11=v_add(w0,n0,128)
		 local w22=v_add(w1,n1,128)
		 polyfill({w0,w1,w22,w11},4,0,ymin,ymax)
	 end
	end
 
	-- remove outside light sphere
	camera(-x0,-y0)
	color(0)
	local rr=r0*r0
	for y=-r0-1,r0+1 do 
	 local x=sqrt(rr-y*y)-0x0.0001
	 rectfill(-r0,y,-x,y)
	 rectfill(x,y,r0,y)
	end	
	camera() 
	circfill(x0+0.5,y0+0.5,r0/12,0)
	clip()
 end