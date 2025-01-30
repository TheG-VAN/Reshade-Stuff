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

#ifndef WIDTH_SCREEN_RESOLUTION
 #define WIDTH_SCREEN_RESOLUTION	1920 
#endif

#ifndef HEIGHT_SCREEN_RESOLUTION
 #define HEIGHT_SCREEN_RESOLUTION	1080 
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

texture texMotionVectors3          { Width = WIDTH_SCREEN_RESOLUTION;   Height = HEIGHT_SCREEN_RESOLUTION;   Format = RG16F; };
sampler sMotionVectorTex         { Texture = texMotionVectors3;  };

texture MotionTex2Cur7               { Width = WIDTH_SCREEN_RESOLUTION >> 7;   Height = HEIGHT_SCREEN_RESOLUTION >> 7;   Format = RGBA16F;  };
sampler sMotionTex2Cur7              { Texture = MotionTex2Cur7;};
texture MotionTex2Cur6               { Width = WIDTH_SCREEN_RESOLUTION >> 6;   Height = HEIGHT_SCREEN_RESOLUTION >> 6;   Format = RGBA16F;  };
sampler sMotionTex2Cur6              { Texture = MotionTex2Cur6;};
texture MotionTex2Cur5               { Width = WIDTH_SCREEN_RESOLUTION >> 5;   Height = HEIGHT_SCREEN_RESOLUTION >> 5;   Format = RGBA16F;  };
sampler sMotionTex2Cur5              { Texture = MotionTex2Cur5;};
texture MotionTex2Cur4               { Width = WIDTH_SCREEN_RESOLUTION >> 4;   Height = HEIGHT_SCREEN_RESOLUTION >> 4;   Format = RGBA16F;  };
sampler sMotionTex2Cur4              { Texture = MotionTex2Cur4;};
texture MotionTex2Cur3               { Width = WIDTH_SCREEN_RESOLUTION >> 3;   Height = HEIGHT_SCREEN_RESOLUTION >> 3;   Format = RGBA16F;  };
sampler sMotionTex2Cur3              { Texture = MotionTex2Cur3;};
texture MotionTex2Cur2               { Width = WIDTH_SCREEN_RESOLUTION >> 2;   Height = HEIGHT_SCREEN_RESOLUTION >> 2;   Format = RGBA16F;  };
sampler sMotionTex2Cur2              { Texture = MotionTex2Cur2;};
texture MotionTex2Cur1               { Width = WIDTH_SCREEN_RESOLUTION >> 1;   Height = HEIGHT_SCREEN_RESOLUTION >> 1;   Format = RGBA16F;  };
sampler sMotionTex2Cur1              { Texture = MotionTex2Cur1;};

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

float min3(float3 xyz) {
	return min(min(xyz.x, xyz.y), xyz.z);
}

