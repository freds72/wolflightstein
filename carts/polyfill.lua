function polyfill(p,np,col,ymin,ymax)
	--find top & bottom of poly
	local miny,maxy,mini=32000,-32000
	for i=1,np do
		local y=p[i][2]
		if (y<miny) mini,miny=i,y
		if (y>maxy) maxy=y
	end
	if(not mini) return
	color(col)
	--data for left & right edges:
	local li,lj,ri,rj,ly,ry,lx,ldx,rx,rdx=mini,mini,mini,mini,miny-1,miny-1

	--step through scanlines.
	for y=max(ymin,miny\1+1),min(ymax,maxy) do
		--maybe update to next vert
		while ly<y do
			li,lj=lj,lj+1
			if (lj>np) lj=1
			local v0,v1=p[li],p[lj]
			local y0,y1=v0[2],v1[2]
			ly=y1&-1
			lx=v0[1]
			ldx=(v1[1]-lx)/(y1-y0)
			--sub-pixel correction
			lx+=(y-y0)*ldx
		end   
		while ry<y do
			ri,rj=rj,rj-1
			if (rj<1) rj=np
			local v0,v1=p[ri],p[rj]
			local y0,y1=v0[2],v1[2]
			ry=y1&-1
			rx=v0[1]
			rdx=(v1[1]-rx)/(y1-y0)
			--sub-pixel correction
			rx+=(y-y0)*rdx
		end
		rectfill(lx,y,rx,y)
		lx+=ldx
		rx+=rdx
	end
end