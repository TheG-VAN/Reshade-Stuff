#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform bool Enabled <
> = true;

uniform int framecount < source = "framecount"; >;

float4 InterlacePass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	if (Enabled) {
		if (framecount % 2 == 0) {
			if (vpos.x % 2 == 0) {
				return tex2Dfetch(ReShade::BackBuffer, vpos.xy);
			}
			return tex2Dfetch(ReShade::BackBuffer, int2(vpos.x - 1, vpos.y));
		} else {
			if (vpos.y % 2 == 0) {
				return tex2Dfetch(ReShade::BackBuffer, vpos.xy);
			}
			return tex2Dfetch(ReShade::BackBuffer, int2(vpos.x, vpos.y - 1));
		}
	} else {
		return tex2Dfetch(ReShade::BackBuffer, vpos.xy);
	}
}


technique Interlace
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = InterlacePass;
	}
}
