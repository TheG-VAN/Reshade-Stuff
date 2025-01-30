#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float Scale <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;	
	ui_step = 0.01;
> = 1;

uniform int Samples <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;	
	ui_step = 1;
> = 10;


float2 hash22(float2 p)
{
	float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return sin((p3.xx+p3.yz)*p3.zy);

}

float2 hash23(float3 p3)
{
	p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return sin((p3.xx+p3.yz)*p3.zy);
}

uniform float timer < source = "timer"; >;


float3 ExactBlurPass(float2 uv : TEXCOORD) : SV_Target
{
	float4 im;
	for (int i = 0; i < Samples; i++) {
		float2 noise = hash23(float3(uv * 100000, i + frac(timer * 0.00)));
		im += tex2D(ReShade::BackBuffer, uv + float2(sin(noise.x), cos(noise.x)) * noise.y * Scale / BUFFER_SCREEN_SIZE);
	}
	return im / im.a;
}

technique ExactBlur
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ExactBlurPass;
	}
}
