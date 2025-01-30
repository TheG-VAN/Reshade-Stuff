
#include "ReShadeUI.fxh"

uniform float Strength <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Amount of effect you want.";
> = 1;

uniform float Size <
	ui_type = "drag";
	ui_min = 2;
	ui_max = 20;
	ui_step = 0.01;
	ui_tooltip = "Size of effect you want.";
> = 8;

uniform float ToneChange <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Amount of variance of effect you want.";
> = 1;

#include "ReShade.fxh"

float3 DepixelatePass(float2 uv : TEXCOORD) : SV_Target
{
	float3 im = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 pix = floor(uv * tex2Dsize(ReShade::BackBuffer));
	float mask = 1 - min(abs(frac((pix.x + pix.y) / Size) * 2 - 1), abs(frac((pix.x - pix.y) / Size) * 2 - 1));
	mask = frac((int(pix.x) ^ int(pix.y)) / Size) - 0.5;
	mask = pow(abs(frac((pix.x + pix.y) / Size) * 2 - 1), 0.5) * pow(abs(frac((pix.x - pix.y) / Size) * 2 - 1), 0.5) - 0.5;
	float m = floor(frac((pix.x / 2 + pix.y * 1.5) / 3) * 3);
	mask = m / 3 - 0.5;
	float3 col = lerp(im, im + mask, Strength);
	
	mask = 1 - pow(length(frac(pix / Size) - 0.5), ToneChange);
	col = lerp(im, im * mask, Strength);
	//col = lerp(col, lerp(col, im, dot(im, float3(0.3, 0.6, 0.2))), ToneChange);
	
	
	
	
	return col;
}

technique Depixelate
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = DepixelatePass;
	}
}