float4 CalcMotionLayer(VSOUT i, int mip_gCurr, float2 searchStart, sampler sCurr, sampler sPrev, in float2 texcoord)
{	
	float2 texelsize = rcp(float2(WIDTH_SCREEN_RESOLUTION, HEIGHT_SCREEN_RESOLUTION) / exp2(mip_gCurr));
	float3 localBlock[BLOCK_AREA];
	float3 searchBlock[BLOCK_AREA];	 

	float3 moments_local = 0;
	float3 moments_local2 = 0;
	float3 moments_search = 0;
	float3 moments_search2 = 0;
	float3 moment_covariate = 0;

	i.uv -= texelsize * BLOCK_SIZE_HALF; //since we only use to sample the blocks now, offset by half a block so we can do it easier inline

	for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
	{
		float2 tuv = i.uv + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize;
		float3 t_local = tex2Dlod(sCurr, float4(tuv, 0, mip_gCurr)).xyz;
		float3 t_search = tex2Dlod(sPrev, float4(tuv + searchStart, 0, mip_gCurr)).xyz;

		localBlock[k] = t_local; 
		searchBlock[k] = t_search;

		moments_local += t_local;
		moments_local2 += t_local * t_local;
		moments_search += t_search;
		moments_search2 += t_search * t_search;
		moment_covariate += t_local * t_search;
	}

	moments_local /= BLOCK_AREA;
	moments_local2 /= BLOCK_AREA;
	moments_search /= BLOCK_AREA;
	moments_search2 /= BLOCK_AREA;
	moment_covariate /= BLOCK_AREA;

	float3 cossim = moment_covariate * rsqrt(moments_local2 * moments_search2);
	float best_sim = saturate(min3(cossim));

	float best_features = min3(abs(moments_search * moments_search - moments_search2));

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

			float3 moments_candidate = 0;		
			float3 moments_candidate2 = 0;				
			moment_covariate = 0;

			[loop]
			for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
			{
				float3 t = tex2Dlod(sPrev, float4(samplePos + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize, 0, mip_gCurr)).xyz;
				moments_candidate += t;
				moments_candidate2 += t * t;
				moment_covariate += t * localBlock[k];
			}
			moments_candidate /= BLOCK_AREA;
			moments_candidate2 /= BLOCK_AREA;
			moment_covariate /= BLOCK_AREA;

			cossim = moment_covariate * rsqrt(moments_local2 * moments_candidate2); 
			float candidate_similarity = saturate(min3(cossim.z));

			[flatten]
			if(candidate_similarity > best_sim)					
			{
				best_sim = candidate_similarity;
				bestMotion = pixelOffset;
				best_features = min3(abs(moments_candidate * moments_candidate - moments_candidate2));
			}			
		}
		searchCenter += bestMotion;
		bestMotion = 0;
		scale *= 0.5;
	}

	return float4(searchCenter, sqrt(best_features), best_sim * best_sim * best_sim * best_sim);  //delayed sqrt for variance -> stddev, cossim^4 for filter
}

float4 atrous_upscale(VSOUT i, int mip_gCurr, sampler sMotionLow)
{	
    float2 texelsize = rcp(float2(WIDTH_SCREEN_RESOLUTION, HEIGHT_SCREEN_RESOLUTION) / exp2(mip_gCurr + 1));	
	float rand = frac(mip_gCurr * 0.2114 + (FRAME_COUNT % 16) * 0.6180339887498) * 3.1415927*0.5;
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
		float wf = saturate(1 - sample_gbuf.z * 128.0);
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

float4 motion_estimation(in VSOUT i, sampler sMotionLow, sampler sCurr, sampler sPrev, int mip_gCurr, float2 texcoord : TexCoord)
{
	float4 upscaledLowerLayer = 0;

	[branch]
	if(UI_ME_LAYER_MIN <= (mip_gCurr-1)) 
		return 0;

	[branch]
    if(mip_gCurr < UI_ME_LAYER_MIN)
    	upscaledLowerLayer = atrous_upscale(i, mip_gCurr, sMotionLow);
	
	[branch]
	if(mip_gCurr >= UI_ME_LAYER_MAX) 
		upscaledLowerLayer = CalcMotionLayer(i, mip_gCurr, upscaledLowerLayer.xy, sCurr, sPrev, texcoord);
	  

    return upscaledLowerLayer;
}

void PSMotion6(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur7, sCurr, sPrev, 6, texcoord);}
void PSMotion5(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur6, sCurr, sPrev, 5, texcoord);}
void PSMotion4(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur5, sCurr, sPrev, 4, texcoord);}
void PSMotion3(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur4, sCurr, sPrev, 3, texcoord);}
void PSMotion2(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur3, sCurr, sPrev, 2, texcoord);}
void PSMotion1(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur2, sCurr, sPrev, 1, texcoord);}
void PSMotion0(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTex2Cur1, sCurr, sPrev, 0, texcoord);}

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

technique FrameInterpolationBultin4
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteColor; 
        RenderTarget = Curr; 

	}

    pass {VertexShader = PostProcessVS;PixelShader = PSMotion6;RenderTarget = MotionTex2Cur6;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion5;RenderTarget = MotionTex2Cur5;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion4;RenderTarget = MotionTex2Cur4;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion3;RenderTarget = MotionTex2Cur3;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion2;RenderTarget = MotionTex2Cur2;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion1;RenderTarget = MotionTex2Cur1;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion0;RenderTarget = texMotionVectors3;}
	
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
