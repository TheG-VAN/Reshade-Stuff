
#include "ReShadeUI.fxh"


uniform float X_OFFSET <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 20;
	ui_step = 1;
	ui_tooltip = "Number of pixels to offset in x.";
> = 2;

uniform float Y_OFFSET <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 20;
	ui_step = 1;
	ui_tooltip = "Number of pixels to offset in y.";
> = 2;

#include "ReShade.fxh"

float3 DeditherPass(float2 uv : TEXCOORD) : SV_Target
{
	float3 C = tex2D(ReShade::BackBuffer, uv).rgb;
	float xoff = X_OFFSET / tex2Dsize(ReShade::BackBuffer).x;
	float yoff = Y_OFFSET / tex2Dsize(ReShade::BackBuffer).y;
	float3 L = tex2D(ReShade::BackBuffer, uv + float2(xoff, 0)).rgb;
	float3 R = tex2D(ReShade::BackBuffer, uv - float2(xoff, 0)).rgb;
	float3 U = tex2D(ReShade::BackBuffer, uv + float2(0, yoff)).rgb;
	float3 D = tex2D(ReShade::BackBuffer, uv - float2(0, yoff)).rgb;
	float ditherx = all(L == R) && C != L;
	float dithery = all(U == D) && C != U;
	float3 res = C;
	if (ditherx && dithery) {
		res = 0.33 * (L + U + C);
	} else if (ditherx) {
		res = 0.5 * (L + C);
	} else if (dithery) {
		res = 0.5 * (U + C);
	}
	return res;
}

technique Dedither
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = DeditherPass;
	}
}
