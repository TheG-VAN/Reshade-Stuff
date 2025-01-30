
#include "ReShadeUI.fxh"
#include "ReShade.fxh"
#include "MotionVectors.fxh"
#include "MotionVectors2.fxh"

uniform float Persistence <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
> = 0;

uniform float2 Location <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
> = float2(0, 0);

uniform float2 Size <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
> = float2(0.05, 0.05);

uniform float3 Colour <
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 0.001;
> = float3(0, 1, 0.8);

uniform int Shadow <
	ui_type = "drag";
	ui_min = 0;
	ui_max = 10;
	ui_step = 1;
> = 2;

uniform bool UseMult <
	ui_type = "checkbox";
	ui_min = 0.0;
	ui_max = 1;
	ui_step = 1;
	ui_label = "Underlying FPS";
	ui_tooltip = "Set to give the FPS of the game/video. Otherwise gives the FPS of the window itself.";
> = 1;

texture2D currTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
texture2D prevTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; };
sampler2D currColor { Texture = currTex; };
sampler2D prevColor { Texture = prevTex; };
texture2D multTex { Width = 2; Height = 1; Format = R32F; };
sampler2D mult { Texture = multTex; MagFilter = POINT; };
texture2D multTex2 { Width = 2; Height = 1; Format = R32F; };
sampler2D mult2 { Texture = multTex2; MagFilter = POINT; };
texture2D ftTex { Width = 1; Height = 1; Format = R32F; };
sampler2D ft { Texture = ftTex; MagFilter = POINT; };
texture2D ftTex2 { Width = 1; Height = 1; Format = R32F; };
sampler2D ft2 { Texture = ftTex2; MagFilter = POINT; };
texture2D isNewFrameTex { Width = 1; Height = 1; Format = R8; };
sampler2D isNewFrame { Texture = isNewFrameTex; };
storage2D isNewFrameStorage {Texture = isNewFrameTex; };

uniform float frametime < source = "frametime"; >;

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
			float prev = tex2D(mult2, float2(0, 0)).r;
			float curr = tex2D(mult2, float2(1, 0)).r;
			float a = lerp(saturate(Persistence - 0.1), Persistence, saturate(prev * 1.5));
			a = lerp(a, 0, saturate(abs(1 / prev - 1 / curr) / 100));
			return lerp(curr, prev, a);
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

float UpdateFt(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return lerp(1 / frametime, tex2D(ft2, uv).r, Persistence);
}

float UpdateFt2(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ft, uv).r;
}

float4 PS_CopyFrame1(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(ReShade::BackBuffer, uv);
}

uint PrintInt(float2 uv, int value)
{
	int font[] = {0x75557, 0x22222, 0x71747, 0x74747, 0x47511, 0x74717, 0x75717, 0x44447, 0x75757, 0x74757};
	int powers[] = {1, 10, 100, 1000, 10000, 100000, 1000000};
	int maxDigits = ceil(log10(value + 1));
    if( abs(uv.y-0.5)<0.5 )
    {
        int iu = int(floor(uv.x));
        if( iu>=0 && iu<maxDigits )
        {
            int n = (value/powers[maxDigits-iu-1]) % 10;
			float2 uv2 = uv;
            uv2.x = frac(uv.x); 
            int2 p = int2(floor(uv2*float2(4.0,5.0)));
			if ((font[n] >> (p.x+p.y*4)) & 1) {
				return 1;
			}
        }
    }
	
	if (Shadow) {
		for (float x = -Shadow; x <= Shadow; x += Shadow)
		for (float y = -Shadow; y <= Shadow; y += Shadow) {
			float2 newv = uv + float2(x / BUFFER_WIDTH, y / BUFFER_HEIGHT) / (Size / float2(1.6, 0.7) / 2);
			if( abs(newv.y-0.5)<0.5 )
			{
				int iu = int(floor(newv.x));
				if( iu>=0 && iu<maxDigits )
				{
					int n = (value/powers[maxDigits-iu-1]) % 10;
					newv.x = frac(newv.x); 
					int2 p = int2(floor(newv*float2(4.0,5.0)));
					if ((font[n] >> (p.x+p.y*4)) & 1) {
						return 0;
					}
				}
			}
		}
	}
    discard;
}

float3 FPSCounterPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	uv = (uv - Location) / Size;
	return Colour * PrintInt((2 * uv - 1) * float2(1.6, 0.7) + float2(1.38,0.5), 1000 * lerp(1, tex2D(mult, float2(0, 0)).r, UseMult) * tex2D(ft, float2(0, 0)).r);
}

float4 PS_CopyFrame(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return tex2D(currColor, uv);
}


technique FPSCounter
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
		PixelShader = UpdateFt;
		RenderTarget = ftTex;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = UpdateFt2;
		RenderTarget = ftTex2;
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
		PixelShader = FPSCounterPass;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_CopyFrame;
		RenderTarget = prevTex;
	}
}
