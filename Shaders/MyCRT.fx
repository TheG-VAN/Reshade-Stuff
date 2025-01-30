
#include "ReShadeUI.fxh"

uniform float Strength <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Amount of effect you want.";
> = 0.5;

uniform float Y_Influence <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 10;
	ui_step = 0.01;
	ui_tooltip = "Amount of y you want.";
> = 3;

uniform float Size <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;
	ui_step = 1;
	ui_tooltip = "Size of effect you want.";
> = 2;

uniform float LineSize <
	ui_type = "drag";
	ui_min = 2;
	ui_max = 20;
	ui_step = 1;
	ui_tooltip = "Size of effect you want.";
> = 4;

uniform float LineBlur <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.05;
	ui_tooltip = "Blur of effect you want.";
> = 0.5;

uniform float LineStrength <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Amount of effect you want.";
> = 0;

uniform float ToneChange <
	ui_type = "drag";
	ui_min = 0; 
	ui_max = 1;
	ui_step = 0.01;
	ui_tooltip = "Amount of variance of effect you want.";
> = 0;


#include "ReShade.fxh"

float3 MyCRTPass(float2 uv : TEXCOORD) : SV_Target
{
	float3 im = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 pix = floor(uv * tex2Dsize(ReShade::BackBuffer)) / Size;
	float m = floor(frac((pix.x + pix.y * Y_Influence) / 3) * 3);
	float3 mask = float3(saturate(1 - m), saturate(1 - abs(m - 1)), saturate(1 - abs(m - 2)));
	float3 col = lerp(im, im * mask, Strength);
	
	float l = smoothstep(- LineBlur, 1 + LineBlur, 2 * abs(frac(pix.y / LineSize) - 0.5));
	col = lerp(col, col * l, LineStrength);
	
	col = lerp(col, lerp(col, im, dot(im, float3(0.3, 0.6, 0.2))), ToneChange);
	
	return col;
}

technique MyCRT
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MyCRTPass;
	}
}
