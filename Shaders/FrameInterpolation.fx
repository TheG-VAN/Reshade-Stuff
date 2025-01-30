
#include ".\MartysMods\mmx_deferred.fxh"
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "MotionVectors.fxh"
#include "MotionVectors2.fxh"
#ifndef UsePreviousFrame
    #define UsePreviousFrame 1
#endif

#ifndef UseBothMotionEstimationAlgorithms
    #define UseBothMotionEstimationAlgorithms 0
#endif

#if UsePreviousFrame

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
	> = 0.1;

#endif

uniform bool SHOWME <
	ui_label = "Debug Output";	
> = false;

texture2D currTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
texture2D prevTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D currColor { Texture = currTex; };
sampler2D prevColor { Texture = prevTex; };

sampler sMotionVectorTex         { Texture = texMotionVectors;  };

float4 PS_CopyFrame1(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv);
}

float4 FrameInterpolationPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 m = tex2D(sMotionVectorTex, uv);//Deferred::get_motion(uv);
	if (SHOWME) return float4(m * 100, (m.x + m.y) * -100, 1);
	#if UseBothMotionEstimationAlgorithms
		if (distance(tex2D(ReShade::BackBuffer, uv - sampleMotion(uv) * 0.5), tex2D(prevColor, uv + sampleMotion(uv) * 0.5)) >
			distance(tex2D(ReShade::BackBuffer, uv - sampleMotion2(uv) * 0.5), tex2D(prevColor, uv + sampleMotion2(uv) * 0.5))) {
			m = sampleMotion2(uv);
		}
	#endif
	float2 shift = uv - m * 0.5;
	float4 im = tex2D(ReShade::BackBuffer, uv);
	float4 shifted = tex2D(ReShade::BackBuffer, shift);
	#if UsePreviousFrame
		if (distance(shifted, tex2D(prevColor, shift)) < Threshold ||
			distance(im, tex2D(prevColor, uv)) < Threshold ||
			distance(shifted, tex2D(prevColor, uv + m * 0.5)) > Threshold2) {
			return im;
		}
		if (distance(shifted, im) < distance(tex2D(prevColor, uv + m * 0.5), im)) {
			return shifted;
		} else {
			return tex2D(prevColor, uv + m * 0.5);
		}
	#endif
	//return shifted;
}

float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(currColor, uv);
}


technique FrameInterpolation
{
	#if UsePreviousFrame
		pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS_CopyFrame1;
			RenderTarget = currTex;
		}
	#endif
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = FrameInterpolationPass;
	}
	#if UsePreviousFrame
		pass
		{
			VertexShader = PostProcessVS;
			PixelShader = PS_CopyFrame;
			RenderTarget = prevTex;
		}
	#endif
}
