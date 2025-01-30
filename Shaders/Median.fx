
#include "ReShadeUI.fxh"


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

uniform int MaxAttempts <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;	
	ui_step = 1;
> = 10;

#include "ReShade.fxh"

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


float3 MedianPass(float2 uv : TEXCOORD) : SV_Target
{
	float3 best_candidate;
	float min_lts = Samples + 1;
	for (int i = 0; i < MaxAttempts; i++) {
		float3 candidate = tex2D(ReShade::BackBuffer, uv + hash23(float3(uv * 10000, (i + 1) * timer * 0.0001)) * Scale * rcp(BUFFER_SCREEN_SIZE)).rgb;
		float luminance = dot(candidate, float3(0.299, 0.587, 0.114));
		int lts = 0;
		for (int s = 0; s < Samples; s++) {
			float3 sam = tex2D(ReShade::BackBuffer, uv + hash23(float3(uv * 10000, hash22(float2(i + 1, s + 1) * timer * 0.0001).x)) * Scale * rcp(BUFFER_SCREEN_SIZE)).rgb;
			if (dot(sam, float3(0.299, 0.587, 0.114)) < luminance) {
				lts++;
			} else if (dot(sam, float3(0.299, 0.587, 0.114)) > luminance) {
				lts--;
			}
		}
		if (abs(lts) < min_lts) {
			best_candidate = candidate;
			min_lts = abs(lts);
		}
	}
	return best_candidate;
}

technique Median
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MedianPass;
	}
}
