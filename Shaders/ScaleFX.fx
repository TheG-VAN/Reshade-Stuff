#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float Scale <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;	
	ui_step = 0.01;
> = 1;

uniform float Threshold <
	ui_type = "drag";
	ui_min = 0.01;
	ui_max = 1.0;	
	ui_step = 0.01;
> = 0.5;

uniform float AASharpness <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 10.0;	
	ui_step = 0.01;
> = 2;

uniform bool FilterAA <
> = true;

uniform bool FilterCorners <
> = true;

texture ColorInputTex : COLOR;
sampler ColorInput 	{ Texture = ColorInputTex; MagFilter = POINT; MinFilter = POINT; };

texture pass0tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pass0smp { Texture = pass0tex; };
texture pass1tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pass1smp { Texture = pass1tex; };
texture pass2tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pass2smp { Texture = pass2tex; };
texture pass3tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler pass3smp { Texture = pass3tex; };
texture pass4tex { Width = BUFFER_WIDTH * 3; Height = BUFFER_HEIGHT * 3; Format = RGBA16F; };
sampler pass4smp { Texture = pass4tex; };

float dist(float3 A, float3 B)
{
	float  r = 0.5 * (A.r + B.r);
	float3 d = A - B;
	float3 c = float3(2 + r, 4, 3 - r);

	return sqrt(dot(c*d, d)) / 3;
}

float str(float d, float2 a, float2 b){
	float diff = a.x - a.y;
	float wght1 = max(Threshold - d, 0) / Threshold;
	float wght2 = clamp((1-d) + (min(a.x, b.x) + a.x > min(a.y, b.y) + a.y ? diff : -diff), 0, 1);
	return (FilterAA || 2*d < a.x + a.y) ? (wght1 * wght2) * (a.x * a.y) : 0;
}

// corner dominance at junctions
float4 dom(float3 x, float3 y, float3 z, float3 w){
	return 2 * float4(x.y, y.y, z.y, w.y) - (float4(x.x, y.x, z.x, w.x) + float4(x.z, y.z, z.z, w.z));
}

// necessary but not sufficient junction condition for orthogonal edges
bool clear(float2 crn, float2 a, float2 b){
	return (crn.x >= max(min(a.x, a.y), min(b.x, b.y))) && (crn.y >= max(min(a.x, b.y), min(b.x, a.y)));
}

// extract first bool4 from float4 - corners
bool4 loadCorn(float4 x){
	return floor((x*15 + 0.5) % 2);
}

// extract second bool4 from float4 - horizontal edges
bool4 loadHori(float4 x){
	return floor((x*7.5 + 0.25) % 2);
}

// extract third bool4 from float4 - vertical edges
bool4 loadVert(float4 x){
	return floor((x*3.75 + 0.125) % 2);
}

// extract fourth bool4 from float4 - orientation
bool4 loadOr(float4 x){
	return floor((x*1.875 + 0.0625) % 2);
}

// extract corners
float4 loadCrn(float4 x){
	return floor((x*80 + 0.5) % 9);
}

// extract mids
float4 loadMid(float4 x){
	return floor((x*8.888888 + 0.055555) % 9);
}

float3 res2x(float3 pre2, float3 pre1, float3 px, float3 pos1, float3 pos2)
{
	float3 t, m;
	float4x3 pre = float4x3(pre2, pre1,   px, pos1);
	float4x3 pos = float4x3(pre1,   px, pos1, pos2);
	float4x3  df = pos - pre;
	
	m = lerp(px, 1-px, step(px, float3(0.5, 0.5, 0.5)));	
	m = AASharpness * min(m, min(abs(df[1]), abs(df[2])));
	t = (7 * (df[1] + df[2]) - 3 * (df[0] + df[3])) / 16;
	t = clamp(t, -m, m);
   
	return t;
}

float4 pass0(float2 uv : TEXCOORD) : SV_Target
{
	float dx = BUFFER_RCP_WIDTH * Scale;
	float dy = BUFFER_RCP_HEIGHT * Scale;
	float4 t1 = uv.xxxy + float4(-dx, 0, dx, -dy);
	float4 t2 = uv.xxxy + float4(-dx, 0, dx,   0);
	// read texels
	float3 A = tex2D(ColorInput, t1.xw).rgb;
	float3 B = tex2D(ColorInput, t1.yw).rgb;
	float3 C = tex2D(ColorInput, t1.zw).rgb;
	float3 E = tex2D(ColorInput, t2.yw).rgb;
	float3 F = tex2D(ColorInput, t2.zw).rgb;

	// output
	return float4(dist(E,A), dist(E,B), dist(E,C), dist(E,F));
}

