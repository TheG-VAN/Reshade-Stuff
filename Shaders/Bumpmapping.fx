/*
   Bumpmapping shader
   
   Copyright (C) 2019 guest(r) - guest.r@gmail.com

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

#include "ReShadeUI.fxh"
#include "ReShade.fxh"


static const float glow  = 1.25;  // max brightness on borders
static const float shde  = 0.75;  // max darkening
static const float bump  = 2.25;  // effect strenght - lower values bring more effect

sampler Texture00S
{
	Texture = ReShade::BackBufferTex;
	MinFilter = Point; MagFilter = Point;
};

texture Texture01 { Width = 2.0 * BUFFER_WIDTH; Height = 2.0 * BUFFER_HEIGHT; Format = RGBA8; };
sampler Texture01S { Texture = Texture01; };


float3 TWODS0(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
	// Calculating texel coordinates
	float2 ps = 0.5 * ReShade::PixelSize;	

	float x = ps.x;
	float y = ps.y;
	float2 dg1 = float2( x,y);  float2 dg2 = float2(-x,y);
	float2 sd1 = dg1*0.5;     float2 sd2 = dg2*0.5;
	float2 ddx = float2(x,0.0); float2 ddy = float2(0.0,y);

	float3 c11 = tex2D(Texture00S, uv.xy).xyz;
	float3 s00 = tex2D(Texture00S, uv.xy - sd1).xyz; 
	float3 s20 = tex2D(Texture00S, uv.xy - sd2).xyz; 
	float3 s22 = tex2D(Texture00S, uv.xy + sd1).xyz; 
	float3 s02 = tex2D(Texture00S, uv.xy + sd2).xyz; 
	float3 c00 = tex2D(Texture00S, uv.xy - dg1).xyz; 
	float3 c22 = tex2D(Texture00S, uv.xy + dg1).xyz; 
	float3 c20 = tex2D(Texture00S, uv.xy - dg2).xyz;
	float3 c02 = tex2D(Texture00S, uv.xy + dg2).xyz;
	float3 c10 = tex2D(Texture00S, uv.xy - ddy).xyz; 
	float3 c21 = tex2D(Texture00S, uv.xy + ddx).xyz; 
	float3 c12 = tex2D(Texture00S, uv.xy + ddy).xyz; 
	float3 c01 = tex2D(Texture00S, uv.xy - ddx).xyz;     
	float3 dt = float3(1.0,1.0,1.0);

	float d1=dot(abs(c00-c22),dt)+0.0001;
	float d2=dot(abs(c20-c02),dt)+0.0001;
	float hl=dot(abs(c01-c21),dt)+0.0001;
	float vl=dot(abs(c10-c12),dt)+0.0001;
	float m1=dot(abs(s00-s22),dt)+0.0001;
	float m2=dot(abs(s02-s20),dt)+0.0001;

	float3 t1=(hl*(c10+c12)+vl*(c01+c21)+(hl+vl)*c11)/(3.0*(hl+vl));
	float3 t2=(d1*(c20+c02)+d2*(c00+c22)+(d1+d2)*c11)/(3.0*(d1+d2));
	
	c11 =.25*(t1+t2+(m2*(s00+s22)+m1*(s02+s20))/(m1+m2));
	
	return c11;
} 


float3 BUMP(float4 pos : SV_Position, float2 uv : TexCoord) : SV_Target
{
	const float3 dt = float3(1.0,1.0,1.0);

	// Calculating texel coordinates
	float2 inv_size = 0.8 * ReShade::PixelSize;	

	float2 dx = float2(inv_size.x,0.0);
	float2 dy = float2(0.0, inv_size.y);
	float2 g1 = float2(inv_size.x,inv_size.y);
	// float2 g2 = float2(-inv_size.x,inv_size.y);
	
	float2 pC4 = uv;	
	
	// Reading the texels
	float3 c00 = tex2D(Texture01S,uv - g1).rgb; 
	float3 c10 = tex2D(Texture01S,uv - dy).rgb;
	// float3 c20 = tex2D(Texture01S,uv - g2).rgb;
	float3 c01 = tex2D(Texture01S,uv - dx).rgb;
	float3 c11 = tex2D(Texture01S,uv     ).rgb;
	float3 c21 = tex2D(Texture01S,uv + dx).rgb;
	// float3 c02 = tex2D(Texture01S,uv + g2).rgb;
	float3 c12 = tex2D(Texture01S,uv + dy).rgb;
	float3 c22 = tex2D(Texture01S,uv + g1).rgb;
	
	float3 d11 = c11;

	c11 = (-c00+c22-c01+c21-c10+c12+bump*d11)/bump;
	c11 = min(c11,glow*d11);
	c11 = max(c11,shde*d11);
	
	return c11;
}

technique BUMPMAPPING
{
	pass bump1
	{
		VertexShader = PostProcessVS;
		PixelShader = TWODS0;
		RenderTarget = Texture01; 		
	}
	pass bump2
	{
		VertexShader = PostProcessVS;
		PixelShader = BUMP;
	}
}
