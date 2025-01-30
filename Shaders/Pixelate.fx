
#include "ReShadeUI.fxh"

uniform float Size <
	ui_type = "drag";
	ui_min = 2;
	ui_max = 20;
	ui_step = 1;
	ui_tooltip = "Size of effect you want.";
> = 4;

uniform float Sharpness <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Sharpness of effect you want.";
> = 0;


#include "ReShade.fxh"

float3 PixelatePass(float2 uv : TEXCOORD) : SV_Target
{
	float2 pix = (floor(uv * tex2Dsize(ReShade::BackBuffer) / Size) + 0.5) * Size / tex2Dsize(ReShade::BackBuffer);
	float2 pix2 = (floor(uv * tex2Dsize(ReShade::BackBuffer) / Size)) * Size;
	float3 im = float3(0, 0, 0);
	for (int i = pix2.x; i < pix2.x + Size; i++) {
		for (int j = pix2.y; j < pix2.y + Size; j++) {
			im += tex2D(ReShade::BackBuffer, float2(i, j) / tex2Dsize(ReShade::BackBuffer)).rgb;
		}
	}
	im = lerp(im / (Size * Size), tex2D(ReShade::BackBuffer, pix).rgb, Sharpness);
	return im;
}

technique Pixelate
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PixelatePass;
	}
}
