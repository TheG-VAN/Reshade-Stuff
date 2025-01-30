#include "ReShadeUI.fxh"
#include "ReShade.fxh"


uniform uint MipLevel <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 20;
	ui_step = 1;
> = 3;

texture Tex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; MipLevels = 8;};
sampler Smp 	{ Texture = Tex; };


float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv);
}

float4 MipMapBlurPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return tex2Dlod(Smp, float4(uv, 0, MipLevel));
}



technique MipMapBlur
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame;
		RenderTarget = Tex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MipMapBlurPass;
	}
}
