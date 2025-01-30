#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform uint Black <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10;
	ui_step = 1;
> = 1;

uniform uint Normal <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10;
	ui_step = 1;
> = 1;

uniform uint framecount < source = "framecount"; >;

float4 BFIPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return tex2D(ReShade::BackBuffer, uv) * (framecount % (Black + Normal) < Normal);
}


technique BlackFrameInsertion
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = BFIPass;
	}
}
