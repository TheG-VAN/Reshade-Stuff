
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "MotionVectors.fxh"
#include "MotionVectors2.fxh"

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

uniform bool UseBoth <
	ui_type = "checkbox";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 1;
	ui_label = "Use both";
	ui_tooltip = "Use both motion estimation algorithms and pick the best.";
> = 1;

uniform float Persistence <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
> = 0;

texture2D currTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
texture2D prevTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D currColor { Texture = currTex; };
sampler2D prevColor { Texture = prevTex; };
texture2D prevMotionTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D prevMotion { Texture = prevMotionTex; };
texture2D prevMotionTex2 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D prevMotion2 { Texture = prevMotionTex2; };
texture2D multTex { Width = 2; Height = 1; Format = R32F; };
sampler2D mult { Texture = multTex; MagFilter = POINT; };
texture2D multTex2 { Width = 2; Height = 1; Format = R32F; };
sampler2D mult2 { Texture = multTex2; MagFilter = POINT; };
texture2D isNewFrameTex { Width = 1; Height = 1; Format = R8; };
sampler2D isNewFrame { Texture = isNewFrameTex; };
storage2D isNewFrameStorage {Texture = isNewFrameTex; };

float ResetIsNewFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return 0;
}

void SetIsNewFrame(uint3 id : SV_DispatchThreadID, uint3 tid : SV_GroupThreadID)
{
	int2 c = int2(id.x % BUFFER_WIDTH, id.x / BUFFER_WIDTH);
	if (any(tex2Dfetch(ReShade::BackBuffer, c) != tex2Dfetch(prevColor, c))) {
		tex2Dstore(isNewFrameStorage, int2(0, 0), 1);
	}
}

float UpdateMult(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	if (tex2D(isNewFrame, float2(0.5, 0.5)).r != 0) {
		if (uv.x > 0.5) {
			return 1;
		} else {
			return lerp(tex2D(mult2, float2(1, 0)).r, tex2D(mult2, float2(0, 0)).r, Persistence);
		}
	} else {
		if (uv.x > 0.5) {
			return 1 / (1 + 1 / tex2D(mult2, float2(1, 0)).r);
		} else {
			return tex2D(mult2, float2(0, 0)).r;
		}
	}
}

float UpdateMult2(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(mult, uv).r;
}

float4 PS_CopyFrame1(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv);
}


float4 PS_CopyMotion(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	if (tex2D(isNewFrame, float2(0.5, 0.5)).r != 0) {
		float2 m;
		if (distance(tex2D(ReShade::BackBuffer, uv - sampleMotion(uv) * 0.5), tex2D(prevColor, uv + sampleMotion(uv) * 0.5)) < 
			distance(tex2D(ReShade::BackBuffer, uv - sampleMotion2(uv) * 0.5), tex2D(prevColor, uv + sampleMotion2(uv) * 0.5)) || !UseBoth) {
			m = sampleMotion(uv);
		} else {
			m = sampleMotion2(uv);
		}
		float2 shift = uv - m * 0.5;
		if (distance(tex2D(ReShade::BackBuffer, shift) , tex2D(prevColor, shift)) < Threshold ||
			distance(tex2D(ReShade::BackBuffer, uv) , tex2D(prevColor, uv)) < Threshold ||
			distance(tex2D(ReShade::BackBuffer, shift), tex2D(prevColor, uv + sampleMotion(uv) * 0.5)) > Threshold2) {
			return 0;
		}
		return float4(m, 0, 1 - tex2D(mult, float2(0, 0)).r);
	} else {
		return saturate(tex2D(prevMotion2, uv) - float4(0, 0, 0, tex2D(mult, float2(0, 0)).r));
	}
}

float4 PS_CopyMotion2(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(prevMotion, uv);
}


float4 FrameInterpolationDynamicPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float4 m = tex2D(prevMotion, uv);
	return tex2D(ReShade::BackBuffer, uv - m.xy * m.w);
	/*if (UseBoth) {
	return tex2D(isNewFrame, uv).r;
	} else {
	return tex2D(mult, uv).r;
	}*/
}

float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(currColor, uv);
}


technique FrameInterpolationDynamic
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ResetIsNewFrame;
		RenderTarget = isNewFrameTex;
	}
	pass
	{
		ComputeShader = SetIsNewFrame<1024,1>;
		DispatchSizeX = BUFFER_WIDTH * BUFFER_HEIGHT / 1024;
		DispatchSizeY = 1;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = UpdateMult;
		RenderTarget = multTex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = UpdateMult2;
		RenderTarget = multTex2;
	}
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
		PixelShader = FrameInterpolationDynamicPass;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame;
		RenderTarget = prevTex;
	}
}