float4 pass1(float2 uv : TEXCOORD) : SV_Target
{
	float dx = BUFFER_RCP_WIDTH * Scale;
	float dy = BUFFER_RCP_HEIGHT * Scale;
	float4 t1 = uv.xxxy + float4(-dx, 0, dx, -dy);
	float4 t2 = uv.xxxy + float4(-dx, 0, dx,   0);
	float4 t3 = uv.xxxy + float4(-dx, 0, dx,  dy);
	// metric data
	float4 A = tex2D(ColorInput, t1.xw), B = tex2D(ColorInput, t1.yw);
	float4 D = tex2D(ColorInput, t2.xw), E = tex2D(ColorInput, t2.yw), F = tex2D(ColorInput, t2.zw);
	float4 G = tex2D(ColorInput, t3.xw), H = tex2D(ColorInput, t3.yw), I = tex2D(ColorInput, t3.zw);

	// corner strength
	float4 res;
	res.x = str(D.z, float2(D.w, E.y), float2(A.w, D.y));
	res.y = str(F.x, float2(E.w, E.y), float2(B.w, F.y));
	res.z = str(H.z, float2(E.w, H.y), float2(H.w, I.y));
	res.w = str(H.x, float2(D.w, H.y), float2(G.w, G.y));	

	return res;
}

float4 pass2(float2 uv : TEXCOORD) : SV_Target
{
	float dx = BUFFER_RCP_WIDTH * Scale;
	float dy = BUFFER_RCP_HEIGHT * Scale;
	float4 t1 = uv.xxxy + float4(-dx, 0, dx, -dy);
	float4 t2 = uv.xxxy + float4(-dx, 0, dx,   0);
	float4 t3 = uv.xxxy + float4(-dx, 0, dx,  dy);
	// metric data
	float4 A = tex2D(pass0smp, t1.xw), B = tex2D(pass0smp, t1.yw);
	float4 D = tex2D(pass0smp, t2.xw), E = tex2D(pass0smp, t2.yw), F = tex2D(pass0smp, t2.zw);
	float4 G = tex2D(pass0smp, t3.xw), H = tex2D(pass0smp, t3.yw), I = tex2D(pass0smp, t3.zw);

	// strength data
	float4 As = tex2D(ColorInput, t1.xw), Bs = tex2D(ColorInput, t1.yw), Cs = tex2D(ColorInput, t1.zw);
	float4 Ds = tex2D(ColorInput, t2.xw), Es = tex2D(ColorInput, t2.yw), Fs = tex2D(ColorInput, t2.zw);
	float4 Gs = tex2D(ColorInput, t3.xw), Hs = tex2D(ColorInput, t3.yw), Is = tex2D(ColorInput, t3.zw);

	// strength & dominance junctions
	float4 jSx = float4(As.z, Bs.w, Es.x, Ds.y), jDx = dom(As.yzw, Bs.zwx, Es.wxy, Ds.xyz);
	float4 jSy = float4(Bs.z, Cs.w, Fs.x, Es.y), jDy = dom(Bs.yzw, Cs.zwx, Fs.wxy, Es.xyz);
	float4 jSz = float4(Es.z, Fs.w, Is.x, Hs.y), jDz = dom(Es.yzw, Fs.zwx, Is.wxy, Hs.xyz);
	float4 jSw = float4(Ds.z, Es.w, Hs.x, Gs.y), jDw = dom(Ds.yzw, Es.zwx, Hs.wxy, Gs.xyz);


	// majority vote for ambiguous dominance junctions
	bool4 jx = jDx > 0 && (jDx.yzwx <= 0 && jDx.wxyz <= 0 || jDx + jDx.zwxy > jDx.yzwx + jDx.wxyz);
	bool4 jy = jDy > 0 && (jDy.yzwx <= 0 && jDy.wxyz <= 0 || jDy + jDy.zwxy > jDy.yzwx + jDy.wxyz);
	bool4 jz = jDz > 0 && (jDz.yzwx <= 0 && jDz.wxyz <= 0 || jDz + jDz.zwxy > jDz.yzwx + jDz.wxyz);
	bool4 jw = jDw > 0 && (jDw.yzwx <= 0 && jDw.wxyz <= 0 || jDw + jDw.zwxy > jDw.yzwx + jDw.wxyz);

	// inject strength without creating new contradictions
	bool4 res;
	res.x = jx.z || !(jx.y || jx.w) && jSx.z != 0 && (jx.x || jSx.x + jSx.z > jSx.y + jSx.w);
	res.y = jy.w || !(jy.z || jy.x) && jSy.w != 0 && (jy.y || jSy.y + jSy.w > jSy.x + jSy.z);
	res.z = jz.x || !(jz.w || jz.y) && jSz.x != 0 && (jz.z || jSz.x + jSz.z > jSz.y + jSz.w);
	res.w = jw.y || !(jw.x || jw.z) && jSw.y != 0 && (jw.w || jSw.y + jSw.w > jSw.x + jSw.z);

	// single pixel & end of line detection
	res = res && (bool4(jx.z, jy.w, jz.x, jw.y) || !(res.wxyz && res.yzwx));	


	// output

	bool4 clr;
	clr.x = clear(float2(D.z, E.x), float2(D.w, E.y), float2(A.w, D.y));
	clr.y = clear(float2(F.x, E.z), float2(E.w, E.y), float2(B.w, F.y));
	clr.z = clear(float2(H.z, I.x), float2(E.w, H.y), float2(H.w, I.y));
	clr.w = clear(float2(H.x, G.z), float2(D.w, H.y), float2(G.w, G.y));

	float4 h = float4(min(D.w, A.w), min(E.w, B.w), min(E.w, H.w), min(D.w, G.w));
	float4 v = float4(min(E.y, D.y), min(E.y, F.y), min(H.y, I.y), min(H.y, G.y));

	bool4 or   = h + float4(D.w, E.w, E.w, D.w) > v + float4(E.y, E.y, H.y, H.y);	// orientation
	bool4 hori = h < v && clr;	// horizontal edges
	bool4 vert = h > v && clr;	// vertical edges

	return (float4(res) + 2 * float4(hori) + 4 * float4(vert) + 8 * float4(or)) / 15;
}

