#include "ReShade.fxh"

/*
    CRT Shader by EasyMode
    License: GPL
*/


uniform float SIZE <
	ui_type = "drag";
	ui_min = 2;
	ui_max = 10;
	ui_step = 1;
	ui_label = "Size Divisor [CRT-Aperture]";
> = 4;

uniform float SCANLINE_SIZE_MIN <
	ui_type = "drag";
	ui_min = 0.5;
	ui_max = 1.5;
	ui_step = 0.05;
	ui_label = "Scanline Size Min. [CRT-Aperture]";
> = 0.5;

uniform float SCANLINE_SIZE_MAX <
	ui_type = "drag";
	ui_min = 0.5;
	ui_max = 1.5;
	ui_step = 0.05;
	ui_label = "Scanline Size Max. [CRT-Aperture]";
> = 1.5;

uniform float LINE_STRENGTH <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.05;
	ui_label = "Line Strength [CRT-Aperture]";
> = 0.5;

uniform float LINE_BLUR <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 10.0;
	ui_step = 0.05;
	ui_label = "Line Blur [CRT-Aperture]";
> = 0.5;

uniform float GAMMA_INPUT <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Gamma Input [CRT-Aperture]";
> = 2.4;

uniform float GAMMA_OUTPUT <
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 5.0;
	ui_step = 0.1;
	ui_label = "Gamma Output [CRT-Aperture]";
> = 2.4;

uniform float BRIGHTNESS <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.05;
	ui_label = "Brightness [CRT-Aperture]";
> = 1.5;


#define texture_size (tex2Dsize(ReShade::BackBuffer))
#define TEX2D(co) pow(tex2D(ReShade::BackBuffer, co).rgb, GAMMA_INPUT)

float3 get_scanline_weight(float x, float3 col)
{
    float3 beam = lerp(float3(SCANLINE_SIZE_MIN,SCANLINE_SIZE_MIN,SCANLINE_SIZE_MIN), float3(SCANLINE_SIZE_MAX,SCANLINE_SIZE_MAX,SCANLINE_SIZE_MAX), col);
    float3 x_mul = 2.0 / beam;
    float3 x_offset = x_mul * 0.5;
	float b = lerp(LINE_BLUR, 0.5, saturate(4 * dot(col, float3(0.3, 0.7, 0.1))));

    return lerp(1, smoothstep(0.5 - b, 0.5 + b, 1.0 - abs(x * x_mul - x_offset)) * x_offset, LINE_STRENGTH);
}


float4 PS_CRTAperture(float4 vpos : SV_Position, float2 co : TEXCOORD0) : SV_Target
{
	float3 col = TEX2D(co).rgb;
	col *= get_scanline_weight(frac(co.y * texture_size.y / SIZE), col);
	col = pow(col * BRIGHTNESS, 1.0 / GAMMA_OUTPUT);

    return float4(col, 1.0);
}

technique ApertureCRT {
	pass CRT_Aperture {
		VertexShader=PostProcessVS;
		PixelShader=PS_CRTAperture;
	}
}