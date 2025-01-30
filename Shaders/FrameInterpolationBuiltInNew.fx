/*=============================================================================
This work is licensed under the 
Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) License
https://creativecommons.org/licenses/by-nc/4.0/	  

Original developer: Jak0bPCoder
Optimization by : Marty McFly
Compatibility by : MJ_Ehsan
=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/
 
#define UI_ME_LAYER_MIN                                 6
#define UI_ME_MAX_ITERATIONS_PER_LEVEL                  2
#define UI_ME_SAMPLES_PER_ITERATION                     5

#ifndef UsePreviousFrame
    #define UsePreviousFrame 1
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

uniform int UI_ME_LAYER_MAX <
	ui_type = "drag";
	ui_label = "Resolution divider";
	ui_tooltip = "0 = Full, 1 = Half, 2 = Quarter etc.";
	ui_min = 0;
	ui_max = 5;	
	ui_step = 1;
> = 2;

uniform float UI_ME_PYRAMID_UPSCALE_FILTER_RADIUS <
	ui_type = "drag";
	ui_label = "Filter Smoothness";
	ui_min = 0.0;
	ui_max = 6.0;	
	ui_step = 0.001;
> = 4.0;

uniform bool SHOWME <
	ui_label = "Debug Output";	
> = false;

/*=============================================================================
	Textures, Samplers, Globals, Structs
=============================================================================*/

texture ColorInputTex : COLOR;
sampler ColorInput 	{ Texture = ColorInputTex; };

#include "ReShadeUI.fxh"
#include "ReShade.fxh"

#ifndef PRE_BLOCK_SIZE_2_TO_7
 #define PRE_BLOCK_SIZE_2_TO_7	3   
#endif

#define BLOCK_SIZE (PRE_BLOCK_SIZE_2_TO_7)

//NEVER change these!!!
#define BLOCK_SIZE_HALF (BLOCK_SIZE * 0.5 - 0.5)
#define BLOCK_AREA 		(BLOCK_SIZE * BLOCK_SIZE)

uniform uint FRAME_COUNT < source = "framecount"; >;

texture GreyscaleCurr          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = R16F; MipLevels = 8; };
sampler sGreyscaleCurr         { Texture = GreyscaleCurr;  };
texture GreyscalePrev          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = R16F; MipLevels = 8; };
sampler sGreyscalePrev         { Texture = GreyscalePrev;   };

texture texMotionVectors          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RG16F; };
sampler sMotionVectorTex         { Texture = texMotionVectors;  };

texture MotionTexCur7               { Width = BUFFER_WIDTH >> 7;   Height = BUFFER_HEIGHT >> 7;   Format = RGBA16F;  };
sampler sMotionTexCur7              { Texture = MotionTexCur7;};
texture MotionTexCur6               { Width = BUFFER_WIDTH >> 6;   Height = BUFFER_HEIGHT >> 6;   Format = RGBA16F;  };
sampler sMotionTexCur6              { Texture = MotionTexCur6;};
texture MotionTexCur5               { Width = BUFFER_WIDTH >> 5;   Height = BUFFER_HEIGHT >> 5;   Format = RGBA16F;  };
sampler sMotionTexCur5              { Texture = MotionTexCur5;};
texture MotionTexCur4               { Width = BUFFER_WIDTH >> 4;   Height = BUFFER_HEIGHT >> 4;   Format = RGBA16F;  };
sampler sMotionTexCur4              { Texture = MotionTexCur4;};
texture MotionTexCur3               { Width = BUFFER_WIDTH >> 3;   Height = BUFFER_HEIGHT >> 3;   Format = RGBA16F;  };
sampler sMotionTexCur3              { Texture = MotionTexCur3;};
texture MotionTexCur2               { Width = BUFFER_WIDTH >> 2;   Height = BUFFER_HEIGHT >> 2;   Format = RGBA16F;  };
sampler sMotionTexCur2              { Texture = MotionTexCur2;};
texture MotionTexCur1               { Width = BUFFER_WIDTH >> 1;   Height = BUFFER_HEIGHT >> 1;   Format = RGBA16F;  };
sampler sMotionTexCur1              { Texture = MotionTexCur1;};
texture MotionTexCur0               { Width = BUFFER_WIDTH >> 0;   Height = BUFFER_HEIGHT >> 0;   Format = RGBA16F;  };
sampler sMotionTexCur0              { Texture = MotionTexCur0;};

struct VSOUT
{
    float4 vpos : SV_Position;
    float2 uv   : TEXCOORD0;
};

/*=============================================================================
	Functions
=============================================================================*/

float noise(float2 co)
{
  return frac(sin(dot(co.xy ,float2(1.0,73))) * 437580.5453);
}

float4 CalcMotionLayer(VSOUT i, int mip_gcurr, float2 searchStart, sampler sGreyscaleCurr, sampler sGreyscalePrev, in float2 texcoord)
{	
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr - 3));
	float localBlock[64];

	for (uint k = 0; k < 64; k++) {
		localBlock[k] = tex2Dlod(sGreyscaleCurr, float4(i.uv + float2(k / 8, k % 8) * texelsize, 0, mip_gcurr - 3)).x;
	}
	
	float minsad = 1000000;
	int2 best_offset = 0;
	for (int x = -8; x < 8; x++)
	for (int y = -8; y < 8; y++) {
		float sad = 0;
		for (uint k = 0; k < 64; k++) {
			sad += abs(localBlock[k] - tex2Dlod(sGreyscalePrev, float4(i.uv + searchStart + float2((k / 8) + x, (k % 8) + y) * texelsize, 0, mip_gcurr - 3)).x);
		}
		if (sad < minsad || (sad == minsad && abs(x) + abs(y) < abs(best_offset.x) + abs(best_offset.y))) {
			minsad = sad;
			best_offset = int2(x, y);
		}
	}
	
	return float4(searchStart + best_offset * texelsize, 0, minsad);
}

