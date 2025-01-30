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
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr));
	float localBlock[BLOCK_AREA];
	float searchBlock[BLOCK_AREA];	 

	float2 moments_local = 0;
	float2 moments_search = 0;
	float moment_covariate = 0;

	i.uv -= texelsize * BLOCK_SIZE_HALF; //since we only use to sample the blocks now, offset by half a block so we can do it easier inline

	for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
	{
		float2 tuv = i.uv + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize;
		float t_local = tex2Dlod(sGreyscaleCurr, float4(tuv, 0, mip_gcurr)).x;
		float t_search = tex2Dlod(sGreyscalePrev, float4(tuv + searchStart, 0, mip_gcurr)).x;

		localBlock[k] = t_local; 
		searchBlock[k] = t_search;

		moments_local += float2(t_local, t_local * t_local);			
		moments_search += float2(t_search, t_search * t_search);
		moment_covariate += t_local * t_search;
	}

	moments_local /= BLOCK_AREA;
	moments_search /= BLOCK_AREA;
	moment_covariate /= BLOCK_AREA;

	float best_sim = moment_covariate * rsqrt(moments_local.y * moments_search.y);

	float local_features = abs(moments_local.x * moments_local.x - moments_local.y);
	float best_features = abs(moments_search.x * moments_search.x - moments_search.y);

	float2 bestMotion = 0;
	float2 searchCenter = searchStart;    

	float randseed = noise(texcoord);
	randseed = frac(randseed + (FRAME_COUNT % 16) * UI_ME_SAMPLES_PER_ITERATION * UI_ME_MAX_ITERATIONS_PER_LEVEL * 0.6180339887498);
	float2 randdir; sincos(randseed * 6.283, randdir.x, randdir.y);
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

			float2 moments_candidate = 0;			
			moment_covariate = 0;

			[loop]
			for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
			{
				float t = tex2Dlod(sGreyscalePrev, float4(samplePos + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize, 0, mip_gcurr)).x;
				moments_candidate += float2(t, t * t);
				moment_covariate += t * localBlock[k];
			}
			moments_candidate /= BLOCK_AREA;
			moment_covariate /= BLOCK_AREA;

			float candidate_similarity = moment_covariate * rsqrt(moments_local.y * moments_candidate.y);

			[flatten]
			if(candidate_similarity > best_sim)					
			{
				best_sim = candidate_similarity;
				bestMotion = pixelOffset;
				best_features = abs(moments_candidate.x * moments_candidate.x - moments_candidate.y);
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

void PSWriteColorAndDepth(in VSOUT i, out float2 o : SV_Target0)
{    
	float depth = ReShade::GetLinearizedDepth(i.uv);
	float luma = dot(tex2D(ColorInput, i.uv).rgb, float3(0.299, 0.587, 0.114));
    o = float2(luma, depth);
}

float4 motion_estimation(in VSOUT i, sampler sMotionLow, sampler sGreyscaleCurr, sampler sGreyscalePrev, int mip_gcurr, float2 texcoord : TexCoord)
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
		upscaledLowerLayer = CalcMotionLayer(i, mip_gcurr, upscaledLowerLayer.xy, sGreyscaleCurr, sGreyscalePrev, texcoord);
	  

    return upscaledLowerLayer;
}

void PSMotion6(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur7, sGreyscaleCurr, sGreyscalePrev, 6, texcoord);}
void PSMotion5(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur6, sGreyscaleCurr, sGreyscalePrev, 5, texcoord);}
void PSMotion4(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur5, sGreyscaleCurr, sGreyscalePrev, 4, texcoord);}
void PSMotion3(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur4, sGreyscaleCurr, sGreyscalePrev, 3, texcoord);}
void PSMotion2(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur3, sGreyscaleCurr, sGreyscalePrev, 2, texcoord);}
void PSMotion1(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur2, sGreyscaleCurr, sGreyscalePrev, 1, texcoord);}
void PSMotion0(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur1, sGreyscaleCurr, sGreyscalePrev, 0, texcoord);}

void PSOut(in VSOUT i, out float4 o : SV_Target0)
{
	if(!SHOWME) discard;
	float2 m = tex2D(sMotionTexCur0, i.uv).xy;
	o = float4(m * 100, (m.x + m.y) * -100, 1);
}

void PSWriteVectors(in VSOUT i, out float2 o : SV_Target0)
{
	o = tex2D(sMotionTexCur0, i.uv).xy;
}

/*=============================================================================
	Techniques
=============================================================================*/

technique EstimateMotion
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteColorAndDepth; 
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
		PixelShader  = PSWriteColorAndDepth; 
        RenderTarget0 = GreyscalePrev; 
	}
	
	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteVectors; 
		RenderTarget = texMotionVectors;
	} 

    pass 
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSOut; 
	}     
}