float4 pass3(float2 uv : TEXCOORD) : SV_Target
{
	float dx = BUFFER_RCP_WIDTH * Scale;
	float dy = BUFFER_RCP_HEIGHT * Scale;
	float4 t1 = uv.xxxy + float4(-dx, -2*dx, -3*dx,     0);	// D, D0, D1
	float4 t2 = uv.xxxy + float4( dx,  2*dx,  3*dx,     0);	// F, F0, F1
	float4 t3 = uv.xyyy + float4(  0,   -dy, -2*dy, -3*dy);	// B, B0, B1
	float4 t4 = uv.xyyy + float4(  0,    dy,  2*dy,  3*dy);	// H, H0, H1
	// read data
	float4 E = tex2D(pass2smp, uv);
	float4 D = tex2D(pass2smp, t1.xw), D0 = tex2D(pass2smp, t1.yw), D1 = tex2D(pass2smp, t1.zw);
	float4 F = tex2D(pass2smp, t2.xw), F0 = tex2D(pass2smp, t2.yw), F1 = tex2D(pass2smp, t2.zw);
	float4 B = tex2D(pass2smp, t3.xy), B0 = tex2D(pass2smp, t3.xz), B1 = tex2D(pass2smp, t3.xw);
	float4 H = tex2D(pass2smp, t4.xy), H0 = tex2D(pass2smp, t4.xz), H1 = tex2D(pass2smp, t4.xw);

	// extract data
	bool4 Ec = loadCorn(E), Eh = loadHori(E), Ev = loadVert(E), Eo = loadOr(E);
	bool4 Dc = loadCorn(D),	Dh = loadHori(D), Do = loadOr(D), D0c = loadCorn(D0), D0h = loadHori(D0), D1h = loadHori(D1);
	bool4 Fc = loadCorn(F),	Fh = loadHori(F), Fo = loadOr(F), F0c = loadCorn(F0), F0h = loadHori(F0), F1h = loadHori(F1);
	bool4 Bc = loadCorn(B),	Bv = loadVert(B), Bo = loadOr(B), B0c = loadCorn(B0), B0v = loadVert(B0), B1v = loadVert(B1);
	bool4 Hc = loadCorn(H),	Hv = loadVert(H), Ho = loadOr(H), H0c = loadCorn(H0), H0v = loadVert(H0), H1v = loadVert(H1);


	// lvl1 corners (hori, vert)
	bool lvl1x = Ec.x && (Dc.z || Bc.z || FilterCorners);
	bool lvl1y = Ec.y && (Fc.w || Bc.w || FilterCorners);
	bool lvl1z = Ec.z && (Fc.x || Hc.x || FilterCorners);
	bool lvl1w = Ec.w && (Dc.y || Hc.y || FilterCorners);

	// lvl2 mid (left, right / up, down)
	bool2 lvl2x = bool2((Ec.x && Eh.y) && Dc.z, (Ec.y && Eh.x) && Fc.w);
	bool2 lvl2y = bool2((Ec.y && Ev.z) && Bc.w, (Ec.z && Ev.y) && Hc.x);
	bool2 lvl2z = bool2((Ec.w && Eh.z) && Dc.y, (Ec.z && Eh.w) && Fc.x);
	bool2 lvl2w = bool2((Ec.x && Ev.w) && Bc.z, (Ec.w && Ev.x) && Hc.y);

	// lvl3 corners (hori, vert)
	bool2 lvl3x = bool2(lvl2x.y && (Dh.y && Dh.x) && Fh.z, lvl2w.y && (Bv.w && Bv.x) && Hv.z);
	bool2 lvl3y = bool2(lvl2x.x && (Fh.x && Fh.y) && Dh.w, lvl2y.y && (Bv.z && Bv.y) && Hv.w);
	bool2 lvl3z = bool2(lvl2z.x && (Fh.w && Fh.z) && Dh.x, lvl2y.x && (Hv.y && Hv.z) && Bv.x);
	bool2 lvl3w = bool2(lvl2z.y && (Dh.z && Dh.w) && Fh.y, lvl2w.x && (Hv.x && Hv.w) && Bv.y);

	// lvl4 corners (hori, vert)
	bool2 lvl4x = bool2((Dc.x && Dh.y && Eh.x && Eh.y && Fh.x && Fh.y) && (D0c.z && D0h.w), (Bc.x && Bv.w && Ev.x && Ev.w && Hv.x && Hv.w) && (B0c.z && B0v.y));
	bool2 lvl4y = bool2((Fc.y && Fh.x && Eh.y && Eh.x && Dh.y && Dh.x) && (F0c.w && F0h.z), (Bc.y && Bv.z && Ev.y && Ev.z && Hv.y && Hv.z) && (B0c.w && B0v.x));
	bool2 lvl4z = bool2((Fc.z && Fh.w && Eh.z && Eh.w && Dh.z && Dh.w) && (F0c.x && F0h.y), (Hc.z && Hv.y && Ev.z && Ev.y && Bv.z && Bv.y) && (H0c.x && H0v.w));
	bool2 lvl4w = bool2((Dc.w && Dh.z && Eh.w && Eh.z && Fh.w && Fh.z) && (D0c.y && D0h.x), (Hc.w && Hv.x && Ev.w && Ev.x && Bv.w && Bv.x) && (H0c.y && H0v.z));

	// lvl5 mid (left, right / up, down)
	bool2 lvl5x = bool2(lvl4x.x && (F0h.x && F0h.y) && (D1h.z && D1h.w), lvl4y.x && (D0h.y && D0h.x) && (F1h.w && F1h.z));
	bool2 lvl5y = bool2(lvl4y.y && (H0v.y && H0v.z) && (B1v.w && B1v.x), lvl4z.y && (B0v.z && B0v.y) && (H1v.x && H1v.w));
	bool2 lvl5z = bool2(lvl4w.x && (F0h.w && F0h.z) && (D1h.y && D1h.x), lvl4z.x && (D0h.z && D0h.w) && (F1h.x && F1h.y));
	bool2 lvl5w = bool2(lvl4x.y && (H0v.x && H0v.w) && (B1v.z && B1v.y), lvl4w.y && (B0v.w && B0v.x) && (H1v.y && H1v.z));

	// lvl6 corners (hori, vert)
	bool2 lvl6x = bool2(lvl5x.y && (D1h.y && D1h.x), lvl5w.y && (B1v.w && B1v.x));
	bool2 lvl6y = bool2(lvl5x.x && (F1h.x && F1h.y), lvl5y.y && (B1v.z && B1v.y));
	bool2 lvl6z = bool2(lvl5z.x && (F1h.w && F1h.z), lvl5y.x && (H1v.y && H1v.z));
	bool2 lvl6w = bool2(lvl5z.y && (D1h.z && D1h.w), lvl5w.x && (H1v.x && H1v.w));

	
	// subpixels - 0 = E, 1 = D, 2 = D0, 3 = F, 4 = F0, 5 = B, 6 = B0, 7 = H, 8 = H0

	float4 crn;
	crn.x = (lvl1x && Eo.x || lvl3x.x && Eo.y || lvl4x.x && Do.x || lvl6x.x && Fo.y) ? 5 : (lvl1x || lvl3x.y && !Eo.w || lvl4x.y && !Bo.x || lvl6x.y && !Ho.w) ? 1 : lvl3x.x ? 3 : lvl3x.y ? 7 : lvl4x.x ? 2 : lvl4x.y ? 6 : lvl6x.x ? 4 : lvl6x.y ? 8 : 0;
	crn.y = (lvl1y && Eo.y || lvl3y.x && Eo.x || lvl4y.x && Fo.y || lvl6y.x && Do.x) ? 5 : (lvl1y || lvl3y.y && !Eo.z || lvl4y.y && !Bo.y || lvl6y.y && !Ho.z) ? 3 : lvl3y.x ? 1 : lvl3y.y ? 7 : lvl4y.x ? 4 : lvl4y.y ? 6 : lvl6y.x ? 2 : lvl6y.y ? 8 : 0;
	crn.z = (lvl1z && Eo.z || lvl3z.x && Eo.w || lvl4z.x && Fo.z || lvl6z.x && Do.w) ? 7 : (lvl1z || lvl3z.y && !Eo.y || lvl4z.y && !Ho.z || lvl6z.y && !Bo.y) ? 3 : lvl3z.x ? 1 : lvl3z.y ? 5 : lvl4z.x ? 4 : lvl4z.y ? 8 : lvl6z.x ? 2 : lvl6z.y ? 6 : 0;
	crn.w = (lvl1w && Eo.w || lvl3w.x && Eo.z || lvl4w.x && Do.w || lvl6w.x && Fo.z) ? 7 : (lvl1w || lvl3w.y && !Eo.x || lvl4w.y && !Ho.w || lvl6w.y && !Bo.x) ? 1 : lvl3w.x ? 3 : lvl3w.y ? 5 : lvl4w.x ? 2 : lvl4w.y ? 8 : lvl6w.x ? 4 : lvl6w.y ? 6 : 0;

	float4 mid;
	mid.x = (lvl2x.x &&  Eo.x || lvl2x.y &&  Eo.y || lvl5x.x &&  Do.x || lvl5x.y &&  Fo.y) ? 5 : lvl2x.x ? 1 : lvl2x.y ? 3 : lvl5x.x ? 2 : lvl5x.y ? 4 : (Ec.x && Dc.z && Ec.y && Fc.w) ? ( Eo.x ?  Eo.y ? 5 : 3 : 1) : 0;
	mid.y = (lvl2y.x && !Eo.y || lvl2y.y && !Eo.z || lvl5y.x && !Bo.y || lvl5y.y && !Ho.z) ? 3 : lvl2y.x ? 5 : lvl2y.y ? 7 : lvl5y.x ? 6 : lvl5y.y ? 8 : (Ec.y && Bc.w && Ec.z && Hc.x) ? (!Eo.y ? !Eo.z ? 3 : 7 : 5) : 0;
	mid.z = (lvl2z.x &&  Eo.w || lvl2z.y &&  Eo.z || lvl5z.x &&  Do.w || lvl5z.y &&  Fo.z) ? 7 : lvl2z.x ? 1 : lvl2z.y ? 3 : lvl5z.x ? 2 : lvl5z.y ? 4 : (Ec.z && Fc.x && Ec.w && Dc.y) ? ( Eo.z ?  Eo.w ? 7 : 1 : 3) : 0;
	mid.w = (lvl2w.x && !Eo.x || lvl2w.y && !Eo.w || lvl5w.x && !Bo.x || lvl5w.y && !Ho.w) ? 1 : lvl2w.x ? 5 : lvl2w.y ? 7 : lvl5w.x ? 6 : lvl5w.y ? 8 : (Ec.w && Hc.y && Ec.x && Bc.z) ? (!Eo.w ? !Eo.x ? 1 : 5 : 7) : 0;


	// ouput
	return (crn + 9 * mid) / 80;
}

