
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "MotionVectors.fxh"

uniform float Threshold <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 0.25;
	ui_step = 0.001;
	ui_label = "Static threshold";
	ui_tooltip = "Increase to reduce flickering of static elements but also reduces total interpolation.";
> = 0.001;

uniform float Threshold2 <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
	ui_label = "Verification threshold";
	ui_tooltip = "Decrease to make interpolation more accurate but less intense (also causes artifacts).";
> = 0.05;

uniform float Multiplier <
	ui_type = "drag";
	ui_min = 2;
	ui_max = 10;
	ui_step = 1;
	ui_label = "Multiplier";
	ui_tooltip = "How much interpolation (e.g. to turn 30fps to 120, set to 4)";
> = 4;

texture2D currTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
texture2D prevTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D currColor { Texture = currTex; };
sampler2D prevColor { Texture = prevTex; };
texture2D prevMotionTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D prevMotion { Texture = prevMotionTex; };
texture2D prevMotionTex2 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D prevMotion2 { Texture = prevMotionTex2; };

float4 PS_CopyFrame1(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv);
}


float4 PS_CopyMotion(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	if (length(sampleMotion(uv)) > 0) {
		float2 shift = uv - sampleMotion(uv) * 0.5;
		if (distance(tex2D(ReShade::BackBuffer, shift) , tex2D(prevColor, shift)) < Threshold ||
			distance(tex2D(ReShade::BackBuffer, uv) , tex2D(prevColor, uv)) < Threshold ||
			distance(tex2D(ReShade::BackBuffer, shift), tex2D(prevColor, uv + sampleMotion(uv) * 0.5)) > Threshold2) {
			return 0;
		}
		return float4(sampleMotion(uv), 0, 1 - 1 / Multiplier);
	} else {
		return saturate(tex2D(prevMotion2, uv) - float4(0, 0, 0, 1 / Multiplier));
	}
}

float4 PS_CopyMotion2(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(prevMotion, uv);
}


float4 FrameInterpolationMultiPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float4 m = tex2D(prevMotion, uv);
	return tex2D(ReShade::BackBuffer, uv - m.xy * m.w);
}

float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(currColor, uv);
}


technique FrameInterpolationMulti
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame1;
		RenderTarget = currTex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyMotion;
		RenderTarget = prevMotionTex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyMotion2;
		RenderTarget = prevMotionTex2;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = FrameInterpolationMultiPass;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame;
		RenderTarget = prevTex;
	}
}
