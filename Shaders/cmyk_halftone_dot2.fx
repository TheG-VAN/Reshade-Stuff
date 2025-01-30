#include "ReShade.fxh"


/*
CMYK Halftone Dot Shader

Adapted from Stefan Gustavson's GLSL shader demo for WebGL:
http://webstaff.itn.liu.se/~stegu/OpenGLinsights/shadertutorial.html

Ported to Cg shader language by hunterk

This shader is licensed in the public domain, as per S. Gustavson's original license.
Note: the MIT-licensed noise functions have been purposely removed.
*/

uniform float frequency <
	ui_type = "drag";
	ui_min = 50.0;
	ui_max = 1000.0;
	ui_step = 1.0;
	ui_label = "HalfTone Dot Density [CMYK HalfTone]";
> = 550.0;

uniform float Intensity <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.05;
	ui_label = "HalfTone Dot Intensity [CMYK HalfTone]";
> = 1;

uniform float Variation <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.05;
	ui_label = "HalfTone Dot Variation [CMYK HalfTone]";
> = 0.25;

uniform float Sparsity <
	ui_type = "drag";
	ui_min = 0.1;
	ui_max = 4;
	ui_step = 0.1;
	ui_label = "HalfTone Dot Sparsity [CMYK HalfTone]";
> = 1;

sampler2D SamplerColorPoint
{
	Texture = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};

float3 PS_cymk_halftone_dot(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Distance to nearest point in a grid of
	// (frequency x frequency) points over the unit square
	float2x2 rotation_matrix = float2x2(0.707, 0.707, -0.707, 0.707);
	float2 st2 = mul(rotation_matrix , texcoord * float2(1, ReShade::ScreenSize.y / ReShade::ScreenSize.x));
    float2 nearest = 2.0 * frac(frequency * st2) - 1.0;
    float dist = length(nearest);
    float3 texcolor = tex2D(SamplerColorPoint, texcoord).rgb; // Unrotated coords
    float3 black = float3(0,0,0);
	
	// Perform a rough RGB-to-CMYK conversion
    float4 cmyk;
    cmyk.xyz = 1.0 - texcolor;
    cmyk.w = min(cmyk.x, min(cmyk.y, cmyk.z)); // Create K
	
	float2x2 k_matrix = float2x2(0.707, 0.707, -0.707, 0.707);
	float2 Kst = frequency * (0.48 * (ReShade::ScreenSize / ReShade::ScreenSize)) * mul(k_matrix , texcoord);
    float2 Kuv = 2.0 * frac(Kst) - 1.0;
    float k = smoothstep(0, 1, sqrt(cmyk.w) - length(Kuv));
	float2x2 c_matrix = float2x2(0.966, 0.259, -0.259, 0.966);
    float2 Cst = frequency * (0.48 * (ReShade::ScreenSize / ReShade::ScreenSize)) * mul(c_matrix , texcoord);
    float2 Cuv = 2.0 * frac(Cst) - 1.0;
    float c = smoothstep(0, 1, sqrt(cmyk.x) - length(Cuv));
	float2x2 m_matrix = float2x2(0.966, -0.259, 0.259, 0.966);
    float2 Mst = frequency * (0.48 * (ReShade::ScreenSize / ReShade::ScreenSize)) * mul(m_matrix , texcoord);
    float2 Muv = 2.0 * frac(Mst) - 1.0;
    float m = smoothstep(0, 1, sqrt(cmyk.y) - length(Muv));
    float2 Yst = frequency * (0.48 * (ReShade::ScreenSize / ReShade::ScreenSize)) * texcoord; // 0 deg
    float2 Yuv = 2.0 * frac(Yst) - 1.0;
    float y = smoothstep(0, 1, sqrt(cmyk.z) - length(Yuv));
	
	float3 rgbscreen = 1.0 - 0.9 * float3(c,m,y);
	rgbscreen = lerp(rgbscreen, black, 0.85 * k);
	
    float4 color = float4(lerp(texcolor , rgbscreen, Intensity), 1.0);
	color = (max(texcolor.r, max(texcolor.g, texcolor.b)) < 0.01) ? float4(0,0,0,0) : color; // make blacks actually black
	
	float d = lerp(0.5 + Variation, 0.5 - Variation, dot(texcolor, float3(0.3, 0.6, 0.2)));
	float b = step(d, length(Sparsity * frac(st2 * frequency) - 0.5));
	texcolor = lerp(texcolor, texcolor * b, Intensity);

	return texcolor;
}

technique CMYK_Halftone2
{
	pass CMYK
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_cymk_halftone_dot;
	}
}