float3 pass4(float2 uv : TEXCOORD) : SV_Target
{
	float dx = BUFFER_RCP_WIDTH * Scale;
	float dy = BUFFER_RCP_HEIGHT * Scale;
	float4 t1 = uv.xxxy + float4( 0, -dx, -2*dx,     0);	// E0, D0, D1
	float4 t2 = uv.xyxy + float4(dx,   0,  2*dx,     0);	// F0, F1
	float4 t3 = uv.xyxy + float4( 0, -dy,     0, -2*dy);	// B0, B1
	float4 t4 = uv.xyxy + float4( 0,  dy,     0,  2*dy);	// H0, H1
	// read data
	float4 E = tex2D(ColorInput, uv);

	// determine subpixel
	float2 fc = frac(uv*tex2Dsize(pass4smp));
	float2 fp = floor(3.0 * fc);

	// check adjacent pixels to prevent artifacts
	float4 hn = tex2D(pass3smp, uv + float2(fp.x - 1, 0) / tex2Dsize(pass4smp));
	float4 vn = tex2D(pass3smp, uv + float2(0, fp.y - 1) / tex2Dsize(pass4smp));

	// extract data
	float4 crn = loadCrn(E), hc = loadCrn(hn), vc = loadCrn(vn);
	float4 mid = loadMid(E), hm = loadMid(hn), vm = loadMid(vn);

	float3 res = fp.y == 0 ? (fp.x == 0 ? float3(crn.x, hc.y, vc.w) : fp.x == 1 ? float3(mid.x, 0, vm.z) : float3(crn.y, hc.x, vc.z)) : (fp.y == 1 ? (fp.x == 0 ? float3(mid.w, hm.y, 0) : fp.x == 1 ? float3(0, 0, 0) : float3(mid.y, hm.w, 0)) : (fp.x == 0 ? float3(crn.w, hc.z, vc.x) : fp.x == 1 ? float3(mid.z, 0, vm.x) : float3(crn.z, hc.w, vc.y)));	

	// reverseAA
	float3 E0 = tex2D(ColorInput, t1.xw);
	float3 B0 = tex2D(ColorInput, t3.xy), B1 = tex2D(ColorInput, t3.zw), H0 = tex2D(ColorInput, t4.xy), H1 = tex2D(ColorInput, t4.zw);
	float3 D0 = tex2D(ColorInput, t1.yw), D1 = tex2D(ColorInput, t1.zw), F0 = tex2D(ColorInput, t2.xy), F1 = tex2D(ColorInput, t2.zw);

	// output coordinate - 0 = E0, 1 = D0, 2 = D1, 3 = F0, 4 = F1, 5 = B0, 6 = B1, 7 = H0, 8 = H1
	float3 sfx = res.x == 1 ? D0 : res.x == 2 ? D1 : res.x == 3 ? F0 : res.x == 4 ? F1 : res.x == 5 ? B0 : res.x == 6 ? B1 : res.x == 7 ? H0 : H1;

	// rAA weight
	float2 w = 2 * fc - 1;
	w.x = res.y == 0 ? w.x : 0;
	w.y = res.z == 0 ? w.y : 0;

	// rAA filter
	float3 t1_other = res2x(D1, D0, E0, F0, F1);
	float3 t2_other = res2x(B1, B0, E0, H0, H1);

	float3 a = min(min(min(min(B0,D0),E0),F0),H0);
	float3 b = max(max(max(max(B0,D0),E0),F0),H0);
	float3 raa = clamp(E0 + w.x*t1_other + w.y*t2_other, a, b);

	// hybrid output
	return (res.x != 0) ? sfx : raa;	
}

float4 pass_final(float2 uv : TEXCOORD) : SV_Target {
	return tex2D(pass4smp, uv);
}


technique ScaleFX
{
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass0;
		RenderTarget = pass0tex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass1;
		RenderTarget = pass1tex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass2;
		RenderTarget = pass2tex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass3;
		RenderTarget = pass3tex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass4;
		RenderTarget = pass4tex;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = pass_final;
	}
}
