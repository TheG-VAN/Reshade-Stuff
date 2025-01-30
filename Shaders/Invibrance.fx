
#include "ReShadeUI.fxh"

uniform float Strength < 
	ui_type = "drag";
	ui_min = -1.0; ui_max = 10;
	ui_step = 0.1;
> = 0.15;

uniform float Power < 
	ui_type = "drag";
	ui_min = 0; ui_max = 10;
	ui_step = 0.1;
> = 2;

uniform float Persistence < 
	ui_type = "drag";
	ui_min = 0; ui_max = 1;
	ui_step = 0.01;
> = 0.95;


#include "ReShade.fxh"

texture2D avgTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; MipLevels = 11; };
sampler2D avgColor { Texture = avgTex; };
texture2D avgTex2 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D avgColor2 { Texture = avgTex; };


float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return lerp(tex2D(ReShade::BackBuffer, uv), tex2D(avgColor2, uv), Persistence);
}

float4 PS_CopyFrame2(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(avgColor, uv);
}

float3 VibrancePass(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
	
	float3 coefLuma = float3(0.212656, 0.715158, 0.072186);
	
	float luma = dot(coefLuma, color);

	float max_color = max(color.r, max(color.g, color.b));
	float min_color = min(color.r, min(color.g, color.b));

	float saturation = max_color - min_color;
	
	float3 avg = tex2Dlod(avgColor, float4(texcoord.x, texcoord.y, 0, 11)).rgb;
	
	float max_color2 = max(avg.r, max(avg.g, avg.b));
	float min_color2 = min(avg.r, min(avg.g, avg.b));

	float saturation2 = max_color2 - min_color2;
	
	return lerp(luma, color, 1.0 + Strength * pow(abs(saturation - saturation2), Power) * sign(saturation - saturation2));//pow(saturation, Power));
}

technique Invibrance
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame;
		RenderTarget = avgTex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame2;
		RenderTarget = avgTex2;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = VibrancePass;
	}
}
