
#include "ReShadeUI.fxh"


uniform float Strength <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.1;
> = 0.5;

uniform float Size <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 10;
	ui_step = 0.1;
> = 2;

#include "ReShade.fxh"

float3 DitherPass(float2 uv : TEXCOORD) : SV_Target
{
	float3 im = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 pix = round(uv * tex2Dsize(ReShade::BackBuffer) / Size);
	float3 res = im;
	float m[] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5}; 
	res = im + Strength * (0.0625 * m[int(pix.x % 4 + 4 * (pix.y % 4))] - 0.5);
	return res;
}

technique Dither
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = DitherPass;
	}
}
