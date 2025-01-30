#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform int Radius <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 10;
	ui_step = 1;
> = 1;

uniform int Threshold <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 100;
	ui_step = 1;
> = 1;

uniform float Alpha <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 1;
	ui_step = 0.01;
> = 1;


#ifndef RESOLUTION_DIVIDER
 #define RESOLUTION_DIVIDER	1
#endif

texture tex          { Width = BUFFER_WIDTH / RESOLUTION_DIVIDER;   Height = BUFFER_HEIGHT / RESOLUTION_DIVIDER;   Format = RGBA8; MipLevels = 8; };
sampler stex         { Texture = tex; MagFilter = POINT; };

float4 Pass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	int newCols = 0;
	float4 arr[100];
	for (int x = -Radius; x <= Radius; x++)
	for (int y = -Radius; y <= Radius; y++) {
		float4 col = tex2Dfetch(ReShade::BackBuffer, (vpos.xy + int2(x, y)) * RESOLUTION_DIVIDER);
		if (all(col.xyz == 0 || col.xyz == 1)) continue;
		bool seen = false;
		for (int i = 0; i <= newCols; i++) {
			if (all(col == arr[i])) {
				seen = true;
				break;
			}
		}
		if (seen == 0) {
			arr[newCols++] = col;
		}
	}
	if (newCols < Threshold) return 0;
	return float(newCols) / 100.0;
}

float4 Up(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	return lerp(tex2D(ReShade::BackBuffer, uv), tex2D(stex, uv), Alpha);
}



technique London
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Pass;
		RenderTarget = tex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = Up;
	}
}
