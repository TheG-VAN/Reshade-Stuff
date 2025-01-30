#include "ReShadeUI.fxh"

uniform float Scale <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 10.0;	
	ui_step = 0.001;
> = 5.625;

uniform float Angle <
	ui_type = "drag";
	ui_min = -180;
	ui_max = 180;	
	ui_step = 1;
> = 45;
#include "ReShade.fxh"

float rad(float deg) {
	return deg * 3.14159265359 / 180;
}

float3 RotatePixelsPass(float2 uv : TEXCOORD) : SV_Target {
	float2 pix = floor(uv * BUFFER_SCREEN_SIZE / Scale) + 0.5;
	float2 centre = pix * Scale / BUFFER_SCREEN_SIZE;
	// sin and cos 45 degrees
	float2x2 rotator = float2x2(cos(rad(Angle)), -sin(rad(Angle)), sin(rad(Angle)), cos(rad(Angle)));
	float2x2 unrotator = float2x2(cos(rad(-Angle)), -sin(rad(-Angle)), sin(rad(-Angle)), cos(rad(-Angle)));
	float2 newv = mul(uv, rotator);
	pix = (floor(newv * BUFFER_SCREEN_SIZE / Scale) + 0.5) * Scale / BUFFER_SCREEN_SIZE;
	newv = mul(pix, unrotator);
	//return float3(newv, 0);
	return tex2D(ReShade::BackBuffer, newv);
}

technique RotatePixels
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = RotatePixelsPass;
	}
}
