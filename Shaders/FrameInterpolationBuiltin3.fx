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
> = 0.25;

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

texture Curr          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 8; };
sampler sCurr         { Texture = Curr;  };
texture Prev          { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 8; };
sampler sPrev         { Texture = Prev;   };

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

float2 three2two(float3 col) {
	return float2(col.r + col.g / 2, col.g / 2 + col.b) * 2 / 3;
}

float4 CalcMotionLayer(VSOUT i, int mip_gcurr, float2 searchStart, sampler sCurr, sampler sPrev, in float2 texcoord)
{	
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr));
	float2 localBlock[BLOCK_AREA];
	float2 searchBlock[BLOCK_AREA];	 

	float4 moments_local = 0;
	float4 moments_search = 0;
	float2 moment_covariate = 0;

	i.uv -= texelsize * BLOCK_SIZE_HALF; //since we only use to sample the blocks now, offset by half a block so we can do it easier inline

	for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
	{
		float2 tuv = i.uv + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize;
		float2 t_local = three2two(tex2Dlod(sCurr, float4(tuv, 0, mip_gcurr)).xyz);
		float2 t_search = three2two(tex2Dlod(sPrev, float4(tuv + searchStart, 0, mip_gcurr)).xyz);

		localBlock[k] = t_local; 
		searchBlock[k] = t_search;

		moments_local += float4(t_local, t_local * t_local);			
		moments_search += float4(t_search, t_search * t_search);
		moment_covariate += t_local * t_search;
	}

	moments_local /= BLOCK_AREA;
	moments_search /= BLOCK_AREA;
	moment_covariate /= BLOCK_AREA;

	float2 cossim = moment_covariate * rsqrt(moments_local.zw * moments_search.zw);
	float best_sim = saturate(min(cossim.x, cossim.y));

	float local_features = abs(moments_local.x * moments_local.x - moments_local.z);
	float best_features = abs(moments_search.x * moments_search.x - moments_search.z);

	float2 bestMotion = 0;
	float2 searchCenter = searchStart;    

	float randseed = noise(texcoord);
	randseed = frac(randseed + (FRAME_COUNT % 16) * UI_ME_SAMPLES_PER_ITERATION * UI_ME_MAX_ITERATIONS_PER_LEVEL * 0.6180339887498);
	float2 randdir; sincos(randseed * 6.283, randdir.x, randdir.y); //yo dawg, I heard you like golden ratios
	float2 scale = texelsize;

	[loop]
	for(int j = 0; j < UI_ME_MAX_ITERATIONS_PER_LEVEL && best_sim < 0.999999; j++)
	{
		[loop]
		for (int s = 1; s < UI_ME_SAMPLES_PER_ITERATION && best_sim < 0.999999; s++) 
		{
			randdir = mul(randdir, float2x2(-0.7373688, 0.6754903, -0.6754903, -0.7373688));//rotate by larger golden angle			
			float2 pixelOffset = randdir * scale;
			float2 samplePos = i.uv + searchCenter + pixelOffset;			 

			float4 moments_candidate = 0;			
			moment_covariate = 0;

			[loop]
			for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
			{
				float2 t = three2two(tex2Dlod(sPrev, float4(samplePos + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize, 0, mip_gcurr)).xyz);
				moments_candidate += float4(t, t * t);
				moment_covariate += t * localBlock[k];
			}
			moments_candidate /= BLOCK_AREA;
			moment_covariate /= BLOCK_AREA;

			cossim = moment_covariate * rsqrt(moments_local.zw * moments_candidate.zw); 
			float candidate_similarity = saturate(min(cossim.x, cossim.y));

			[flatten]
			if(candidate_similarity > best_sim)					
			{
				best_sim = candidate_similarity;
				bestMotion = pixelOffset;
				best_features = abs(moments_candidate.x * moments_candidate.x - moments_candidate.z);
			}			
		}
		searchCenter += bestMotion;
		bestMotion = 0;
		scale *= 0.5;
	}

	return float4(searchCenter, sqrt(best_features), best_sim * best_sim * best_sim * best_sim);  //delayed sqrt for variance -> stddev, cossim^4 for filter
}

float4 atrous_upscale(VSOUT i, int mip_gcurr, sampler sMotionLow)
{	
    float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr + 1));	
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

	return gbuffer_sum / wsum;	
}

/*=============================================================================
	Shader Entry Points
=============================================================================*/

void PSWriteColor(in VSOUT i, out float4 o : SV_Target0)
{    
    o = tex2D(ColorInput, i.uv);
}

void PSWritePrevColor(in VSOUT i, out float4 o : SV_Target0)
{    
    o = tex2D(sCurr, i.uv);
}

float4 motion_estimation(in VSOUT i, sampler sMotionLow, sampler sCurr, sampler sPrev, int mip_gcurr, float2 texcoord : TexCoord)
{
	float4 upscaledLowerLayer = 0;

	[branch]
	if(UI_ME_LAYER_MIN <= (mip_gcurr-1)) 
		return 0;

	[branch]
    if(mip_gcurr < UI_ME_LAYER_MIN)
    	upscaledLowerLayer = atrous_upscale(i, mip_gcurr, sMotionLow);
	
	[branch]
	if(mip_gcurr >= UI_ME_LAYER_MAX) 
		upscaledLowerLayer = CalcMotionLayer(i, mip_gcurr, upscaledLowerLayer.xy, sCurr, sPrev, texcoord);
	  

    return upscaledLowerLayer;
}

void PSMotion6(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur7, sCurr, sPrev, 6, texcoord);}
void PSMotion5(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur6, sCurr, sPrev, 5, texcoord);}
void PSMotion4(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur5, sCurr, sPrev, 4, texcoord);}
void PSMotion3(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur4, sCurr, sPrev, 3, texcoord);}
void PSMotion2(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur3, sCurr, sPrev, 2, texcoord);}
void PSMotion1(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur2, sCurr, sPrev, 1, texcoord);}
void PSMotion0(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur1, sCurr, sPrev, 0, texcoord);}

float4 FrameInterpolationPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 m = tex2D(sMotionVectorTex, uv).xy;
	if (SHOWME) return float4(m * 100, (m.x + m.y) * -100, 1);
	float2 shift = uv - m * 0.5;
	float4 im = tex2D(ReShade::BackBuffer, uv);
	float4 shifted = tex2D(ReShade::BackBuffer, shift);
	if (distance(shifted, tex2D(sPrev, shift)) < Threshold ||
		distance(im, tex2D(sPrev, uv)) < Threshold ||
		distance(shifted, tex2D(sPrev, uv + m * 0.5)) > Threshold2) {
		return im;
	}
	if (distance(shifted, im) < distance(tex2D(sPrev, uv + m * 0.5), im)) {
		return shifted;
	} else {
		return tex2D(sPrev, uv + m * 0.5);
	}
}

/*=============================================================================
	Techniques
=============================================================================*/

technique FrameInterpolationBultin3
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteColor; 
        RenderTarget = Curr; 

	}

    pass {VertexShader = PostProcessVS;PixelShader = PSMotion6;RenderTarget = MotionTexCur6;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion5;RenderTarget = MotionTexCur5;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion4;RenderTarget = MotionTexCur4;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion3;RenderTarget = MotionTexCur3;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion2;RenderTarget = MotionTexCur2;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion1;RenderTarget = MotionTexCur1;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion0;RenderTarget = texMotionVectors;}
	
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = FrameInterpolationPass;
	}
    
	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWritePrevColor; 
        RenderTarget0 = Prev; 
	}
}
