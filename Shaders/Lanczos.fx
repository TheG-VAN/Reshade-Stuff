#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float Scale <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;
	ui_step = 0.1;
> = 2;

uniform bool Show <
> = true;

#define FIX(c) max(abs(c), 1e-5);
#define PI 3.1415926535897932384626433832795

float3 weight3(float x)
{
	const float radius = 3.0;
	float3 s = FIX(2.0 * PI * float3(x - 1.5, x - 0.5, x + 0.5));

	// Lanczos3. Note: we normalize outside this function, so no point in multiplying by radius.
	return sin(s) * sin(s / radius) / (s * s);
}

float3 pixel(float xpos, float ypos)
{
	return tex2D(ReShade::BackBuffer, float2(xpos, ypos)).rgb;
}

float3 line(float ypos, float3 xpos1, float3 xpos2, float3 linetaps1, float3 linetaps2)
{
	return
		pixel(xpos1.r, ypos) * linetaps1.r +
		pixel(xpos1.g, ypos) * linetaps2.r +
		pixel(xpos1.b, ypos) * linetaps1.g +
		pixel(xpos2.r, ypos) * linetaps2.g +
		pixel(xpos2.g, ypos) * linetaps1.b +
		pixel(xpos2.b, ypos) * linetaps2.b;
}


float4 LanczosPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 stepxy = 1.0 / BUFFER_SCREEN_SIZE * Scale;
	float2 pos = uv + stepxy * 0.5;
	float2 f = frac(pos / stepxy);

	float3 linetaps1   = weight3(0.5 - f.x * 0.5);
	float3 linetaps2   = weight3(1.0 - f.x * 0.5);
	float3 columntaps1 = weight3(0.5 - f.y * 0.5);
	float3 columntaps2 = weight3(1.0 - f.y * 0.5);

	// make sure all taps added together is exactly 1.0, otherwise some
	// (very small) distortion can occur
	float suml = dot(linetaps1, 1) + dot(linetaps2, 1);
	float sumc = dot(columntaps1, 1) + dot(columntaps2, 1);
	linetaps1 /= suml;
	linetaps2 /= suml;
	columntaps1 /= sumc;
	columntaps2 /= sumc;

	float2 xystart = (-2.5 - f) * stepxy + pos;
	float3 xpos1 = float3(xystart.x, xystart.x + stepxy.x, xystart.x + stepxy.x * 2.0);
	float3 xpos2 = float3(xystart.x + stepxy.x * 3.0, xystart.x + stepxy.x * 4.0, xystart.x + stepxy.x * 5.0);

	if (Show) {
	return float4(
		line(xystart.y                 , xpos1, xpos2, linetaps1, linetaps2) * columntaps1.r +
		line(xystart.y + stepxy.y      , xpos1, xpos2, linetaps1, linetaps2) * columntaps2.r +
		line(xystart.y + stepxy.y * 2.0, xpos1, xpos2, linetaps1, linetaps2) * columntaps1.g +
		line(xystart.y + stepxy.y * 3.0, xpos1, xpos2, linetaps1, linetaps2) * columntaps2.g +
		line(xystart.y + stepxy.y * 4.0, xpos1, xpos2, linetaps1, linetaps2) * columntaps1.b +
		line(xystart.y + stepxy.y * 5.0, xpos1, xpos2, linetaps1, linetaps2) * columntaps2.b,
		1.0);
	} else {
		return tex2D(ReShade::BackBuffer, uv);
	}
}

float4 Downsample(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 pix2 = (floor(uv * BUFFER_SCREEN_SIZE / Scale)) * Scale;
	float4 im;
	for (int i = -Scale * 0.5; i < Scale * 0.5; i++) {
		for (int j = -Scale * 0.5; j < Scale * 0.5; j++) {
			im += tex2D(ReShade::BackBuffer, uv + float2(i, j) / BUFFER_SCREEN_SIZE);
		}
	}
	return im / im.a;
}


technique Lanczos
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = Downsample; 
	}
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = LanczosPass; 
	}

}