float4 atrous_upscale(VSOUT i, int mip_gcurr, sampler sMotionLow)
{	
    return tex2Dlod(sMotionLow, float4(i.uv, 0, 0));
	/*float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr + 1));	
	float rand = frac(mip_gcurr * 0.2114 + (FRAME_COUNT % 16) * 0.6180339887498) * 3.1415927*0.5;
	float2x2 rotm = float2x2(cos(rand), -sin(rand), sin(rand), cos(rand)) * UI_ME_PYRAMID_UPSCALE_FILTER_RADIUS;
	const float3 gauss = float3(1, 0.85, 0.65);

	float4 gbuffer_sum = 0;
	float wsum = 1e-6;

	for(int x = -1; x <= 1; x++)
	for(int y = -1; y <= 1; y++)
	{
		float2 offs = mul(float2(x, y), rotm) * texelsize;
		float2 sample_uv = i.uv + offs;

		float4 sample_gbuf = tex2Dlod(sMotionLow, float4(sample_uv, 0, 0));

		float ws = saturate(1 - sample_gbuf.w * 4);
		float wf = saturate(1 - sample_gbuf.b * 128.0);
		float wm = dot(sample_gbuf.xy, sample_gbuf.xy) * 4;

		float weight = exp2(-(ws + wm + wf)) * gauss[abs(x)] * gauss[abs(y)];
		gbuffer_sum += sample_gbuf * weight;
		wsum += weight;		
	}

	return gbuffer_sum / wsum;*/
}

/*=============================================================================
	Shader Entry Points
=============================================================================*/

void PSWriteGreyscale(in VSOUT i, out float2 o : SV_Target0)
{    
    o = dot(tex2D(ColorInput, i.uv).rgb, float3(0.299, 0.587, 0.114));
}

void PSWriteGreyscalePrev(in VSOUT i, out float2 o : SV_Target0)
{    
    o = tex2D(sGreyscaleCurr, i.uv).r;
}

float4 motion_estimation(in VSOUT i, sampler sMotionLow, sampler sGreyscaleCurr, sampler sGreyscalePrev, int mip_gcurr, float2 texcoord : TexCoord)
{
	float4 upscaledLowerLayer = 0;

	[branch]
	if(UI_ME_LAYER_MIN < mip_gcurr) 
		return 0;

	[branch]
    if(mip_gcurr < UI_ME_LAYER_MIN)
    	upscaledLowerLayer = atrous_upscale(i, mip_gcurr, sMotionLow);
	
	[branch]
	if(mip_gcurr >= UI_ME_LAYER_MAX) {
		float4 norm = CalcMotionLayer(i, mip_gcurr, upscaledLowerLayer.xy, sGreyscaleCurr, sGreyscalePrev, texcoord);
		float4 oth = CalcMotionLayer(i, mip_gcurr, 0, sGreyscaleCurr, sGreyscalePrev, texcoord);
		if (norm.w < oth.w) {
			return norm;
		} else {
			return oth;
		}
	}
	  

    return upscaledLowerLayer;
}

void PSMotion6(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur7, sGreyscaleCurr, sGreyscalePrev, 6, texcoord);}
void PSMotion5(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur6, sGreyscaleCurr, sGreyscalePrev, 5, texcoord);}
void PSMotion4(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur5, sGreyscaleCurr, sGreyscalePrev, 4, texcoord);}
void PSMotion3(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur4, sGreyscaleCurr, sGreyscalePrev, 3, texcoord);}
void PSMotion2(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur3, sGreyscaleCurr, sGreyscalePrev, 2, texcoord);}
void PSMotion1(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur2, sGreyscaleCurr, sGreyscalePrev, 1, texcoord);}
void PSMotion0(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur1, sGreyscaleCurr, sGreyscalePrev, 0, texcoord);}

void PSWriteVectors(in VSOUT i, out float2 o : SV_Target0)
{
	o = tex2D(sMotionTexCur0, i.uv).xy;
}

float4 FrameInterpolationPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 m = tex2D(sMotionVectorTex, uv).xy;
	if (SHOWME) {
		return float4(m * 100, (m.x + m.y) * -100, 1);
	}
	float2 shift = uv - m * 0.5;
	float4 im = tex2D(sGreyscaleCurr, uv);
	float4 shifted = tex2D(sGreyscaleCurr, shift);
	#if UsePreviousFrame
		if (distance(shifted, tex2D(sGreyscalePrev, shift)) < Threshold ||
			distance(im, tex2D(sGreyscalePrev, uv)) < Threshold ||
			distance(shifted, tex2D(sGreyscalePrev, uv + m * 0.5)) > Threshold2) {
			return tex2D(ReShade::BackBuffer, uv);
		}
	#endif
	return tex2D(ReShade::BackBuffer, shift);
}

/*=============================================================================
	Techniques
=============================================================================*/

technique FrameInterpolationBuiltIn
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteGreyscale; 
        RenderTarget = GreyscaleCurr; 

	}

    pass {VertexShader = PostProcessVS;PixelShader = PSMotion6;RenderTarget = MotionTexCur6;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion5;RenderTarget = MotionTexCur5;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion4;RenderTarget = MotionTexCur4;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion3;RenderTarget = MotionTexCur3;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion2;RenderTarget = MotionTexCur2;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion1;RenderTarget = MotionTexCur1;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion0;RenderTarget = MotionTexCur0;}

	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteVectors; 
		RenderTarget = texMotionVectors;
	} 

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = FrameInterpolationPass;
	}  

	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteGreyscalePrev; 
        RenderTarget = GreyscalePrev; 
	}
}

