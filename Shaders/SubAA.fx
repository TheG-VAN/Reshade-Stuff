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

texture2D wideTex { Width = BUFFER_WIDTH * 3; Height = BUFFER_HEIGHT; };
sampler2D wideSmp { Texture = wideTex; };


float4 Widen(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return tex2D(ReShade::BackBuffer, uv) * float4(floor(vpos.x % 3) == 2, floor(vpos.x % 3) == 1, floor(vpos.x % 3) == 0, 1);
}



float4 SubAAPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return tex2D(wideSmp, uv) + tex2D(wideSmp, uv + float2(1.0 / (3.0 * BUFFER_WIDTH), 0)) + tex2D(wideSmp, uv + float2(2.0 / (3.0 * BUFFER_WIDTH), 0));
}



technique SubAA
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Widen;
		RenderTarget = wideTex;
	}
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = SubAAPass; 
	}

}

